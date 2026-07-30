import { describe, expect, it } from "vitest";

import {
  normalizeContentRoute,
  resolveRelativeAssetPath,
} from "./paths";

describe("Markdown paths", () => {
  it("resolves assets relative to their document", () => {
    expect(
      resolveRelativeAssetPath(
        "./chapters_split/05/5-01-asthma.md",
        "images/asthma.png",
      ),
    ).toBe("chapters_split/05/images/asthma.png");
  });

  it("maps legacy extracted-image directories to chapter image folders", () => {
    expect(
      resolveRelativeAssetPath(
        "./chapters_split/17/growth.md",
        "UCG2023_images/imageFile29.png",
      ),
    ).toBe("chapters_split/17/images/imageFile29.png");
  });

  it("preserves external and root-relative assets", () => {
    expect(resolveRelativeAssetPath("./chapter.md", "https://example.org/a.png"))
      .toBe("https://example.org/a.png");
    expect(resolveRelativeAssetPath("./chapter.md", "/images/a.png")).toBe(
      "/images/a.png",
    );
  });

  it("normalizes reader routes", () => {
    expect(normalizeContentRoute("/chapters/01/emergencies/")).toBe(
      "chapters/01/emergencies",
    );
  });
});
