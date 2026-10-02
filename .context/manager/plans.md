# Manager plans

1. Owner installs preview `4.0.0-preview.35` over preview.33 with Yandex Browser left open.
2. Click `Переустановить` while Network Recorder is already installed and visible.
3. Verify no 15-second live-reset timeout occurs; active same-version reinstall must remain on the v3.0.2 in-place registration path.
4. Verify ExtensionInstaller returns to foreground and the success dialog appears above the browser as an owned modal window.
5. Verify Network Recorder remains visible/operational with Extension ID `paolfcaakecapidipfcfbbhgkpcmgcip`.
6. Run one final no-restart install -> uninstall -> install/reinstall cycle.
7. If it passes, promote Network Recorder v1.6.0 to stable and test a later real update.
8. Stable ExtensionInstaller publication remains gated on owner approval.
