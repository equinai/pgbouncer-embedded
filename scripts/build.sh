#!/usr/bin/env bash
set -euo pipefail

# The PgBouncer release to build, e.g. 1.26.1. Required: the workflow's
# `resolve` job is its one source of truth (and the npm version equals it).
: "${PGBOUNCER_VERSION:?PGBOUNCER_VERSION must be set (e.g. PGBOUNCER_VERSION=1.26.1)}"
if ! [[ "${PGBOUNCER_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "PGBOUNCER_VERSION must be X.Y.Z, got: ${PGBOUNCER_VERSION}" >&2
  exit 1
fi
LIBEVENT_VERSION="2.1.12-stable"

# Upstream tags releases as pgbouncer_X_Y_Z.
PGBOUNCER_TAG="pgbouncer_${PGBOUNCER_VERSION//./_}"
PGBOUNCER_URL="https://github.com/pgbouncer/pgbouncer/releases/download/${PGBOUNCER_TAG}/pgbouncer-${PGBOUNCER_VERSION}.tar.gz"
LIBEVENT_URL="https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}/libevent-${LIBEVENT_VERSION}.tar.gz"

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH_RAW=$(uname -m)
case "$ARCH_RAW" in
  arm64|aarch64) ARCH="arm64" ;;
  x86_64)        ARCH="x64"   ;;
  *) echo "Unsupported arch: $ARCH_RAW" && exit 1 ;;
esac
PLATFORM="${OS}-${ARCH}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${REPO_ROOT}/.build/${PLATFORM}"
LIBEVENT_PREFIX="${BUILD_DIR}/libevent"
OUT_DIR="${REPO_ROOT}/packages/${PLATFORM}/native/bin"

echo "==> Building for platform: ${PLATFORM}"
mkdir -p "${BUILD_DIR}/src" "${LIBEVENT_PREFIX}" "${OUT_DIR}"

# ── 1. libevent (static only) ─────────────────────────────────────────────
LIBEVENT_SRC="${BUILD_DIR}/src/libevent-${LIBEVENT_VERSION}"
if [ ! -d "${LIBEVENT_SRC}" ]; then
  echo "==> Downloading libevent ${LIBEVENT_VERSION}"
  curl -fsSL "${LIBEVENT_URL}" | tar xz -C "${BUILD_DIR}/src"
fi

echo "==> Building libevent (static)"
cd "${LIBEVENT_SRC}"
if [ ! -f Makefile ]; then
  ./configure \
    --prefix="${LIBEVENT_PREFIX}" \
    --enable-static \
    --disable-shared \
    --disable-openssl \
    --disable-samples \
    --disable-benchmark \
    --disable-libevent-regress
fi
make -j"$(nproc 2>/dev/null || sysctl -n hw.logicalcpu)"
make install

# ── 2. pgbouncer ─────────────────────────────────────────────────────────
PGBOUNCER_SRC="${BUILD_DIR}/src/pgbouncer-${PGBOUNCER_VERSION}"
if [ ! -d "${PGBOUNCER_SRC}" ]; then
  echo "==> Downloading PgBouncer ${PGBOUNCER_VERSION}"
  curl -fsSL "${PGBOUNCER_URL}" | tar xz -C "${BUILD_DIR}/src"
fi

echo "==> Building PgBouncer"
cd "${PGBOUNCER_SRC}"

# Our patches on top of the release (patches/*.patch, in name order). Applied
# once per extracted tree: the marker keeps a rebuild of the same tree from
# applying them twice. `patch --dry-run` first, so a patch that no longer
# applies to a new upstream release fails the build loudly, naming itself.
if [ ! -f .equin-patched ]; then
  for p in "${REPO_ROOT}"/patches/*.patch; do
    [ -e "$p" ] || continue
    echo "==> Applying $(basename "$p")"
    if ! patch -p1 --forward --dry-run --silent < "$p" > /dev/null; then
      echo "Patch $(basename "$p") does not apply to PgBouncer ${PGBOUNCER_VERSION}" >&2
      exit 1
    fi
    patch -p1 --forward --silent < "$p"
  done
  touch .equin-patched
fi

export LIBEVENT_CFLAGS="-I${LIBEVENT_PREFIX}/include"

if [ "$OS" = "linux" ]; then
  export LIBEVENT_LIBS="${LIBEVENT_PREFIX}/lib/libevent.a -lpthread -ldl"
  export LDFLAGS="-static"
else
  export LIBEVENT_LIBS="${LIBEVENT_PREFIX}/lib/libevent.a"
fi

export CFLAGS="-O2"

if [ ! -f config.mak ]; then
  ./configure \
    --without-openssl \
    --without-cares \
    --disable-evdns
fi
make -j"$(nproc 2>/dev/null || sysctl -n hw.logicalcpu)" pgbouncer

# ── 3. Copy and strip binary ──────────────────────────────────────────────
cp pgbouncer "${OUT_DIR}/pgbouncer"
strip "${OUT_DIR}/pgbouncer"
chmod 755 "${OUT_DIR}/pgbouncer"

echo "==> Done: ${OUT_DIR}/pgbouncer"
ls -lh "${OUT_DIR}/pgbouncer"
file "${OUT_DIR}/pgbouncer"
