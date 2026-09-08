#!/usr/bin/env bun

import { readFile, writeFile } from "node:fs/promises";
import { basename } from "node:path";

const [inputPath, outputPath] = process.argv.slice(2);
if (!inputPath || !outputPath) {
  console.error(
    "Usage: bun scripts/normalize-guideline-markdown.mjs <input.md> <output.md>",
  );
  process.exit(2);
}

const legacyCalloutTypes = new Map([
  ["note", { type: "clinical-note" }],
  ["info", { type: "clinical-note" }],
  ["tip", { type: "key-point" }],
  ["example", { type: "clinical-note" }],
  ["quote", { type: "clinical-note" }],
  ["caution", { type: "caution" }],
  ["warning", { type: "warning" }],
  ["danger", { type: "warning", severity: "critical" }],
  ["important", { type: "warning", severity: "important" }],
]);

const source = (await readFile(inputPath, "utf8")).replace(/\r\n?/gu, "\n");
const sourceLines = source.split("\n");
const converted = [];
const calloutChanges = [];

for (let index = 0; index < sourceLines.length; index += 1) {
  const line = sourceLines[index].replace(/[ \t]+$/u, "");
  const opening =
    /^([ \t]*)!!!\s+([a-z_-]+)(?:\s+(?:"([^"]*)"|'([^']*)'|(.+)))?\s*$/iu.exec(
      line,
    );
  if (!opening) {
    converted.push(line);
    continue;
  }

  const legacyType = opening[2].toLowerCase();
  const mapping = legacyCalloutTypes.get(legacyType);
  if (!mapping) {
    throw new Error(
      `Unsupported legacy callout type “${legacyType}” on line ${index + 1}`,
    );
  }

  let cursor = index + 1;
  while (cursor < sourceLines.length && !sourceLines[cursor].trim()) cursor += 1;
  if (cursor >= sourceLines.length) {
    throw new Error(`Legacy callout on line ${index + 1} has no content`);
  }

  const firstBody = sourceLines[cursor];
  const firstIndent = /^[ \t]*/u.exec(firstBody)?.[0].length ?? 0;
  const body = [];
  if (firstIndent === 0) {
    while (
      cursor < sourceLines.length &&
      sourceLines[cursor].trim() &&
      !/^\s*!!!\s+/u.test(sourceLines[cursor])
    ) {
      const candidate = sourceLines[cursor].replace(/[ \t]+$/u, "");
      body.push(candidate);
      cursor += 1;
      if (/[.!?]["')\]]*$/u.test(candidate.trim())) break;
    }
  } else {
    let pendingBlankLines = [];
    while (cursor < sourceLines.length) {
      const candidate = sourceLines[cursor].replace(/[ \t]+$/u, "");
      if (!candidate.trim()) {
        pendingBlankLines.push("");
        cursor += 1;
        continue;
      }
      const indentation = /^[ \t]*/u.exec(candidate)?.[0].length ?? 0;
      if (indentation < firstIndent) break;
      body.push(...pendingBlankLines);
      pendingBlankLines = [];
      body.push(candidate.slice(firstIndent));
      cursor += 1;
    }
  }

  if (!body.some((value) => value.trim())) {
    throw new Error(`Legacy callout on line ${index + 1} has no content`);
  }

  const quotedTitle = opening[3] ?? opening[4];
  const unquotedTitle = opening[5]
    ? `${opening[2]} ${opening[5]}`
    : undefined;
  const title = (quotedTitle ?? unquotedTitle)?.trim().replaceAll('"', "'");
  const metadata = [
    title ? `title="${title}"` : "",
    mapping.severity ? `severity=${mapping.severity}` : "",
  ]
    .filter(Boolean)
    .join(" ");
  converted.push(`:::${mapping.type}${metadata ? ` ${metadata}` : ""}`);
  converted.push(...body);
  converted.push(":::");
  calloutChanges.push({
    line: index + 1,
    from: legacyType,
    to: mapping.type,
  });
  index = cursor - 1;
}

const headingPattern = /^(#{1,6})\s+(.+?)\s*#*\s*$/u;
const headings = [];
const usedAnchors = new Set();
const headingChanges = [];

function headingAnchor(value) {
  return value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9\s-]/gu, "")
    .replace(/[\s-]+/gu, "-")
    .replace(/^-+|-+$/gu, "");
}

for (let index = 0; index < converted.length; index += 1) {
  const match = headingPattern.exec(converted[index]);
  if (!match) continue;
  const level = match[1].length;
  while (headings.length && headings.at(-1).level >= level) headings.pop();

  const original = match[2].trim();
  let replacement = original;
  let anchor = headingAnchor(replacement);
  if (usedAnchors.has(anchor)) {
    const parent = headings.at(-1)?.text;
    const context = parent ? parent.replace(/^\d+(?:\.\d+)*\s*/u, "") : "continued";
    replacement = `${original} — ${context}`;
    anchor = headingAnchor(replacement);
    let suffix = 2;
    while (usedAnchors.has(anchor)) {
      replacement = `${original} — ${context} (${suffix})`;
      anchor = headingAnchor(replacement);
      suffix += 1;
    }
    converted[index] = `${match[1]} ${replacement}`;
    headingChanges.push({ line: index + 1, from: original, to: replacement });
  }
  usedAnchors.add(anchor);
  headings.push({ level, text: replacement });
}

const output = converted.join("\n").replace(/\n{4,}/gu, "\n\n\n").trimEnd() + "\n";
await writeFile(outputPath, output, "utf8");

console.log(
  JSON.stringify(
    {
      input: basename(inputPath),
      output: basename(outputPath),
      legacyCalloutsConverted: calloutChanges.length,
      duplicateHeadingsDisambiguated: headingChanges.length,
      headingChanges,
    },
    null,
    2,
  ),
);
