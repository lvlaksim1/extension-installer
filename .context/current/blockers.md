# Current blockers and open risks

- No repository/CI blocker is currently known.
- Real owner-side verification of hot Network Recorder installation into an already-running Yandex Browser in `4.0.0-preview.22` is pending.
- Preview.22 intentionally avoids editing Yandex Preferences while the browser is running; it uses Chromium/Yandex live registry-change handling via a two-phase owned-key remove/recreate.
- Browser installed-state detection now uses profile `extensions.settings`; stale extension directories alone must not produce “Установлено”.
- A real later-version extension update in Yandex Browser still requires a later Network Recorder release.
- Network Recorder remains on the `prerelease` catalog channel until owner-side verification passes.
