#!/usr/bin/env node
// Points every registry URL in the apps' package-lock.json files at the public npm registry.
// Installs made through a registry proxy record the proxy's host in "resolved", which the
// catalog build and anyone outside that network cannot reach. Tarball paths and integrity
// hashes are the same on both, so only the host changes.
//
//   node scripts/normalize-lock.mjs [lock files...]   rewrite (default: every apps/*/package-lock.json)
//   node scripts/normalize-lock.mjs --check [...]     exit 1 if any lock file needs rewriting

import { execFileSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const PUBLIC_REGISTRY = "https://registry.npmjs.org/";
const root = join(dirname(fileURLToPath(import.meta.url)), "..");

const args = process.argv.slice(2);
const check = args.includes("--check");
const given = args.filter((arg) => arg !== "--check");

const lockFiles = given.length > 0 ? given : findLockFiles();

function findLockFiles() {
  const appsDir = join(root, "apps");
  return readdirSync(appsDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => join(appsDir, entry.name, "package-lock.json"))
    .filter((file) => existsSync(file));
}

function configuredRegistry() {
  const registry = execFileSync("npm", ["config", "get", "registry"], { encoding: "utf8" }).trim();
  return registry.endsWith("/") ? registry : `${registry}/`;
}

// In check mode any registry host other than the public one is a failure. When rewriting,
// only the locally configured registry is replaced, so git and file dependencies are left alone.
const proxy = check ? null : configuredRegistry();

let failed = false;

for (const file of lockFiles) {
  const lock = JSON.parse(readFileSync(file, "utf8"));
  const label = relative(process.cwd(), file);
  let count = 0;

  for (const entry of Object.values(lock.packages ?? {})) {
    const resolved = entry.resolved;
    if (typeof resolved !== "string" || !/^https?:\/\//.test(resolved)) continue;
    if (resolved.startsWith(PUBLIC_REGISTRY)) continue;

    if (check) {
      count += 1;
    } else if (proxy !== PUBLIC_REGISTRY && resolved.startsWith(proxy)) {
      entry.resolved = PUBLIC_REGISTRY + resolved.slice(proxy.length);
      count += 1;
    }
  }

  if (check && count > 0) {
    failed = true;
    console.error(`${label}: ${count} package(s) not resolved from ${PUBLIC_REGISTRY}`);
  } else if (!check && count > 0) {
    writeFileSync(file, `${JSON.stringify(lock, null, 2)}\n`);
    console.log(`${label}: rewrote ${count} URL(s)`);
  } else {
    console.log(`${label}: ok`);
  }
}

if (failed) {
  console.error("Run `node scripts/normalize-lock.mjs` and commit the result.");
  process.exit(1);
}
