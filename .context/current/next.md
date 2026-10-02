# Next actions

1. Owner installs `ExtensionInstaller_Setup_v4.0.0-preview.37.exe` over preview.35; Yandex Browser may remain open.
2. Press `Проверить`. Expected: latest Network Recorder prerelease resolves as `1.7.0` without the duplicate `extension-release.json` error.
3. Update Network Recorder from 1.6.0 to 1.7.0.
4. Verify v1.7.0 lightweight defaults: API bodies ON; textual page resources ON; all resource bodies OFF; files/blob bytes OFF; deep diagnostics OFF; Chromium Tracing OFF.
5. Repeat the representative ~10-second recording that previously produced >100 MB.
6. Compare ZIP size and inspect `session-manifest.json.archiveSizeBreakdown` if needed.
7. Stable publication remains owner-controlled.
