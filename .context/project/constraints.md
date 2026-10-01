# Project constraints

- Public repository.
- Project Manager context capsule is installed.
- Standard Telegram secrets are not required.
- Never commit `RSA_PRIVATE_KEY.txt`, PEM/private-key material, tokens, passwords or other credentials.
- Do not store extension ZIP/CRX binaries in normal Git history; publish distributable binaries via GitHub Releases.
- Do not accumulate GitHub Actions artifacts unless explicitly required.
- Existing extension IDs must remain stable when moving signing to GitHub-hosted release workflows.
- Current baseline behavior may read local RSA files; that is legacy behavior and must not be mistaken for the target architecture.
