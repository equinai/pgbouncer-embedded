const path = require("path");
const fs = require("fs");

const PLATFORMS = {
  darwin: { arm64: "darwin-arm64", x64: "darwin-x64" },
  linux: { arm64: "linux-arm64", x64: "linux-x64" },
};

function pgbouncerBinPath() {
  const key = PLATFORMS[process.platform]?.[process.arch];
  if (!key) {
    throw new Error(
      `@equin/pgbouncer-embedded: unsupported platform ${process.platform}/${process.arch}`
    );
  }
  const bin = path.join(
    __dirname,
    "node_modules",
    `@equin`,
    `pgbouncer-${key}`,
    "native",
    "bin",
    "pgbouncer"
  );
  if (!fs.existsSync(bin)) {
    throw new Error(
      `@equin/pgbouncer-embedded: binary not found at ${bin}; run \`bun install\` or \`npm install\``
    );
  }
  return bin;
}

module.exports = { pgbouncerBinPath };
