# Manager intentions and commitments

## EI-PM-001 — establish ExtensionInstaller repository
- status: completed
- source: owner directive
- result: public repository created through repo-factory with Project Manager v2.

## EI-PM-002 — implement clean signed-release architecture
- status: completed
- source: owner directive
- result: clean PowerShell GUI + release engine + catalog; local source-folder/ZIP/RSA product path removed from the current tree.
- verification: Windows CI.

## EI-PM-003 — preserve security and storage invariants
- status: active
- source: owner directive
- commitment: keep private signing material out of Git/local installer, preserve Extension IDs, verify signed releases, prevent foreign-registration takeover and avoid retained build artifacts.

## EI-PM-004 — integrate Network Recorder
- status: active; corrected real-browser migration/reinstall retest pending
- source: owner directive
- result so far: Network Recorder v1.6.0 source is in its own public repository, signing secret is GitHub-hosted, signed prerelease preserves the original Extension ID, catalog entry is active, and ExtensionInstaller resolves/verifies it successfully. Owner-side preview.11 testing exposed a legacy-registration/manual-browser-removal defect; preview.22 contains the current CI-verified correction, including authoritative profile-state detection and no-restart live registry re-registration.
- remaining: owner-side preview.22 no-restart Yandex Browser reinstall/function verification, then a real later-version update test.

## EI-PM-005 — make ExtensionInstaller installable/updatable
- status: completed
- source: owner directive
- result: single Inno Setup EXE, fixed AppId, per-user installation, in-place update, obsolete installed CMD cleanup, optional removal of application data on uninstall.
- current verified setup: `4.0.0-preview.22`; build run `36941269628`.

## EI-PM-006 — coordinate extension ecosystem
- status: active
- source: owner directive
- commitment: coordinate ExtensionInstaller plus agentless extension repositories from `extension-installer-project-manager` until the owner assigns separate managers.

## EI-PM-007 — stable publication gate
- status: pending
- source: owner constraints
- commitment: do not designate a stable ExtensionInstaller release until real Yandex Browser installation and extension-update behavior have been verified and owner approval is obtained.
