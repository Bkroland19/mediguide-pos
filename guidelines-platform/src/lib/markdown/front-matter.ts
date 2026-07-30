import { parse } from "yaml";

import type { MarkdownMetadata } from "../../types/content";

export function parseFrontMatter(source: string): {
  metadata: MarkdownMetadata;
  content: string;
} {
  const normalizedSource = source.replace(/\r\n/g, "\n");

  if (!normalizedSource.startsWith("---\n")) {
    return { metadata: {}, content: normalizedSource };
  }

  const closingDelimiterIndex = normalizedSource.indexOf("\n---\n", 4);
  if (closingDelimiterIndex === -1) {
    return { metadata: {}, content: normalizedSource };
  }

  const frontMatter = normalizedSource.slice(4, closingDelimiterIndex);
  const content = normalizedSource.slice(closingDelimiterIndex + 5);

  try {
    const parsed = parse(frontMatter);
    return {
      metadata:
        parsed && typeof parsed === "object"
          ? (parsed as MarkdownMetadata)
          : {},
      content,
    };
  } catch {
    return { metadata: {}, content: normalizedSource };
  }
}
