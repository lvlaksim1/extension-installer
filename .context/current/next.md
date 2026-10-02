# Next actions

1. Owner opens the already-working ExtensionInstaller preview `4.0.0-preview.35` and presses `Проверить`; catalog channel `prerelease` should expose Network Recorder `1.7.0`.
2. Update Network Recorder from 1.6.0 to 1.7.0 without restarting Yandex Browser.
3. Open Network Recorder settings and verify the lightweight defaults: API bodies ON, textual page resources ON; all resource bodies OFF, files/blob bytes OFF, deep diagnostics OFF, Chromium Tracing OFF.
4. Record the same representative page for about 10 seconds without enabling the heavy options.
5. Compare the resulting ZIP size with the former >100 MB / ~10 s behavior.
6. Open `session-manifest.json` and inspect `archiveSizeBreakdown` if the ZIP remains unexpectedly large; it reports uncompressed/archive bytes by category and compression savings.
7. Verify the ZIP still contains usable network metadata, API evidence and textual page resources required for research.
8. Based on the real owner test, tune defaults/limits only if necessary.
9. Stable publication of Network Recorder and ExtensionInstaller remains owner-controlled.
