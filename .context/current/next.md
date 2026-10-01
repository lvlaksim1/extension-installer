# Next actions

1. Owner installs `ExtensionInstaller_Setup_v4.0.0-preview.11.exe` over the currently installed older preview.
2. Confirm on the owner's PC that the old folder/ZIP UI is gone and `ExtensionInstaller.cmd` is no longer present in the installed program directory.
3. In the clean GUI, confirm Network Recorder is loaded automatically from the catalog and no local folder/file selection is requested.
4. Run release check and install Network Recorder v1.6.0 from its signed GitHub prerelease.
5. Verify in the owner's real Yandex Browser that Extension ID is `paolfcaakecapidipfcfbbhgkpcmgcip`, registration succeeds and Network Recorder functions normally.
6. After the real install passes, promote Network Recorder v1.6.0 to stable and switch its catalog channel from `prerelease` to `stable`.
7. Produce a later Network Recorder release and verify a real update through ExtensionInstaller.
8. Only after install/update verification and explicit owner approval designate a stable ExtensionInstaller release.
