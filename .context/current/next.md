# Next actions

1. Owner installs `ExtensionInstaller_Setup_v4.0.0-preview.22.exe` over the currently installed preview while leaving Yandex Browser open.
2. Start ExtensionInstaller and press `Проверить`; stale profile directories must not by themselves report Network Recorder as installed.
3. Click install/reinstall for Network Recorder v1.6.0 without closing or restarting Yandex Browser.
4. ExtensionInstaller should replace the owned external registration in two phases so the running browser observes a fresh registry event and loads the verified CRX.
5. Verify directly in the already-running Yandex Browser that Network Recorder appears with Extension ID `paolfcaakecapidipfcfbbhgkpcmgcip` and works normally.
6. After the real hot-install passes, promote Network Recorder v1.6.0 to a stable GitHub Release and switch its catalog channel from `prerelease` to `stable`.
7. Produce a later Network Recorder release and verify a real hot update through ExtensionInstaller.
8. Only after install/update verification and explicit owner approval designate a stable ExtensionInstaller release.
