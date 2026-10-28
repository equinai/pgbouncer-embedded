# pgbouncer-embedded

Statically-linked PgBouncer binaries packaged as platform-specific npm packages, following the same pattern as `@embedded-postgres/*`.

## Packages

| Package | OS | CPU |
|---|---|---|
| `@equin/pgbouncer-darwin-arm64` | macOS | ARM64 (Apple Silicon) |
| `@equin/pgbouncer-darwin-x64` | macOS | x64 (Intel) |
| `@equin/pgbouncer-linux-arm64` | Linux | ARM64 |
| `@equin/pgbouncer-linux-x64` | Linux | x64 |

## Usage

Add all four as `optionalDependencies` — bun/npm installs only the matching platform:

```json
{
  "optionalDependencies": {
    "@equin/pgbouncer-darwin-arm64": "1.26.1",
    "@equin/pgbouncer-darwin-x64": "1.26.1",
    "@equin/pgbouncer-linux-arm64": "1.26.1",
    "@equin/pgbouncer-linux-x64": "1.26.1"
  }
}
```

Binary location after install:

```
node_modules/@equin/pgbouncer-<platform>/native/bin/pgbouncer
```

## Versions

The npm version equals the PgBouncer version it wraps: `1.26.1` = PgBouncer 1.26.1.

This holds from 1.26.x on. Earlier releases used their own patch numbers: `1.25.2`
through `1.25.7` all wrap PgBouncer 1.25.2 (the later ones are wrapper-only
rebuilds). The switch is monotonic, since 1.26.x > 1.25.7.

Because the version is the upstream version, there is no wrapper-only release
any more: a change to the build (libevent, configure flags, packaging) ships with
the next upstream PgBouncer release.

## Build details

- PgBouncer compiled from the official release tarball
  (`https://github.com/pgbouncer/pgbouncer/releases/download/pgbouncer_<X_Y_Z>/pgbouncer-<X.Y.Z>.tar.gz`)
- libevent 2.1.12-stable, statically linked
- No OpenSSL (designed for Unix socket connections, no TLS)
- Linux: fully static ELF
- macOS: libevent statically linked; only system `libSystem` is dynamic

Build locally (for the current platform):

```sh
PGBOUNCER_VERSION=1.26.1 bash scripts/build.sh
```

`PGBOUNCER_VERSION` is required; the script fails without it.

## Releases

Nothing to do. The **Build and Publish** workflow
(`.github/workflows/build-and-publish.yml`) runs daily: it resolves the newest
PgBouncer release (the highest `pgbouncer_X_Y_Z` tag of
github.com/pgbouncer/pgbouncer), and if `@equin/pgbouncer-*` has not published it
yet, builds all four platforms, checks each binary's `--version`, publishes the
four platform packages and `@equin/pgbouncer-embedded`, and tags the commit
`v<version>`.

| Trigger | Version | Publishes |
|---|---|---|
| daily schedule | newest upstream | if not on npm yet |
| `workflow_dispatch` with `version` | the input | if not on npm yet |
| tag push `v<version>` | the tag | if not on npm yet |
| pull request / push to `main` | newest upstream | never (build + verify only) |

Every publish is idempotent: a package whose version is already on npm is
skipped, so re-running a failed release completes it.

To publish a specific PgBouncer release by hand: run the workflow with
`version` set (Actions → Build and Publish → Run workflow).

GitHub disables scheduled workflows on a public repo after 60 days without
activity; re-enable it with `gh workflow enable "Build and Publish"`.

Publishing uses npm trusted publishing from GitHub Actions (OIDC, with
provenance); no npm token is stored in the repo.
