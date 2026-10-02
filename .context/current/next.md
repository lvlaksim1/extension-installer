# Next actions

1. Owner installs `ExtensionInstaller_Setup_v4.0.0-preview.31.exe` over preview.26 while leaving Yandex Browser open.
2. Press `Проверить`, then run reinstall once. Do not restart the browser.
3. Preview.31 must register exactly as v3.0.2 did: keep the existing `HKCU\Software\Yandex\YandexBrowser\Extensions\<id>` key and overwrite only `path` / `version`; it must never delete/recreate that key as part of install/update.
4. If the registration values really changed, ExtensionInstaller activates the already-open Yandex Browser using the ported v3 `user32.dll` foreground bridge so the browser's own confirmation is visible.
5. If the same version/path was already registered, or the pre-install state is browser-only/removed/ambiguous, ExtensionInstaller must not claim a successful live load from stale profile data; it opens `browser://tune/` and selects the exact verified managed CRX for user-confirmed no-restart installation.
6. Verify that Network Recorder actually appears in Yandex Browser's extensions UI with Extension ID `paolfcaakecapidipfcfbbhgkpcmgcip`, not merely that ExtensionInstaller says “Установлено”.
7. After actual appearance is confirmed, test ExtensionInstaller uninstall -> immediate check -> reinstall in the same browser session; ownership must remain recoverable and no false foreign state may appear.
8. Only after the full no-restart install/uninstall/reinstall path works, promote Network Recorder v1.6.0 to stable and test a later real extension update.
9. Stable ExtensionInstaller publication remains owner-controlled.
