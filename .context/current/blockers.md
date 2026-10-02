# Current blockers and open risks

- No repository/CI blocker is currently known.
- Real owner-side verification of hot Network Recorder installation into an already-running Yandex Browser in `4.0.0-preview.33` is pending.
- Preview.33 keeps durable ownership and v3-style normal registration, detects Chromium `state=2` as removed, and performs a browser-acknowledged live reset before blocked/same-value reinstall.
- Browser installed-state detection excludes `state=2` (`EXTERNAL_EXTENSION_UNINSTALLED`); stale profile residue must not produce “Установлено”.
- A real later-version extension update in Yandex Browser still requires a later Network Recorder release.
- Network Recorder remains on the `prerelease` catalog channel until owner-side verification passes.
