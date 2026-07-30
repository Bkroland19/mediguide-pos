import GithubSlugger from "github-slugger";

import type { MarkdownHeading } from "../../types/content";

export function stripMarkdown(value: string) {
  return value
    .replace(/\[([^\]]+)\]\([^)]*\)/g, "$1")
    .replace(/[*_`~]/g, "")
    .trim();
}

export function getMarkdownHeadings(content: string): MarkdownHeading[] {
  const slugger = new GithubSlugger();

  return content.split("\n").flatMap((line) => {
    const match = /^(#{1,6})\s+(.+?)\s*#*$/.exec(line);
    if (!match) return [];

    const depth = match[1].length;
    const text = stripMarkdown(match[2]);
    const id = slugger.slug(text);

    return depth >= 2 && depth <= 4 ? [{ depth, text, id }] : [];
  });
}
