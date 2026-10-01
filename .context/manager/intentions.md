# Manager intentions and commitments

## EI-PM-001 — establish ExtensionInstaller repository baseline
- status: completed
- source: owner directive
- result: public repository created through repo-factory, Project Manager v2 installed, v3.0.2 imported, repository hygiene added.
- verification: repository state on `main`.

## EI-PM-002 — migrate installer architecture to signed-release consumption
- status: accepted/active
- source: owner directive and approved architecture
- commitment: document the existing v3.0.2 responsibilities, define the release contract, then modify the installer so normal installation/update does not require local RSA private keys.

## EI-PM-003 — preserve security and storage invariants
- status: accepted/active
- source: owner directive
- commitment: prevent private signing material from entering Git/durable context, preserve stable extension IDs, and avoid unnecessary build artifacts.

## EI-PM-004 — prepare first real ecosystem integration
- status: accepted/active
- source: owner directive
- commitment: after the installer contract is defined, integrate Network Recorder as the first separately managed extension without silently changing its stable identity or chosen stable code baseline.


## EI-PM-005 — make ExtensionInstaller installable on Windows
- status: completed
- source: owner directive
- result: per-user Inno Setup package with fixed AppId, Start Menu launcher, optional desktop shortcut, direct GitHub prerelease publication, and no Actions artifact retention.
- verification: Windows run 36897779451 successfully completed build, install, in-place reinstall, payload verification, uninstall, and prerelease publication.


## EI-PM-006 — coordinate the extension ecosystem
- status: accepted/active
- source: owner directive
- commitment: manage the shared ExtensionInstaller + extension-repository integration from `extension-installer-project-manager` while extension repositories remain agentless unless the owner later assigns them their own manager.
