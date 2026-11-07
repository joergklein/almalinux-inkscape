# Inkscape Sources

This directory contains the source archives and patches used to build the Inkscape RPM package for AlmaLinux 10 (x86_64).

## Source archives

The Inkscape source archive is automatically downloaded and prepared by `scripts/prepare-sources.sh`.

The script retrieves the latest stable Inkscape release, including its required Git submodules, and creates the source archive used for the RPM build.

Generated source archives are not committed to the Git repository.

## Patches

The `patches/` directory contains patches for AlmaLinux 10 compatibility and RPM packaging.

Patches are maintained separately and applied during the RPM build process through the SPEC file.

## Directory structure

```text
SOURCES/
├── patches/
└── README.md
```

## Licensing

The Inkscape source code remains subject to its original upstream licenses.

Project-specific patches are distributed under the license specified in the repository's `LICENSE` file.

