import { describe, expect, it } from "vitest";

import { parseFrontMatter } from "./front-matter";

describe("parseFrontMatter", () => {
  it("parses metadata and separates content", () => {
    const result = parseFrontMatter(
      "---\ntitle: Malaria\norder: 2\n---\n# Guidance\n",
    );

    expect(result.metadata).toEqual({ title: "Malaria", order: 2 });
    expect(result.content).toBe("# Guidance\n");
  });

  it("keeps ordinary Markdown unchanged", () => {
    const source = "# Guidance\n\nClinical content.";
    expect(parseFrontMatter(source)).toEqual({ metadata: {}, content: source });
  });

  it("fails safely when front matter is malformed", () => {
    const source = "---\ntitle: [broken\n---\n# Guidance\n";
    expect(parseFrontMatter(source)).toEqual({ metadata: {}, content: source });
  });
});
