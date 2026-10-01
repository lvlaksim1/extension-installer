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

Clean preview `4.0.0-preview.11` passed Windows CI, including stale-CMD cleanup during upgrade. The remaining gate is real owner-side Yandex Browser installation and later real extension-update verification.

- source: Windows CI run `36935180820` + current project state
- authority: verified-ci + verified-repository
- status: active
