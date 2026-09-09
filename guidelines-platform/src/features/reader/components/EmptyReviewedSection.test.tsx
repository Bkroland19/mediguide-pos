import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import type { PublicGuidelineBlock, PublicGuidelineSection } from "../../../api/public-guidelines";
import { EmptyReviewedSection } from "./EmptyReviewedSection";
import { reviewedDescendants } from "./empty-reviewed-section";

const section = (id: string, parent_id?: string): PublicGuidelineSection => ({ id, parent_id, title: id, slug: id, level: parent_id ? 2 : 1, sort_order: 1 });

describe("EmptyReviewedSection", () => {
  it("does not offer an unavailable original document for an empty leaf", () => {
    const html = renderToStaticMarkup(<EmptyReviewedSection hasOriginalDocument={false} descendants={[]} onSection={() => undefined} onOpenOriginal={() => undefined} />);
    expect(html).toContain("This section has not yet been published as reviewed content.");
    expect(html).toContain("0 reviewed blocks");
    expect(html).not.toContain("Open original document");
  });

  it("offers the original only when it exists", () => {
    const html = renderToStaticMarkup(<EmptyReviewedSection hasOriginalDocument descendants={[]} onSection={() => undefined} onOpenOriginal={() => undefined} />);
    expect(html).toContain("No approved structured content is available for this section.");
    expect(html).toContain("Open original document");
  });

  it("treats an empty parent with reviewed descendants as a container", () => {
    const sections = [section("root"), section("chapter", "root"), section("leaf", "chapter")];
    const blocks: PublicGuidelineBlock[] = [{ id: "block", section_id: "leaf", type: "paragraph", sort_order: 1, content: { text: "reviewed" } }];
    const descendants = reviewedDescendants("root", sections, blocks);
    expect(descendants.map((item) => item.id)).toEqual(["leaf"]);
    const html = renderToStaticMarkup(<EmptyReviewedSection hasOriginalDocument={false} descendants={descendants} onSection={() => undefined} onOpenOriginal={() => undefined} />);
    expect(html).toContain("Reviewed content in this chapter");
    expect(html).not.toContain("0 reviewed blocks");
  });
});
