import { describe, expect, it } from "vitest";

import type { ContentManifestItem } from "../../types/content";
import { buildNavigationTree, compareContentOrder } from "./navigation";

function item(
  id: string,
  chapter: number,
  order: number[],
): ContentManifestItem {
  return {
    id,
    publicationId: "test",
    sourcePath: `./${id}.md`,
    route: id,
    chapter,
    chapterTitle: `Chapter ${chapter}`,
    title: id,
    order,
  };
}

describe("content navigation", () => {
  it("orders numeric sections naturally", () => {
    const values = [
      item("section-10", 1, [1, 10]),
      item("section-2", 1, [1, 2]),
      item("section-2-1", 1, [1, 2, 1]),
    ].sort(compareContentOrder);

    expect(values.map(({ id }) => id)).toEqual([
      "section-2",
      "section-2-1",
      "section-10",
    ]);
  });

  it("groups ordered documents by chapter", () => {
    const tree = buildNavigationTree([
      item("chapter-2", 2, [2]),
      item("chapter-1", 1, [1]),
    ]);

    expect(tree.map(({ number }) => number)).toEqual([1, 2]);
  });
});
