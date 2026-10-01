# Manager plans

1. Owner installs clean preview `4.0.0-preview.16` over the currently installed 4.0 preview.
2. Owner fully closes Yandex Browser before the explicit Network Recorder reinstall/migration.
3. Verify that `Проверить` no longer treats the exact old ExtensionInstaller v3 registration as foreign and no longer reports registry metadata alone as an installed browser extension.
4. Use the enabled install/reinstall action to install Network Recorder v1.6.0 from its signed GitHub prerelease; for a user-removed external extension, clear only the target `external_uninstalls` marker and migrate the legacy registration to the new managed CRX path.
5. Start/restart Yandex Browser and verify Extension ID `paolfcaakecapidipfcfbbhgkpcmgcip`, actual registration, extension startup and normal Network Recorder behavior.
6. If the real install passes, promote Network Recorder v1.6.0 to a stable GitHub Release and switch its catalog channel from `prerelease` to `stable`.
7. Produce a later Network Recorder release and verify a real update through ExtensionInstaller.
8. After install/update verification and explicit owner approval, designate a stable ExtensionInstaller release.
