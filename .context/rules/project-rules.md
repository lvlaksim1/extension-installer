# Project rules

1. Do not commit, print, log or persist private signing-key values, tokens or credentials.
2. One independently versioned browser extension belongs in one dedicated repository.
3. Keep stable extension IDs stable unless the owner explicitly authorizes an identity change.
4. Do not use normal Git history as binary release storage.
5. Do not retain GitHub Actions artifacts by default; publish required distributables directly to GitHub Releases.
6. Do not reintroduce the removed legacy ExtensionInstaller workflow: no local extension-folder selector, local ZIP discovery/build path or local RSA signing path.
7. ExtensionInstaller must verify release descriptor metadata, SHA-256, CRX3 signature and pinned Extension ID before registration/update.
8. Do not overwrite or remove a foreign Yandex Browser registration that is not owned by ExtensionInstaller state.
9. Do not claim browser installation/update complete without checking the actual owner-side Yandex Browser path.
10. Stable ExtensionInstaller publication requires explicit owner approval.
11. Network Recorder currently remains agentless; ecosystem coordination stays with `extension-installer-project-manager` unless the owner changes that decision.
