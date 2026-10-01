# Next actions

1. Owner installs `ExtensionInstaller_Setup_v4.0.0-preview.16.exe` over the currently installed 4.0 preview.
2. Fully close Yandex Browser before attempting to reinstall Network Recorder that was previously removed through the browser UI.
3. Start ExtensionInstaller and press `Проверить`. The old v3 ExtensionInstaller registration must no longer be classified as a foreign installation; the UI should reflect that the extension is not actually installed / was removed through the browser.
4. Click the enabled install/reinstall action for Network Recorder v1.6.0. ExtensionInstaller should clear only the target browser user-uninstall marker, migrate the exact legacy-owned registration to the new managed CRX path, and preserve the pinned Extension ID.
5. Start/restart Yandex Browser and verify Extension ID `paolfcaakecapidipfcfbbhgkpcmgcip`, successful registration, extension startup and normal Network Recorder behavior.
6. After that real install passes, promote Network Recorder v1.6.0 to a stable GitHub Release and switch its catalog channel from `prerelease` to `stable`.
7. Produce a later Network Recorder release and verify a real update through ExtensionInstaller.
8. Only after install/update verification and explicit owner approval designate a stable ExtensionInstaller release.
