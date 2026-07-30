import { access, readdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const projectRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const contentRoot = join(projectRoot, "src/content/chapters_split");
const outputPath = join(projectRoot, "src/content/generated-manifest.json");

async function walk(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = await Promise.all(
    entries.map((entry) => {
      const path = join(directory, entry.name);
      return entry.isDirectory() ? walk(path) : path;
    }),
  );

  return files.flat();
}

function cleanHeading(value) {
  return value
    .replace(/\[([^\]]+)\]\([^)]*\)/g, "$1")
    .replace(/[*_`~]/g, "")
    .replace(/^Chapter\s+\d+\s*:\s*/i, "")
    .trim();
}

function titleFromFilename(stem) {
  return stem
    .replace(/^\d+(?:-\d+)*-?/, "")
    .split("-")
    .filter(Boolean)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(" ");
}

function getSectionNumber(stem) {
  const match = /^(\d+(?:-\d+)*)/.exec(stem);
  if (!match) return undefined;

  return match[1]
    .split("-")
    .map((part) => String(Number(part)))
    .join(".");
}

function getTitle(source, stem, sectionNumber) {
  const headings = source
    .split(/\r?\n/)
    .flatMap((line) => {
      const match = /^(#{1,6})\s+(.+?)\s*#*$/.exec(line);
      return match
        ? [{ depth: match[1].length, text: cleanHeading(match[2]) }]
        : [];
    });

  if (sectionNumber) {
    const exactHeading = headings.find(({ text }) =>
      text.toLowerCase().startsWith(sectionNumber.toLowerCase()),
    );
    if (exactHeading) {
      return exactHeading.text
        .replace(new RegExp(`^${sectionNumber.replaceAll(".", "\\.")}\\s*`), "")
        .trim();
    }
  }

  return (
    headings.find(({ depth }) => depth > 1)?.text ||
    headings[0]?.text ||
    titleFromFilename(stem)
  );
}

function orderFromStem(stem) {
  const match = /^(\d+(?:-\d+)*)/.exec(stem);
  if (!match) return [Number.MAX_SAFE_INTEGER];
  return match[1].split("-").map(Number);
}

function extractRelativeAssets(source) {
  const matches = [
    ...source.matchAll(/!\[[^\]]*\]\(([^)\s]+)(?:\s+["'][^)]*)?\)/g),
    ...source.matchAll(/<img[^>]+src=["']([^"']+)["']/gi),
  ];

  return matches
    .map((match) => match[1])
    .filter((value) => value && !/^(?:[a-z]+:|\/|#)/i.test(value))
    .map((value) => value.replace(/(^|\/)UCG2023_images\//, "$1images/"));
}

const markdownFiles = (await walk(contentRoot))
  .filter((path) => path.endsWith(".md"))
  .filter((path) => !path.endsWith(`${sep}index.md`));

const documents = await Promise.all(
  markdownFiles.map(async (path) => {
    const relativePath = relative(contentRoot, path).split(sep).join("/");
    const sourcePath = `./chapters_split/${relativePath}`;
    const source = await readFile(path, "utf8");
    const stem = relativePath.replace(/\.md$/, "").split("/").at(-1);

    if (relativePath === "00-front-matter.md") {
      return {
        id: "front-matter",
        publicationId: "uganda-clinical-guidelines",
        sourcePath,
        route: "front-matter",
        chapter: 0,
        chapterTitle: "Front matter",
        sectionNumber: "0",
        title: "Front Matter",
        order: [-1],
      };
    }

    const chapterMatch = /^(\d+)\//.exec(relativePath);
    if (!chapterMatch || !stem) return null;

    const chapter = Number(chapterMatch[1]);
    const chapterIndexPath = join(contentRoot, chapterMatch[1], "index.md");
    let chapterTitle = `Chapter ${chapter}`;

    try {
      const chapterSource = await readFile(chapterIndexPath, "utf8");
      const chapterHeading = /^#\s+(.+)$/m.exec(chapterSource)?.[1];
      if (chapterHeading) chapterTitle = cleanHeading(chapterHeading);
    } catch {
      // A fallback chapter title is sufficient when an index is absent.
    }

    const sectionNumber = getSectionNumber(stem);
    return {
      id: `${chapterMatch[1]}-${stem}`,
      publicationId: "uganda-clinical-guidelines",
      sourcePath,
      route: `chapters/${chapterMatch[1]}/${stem}`,
      chapter,
      chapterTitle,
      sectionNumber,
      title: getTitle(source, stem, sectionNumber),
      order: orderFromStem(stem),
    };
  }),
);

const manifest = documents
  .filter(Boolean)
  .sort((first, second) => {
    const maxLength = Math.max(first.order.length, second.order.length);
    for (let index = 0; index < maxLength; index += 1) {
      const difference =
        (first.order[index] ?? -1) - (second.order[index] ?? -1);
      if (difference !== 0) return difference;
    }
    return first.route.localeCompare(second.route);
  });

const duplicateCheck = new Set();
for (const item of manifest) {
  if (!item.title.trim()) {
    throw new Error(`Missing title for ${item.sourcePath}`);
  }
  if (duplicateCheck.has(item.route)) {
    throw new Error(`Duplicate content route: ${item.route}`);
  }
  duplicateCheck.add(item.route);
}

const brokenAssets = [];
for (const path of markdownFiles) {
  const source = await readFile(path, "utf8");
  for (const asset of extractRelativeAssets(source)) {
    const assetPath = resolve(dirname(path), asset);
    try {
      await access(assetPath);
    } catch {
      brokenAssets.push(
        `${relative(contentRoot, path).split(sep).join("/")}: ${asset}`,
      );
    }
  }
}

await writeFile(outputPath, `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`Generated ${manifest.length} content manifest entries.`);
if (brokenAssets.length > 0) {
  console.warn(
    `Content warning: ${brokenAssets.length} referenced assets are missing:\n` +
      brokenAssets.map((asset) => `- ${asset}`).join("\n"),
  );
}
