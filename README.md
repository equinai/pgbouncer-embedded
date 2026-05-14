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
    "@equin/pgbouncer-darwin-arm64": "1.25.2",
    "@equin/pgbouncer-darwin-x64": "1.25.2",
    "@equin/pgbouncer-linux-arm64": "1.25.2",
    "@equin/pgbouncer-linux-x64": "1.25.2"
  }
}
```

Binary location after install:

```
node_modules/@equin/pgbouncer-<platform>/native/bin/pgbouncer
```

## Versions

Package versions match PgBouncer versions (`1.25.2` = PgBouncer 1.25.2).

## Build details

- PgBouncer 1.25.2, compiled from official release tarball
- libevent 2.1.12-stable, statically linked
- No OpenSSL (designed for Unix socket connections, no TLS)
- Linux: fully static ELF
- macOS: libevent statically linked; only system `libSystem` is dynamic

## Publishing a new release

1. Update `PGBOUNCER_VERSION` and `LIBEVENT_VERSION` in `scripts/build.sh`
2. Update `version` in each `packages/*/package.json`
3. Commit and push
4. Tag and push: `git tag v<version> && git push origin v<version>`
5. GitHub Actions builds all 4 platforms and publishes to npm

Requires `NPM_TOKEN` secret configured in the repo with publish access to the `@equin` npm org.
