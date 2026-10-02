# Manager plans

1. Owner uses the verified ExtensionInstaller preview `4.0.0-preview.35`, already confirmed working, to update Network Recorder to `1.7.0` from the prerelease channel.
2. Verify the update occurs in the running Yandex Browser with the same Extension ID `paolfcaakecapidipfcfbbhgkpcmgcip`.
3. Verify v1.7.0 settings defaults: API bodies ON; textual page resources ON; all resource bodies OFF; files/blob bytes OFF; deep diagnostics OFF; Chromium Tracing OFF.
4. Repeat the representative ~10-second recording that previously produced >100 MB.
5. Compare the resulting ZIP size and inspect `session-manifest.json.archiveSizeBreakdown`.
6. Verify the lighter archive still contains the research evidence the owner actually needs.
7. If a remaining category dominates size, tune that category specifically rather than weakening capture globally.
8. Stable Network Recorder / ExtensionInstaller publication remains gated on owner approval.
