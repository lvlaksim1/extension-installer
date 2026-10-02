# Current blockers and open risks

- No repository/CI blocker is currently known.
- Real owner-side verification of hot Network Recorder installation into an already-running Yandex Browser in `4.0.0-preview.35` is pending.
- Preview.35 keeps durable ownership and v3-style normal registration. Live reset is now limited to genuinely blocked or missing-active-profile recovery; an already active same-version install is re-registered in place.
- Browser installed-state detection excludes `state=2` (`EXTERNAL_EXTENSION_UNINSTALLED`); stale profile residue must not produce “Установлено”.
- Owner verification of preview.35 foreground behavior and `Переустановить` is pending.
- A real later-version extension update in Yandex Browser still requires a later Network Recorder release.
- Network Recorder remains on the `prerelease` catalog channel until owner-side verification passes.
