import { readdir, readFile, writeFile } from "node:fs/promises";
import { basename, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const contentRoot = fileURLToPath(
  new URL("../src/content/chapters_split/", import.meta.url),
);

async function collectMarkdownFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const nestedFiles = await Promise.all(
    entries.map((entry) => {
      const path = join(directory, entry.name);
      return entry.isDirectory()
        ? collectMarkdownFiles(path)
        : Promise.resolve(entry.name.endsWith(".md") ? [path] : []);
    }),
  );
  return nestedFiles.flat().sort();
}

function calloutLabel(type, title) {
  if (title) return title;
  const labels = {
    caution: "Caution",
    example: "Example",
    info: "Information",
    note: "Note",
    quote: "Key point",
    tip: "Tip",
    warning: "Warning",
  };
  return labels[type.toLowerCase()] ?? type;
}

function convertCallouts(lines) {
  const output = [];

  for (let index = 0; index < lines.length; index += 1) {
    const match = /^!!!\s+([\w-]+)(?:\s+"([^"]+)"|\s+(.+))?\s*$/.exec(
      lines[index],
    );
    if (!match) {
      output.push(lines[index]);
      continue;
    }

    const title = match[2] ?? (match[3] ? `${match[1]} ${match[3]}` : undefined);
    output.push(`> **${calloutLabel(match[1], title)}**`);
    let bodyIndex = index + 1;

    while (
      bodyIndex < lines.length &&
      (lines[bodyIndex].trim() === "" || /^\s+/.test(lines[bodyIndex]))
    ) {
      const line = lines[bodyIndex];
      output.push(line.trim() === "" ? ">" : `> ${line.replace(/^ {1,4}/, "")}`);
      bodyIndex += 1;
    }

    index = bodyIndex - 1;
  }

  return output;
}

function deduplicateAdjacentHeadings(lines) {
  const output = [];

  for (const line of lines) {
    const heading = /^#{1,6}\s+(.+)$/.exec(line);
    if (heading) {
      const previousLine = output.findLast((candidate) => candidate.trim() !== "");
      const previousHeading = previousLine
        ? /^#{1,6}\s+(.+)$/.exec(previousLine)
        : undefined;
      if (
        previousHeading &&
        previousHeading[1].trim().toLowerCase() ===
          heading[1].trim().toLowerCase()
      ) {
        continue;
      }
    }
    output.push(line);
  }

  return output;
}

function deduplicateOpeningHeadings(lines) {
  const seen = new Set();
  let inOpeningHeadings = true;

  return lines.filter((line) => {
    if (!inOpeningHeadings) return true;
    if (line.trim() === "") return true;

    const heading = /^(#{1,6})\s+(.+)$/.exec(line);
    if (!heading) {
      inOpeningHeadings = false;
      return true;
    }

    const key = `${heading[1]}:${heading[2].trim().toLowerCase()}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function formatMarkdown(source, fallbackChapterTitle) {
  let text = source
    .replace(/\r\n?/g, "\n")
    .replace(/\t/g, "    ")
    .replace(/[\u0080-\u009f]/g, "•")
    .replace(/[ \t]+$/gm, "")
    .replace(/^<\/?figure(?:\s+[^>]*)?>\s*$/gim, "")
    .replace(/(!\[[^\]]*\]\([^\n)]+\))\s*\{[^\n}]*\}/g, "$1")
    .replace(/^(#{1,6})([^#\s])/gm, "$1 $2");

  let lines = convertCallouts(text.split("\n"));
  lines = deduplicateOpeningHeadings(lines);
  lines = deduplicateAdjacentHeadings(lines);

  if (!lines.some((line) => /^#\s+/.test(line)) && fallbackChapterTitle) {
    lines.unshift(fallbackChapterTitle, "");
  }

  text = lines.join("\n").replace(/\n{4,}/g, "\n\n\n").trimEnd();
  return `${text}\n`;
}

const files = await collectMarkdownFiles(contentRoot);
const chapterTitles = new Map();

for (const file of files.filter((path) => basename(path) === "index.md")) {
  const source = await readFile(file, "utf8");
  const title = source.match(/^#\s+.+$/m)?.[0];
  if (title) chapterTitles.set(dirname(file), title);
}

let changed = 0;
for (const file of files) {
  const source = await readFile(file, "utf8");
  const formatted = formatMarkdown(source, chapterTitles.get(dirname(file)));
  if (formatted !== source) {
    await writeFile(file, formatted);
    changed += 1;
  }
}

console.log(`Formatted ${changed} of ${files.length} Markdown files.`);
