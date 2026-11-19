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
    "@equin/pgbouncer-darwin-arm64": "1.26.101",
    "@equin/pgbouncer-darwin-x64": "1.26.101",
    "@equin/pgbouncer-linux-arm64": "1.26.101",
    "@equin/pgbouncer-linux-x64": "1.26.101"
  }
}
```

Binary location after install:

```
node_modules/@equin/pgbouncer-<platform>/native/bin/pgbouncer
```

## Versions

An npm version names the PgBouncer release it wraps and a wrapper rebuild
count, in its patch number (`scripts/version.sh`):

| PgBouncer | rebuild | npm version |
|---|---|---|
| 1.26.1 | 1 | `1.26.101` |
| 1.26.2 | 0 | `1.26.200` |
| 1.27.0 | 3 | `1.27.3` |

`X.Y.(Z*100 + R)`: a rebuild never waits for an upstream release, every version
stays a plain `X.Y.Z` (a prerelease tag such as `1.26.1-1` would sort *below*
1.26.1 and fall outside `^` ranges), and every later release sorts higher than
every rebuild of an earlier one.

Versions up to `1.26.1` predate the rule and wrap the release they name
(`1.26.1` = PgBouncer 1.26.1), except `1.25.2`–`1.25.7`, which all wrap 1.25.2.
`scripts/version.sh decode <npm version>` gives the release any version wraps;
equin's dependency policy reads versions the same way (`wraps.revisions`).

## Patches

Every build applies `patches/*.patch` (in name order) to the release tarball.
A patch that no longer applies to a new release fails that build, naming
itself — fix or drop it in the same change.

- `0001-unix-socket-buffer.patch` — PgBouncer applies `tcp_socket_buffer`
  (`SO_SNDBUF` / `SO_RCVBUF`) to Unix-domain sockets too, both client-facing and
  towards Postgres. Upstream applies it to TCP sockets only. On macOS a Unix
  stream socket's send buffer is 8 KB (`net.local.stream.sendspace`), and the
  sender's buffer bounds what is in flight, so a client read a large reply
  8 KB per wakeup: a 768 KB reply took 97 reads (15 s on a client whose event
  loop turns took 150 ms), 2 reads (0.16 s) with `tcp_socket_buffer = 1048576`.
  The key stays the existing one, so the same config is valid for an
  unpatched binary (which applies it to no Unix socket).

## Patch-only rebuilds

To ship a change to the build (a patch, libevent, configure flags) for the
PgBouncer release already published, without waiting for the next one: merge
it, then run **Build and Publish** by hand with `version` = that release and
`rebuild` = one more than its newest rebuild on npm:

```sh
gh workflow run "Build and Publish" -R equinai/pgbouncer-embedded -f version=1.26.1 -f rebuild=1
```

It publishes `1.26.101` for all four platforms and the meta package, and tags
`v1.26.101`. The daily run never shadows it: for the newest upstream release
it completes that release's newest wrapper on npm, and builds rebuild 0 only
for a release nothing wraps yet.

## Build details

- PgBouncer compiled from the official release tarball, with `patches/` applied
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

Nothing to do for an upstream release. The **Build and Publish** workflow
(`.github/workflows/build-and-publish.yml`) runs daily: it resolves the newest
PgBouncer release (the highest `pgbouncer_X_Y_Z` tag of
github.com/pgbouncer/pgbouncer), and if no `@equin/pgbouncer-*` version wraps
it yet, builds all four platforms (patches applied), checks each binary's
`--version`, publishes the four platform packages and
`@equin/pgbouncer-embedded` as rebuild 0, and tags the commit `v<npm version>`.

| Trigger | Version | Publishes |
|---|---|---|
| daily schedule | newest upstream, its newest wrapper on npm, else rebuild 0 | if not on npm yet |
| `workflow_dispatch` with `version`, `rebuild` | the input | if not on npm yet |
| tag push `v<npm version>` | the tag | if not on npm yet |
| pull request / push to `main` | newest upstream | never (build + verify only) |

Every publish is idempotent: a package whose version is already on npm is
skipped, so re-running a failed release completes it.

To publish a specific PgBouncer release by hand: run the workflow with
`version` set and `rebuild` 0 (Actions → Build and Publish → Run workflow).

GitHub disables scheduled workflows on a public repo after 60 days without
activity; re-enable it with `gh workflow enable "Build and Publish"`.

Publishing uses npm trusted publishing from GitHub Actions (OIDC, with
provenance); no npm token is stored in the repo.
