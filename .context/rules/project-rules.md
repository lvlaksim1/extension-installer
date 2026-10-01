# Project rules

1. Do not commit, print, log or persist private signing-key values, tokens or credentials.
2. One independently versioned browser extension belongs in one dedicated repository.
3. Keep stable extension IDs stable unless the owner explicitly authorizes an identity change.
4. Do not use normal Git history as binary release storage.
5. Do not retain GitHub Actions artifacts by default; publish required distributables directly to GitHub Releases.
6. Preserve the v3.0.2 installer as the migration baseline until replacement behavior is verified.
7. Do not claim a migration or installer update complete without checking the actual browser-install/update path.
8. Stable release publication requires owner approval.
