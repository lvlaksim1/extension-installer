# Current blockers and open risks

- No repository/CI blocker is currently known.
- Real owner-side verification of the corrected Yandex Browser migration/reinstall path in `4.0.0-preview.16` is pending.
- Because Yandex/Chromium records a user-removed external extension, Yandex Browser must be fully closed when ExtensionInstaller performs an explicit reinstall that clears the target `external_uninstalls` marker.
- The corrected state-detection logic is covered by Windows CI with simulated browser-profile/Preferences state but still requires confirmation against the owner's real Yandex Browser profile.
- A real extension-version update in Yandex Browser still requires a later Network Recorder release.
- Network Recorder remains on the `prerelease` catalog channel until owner-side verification passes.
