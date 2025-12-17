#!perl -T

use strict;
use warnings;

use Test::More;

use_ok('Module::CoreList::SBOM');

done_testing();

diag("Module::CoreList::SBOM $Module::CoreList::SBOM::VERSION, Perl $], $^X");
