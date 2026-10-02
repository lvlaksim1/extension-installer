# Next actions

1. Owner installs `ExtensionInstaller_Setup_v4.0.0-preview.35.exe` over preview.33 while leaving Yandex Browser open.
2. With Network Recorder already installed and visible in Yandex Browser, click `Переустановить`.
3. Expected result: no live-reset timeout; active same-version reinstall uses the canonical v3.0.2 in-place `path/version` update and remains installed in the same browser session.
4. After success, ExtensionInstaller must restore itself above Yandex Browser and the success dialog must be modal/owned by the main ExtensionInstaller window rather than appearing behind the browser.
5. Verify Network Recorder remains visible and operational with Extension ID `paolfcaakecapidipfcfbbhgkpcmgcip`.
6. If both checks pass, run one final install -> uninstall -> install/reinstall cycle without browser restart.
7. Then promote Network Recorder v1.6.0 to stable and test a later real extension update.
8. Stable ExtensionInstaller publication remains owner-controlled.
