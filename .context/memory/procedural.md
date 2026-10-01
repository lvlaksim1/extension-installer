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

## PM-003 — use authenticated GitHub API only in CI when available

The installed application should work against public releases without a user token. CI may hit shared-IP API rate limits, so the release engine accepts an optional environment token for CI validation while keeping normal user operation token-free.

## PM-004 — validate extension releases independently

Do not trust the extension signing workflow alone. After publication, ExtensionInstaller should independently download the actual Release assets and verify descriptor fields, SHA-256, CRX3 signature, and CRX-derived Extension ID against the catalog trust anchor.

## PM-005 — avoid retained Actions artifacts

For distributable outputs, publish directly to GitHub Releases. Use ephemeral runner storage for intermediate files and verify the workflow leaves no retained Actions artifacts.

## PM-006 — test external-extension state as a multi-source state machine

Do not equate `HKCU\Software\Yandex\YandexBrowser\Extensions\<id>` with “installed”.

For migration/reinstall tests cover at least:
- actual extension version directories under Yandex browser profiles;
- the external registry registration;
- ExtensionInstaller-owned state/CRX path;
- exact v3 legacy-owned `UniversalExtensionBuilder\projects\<id>\crx` path;
- Chromium/Yandex `extensions.external_uninstalls` after user removal;
- unrelated/foreign registry paths.

An explicit reinstall after browser-UI removal should require Yandex to be closed, edit only the target uninstall marker, and roll back Preferences if installation later fails.

## PM-007 — avoid replacement-string metacharacter corruption when generating source

When programmatically inserting source with JavaScript `String.replace`, use a replacement callback rather than a raw replacement string if inserted text can contain JavaScript replacement tokens such as `$'`. The initial browser-state patch was corrupted by such replacement semantics and was caught by the Windows PowerShell 5.1 validation run before release.
