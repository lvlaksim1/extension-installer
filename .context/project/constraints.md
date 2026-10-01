# Project constraints

- Public repository.
- Project Manager context capsule is installed.
- Standard Telegram secrets are not required.
- Do not commit private keys, tokens, passwords or other credentials.
- Extension signing keys belong only in the corresponding extension repository's GitHub secret scope.
- Do not store extension CRX/ZIP distributables in normal Git history; use GitHub Releases.
- Do not accumulate GitHub Actions artifacts unless explicitly required.
- Existing Extension IDs must remain stable.
- Current product must not reintroduce a local extension-source folder selector, local ZIP build path or local RSA signing path.
- ExtensionInstaller must verify descriptor metadata, SHA-256, CRX3 signature and pinned Extension ID before installation/update.
- Stable ExtensionInstaller publication requires owner approval after real browser validation.
