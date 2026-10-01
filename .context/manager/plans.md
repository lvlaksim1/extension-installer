# Manager plans

Current plan for active intentions EI-PM-002…004:

1. Audit `src/ExtensionInstaller.cmd` and separate its responsibilities into discovery, validation, signing/building, browser registration, diagnostics and local state.
2. Define the extension release contract consumed by ExtensionInstaller:
   - repository identity;
   - extension ID;
   - version;
   - signed CRX asset;
   - optional source ZIP asset;
   - SHA-256/integrity metadata;
   - release channel and compatibility metadata.
3. Design the migration from local signing to GitHub-side signing so an existing RSA key continues to produce the same extension ID.
4. Refactor the installer so signed-CRX installation/update is the primary path and local private-key signing is not required for normal operation.
5. Add validation and diagnostics before removing/deprecating legacy code paths.
6. Use EINV Network Recorder as the first end-to-end integration after its own repository is created and signing secret is configured.
7. Verify installation/update against Yandex Browser before any stable installer release is designated.
