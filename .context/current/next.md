# Next actions

1. Owner installs `ExtensionInstaller_Setup_v4.0.0-preview.33.exe` over the current preview while leaving Yandex Browser open.
2. Press `Проверить`, then run reinstall once. Do not restart the browser.
3. For the current same-value/recovery case, preview.33 should temporarily remove only its owned external registry key, wait until Yandex clears the previous external-uninstall/profile state through its live registry watcher, then re-register the verified CRX using the canonical v3.0.2 `path/version` format.
4. ExtensionInstaller waits for browser-side confirmation of a non-uninstalled profile state before reporting live success. Persisted Chromium `state=2` must be treated as removed, never installed.
5. Verify that Network Recorder actually appears in Yandex Browser's extensions UI with Extension ID `paolfcaakecapidipfcfbbhgkpcmgcip`.
6. If browser confirmation is not observed, ExtensionInstaller must say so and open the no-restart `browser://tune` fallback instead of displaying a false “Установлено”.
7. After actual appearance passes, test uninstall -> check -> reinstall in the same browser session.
8. Only after the full no-restart cycle works, promote Network Recorder v1.6.0 to stable and test a later real extension update.
9. Stable ExtensionInstaller publication remains owner-controlled.
