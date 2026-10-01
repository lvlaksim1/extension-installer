# Manager plans

1. Owner installs clean preview `4.0.0-preview.22` over the current preview while leaving Yandex Browser open.
2. Verify that `Проверить` does not infer installation from stale extension directories.
3. Install/reinstall Network Recorder v1.6.0 without closing or restarting the browser.
4. Verify that the two-phase owned registry re-registration is observed by the running browser and Network Recorder appears with Extension ID `paolfcaakecapidipfcfbbhgkpcmgcip`.
5. Verify extension startup and normal Network Recorder behavior.
6. If the real hot install passes, promote Network Recorder v1.6.0 to a stable GitHub Release and switch its catalog channel from `prerelease` to `stable`.
7. Produce a later Network Recorder release and verify a real no-restart update through ExtensionInstaller.
8. After install/update verification and explicit owner approval, designate a stable ExtensionInstaller release.
