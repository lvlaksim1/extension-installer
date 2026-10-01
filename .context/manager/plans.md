# Manager plans

1. Owner installs clean preview `4.0.0-preview.11` over the currently installed older preview.
2. Verify on the owner's PC that the old folder/ZIP UI and obsolete installed `ExtensionInstaller.cmd` are gone.
3. Verify that Network Recorder appears automatically from the catalog with no local folder/file selection.
4. Use the new GUI to resolve and install Network Recorder v1.6.0 from its signed GitHub prerelease.
5. Verify actual Yandex Browser registration, Extension ID `paolfcaakecapidipfcfbbhgkpcmgcip`, extension startup and normal Network Recorder behavior.
6. If the real install passes, promote Network Recorder v1.6.0 to a stable GitHub Release and switch its catalog channel from `prerelease` to `stable`.
7. Produce a later Network Recorder release and verify a real update through ExtensionInstaller.
8. After install/update verification and explicit owner approval, designate a stable ExtensionInstaller release.
