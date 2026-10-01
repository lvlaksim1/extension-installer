# Next actions

1. Owner installs `ExtensionInstaller_Setup_v4.0.0-preview.24.exe` over the currently installed preview while leaving Yandex Browser open.
2. Start ExtensionInstaller and press `Проверить`; stale registry/profile residue must not by itself be treated as a real installed browser extension.
3. Click install/reinstall/apply for Network Recorder v1.6.0 without closing or restarting Yandex Browser.
4. ExtensionInstaller first attempts live owned registry re-registration. If the browser does not accept it, ExtensionInstaller automatically opens `browser://tune` and opens Explorer with the exact verified managed CRX selected.
5. In the fallback path, confirm the browser's enable/install prompt; if no prompt appears, drag the already-selected CRX onto the opened `browser://tune` page and confirm. Browser restart is not part of the test.
6. Verify directly in the still-running Yandex Browser that Network Recorder appears with Extension ID `paolfcaakecapidipfcfbbhgkpcmgcip` and works normally.
7. After the real no-restart install passes, promote Network Recorder v1.6.0 to a stable GitHub Release and switch its catalog channel from `prerelease` to `stable`.
8. Produce a later Network Recorder release and verify a real no-restart update through ExtensionInstaller.
9. Only after install/update verification and explicit owner approval designate a stable ExtensionInstaller release.
