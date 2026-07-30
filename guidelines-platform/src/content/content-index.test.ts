import { describe, expect, it } from "vitest";

import {
  contentManifest,
  getContentByRoute,
  getPublicationNavigation,
} from "./content-index";

describe("generated content index", () => {
  it("contains unique routes and source files", () => {
    const routes = contentManifest.map(({ route }) => route);
    const sources = contentManifest.map(({ sourcePath }) => sourcePath);

    expect(new Set(routes).size).toBe(routes.length);
    expect(new Set(sources).size).toBe(sources.length);
  });

  it("resolves a valid route and returns undefined for missing content", () => {
    expect(
      getContentByRoute("uganda-clinical-guidelines", "/front-matter/")?.id,
    ).toBe("front-matter");
    expect(
      getContentByRoute("uganda-clinical-guidelines", "not-a-real-page"),
    ).toBeUndefined();
  });

  it("builds front matter plus 24 clinical chapters", () => {
    const navigation = getPublicationNavigation("uganda-clinical-guidelines");
    expect(navigation.map(({ number }) => number)).toEqual([
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
      20, 21, 22, 23, 24,
    ]);
  });
});
