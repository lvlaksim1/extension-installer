# Manager plans

1. Owner installs clean preview `4.0.0-preview.24` over the current preview while leaving Yandex Browser open.
2. Verify that `Проверить` does not infer real installation from stale registry/profile residue.
3. Install/reinstall/apply Network Recorder v1.6.0 without closing or restarting the browser.
4. Verify the hot owned registry re-registration path first.
5. If the running browser still does not report the extension, use the automatically opened `browser://tune` page and the exact verified CRX already selected in Explorer; confirm the browser install/enable action without restarting.
6. Verify Extension ID `paolfcaakecapidipfcfbbhgkpcmgcip`, extension startup and normal Network Recorder behavior in the same browser session.
7. If the real no-restart install passes, promote Network Recorder v1.6.0 to a stable GitHub Release and switch its catalog channel from `prerelease` to `stable`.
8. Produce a later Network Recorder release and verify a real no-restart update through ExtensionInstaller.
9. After install/update verification and explicit owner approval, designate a stable ExtensionInstaller release.
