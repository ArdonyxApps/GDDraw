# GDDraw Updater Guide

This guide explains how the staged updater is used for normal GDDraw releases and what happens on a user's machine during an upgrade.

## Intended Lifetime

The updater is designed to be reused for every stable semantic release, such as `v0.2.0`, `v0.2.1`, and `v0.3.0`. A routine stable release does not require updater code changes; it requires producing an asset that follows the release contract below.

The updater may still need maintenance if an external dependency changes, such as GitHub's Release API or redirect infrastructure, Godot's editor restart or ZIP APIs, or the supported operating-system behavior. Future features such as maintainer code signing, alternate update channels, or unattended installation would also require deliberate updater changes. These are not part of the normal version-publishing process.

## Maintainer Release Checklist

For each stable release:

1. Set `GDDraw.gd` `PLUGIN_VERSION` to the normalized `X.Y.Z` version.
2. Set `plugin.cfg` `version` to the same value.
3. Package the complete plugin with `addons/GDDraw/plugin.cfg` at that exact root-relative archive path.
4. Name the uploaded ZIP exactly `GDDraw-vX.Y.Z.zip`.
5. Ensure GitHub publishes the asset's SHA-256 digest in the authenticated Release API metadata.
6. Create a non-draft, non-prerelease GitHub Release tagged exactly `vX.Y.Z`.
7. Confirm the release tag, asset filename, `PLUGIN_VERSION`, and `plugin.cfg` version all agree before publishing.

For example, release `v0.2.1` must agree in all four places:

```text
Release tag:       v0.2.1
Asset filename:    GDDraw-v0.2.1.zip
GDDraw.gd:         0.2.1
plugin.cfg:        0.2.1
```

The ZIP must begin directly with the package boundary:

```text
addons/
  GDDraw/
    plugin.cfg
    GDDraw.gd
    gddraw_dock.gd
    gddraw_update_checker.gd
    gddraw_updater.gd
    ...all other required plugin files
```

An extra wrapper such as `GDDraw-v0.2.1/addons/GDDraw/` is invalid. Generated `.godot` or `.import` content, project-owned `res://gddraw/` content, repository development files, and uncontracted native executables or libraries must not be included.

Development continues on the active development branch, and maintained release lines may use branches such as `0.2` or `0.3`. Branch names never establish release stability. The updater never downloads branch archives or GitHub-generated source archives; its only public input is a stable GitHub Release with the exact uploaded asset above.

## User Upgrade Flow

Checking, downloading, validation, installation, restart, and activation are separate phases. Reaching one phase never grants consent for the next.

### 1. Check

GDDraw compares the installed `GDDraw.gd` `PLUGIN_VERSION` with the latest stable GitHub Release. Drafts, prereleases, malformed semantic tags, and releases without exactly one contracted asset are rejected.

- Equal versions report that GDDraw is current.
- A newer published version displays the Help badge and offers **Download Update**.
- A locally installed version newer than the published release reports: **This GDDraw build is newer than the latest published release.**

Automatic checks remain silent when current, locally ahead, offline, or rate-limited. They may show the existing badge for a newer valid release, but never download or install anything.

### 2. Download and Validate

The user must select **Download Update**. GDDraw then:

1. Downloads the validated release asset over HTTPS to a unique `.part` file below `user://gddraw/updates/downloads/`.
2. Reports byte progress where the server provides a total size.
3. Enforces the archive-size limit and rejects incomplete responses.
4. Renames the `.part` file only after the download completes successfully.
5. Verifies the archive SHA-256 against GitHub's authenticated release-asset metadata.
6. Inspects every ZIP entry before extracting any file.
7. Rejects traversal, absolute or drive-letter paths, backslash and encoded traversal, alternate roots, generated project content, link-like paths, and unexpected native payloads.
8. Verifies the required files and confirms the tag, asset name, `PLUGIN_VERSION`, and `plugin.cfg` version agree.
9. Extracts only the validated package beneath `user://gddraw/updates/staged/vX.Y.Z/` and records a validation manifest containing file hashes and release metadata.

Canceling or failing a download removes only that operation's `.part` file. Downloading and validation never modify `res://addons/GDDraw/`.

### 3. Explicit Installation

After validation, the popup enters **Ready to Install**. The user may choose **Later** and leave the staged package untouched. Installation begins only when the user explicitly selects **Install and Restart**.

Before changing the installed package, GDDraw:

1. Revalidates every staged file and confirms the installed and target versions have not changed.
2. Copies the complete installed plugin to a unique directory below `user://gddraw/updates/backups/`.
3. Verifies that backup byte-for-byte.
4. Records an installation transaction descriptor.
5. Builds and verifies a complete sibling replacement candidate.

It then moves the installed directory aside and moves the verified candidate into `res://addons/GDDraw/`. Replacing the complete directory removes obsolete package files as well as updating changed files, while all destructive operations remain confined to the resolved GDDraw package and transaction paths.

The two directory renames are a short transaction boundary rather than one portable atomic operation. If copying, swapping, verification, or restart preparation fails, GDDraw deterministically restores the moved-aside package or the verified backup.

### 4. Restart and Activation

After the replacement verifies successfully, GDDraw requests an editor restart through Godot's supported `EditorInterface.restart_editor(true)` API. It does not terminate the editor process forcibly. If the restart request is unavailable, the popup tells the user to restart the editor manually.

Installation success does not mean the new release is active. The update becomes active only after a later editor session loads the target `PLUGIN_VERSION` and startup recovery validates the installed package against the transaction manifest.

On startup:

- A complete, validated target finalizes the transaction.
- An incomplete or invalid target is rolled back when a verified backup exists.
- If neither the target nor backup validates, GDDraw stops destructive recovery, preserves all staged and backup data, and presents manual recovery information.

At least the immediately previous known-good backup is retained after successful activation.

After startup validates a completed update, the documentation popup opens `addons/GDDraw/docs/whats-new.md` at the top. The dock records `whats_new_shown_version` in project-scoped editor metadata after showing the page. The same version is not announced again when the editor or dock reopens. Fresh installs, manual package replacements, failed updates, and rollbacks do not trigger the popup. **Help > What's New** always allows users to reopen the release history. Add each release's highlights above older versions in the Markdown file before packaging it.

## Storage Boundaries

```text
res://addons/GDDraw/                  Installed plugin; changed only by confirmed installation
user://gddraw/updates/downloads/      Completed archives and operation-scoped .part files
user://gddraw/updates/staged/         Extracted validated candidates and manifests
user://gddraw/updates/backups/        Verified previous plugin packages
user://gddraw/updates/                Installation transaction descriptor
```

No update phase creates project asset directories under `res://gddraw/`. Ordinary checking, popup use, downloading, validation, cancellation, and recovery inspection keep the installed package immutable.

## Integrity and Authenticity

TLS certificate validation remains enabled, and the expected SHA-256 digest comes from GitHub's authenticated Release metadata rather than from inside the downloaded archive. This detects corrupted or substituted archive bytes relative to the published asset metadata. It does not provide independent maintainer code signing: compromise of the maintainer's GitHub release authority could still publish a malicious asset and matching metadata.

Godot 4.4's ZIP API does not expose ZIP external attributes. GDDraw rejects link-like names and confines extraction after validating the complete entry list, but cannot directly identify a symlink encoded only in unavailable external attributes. This limitation, along with the lack of independent code signing, is why the updater remains conservative and rejects any ambiguous package.

## First Contracted Release

The historical `v0.1.0` GitHub Release uses the legacy asset name `v0.1.0.zip`, which does not satisfy the new contract and is intentionally rejected. The first release served through this updater must use the contracted format, for example:

```text
Tag:       v0.2.0
Asset:     GDDraw-v0.2.0.zip
ZIP root:  addons/GDDraw/plugin.cfg
Digest:    SHA-256 in GitHub Release asset metadata
```

After that first compliant release, every routine stable release follows the same checklist without changes to the updater itself.
