# Manager plans

1. Owner installs preview `4.0.0-preview.31` over preview.26 while Yandex Browser stays open.
2. Reinstall Network Recorder once and verify real appearance in the browser extensions UI.
3. Confirm registration is v3-style in-place: no delete/recreate pulse; only `path` and `version` are written under the existing Extension ID key.
4. For a genuine changed registration, verify the ported v3 foreground bridge brings the browser forward so any Yandex confirmation is visible.
5. For the current same-version/recovery case, verify preview.31 opens the no-restart `browser://tune` + selected verified CRX fallback rather than claiming a successful live load from stale profile state.
6. Once Network Recorder actually appears and works, test ExtensionInstaller uninstall -> immediate check -> reinstall in the same browser session; ownership recovery must remain correct.
7. If the complete cycle passes, promote Network Recorder v1.6.0 to stable and test a later real update.
8. Stable ExtensionInstaller publication remains gated on owner approval.
