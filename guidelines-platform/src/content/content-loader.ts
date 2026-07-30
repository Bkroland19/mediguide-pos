import { parseFrontMatter } from "../lib/markdown/front-matter";
import { resolveRelativeAssetPath } from "../lib/markdown/paths";
import type { ContentManifestItem, MarkdownDocument } from "../types/content";

type RawMarkdownLoader = () => Promise<string>;

const markdownModules = import.meta.glob<string>(
  [
    "./chapters_split/**/*.md",
    "!./chapters_split/**/index.md",
  ],
  {
    query: "?raw",
    import: "default",
  },
);

const markdownAssets = import.meta.glob<string>(
  "./chapters_split/**/*.{png,jpg,jpeg,gif,svg,webp}",
  {
    query: "?url",
    import: "default",
    eager: true,
  },
);

export async function loadMarkdownDocument(
  item: ContentManifestItem,
): Promise<MarkdownDocument> {
  const loader = markdownModules[item.sourcePath] as
    | RawMarkdownLoader
    | undefined;

  if (!loader) {
    throw new Error(`No Markdown module found for ${item.sourcePath}`);
  }

  const source = await loader();
  const parsed = parseFrontMatter(source);

  return {
    ...item,
    content: parsed.content,
    metadata: parsed.metadata,
    title: parsed.metadata.title ?? item.title,
  };
}

export function resolveMarkdownAsset(
  item: ContentManifestItem,
  source: string | undefined,
) {
  const assetPath = resolveRelativeAssetPath(item.sourcePath, source);
  return assetPath ? (markdownAssets[`./${assetPath}`] ?? source) : source;
}
