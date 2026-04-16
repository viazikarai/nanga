#!/usr/bin/env node

// launch the staged swift binary installed by npm.
const fs = require("node:fs");
const path = require("node:path");
const cp = require("node:child_process");

const root = path.resolve(__dirname, "..");
const args = process.argv.slice(2);

const candidates = [
  path.join(root, "vendor", "context-anchor"),
  path.join(root, ".build", "release", "context-anchor"),
  path.join(root, ".build", "arm64-apple-macosx", "release", "context-anchor"),
  path.join(root, ".build", "x86_64-apple-macosx", "release", "context-anchor"),
  path.join(root, ".build", "x86_64-unknown-linux-gnu", "release", "context-anchor"),
  path.join(root, ".build", "aarch64-unknown-linux-gnu", "release", "context-anchor"),
];

const binaryPath = candidates.find((candidate) => fs.existsSync(candidate));

if (!binaryPath) {
  process.stderr.write("context-anchor: binary not found.\n");
  process.stderr.write("run `npm rebuild context-anchor` or reinstall the package.\n");
  process.exit(1);
}

const child = cp.spawn(binaryPath, args, {
  stdio: "inherit",
});

child.on("exit", (code, signal) => {
  if (signal) {
    process.kill(process.pid, signal);
    return;
  }

  process.exit(code ?? 1);
});
