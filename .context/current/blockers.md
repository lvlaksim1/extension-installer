# Current blockers and open risks

- No repository/CI blocker is currently known.
- Real owner-side verification of hot Network Recorder installation into an already-running Yandex Browser in `4.0.0-preview.24` is pending.
- Preview.24 intentionally avoids editing Yandex Preferences while the browser is running. It first uses live registry-change handling; if the running browser does not accept the external registration (including a prior user-removal case), it opens `browser://tune` and selects the verified managed CRX for normal browser confirmation without restart.
- Browser installed-state detection now uses profile `extensions.settings`; stale extension directories alone must not produce “Установлено”.
- A real later-version extension update in Yandex Browser still requires a later Network Recorder release.
- Network Recorder remains on the `prerelease` catalog channel until owner-side verification passes.
