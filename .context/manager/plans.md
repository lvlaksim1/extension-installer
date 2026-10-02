# Manager plans

1. Owner installs preview `4.0.0-preview.26` over preview.24 with Yandex Browser left open.
2. Verify the current residual browser-only Network Recorder state is no longer classified as foreign and that install/reinstall is enabled.
3. Reinstall/connect Network Recorder v1.6.0 without restarting Yandex Browser and verify normal operation.
4. Uninstall Network Recorder from ExtensionInstaller while Yandex remains open.
5. Immediately recheck: durable `ownership.json` must keep the state recognized as removed by ExtensionInstaller, never foreign, and the reinstall action must remain available.
6. Reinstall again in the same browser session and verify Extension ID `paolfcaakecapidipfcfbbhgkpcmgcip` plus normal operation.
7. If the full no-restart install -> uninstall -> reinstall cycle passes, promote Network Recorder v1.6.0 to stable and test a later real update.
8. Stable ExtensionInstaller publication remains gated on owner approval.
