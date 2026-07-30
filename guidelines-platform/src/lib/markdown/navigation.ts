import type {
  ContentManifestItem,
  NavigationChapter,
} from "../../types/content";

export function compareContentOrder(
  first: ContentManifestItem,
  second: ContentManifestItem,
) {
  const maxLength = Math.max(first.order.length, second.order.length);

  for (let index = 0; index < maxLength; index += 1) {
    const difference = (first.order[index] ?? -1) - (second.order[index] ?? -1);
    if (difference !== 0) return difference;
  }

  return first.route.localeCompare(second.route);
}

export function buildNavigationTree(
  items: ContentManifestItem[],
): NavigationChapter[] {
  const chapters = new Map<number, NavigationChapter>();

  for (const item of [...items].sort(compareContentOrder)) {
    const existing = chapters.get(item.chapter);
    if (existing) {
      existing.items.push(item);
      continue;
    }

    chapters.set(item.chapter, {
      number: item.chapter,
      title: item.chapterTitle,
      items: [item],
    });
  }

  return [...chapters.values()];
}
