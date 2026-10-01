# Semantic memory

## SM-001 — clean architecture is an owner invariant

The owner explicitly rejected retaining legacy compatibility because it creates confusion. ExtensionInstaller must expose only the clean release-driven workflow: catalog -> signed GitHub Release -> verified CRX -> browser registration.

- source: owner directive
- authority: owner-directive
- status: active

## SM-002 — extension release assets are remote producer outputs

Signed CRX and `extension-release.json` belong in the corresponding extension's GitHub Release. They are not files the user manually places into ExtensionInstaller.

- source: owner clarification + implemented architecture
- authority: owner-directive + verified-repository
- status: active

## SM-003 — extension repository governance

Extension repositories may remain agentless. At present Network Recorder has no separate manager; `extension-installer-project-manager` owns ecosystem coordination.

- source: owner directive
- authority: owner-directive
- status: active

## SM-004 — Network Recorder identity

Network Recorder v1.6.0 uses Extension ID `paolfcaakecapidipfcfbbhgkpcmgcip`. GitHub-side signing with `RSA_PRIVATE_KEY_BASE64` preserved that ID.

- source: verified signing workflow + independent ExtensionInstaller validation
- authority: verified-ci
- status: active

## SM-005 — current product/release gate

Preview.11 exposed a real-browser migration/state-detection defect after the owner removed the legacy-installed Network Recorder through Yandex Browser. Preview `4.0.0-preview.24` supersedes it as the current test candidate and passed Windows validation/build runs `36942756644` and `36942832970`. Preview.24 derives installed state from browser profile `extensions.settings`, treats stale extension directories as non-authoritative, first uses two-phase registry re-registration for no-restart installation, and falls back to browser-owned `browser://tune` installation with the exact verified CRX selected when the extension was user-removed or is not accepted live.

The remaining gate is owner-side verification of the corrected reinstall/migration path, followed by a real later-version extension update.

- source: owner runtime observation + verified Windows CI + current repository
- authority: owner-runtime-evidence + verified-ci + verified-repository
- status: active

## SM-006 — external registration is not actual-install evidence

A Yandex external-extension registry entry can remain after the user removes the extension in the browser. The old ExtensionInstaller v3 path under `UniversalExtensionBuilder\projects\<id>\crx` is legacy-owned, not foreign. Browser user removal may also be persisted in `extensions.external_uninstalls`.

Status/migration logic must distinguish these states and must retain protection against genuinely foreign registrations.

- source: owner runtime observation + verified v3 source + current implementation/CI
- authority: owner-runtime-evidence + verified-repository + verified-ci
- status: active

## SM-007 — no-restart install uses browser-owned registry watching

When Yandex Browser is already running, ExtensionInstaller must not modify profile Preferences behind the browser's back. For an owned existing external-registration key, remove the child key, allow the browser registry watcher to observe removal, then recreate the key with the validated CRX path/version. This preserves the browser as the authority for its in-memory extension/preferences state and restores hot installation behavior.

- source: owner directive + Chromium external registry loader + verified implementation/CI
- authority: owner-directive + verified-repository + verified-ci
- status: active

## SM-008 — do not silently defeat browser user-removal state

When the user removes an externally registered extension through Yandex Browser, the browser may remember that decision and ignore later external registration. A registry pulse is useful for normal hot registration but is not a legitimate substitute for user confirmation after explicit browser removal.

The reusable recovery pattern is: keep the browser running, attempt the normal hot registration, then if browser profile state still lacks the extension (or the prior snapshot records user removal), open the browser's extension-management page and surface the already verified CRX for normal confirmation. Do not edit live browser Preferences behind the browser.

- source: owner runtime observation + browser external-extension semantics + preview.24 implementation/CI
- authority: owner-runtime-evidence + verified-repository + verified-ci
- status: active
