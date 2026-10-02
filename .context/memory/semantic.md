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

Preview.11 exposed a real-browser migration/state-detection defect after the owner removed the legacy-installed Network Recorder through Yandex Browser. Preview `4.0.0-preview.31` supersedes it as the current test candidate and passed Windows validation/build runs `36945415272` and `36945552459`. Preview.31 keeps durable ownership/browser-only recovery but restores the old v3.0.2 non-destructive registry registration path: update only `path` and `version`, never delete/recreate the external-extension key during install/update.

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

## SM-007 — canonical hot registration is non-destructive

The old ExtensionInstaller v3.0.2 working implementation is authoritative for Yandex registration behavior. During install/update it never deletes the extension's registry child key. It creates/opens the same key and overwrites only `path` and `version`.

The v4 preview.22–26 remove/recreate “pulse” was an invented regression, not legacy behavior. A temporary key deletion can be observed as external uninstall by a running Chromium/Yandex instance. Preview.31 removes that pulse and restores v3 semantics.

- source: verified v3.0.2 source + owner runtime observation + preview.31 implementation/CI
- authority: verified-repository + owner-runtime-evidence + verified-ci
- status: active

## SM-008 — do not silently defeat browser user-removal state

When the user removes an externally registered extension through Yandex Browser, the browser may remember that decision and ignore later external registration. A registry pulse is useful for normal hot registration but is not a legitimate substitute for user confirmation after explicit browser removal.

The reusable recovery pattern is: keep the browser running, attempt the normal hot registration, then if browser profile state still lacks the extension (or the prior snapshot records user removal), open the browser's extension-management page and surface the already verified CRX for normal confirmation. Do not edit live browser Preferences behind the browser.

- source: owner runtime observation + browser external-extension semantics + preview.24 implementation/CI
- authority: owner-runtime-evidence + verified-repository + verified-ci
- status: active

## SM-009 — uninstall must not erase ownership before browser convergence

With a running Chromium/Yandex process, deleting the external registry entry and installer state can complete before the browser removes its profile-side extension record. If installer ownership evidence is deleted at the same time, the next status refresh can falsely reinterpret the residual profile entry as foreign.

Reusable rule: persist a small durable ownership tombstone before destructive uninstall, keep it outside the deleted CRX/state payload, and clear it only after a successful reinstall. Separately, profile-only presence of a catalog-pinned Extension ID is not itself a foreign external registration and must not disable reinstall.

- source: owner runtime observation + preview.26 implementation/CI
- authority: owner-runtime-evidence + verified-repository + verified-ci
- status: active

## SM-010 — real browser UI is the external acceptance criterion

Installer-owned registry/state and browser preference residue are diagnostic inputs, not the final proof that an extension is live. Preview.26 demonstrated that ExtensionInstaller could display “Установлено” while the extension was absent from the actual Yandex extensions UI.

For install/reinstall validation, the external acceptance criterion is actual browser presence and operation. Ambiguous recovery/same-value cases must use browser-owned confirmation (`browser://tune` with the verified CRX) instead of inferring success from stale profile records.

- source: owner runtime observation + preview.31 design
- authority: owner-runtime-evidence + verified-repository
- status: active
