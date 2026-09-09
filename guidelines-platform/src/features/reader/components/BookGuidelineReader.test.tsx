import { describe, expect, it } from "vitest";

import { bookReaderPublicationGuidance } from "./book-reader-publication-guidance";

describe("BookGuidelineReader partial publication guidance", () => {
  it("does not advertise an unavailable original document", () => {
    const guidance = bookReaderPublicationGuidance(true, false);
    expect(guidance.showOriginal).toBe(false);
    expect(guidance.partialNotice).toContain("reviewed public content currently available");
    expect(guidance.partialNotice).not.toContain("original document as the fidelity reference");
  });

  it("offers and explains the original PDF only when it exists", () => {
    const guidance = bookReaderPublicationGuidance(true, true);
    expect(guidance.showOriginal).toBe(true);
    expect(guidance.partialNotice).toContain("open the original PDF as the fidelity reference");
  });

  it("does not show partial-publication guidance for a complete publication", () => {
    expect(bookReaderPublicationGuidance(false, false).partialNotice).toBeUndefined();
  });
});
