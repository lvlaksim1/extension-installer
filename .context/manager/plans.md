# Manager plans

1. Owner installs preview `4.0.0-preview.33` over the current preview with Yandex Browser left open.
2. Reinstall Network Recorder and verify actual appearance in the browser UI.
3. Confirm current blocked/same-value state is handled by browser-owned live reset: owned registry key removed, Yandex acknowledgement observed, then verified CRX re-registered.
4. Confirm Chromium `state=2` is never presented as installed.
5. If browser-side install confirmation is observed, verify Extension ID `paolfcaakecapidipfcfbbhgkpcmgcip` and normal Network Recorder operation.
6. Test ExtensionInstaller uninstall -> immediate check -> reinstall in the same browser session.
7. If the full cycle passes, promote Network Recorder v1.6.0 to stable and test a later real update.
8. Stable ExtensionInstaller publication remains gated on owner approval.
