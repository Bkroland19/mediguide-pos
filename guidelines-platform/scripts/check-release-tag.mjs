import { readFile } from "node:fs/promises";

const packageJson = JSON.parse(
  await readFile(new URL("../package.json", import.meta.url), "utf8"),
);
const tag = process.argv[2] ?? process.env.GITHUB_REF_NAME;

if (!tag) {
  console.error(
    "A release tag is required. Pass one as an argument or set GITHUB_REF_NAME.",
  );
  process.exit(1);
}

const expectedTag = `v${packageJson.version}`;

if (tag !== expectedTag) {
  console.error(
    `Release tag ${tag} does not match package version ${packageJson.version}; expected ${expectedTag}.`,
  );
  process.exit(1);
}

console.log(`Release tag ${tag} matches package version ${packageJson.version}.`);
