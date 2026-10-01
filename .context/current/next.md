# Next actions

1. Audit the imported v3.0.2 code path and document its install/update/signing responsibilities.
2. Design the installer-to-extension release contract: extension ID, version, release asset names, SHA-256 and repository metadata.
3. Remove local signing responsibility from the target installer architecture while retaining a safe migration path from v3.0.2.
4. Create the first extension repository for EINV Network Recorder and preserve its stable extension ID.
5. Add tests/diagnostics for release discovery, checksum verification and Yandex Browser registration.
