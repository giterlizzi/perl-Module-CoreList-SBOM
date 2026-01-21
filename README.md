[![Release](https://img.shields.io/github/release/giterlizzi/perl-Module-CoreList-SBOM.svg)](https://github.com/giterlizzi/perl-Module-CoreList-SBOM/releases) [![Actions Status](https://github.com/giterlizzi/perl-Module-CoreList-SBOM/workflows/linux/badge.svg)](https://github.com/giterlizzi/perl-Module-CoreList-SBOM/actions) [![License](https://img.shields.io/github/license/giterlizzi/perl-Module-CoreList-SBOM.svg)](https://github.com/giterlizzi/perl-Module-CoreList-SBOM) [![Starts](https://img.shields.io/github/stars/giterlizzi/perl-Module-CoreList-SBOM.svg)](https://github.com/giterlizzi/perl-Module-CoreList-SBOM) [![Forks](https://img.shields.io/github/forks/giterlizzi/perl-Module-CoreList-SBOM.svg)](https://github.com/giterlizzi/perl-Module-CoreList-SBOM) [![Issues](https://img.shields.io/github/issues/giterlizzi/perl-Module-CoreList-SBOM.svg)](https://github.com/giterlizzi/perl-Module-CoreList-SBOM/issues) [![Coverage Status](https://coveralls.io/repos/github/giterlizzi/perl-Module-CoreList-SBOM/badge.svg)](https://coveralls.io/github/giterlizzi/perl-Module-CoreList-SBOM)

# Module-CoreList-SBOM (Software Bill of Materials) generator for Modules::CoreList

## Synopsis

```.bash
corelist-sbom <PerlVersion> [--disable-metacpan] [--output,-o FILENAME]
corelist-sbom [--help|--man|-v]


Options:
  -o, --output            Output file. Default perl-core-<PerlVersion>.bom.json
      --disable-metacpan  Disable MetaCPAN client

      --help              Brief help message
      --man               Full documentation
  -v, --version           Print version
```

## Install

Using Makefile.PL:

To install `Module-CoreList-SBOM` distribution, run the following commands.

    perl Makefile.PL
    make
    make test
    make install

Using `App::cpanminus`:

    cpanm Modules::CoreList::SBOM


## Documentation

- `perldoc Modules::CoreList::SBOM`
- https://metacpan.org/release/Module-CoreList-SBOM

## Copyright

- Copyright 2025 © Giuseppe Di Terlizzi
