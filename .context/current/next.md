# Next actions

1. Owner installs `ExtensionInstaller_Setup_v4.0.0-preview.26.exe` over preview.24 while leaving Yandex Browser open.
2. Press `Проверить` in the current browser-only residual state created by preview.24 uninstall.
3. Expected result: no “сторонняя установка”; install/reinstall must be enabled. Without a historical ownership marker, the state is shown as the same trusted Extension ID present only in the browser profile.
4. Reinstall/connect Network Recorder v1.6.0 without restarting Yandex Browser and verify normal operation.
5. Use ExtensionInstaller to uninstall Network Recorder again while Yandex remains open.
6. Press `Проверить` immediately after uninstall. Preview.26 must use the durable `ownership.json` tombstone and show “Удалено через ExtensionInstaller; можно установить снова”, with reinstall enabled rather than foreign classification.
7. Reinstall again in the same browser session and verify Extension ID `paolfcaakecapidipfcfbbhgkpcmgcip` and normal Network Recorder operation.
8. After the complete no-restart install -> uninstall -> reinstall cycle passes, promote Network Recorder v1.6.0 to stable, then test a later real extension update.
9. Stable ExtensionInstaller publication remains owner-controlled.
