# Solc Archive

This repo contains an archive of historical solidity compilers plus some tools for fetching & verifying them.

The `refresh.sh` script in the project root should be run periodically to keep the lists of available versions up-to-date and to download any new versions that aren't present in this repo yet. SHA256 checksums will be verified for all present solc versions every time `refresh.sh` is run including immediately after downloading a new version.

Additionally, it will download any new solc binaries that aren't present in this repo yet and verify their checksums.

Currently, we support 3 architectures:
- `linux-amd64`
- `macosx-amd64`
- `windows-amd64`

For each architecture, there is a folder of the same name which contains all solc binaries for that architecture. Additionally, each folder contains:
- `list-latest.json`: An auto-generated list of available solidity versions & their expected sha256 hash. Do not edit by hand otherwise your changes will be lost the next time `refresh.sh` is run.
- `list-legacy.json`: A manually curated list of unusual solc versions that aren't covered by the public list of supported versions. All manual additions & updates should happen in this file.
- `list.json`: An auto-generated list that is simply the combination of content from both `list-latest.json` and `list-legacy.json`. If a version is specified by both lists, the one from `list-legacy.json` will be prioritized here.
