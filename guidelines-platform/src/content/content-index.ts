import rawManifest from "./generated-manifest.json";

import { buildNavigationTree } from "../lib/markdown/navigation";
import { normalizeContentRoute } from "../lib/markdown/paths";
import type { ContentManifestItem } from "../types/content";

export const contentManifest = rawManifest as ContentManifestItem[];

export function getPublicationDocuments(publicationId: string) {
  return contentManifest.filter((item) => item.publicationId === publicationId);
}

export function getPublicationNavigation(publicationId: string) {
  return buildNavigationTree(getPublicationDocuments(publicationId));
}

export function getContentByRoute(
  publicationId: string,
  route: string | undefined,
) {
  if (!route) return undefined;
  const normalizedRoute = normalizeContentRoute(route);

  return contentManifest.find(
    (item) =>
      item.publicationId === publicationId && item.route === normalizedRoute,
  );
}

export function getAdjacentDocuments(item: ContentManifestItem) {
  const documents = getPublicationDocuments(item.publicationId);
  const activeIndex = documents.findIndex((document) => document.id === item.id);

  return {
    previous: activeIndex > 0 ? documents[activeIndex - 1] : undefined,
    next:
      activeIndex >= 0 && activeIndex < documents.length - 1
        ? documents[activeIndex + 1]
        : undefined,
  };
}
