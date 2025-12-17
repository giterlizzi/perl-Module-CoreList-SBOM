package Module::CoreList::SBOM;

use 5.010001;
use strict;
use warnings;
use utf8;

use Carp;
use Getopt::Long qw(GetOptionsFromArray);
use MetaCPAN::Client;
use Module::CoreList::Utils;
use Module::CoreList;
use Pod::Usage;
use URI::PackageURL;

use SBOM::CycloneDX::Component;
use SBOM::CycloneDX::ExternalReference;
use SBOM::CycloneDX::License;
use SBOM::CycloneDX::OrganizationalContact;
use SBOM::CycloneDX::Util qw(cpan_meta_to_spdx_license cyclonedx_tool cyclonedx_component);
use SBOM::CycloneDX;

our $VERSION = '1.00';


sub DEBUG { $ENV{SBOM_DEBUG} || 0 }

sub cli_error {
    my ($error, $code) = @_;
    $error =~ s/ at .* line \d+.*//;
    say STDERR "ERROR: $error";
    return $code || 1;
}

sub show_version {

    (my $progname = $0) =~ s/.*\///;

    say <<"VERSION";
$progname version $Module::CoreList::SBOM::VERSION

Copyright 2025, Giuseppe Di Terlizzi <gdt\@cpan.org>

This program is part of the "Module-CoreList-SBOM" distribution and is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.

Complete documentation for $progname can be found using 'man $progname'
or on the internet at <https://metacpan.org/dist/Module-CoreList-SBOM>.
VERSION

    return 0;

}

sub run {

    my (@args) = @_;

    my %options = ('disable-metacpan' => 0, help => undef, version => undef, man => undef, v => undef);

    GetOptionsFromArray(
        \@args, \%options, qw(
            help|h
            man
            version
            debug|d

            v=s
            output|o=s
            disable-metacpan
        )
    ) or pod2usage(-verbose => 0);

    pod2usage(-exitstatus => 0, -verbose => 2) if defined $options{man};
    pod2usage(-exitstatus => 0, -verbose => 0) if defined $options{help};

    if (defined $options{version}) {
        return show_version();
    }

    my $mcpan = MetaCPAN::Client->new;

    my $perl_version          = $options{v} || $];
    my $perl_version_numified = version->new($perl_version)->numify;

    my $modules   = Module::CoreList->find_version($perl_version_numified);
    my @utilities = Module::CoreList::Utils->utilities($perl_version_numified);

    unless (keys %{$modules}) {
        say "Module::CoreList has no info on perl $perl_version_numified";
        exit 1;
    }

    my $bom = SBOM::CycloneDX->new;

    my $root_component = SBOM::CycloneDX::Component->new(
        type     => 'platform',
        name     => 'Perl',
        version  => $perl_version_numified,
        licenses => [SBOM::CycloneDX::License->new(id => cpan_meta_to_spdx_license('perl_5'))],
        bom_ref  => "perl\@$perl_version_numified",
        purl     => URI::PackageURL->new(type => 'generic', name => 'perl', version => $perl_version)
    );

    my $metadata = $bom->metadata;

    $metadata->tools->push(cyclonedx_tool());

    $metadata->component($root_component);

    my $total = scalar keys %{$modules};
    my $i     = 0;

    foreach my $module_name (sort keys %{$modules}) {

        $i++;

        my $module_version = $modules->{$module_name} || '0.00';

        my $distribution        = undef;
        my $author              = undef;
        my @authors             = ();
        my @licenses            = ();
        my $version             = undef;
        my $abstract            = undef;
        my @external_references = ();

        say STDERR "[$total / $i] $module_name @ $module_version";

        unless ($options{'disable-metacpan'}) {

            my $module = eval { $mcpan->module($module_name) };

            unless ($@) {

                my $filter = {all => [{distribution => $module->distribution}, {version => $module_version}]};

                my $release = $mcpan->release($filter);

                if ($release->total == 0) {
                    say STDERR "\t(!) Fallback to perl @ $perl_version";
                    $filter  = {all => [{distribution => 'perl'}, {version => $perl_version_numified}]};
                    $release = $mcpan->release($filter);
                }

                while (my $r = $release->next) {

                    $distribution = $r->distribution;
                    $version      = $r->version;
                    $author       = $r->author;
                    $abstract     = $r->abstract;

                    @licenses = ();
                    @authors  = make_authors($r->metadata->{author});

                    foreach my $license (@{$r->license}) {
                        next if $license eq 'unknown';
                        my $spdx_license = cpan_meta_to_spdx_license($license);
                        push @licenses, SBOM::CycloneDX::License->new($spdx_license);
                    }

                    @external_references = make_external_references($r->metadata->{resources});

                }

            }

        }

        my $component = SBOM::CycloneDX::Component->new(
            type    => 'library',
            name    => $module_name,
            group   => 'perl.core',
            version => $module_version,
            bom_ref => "perl-core:module/$module_name\@$module_version",
        );

        if ($abstract) {
            $component->description($abstract);
        }

        if (@external_references) {
            $component->external_references(\@external_references);
        }

        if (@licenses) {
            $component->licenses(\@licenses);
        }

        if (@authors) {
            $component->authors(\@authors);
        }

        if ($distribution && $author) {

            my $purl = URI::PackageURL->new(type => 'cpan', namespace => $author, name => $distribution,
                version => $version);

            say STDERR "\t$purl";

            $component->purl($purl);

        }

        $bom->components->add($component);
        $bom->add_dependency($root_component, [$component]);

    }

    foreach my $utility (@utilities) {

        my $component = SBOM::CycloneDX::Component->new(
            type    => 'application',
            name    => $utility,
            group   => 'perl.util',
            bom_ref => "perl-core:util/$utility",
        );

        $bom->components->add($component);
        $bom->add_dependency($root_component, [$component]);

    }

    my @errors = $bom->validate;

    if (@errors) {

        say STDERR "Validation errors:";
        say STDERR " - $_" for @errors;

    }

    my $filename = $options{output} // sprintf('perl-core-%s.bom.json', version->new($perl_version_numified)->normal);

    say STDERR "Write SBOM file to $filename";

    open my $fh, '>', $filename or Carp::croak "Failed to open file: $!";

    say $fh $bom->to_string;

    close $fh;

}

# Utilities from Module::CoreList::SBOM

sub make_external_references {

    my $resources = shift;

    my @external_references = ();

    foreach my $type (keys %{$resources}) {

        my $resource = $resources->{$type};

        if ($type eq 'repository' && defined $resource->{url}) {
            push @external_references, SBOM::CycloneDX::ExternalReference->new(type => 'vcs', url => $resource->{url});
        }

        if ($type eq 'bugtracker' && defined $resource->{web}) {
            push @external_references,
                SBOM::CycloneDX::ExternalReference->new(type => 'issue-tracker', url => $resource->{web});
        }
    }

    return @external_references;

}

sub make_authors {

    my $metadata_authors = shift;

    my @authors = ();

    foreach my $metadata_author (@{$metadata_authors}) {
        if ($metadata_author =~ /(.*) <(.*)>/) {
            my ($name, $email) = $metadata_author =~ /(.*) <(.*)>/;
            push @authors, SBOM::CycloneDX::OrganizationalContact->new(name => $name, email => _clean_email($email));
        }
        elsif ($metadata_author =~ /(.*), (.*)/) {
            my ($name, $email) = $metadata_author =~ /(.*), (.*)/;
            push @authors, SBOM::CycloneDX::OrganizationalContact->new(name => $name, email => _clean_email($email));
        }
        else {
            push @authors, SBOM::CycloneDX::OrganizationalContact->new(name => $metadata_author);
        }
    }

    return @authors;

}

sub _clean_email {

    my $email = shift;

    $email =~ s/E<lt>//;
    $email =~ s/<lt>//;
    $email =~ s/<gt>//;
    $email =~ s/\[at\]/@/;

    return $email;

}

1;

__END__

=encoding utf-8

=head1 NAME

Module::CoreList::SBOM - Generate SBOM (Software Bill of Materials) from Module::CoreList

=head1 SYNOPSIS

    use Module::CoreList::SBOM qw(run);

    run(\@ARGV);

=head1 DESCRIPTION

L<Module::CoreList::SBOM> is a "Command Line Interface" helper module for C<corelist-sbom(1)> command.

=head2 METHODS

=over

=item Module::CoreList::SBOM->run(@args)

=back

Execute the command

=head1 SUPPORT

=head2 Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at L<https://github.com/giterlizzi/perl-Module-CoreList-SBOM/issues>.
You will be notified automatically of any progress on your issue.

=head2 Source Code

This is open source software.  The code repository is available for
public review and contribution under the terms of the license.

L<https://github.com/giterlizzi/perl-Module-CoreList-SBOM>

    git clone https://github.com/giterlizzi/perl-Module-CoreList-SBOM.git


=head1 AUTHOR

=over 4

=item * Giuseppe Di Terlizzi <gdt@cpan.org>

=back


=head1 LICENSE AND COPYRIGHT

This software is copyright (c) 2025 by Giuseppe Di Terlizzi.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
