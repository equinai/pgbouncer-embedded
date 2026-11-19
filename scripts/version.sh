#!/usr/bin/env bash
# The npm version of a wrapper build, and the PgBouncer release a wrapper
# version wraps — one rule, read by the workflow and by equin's dependency
# policy (`wraps.revisions` in plugins/database/plugins/pgbouncer/package.json).
#
# Versions after LEGACY_THROUGH carry a wrapper rebuild count in the last
# REVISION_DIGITS digits of their patch:
#
#   PgBouncer X.Y.Z, rebuild R  →  X.Y.(Z*100 + R)
#   1.26.1 rebuild 1            →  1.26.101
#   1.26.2 (first build)        →  1.26.200
#   1.27.0 rebuild 3            →  1.27.3
#
# so a rebuild never waits for an upstream release, every version stays plain
# X.Y.Z (no prerelease tag that `^` ranges would skip), and later releases always
# sort higher. Versions up to LEGACY_THROUGH wrap the release they name
# (1.26.1 = PgBouncer 1.26.1), except 1.25.2–1.25.7, which all wrap 1.25.2.
#
#   version.sh encode <X.Y.Z> <R>   prints the npm version
#   version.sh decode <npm version> prints the PgBouncer release it wraps
set -euo pipefail

LEGACY_THROUGH="1.26.1"
REVISION_DIGITS=2
SCALE=$((10 ** REVISION_DIGITS))

semver_le() { # a <= b
  [ "$(printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n -k3,3n | head -n 1)" = "$1" ]
}

need_xyz() {
  if ! [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "not X.Y.Z: '$1'" >&2
    exit 1
  fi
}

case "${1:-}" in
  encode)
    need_xyz "$2"
    R="$3"
    if ! [[ "$R" =~ ^[0-9]+$ ]] || [ "$R" -ge "$SCALE" ]; then
      echo "rebuild count must be 0..$((SCALE - 1)), got '$R'" >&2
      exit 1
    fi
    IFS=. read -r X Y Z <<<"$2"
    V="${X}.${Y}.$((Z * SCALE + R))"
    if semver_le "$V" "$LEGACY_THROUGH"; then
      echo "PgBouncer $2 rebuild $R encodes to $V, which is not past the legacy versions (<= ${LEGACY_THROUGH})" >&2
      exit 1
    fi
    echo "$V"
    ;;
  decode)
    need_xyz "$2"
    IFS=. read -r X Y P <<<"$2"
    if semver_le "$2" "$LEGACY_THROUGH"; then
      echo "$2"
    else
      echo "${X}.${Y}.$((P / SCALE))"
    fi
    ;;
  *)
    echo "usage: version.sh encode <X.Y.Z> <rebuild> | decode <npm version>" >&2
    exit 2
    ;;
esac
