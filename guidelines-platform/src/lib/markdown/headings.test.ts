import { describe, expect, it } from "vitest";

import { getMarkdownHeadings } from "./headings";

describe("getMarkdownHeadings", () => {
  it("extracts navigable headings with stable duplicate slugs", () => {
    expect(
      getMarkdownHeadings(
        "# Page\n## Clinical *features*\n### Management\n## Clinical features\n",
      ),
    ).toEqual([
      { depth: 2, text: "Clinical features", id: "clinical-features" },
      { depth: 3, text: "Management", id: "management" },
      { depth: 2, text: "Clinical features", id: "clinical-features-1" },
    ]);
  });
});
