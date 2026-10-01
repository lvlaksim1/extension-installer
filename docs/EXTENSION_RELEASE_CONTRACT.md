# Extension release contract v1

## Scope

This contract defines what a browser-extension repository must publish so ExtensionInstaller can install/update it without access to the private signing key.

## Installer catalog entry

The installer owns a pinned catalog entry:

```json
{
  "slug": "example-extension",
  "name": "Example Extension",
  "repository": "lvlaksim1/example-extension",
  "extension_id": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "channel": "stable"
}
```

`extension_id` is an installer-side trust anchor. Release metadata is not allowed to silently change it.

`channel` may be `stable` or `prerelease`. `stable` resolves GitHub's latest stable Release. `prerelease` resolves the newest published non-draft prerelease and is intended for controlled integration testing.

## GitHub Release assets

Every installable extension release, whether stable or prerelease, must contain:

- exactly one `extension-release.json`;
- the signed CRX named by that descriptor.

A source ZIP may also be published for audit/debugging, but ExtensionInstaller does not use it for normal installation and never signs it locally.

## extension-release.json

Required fields:

```json
{
  "schema": "extension-installer-release",
  "schema_version": 1,
  "slug": "example-extension",
  "version": "1.2.3",
  "extension_id": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "crx_asset": "Example_Extension_v1.2.3.crx",
  "crx_sha256": "64-lowercase-hex-characters"
}
```

Optional forward-compatible fields may be added, but v1 consumers must reject a different `schema` or unsupported `schema_version`.

## Installer validation order

Before changing Yandex Browser registration, ExtensionInstaller must:

1. resolve the catalog entry;
2. fetch the selected GitHub Release;
3. download `extension-release.json`;
4. validate descriptor schema/version/slug/version/Extension ID;
5. resolve exactly one CRX asset matching `crx_asset`;
6. download CRX to a temporary path;
7. compute SHA-256 and compare with `crx_sha256`;
8. inspect CRX3 and derive its Extension ID from the embedded public key;
9. verify the CRX3 RSA/SHA-256 proof;
10. require inspected Extension ID == descriptor Extension ID == pinned catalog Extension ID;
11. only then move the CRX into installer-owned storage and update the Yandex Browser registry;
12. rollback registry/file state on any failure.

## Signing-key boundary

The private RSA key belongs to the extension repository's release environment/secret scope. It must never be:

- committed to either repository;
- embedded in release metadata;
- downloaded by ExtensionInstaller;
- copied into the owner's persistent local extension library;
- written to Context Capsule state or logs.

## Release storage

Release CRX files are GitHub Release assets. Normal Git history and retained Actions artifacts are not release storage.
