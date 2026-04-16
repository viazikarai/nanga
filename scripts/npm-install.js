#!/usr/bin/env node

// build and stage the swift binary for npm installs.
const fs = require("node:fs");
const path = require("node:path");
const cp = require("node:child_process");

const root = path.resolve(__dirname, "..");
const vendorDir = path.join(root, "vendor");
const stagedBinary = path.join(vendorDir, "context-anchor");

function run(command, args) {
  const result = cp.spawnSync(command, args, {
    cwd: root,
    stdio: "inherit",
    env: process.env,
  });

  if (result.error) {
    throw result.error;
  }

  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} failed with code ${result.status}`);
  }
}

function binaryCandidates() {
  return [
    path.join(root, ".build", "release", "context-anchor"),
    path.join(root, ".build", "arm64-apple-macosx", "release", "context-anchor"),
    path.join(root, ".build", "x86_64-apple-macosx", "release", "context-anchor"),
    path.join(root, ".build", "x86_64-unknown-linux-gnu", "release", "context-anchor"),
    path.join(root, ".build", "aarch64-unknown-linux-gnu", "release", "context-anchor"),
  ];
}

function firstExisting(paths) {
  for (const candidate of paths) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }

  return null;
}

try {
  // allow users to skip install-time build when packaging.
  if (process.env.CONTEXT_ANCHOR_SKIP_BUILD === "1") {
    process.exit(0);
  }

  run("swift", ["--version"]);
  run("swift", ["build", "-c", "release", "--product", "context-anchor"]);

  const builtBinary = firstExisting(binaryCandidates());
  if (!builtBinary) {
    throw new Error("could not locate built context-anchor binary after swift build");
  }

  fs.mkdirSync(vendorDir, { recursive: true });
  fs.copyFileSync(builtBinary, stagedBinary);
  fs.chmodSync(stagedBinary, 0o755);

  // keep output short and direct for npm users.
  process.stdout.write("context-anchor: installed binary successfully.\n");
} catch (error) {
  const detail = error instanceof Error ? error.message : String(error);
  process.stderr.write("context-anchor: install failed.\n");
  process.stderr.write(`${detail}\n`);
  process.stderr.write("install requires a working swift toolchain right now.\n");
  process.exit(1);
}
