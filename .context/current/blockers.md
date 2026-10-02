# Current blockers and open risks

- No repository/CI blocker is currently known.
- Real owner-side verification of hot Network Recorder installation into an already-running Yandex Browser in `4.0.0-preview.26` is pending.
- Preview.26 preserves the preview.24 no-restart activation path and additionally keeps durable ownership evidence after ExtensionInstaller-driven uninstall so browser-profile residue cannot become a false foreign state.
- Browser installed-state detection now uses profile `extensions.settings`; stale extension directories alone must not produce “Установлено”.
- A real later-version extension update in Yandex Browser still requires a later Network Recorder release.
- Network Recorder remains on the `prerelease` catalog channel until owner-side verification passes.
