import { readFile } from "node:fs/promises";

const apiBaseUrl = (process.env.MEDIGUIDE_API_URL || process.argv[2] || "http://localhost:8080")
  .replace(/\/+$/, "");
const source = await readFile(new URL("../src/content/publications.ts", import.meta.url), "utf8");
const bundledSlugs = [...source.matchAll(/\bslug:\s*"([^"]+)"/g)].map((match) => match[1]);

const response = await fetch(`${apiBaseUrl}/api/public/guidelines?page=1&per_page=100`, {
  headers: { Accept: "application/json" },
});
if (!response.ok) {
  throw new Error(`Public guideline list returned HTTP ${response.status}`);
}
const envelope = await response.json();
const publicSlugs = new Set((envelope.data?.items ?? []).map((item) => item.slug));
const missing = bundledSlugs.filter((slug) => !publicSlugs.has(slug));

console.log(`Bundled publications: ${bundledSlugs.length}`);
console.log(`Backend publications: ${publicSlugs.size}`);
if (missing.length) {
  console.log("Bundled publications missing from the backend:");
  for (const slug of missing) console.log(`- ${slug}`);
  process.exitCode = 1;
} else {
  console.log("Every bundled publication has a matching public backend slug.");
}
