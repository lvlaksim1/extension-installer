# Procedural memory

## PM-001 — verify Windows PowerShell 5.1 explicitly

For Windows PowerShell scripts with non-ASCII UI text:
- keep an explicit UTF-8 BOM;
- parse/execute under Windows PowerShell 5.1 in CI;
- add a CI assertion for the BOM so encoding regressions fail early.

This was required for the clean ExtensionInstaller GUI/release engine.

## PM-002 — verify upgrade cleanup, not only fresh install

When replacing an old architecture under the same fixed installer AppId:
- seed representative obsolete files in the installed directory;
- run the new installer over the existing installation;
- assert obsolete files are removed;
- then continue reinstall/uninstall smoke tests.

This caught the important requirement that old `ExtensionInstaller.cmd` must physically disappear.

## PM-003 — use authenticated GitHub API only in CI when available

The installed application should work against public releases without a user token. CI may hit shared-IP API rate limits, so the release engine accepts an optional environment token for CI validation while keeping normal user operation token-free.

## PM-004 — validate extension releases independently

Do not trust the extension signing workflow alone. After publication, ExtensionInstaller should independently download the actual Release assets and verify:
- descriptor schema/slug/version/ID;
- SHA-256;
- CRX3 signature;
- CRX-derived Extension ID against the catalog trust anchor.

## PM-005 — avoid retained Actions artifacts

For distributable outputs, publish directly to GitHub Releases. Use ephemeral runner storage for intermediate files and verify the workflow leaves no retained Actions artifacts.
