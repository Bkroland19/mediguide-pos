import { describe, expect, it } from "vitest";

import {
  formatMarkdown,
  clinicalCalloutMarkdown,
  lineDiff,
  markdownHeadings,
  markdownTemplates,
  moveMarkdownSection,
  parseClinicalCallouts,
  prepareMarkdownForReview,
  stableHeadingAnchors,
  validateMarkdown,
  wordDiff,
} from "./markdown-authoring";

describe("Markdown authoring utilities", () => {
  it("provides structure-only templates for each required clinical document type", () => {
    expect(markdownTemplates.map((template) => template.key)).toEqual([
      "general",
      "emergency",
      "medication",
      "diagnostic",
      "procedure",
      "outbreak",
    ]);
    for (const template of markdownTemplates) {
      expect(template.content).toMatch(/^# /u);
      expect(template.content).toContain("_Add reviewed clinical content._");
    }
  });

  it("builds stable heading navigation with section word counts", () => {
    const headings = markdownHeadings(
      "# Care\n\nIntro words.\n\n## Assessment\n\nCheck danger signs.",
    );

    expect(headings).toEqual([
      expect.objectContaining({ id: "care", level: 1, line: 1, words: 2 }),
      expect.objectContaining({
        id: "assessment",
        level: 2,
        line: 5,
        words: 3,
      }),
    ]);
  });

  it("indexes large clinical documents without changing heading boundaries", () => {
    const markdown = Array.from(
      { length: 2_000 },
      (_, index) =>
        `## Section ${index + 1}\n\nClinical recommendation ${index + 1}.`,
    ).join("\n\n");

    const headings = markdownHeadings(`# Guideline\n\n${markdown}`);

    expect(headings).toHaveLength(2_001);
    expect(headings[0]).toEqual(
      expect.objectContaining({
        text: "Guideline",
        words: 0,
        breadcrumb: ["Guideline"],
      }),
    );
    expect(headings[1]).toEqual(
      expect.objectContaining({
        text: "Section 1",
        words: 3,
        breadcrumb: ["Guideline", "Section 1"],
      }),
    );
    expect(headings.at(-1)).toEqual(
      expect.objectContaining({ text: "Section 2000", words: 3 }),
    );
    expect(headings.at(-1)?.end).toBe(
      markdown.length + "# Guideline\n\n".length + 1,
    );
  });

  it("blocks executable Markdown and detects structural/callout errors", () => {
    const issues = validateMarkdown(
      "## Assessment\n\n#### Details\n\n<script>alert(1)</script>\n\n:::warning\nReview.",
    );

    expect(issues.map((issue) => issue.code)).toEqual(
      expect.arrayContaining([
        "missing_h1",
        "skipped_heading_level",
        "unsafe_html",
        "unclosed_callout",
      ]),
    );
    expect(issues.find((issue) => issue.code === "unsafe_html")?.severity).toBe(
      "error",
    );
  });

  it("treats duplicate anchors and missing image alt text as production errors", () => {
    const issues = validateMarkdown(
      "# Care\n\n## Review\n\n## Review\n\n![](asset:missing)",
    );

    expect(issues).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: "duplicate_heading_anchor",
          severity: "error",
          line: 5,
        }),
        expect.objectContaining({
          code: "missing_image_alt",
          severity: "error",
          line: 7,
        }),
      ]),
    );
  });

  it("accepts trailing empty table cells and literal pipes", () => {
    const issues = validateMarkdown(
      "# Care\n\n| Area | Primary | Secondary | Tertiary |\n| --- | --- | --- | --- |\n| History | x |  |  |\n| Expression | `a | b` | A \\| B |  |",
    );

    expect(issues.filter((issue) => issue.code === "malformed_table")).toEqual(
      [],
    );
    expect(issues).toContainEqual(
      expect.objectContaining({
        code: "high_risk_table_review_required",
        severity: "warning",
        message:
          "Clinical table “Care” requires explicit publisher review after regeneration.",
      }),
    );
  });

  it("rejects real table column mismatches", () => {
    const issues = validateMarkdown(
      "# Care\n\n| One | Two | Three |\n| --- | --- | --- |\n| A | B |",
    );

    expect(issues).toContainEqual(
      expect.objectContaining({
        code: "malformed_table",
        severity: "error",
        line: 5,
      }),
    );
  });

  it("formats line endings and creates a deterministic safe line diff", () => {
    expect(formatMarkdown("# Care\r\n\r\nOld.  \r\n")).toBe("# Care\n\nOld.\n");
    expect(lineDiff("# Care\nOld", "# Care\nNew")).toEqual([
      { type: "same", text: "# Care" },
      { type: "removed", text: "Old" },
      { type: "added", text: "New" },
    ]);
    expect(
      wordDiff("Give 5 mg", "Give 10 mg").filter(
        (part) => part.type !== "same",
      ),
    ).toEqual([
      { type: "removed", text: "5" },
      { type: "added", text: "10" },
    ]);
  });

  it("diffs large documents without allocating a quadratic line matrix", () => {
    const before = Array.from({ length: 5_000 }, (_, index) => `Line ${index}`);
    const after = [...before];
    after.splice(2_500, 1, "Updated clinical line");

    const result = lineDiff(before.join("\n"), after.join("\n"));

    expect(result.filter((line) => line.type === "removed")).toEqual([
      { type: "removed", text: "Line 2500" },
    ]);
    expect(result.filter((line) => line.type === "added")).toEqual([
      { type: "added", text: "Updated clinical line" },
    ]);
  });

  it("prepares legacy Markdown for review without changing clinical values", () => {
    const source = [
      "# Diabetes care  \r",
      "\r",
      "## Treatment\r",
      "\r",
      '!!! warning "Dose check"\r',
      "    Give 5 mg/kg every 8 hours.\r",
      "\r",
      "\r",
      "\r",
      "## Treatment\r",
      "\r",
      "Do not change 10 units subcutaneously.\r",
    ].join("\n");

    const result = prepareMarkdownForReview(source);

    expect(result.content).toContain(
      ':::warning title="Dose check"\nGive 5 mg/kg every 8 hours.\n:::',
    );
    expect(result.content).toContain("Do not change 10 units subcutaneously.");
    expect(result.content).toContain("## Treatment — Diabetes care");
    expect(result.changes).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ code: "converted_legacy_callouts", count: 1 }),
        expect.objectContaining({
          code: "disambiguated_duplicate_headings",
          category: "editor-review",
          count: 1,
        }),
      ]),
    );
    expect(
      result.afterIssues.filter(
        (issue) => issue.code === "duplicate_heading_anchor",
      ),
    ).toEqual([]);
    expect(prepareMarkdownForReview(result.content).content).toBe(result.content);
  });

  it("leaves code examples and unsupported legacy callouts for manual review", () => {
    const source =
      "# Examples\n\n```md\n!!! warning\n    Example only.\n```\n\n!!! custom\n    Needs a decision.\n";

    const result = prepareMarkdownForReview(source);

    expect(result.content).toContain("```md\n!!! warning\n    Example only.\n```");
    expect(result.content).toContain("!!! custom\n    Needs a decision.");
    expect(result.changes).toContainEqual(
      expect.objectContaining({
        code: "unsupported_legacy_callouts",
        category: "manual-review",
        count: 1,
      }),
    );
  });

  it("parses safe typed callouts without rewriting clinical values", () => {
    const source = clinicalCalloutMarkdown({
      type: "dosage",
      title: "Reviewed dose",
      severity: "high",
      evidenceGrade: "A",
      content: "Give 5 mg/kg.",
    });
    expect(source).toContain("Give 5 mg/kg.");
    expect(parseClinicalCallouts(source)).toEqual([
      expect.objectContaining({
        type: "dosage",
        title: "Reviewed dose",
        severity: "high",
        evidenceGrade: "A",
        content: "Give 5 mg/kg.",
      }),
    ]);
  });

  it("moves a heading with its complete section content", () => {
    expect(
      moveMarkdownSection("# One\nBody one.\n\n# Two\nBody two.\n", 1, 0),
    ).toBe("# Two\nBody two.\n# One\nBody one.\n\n");
    expect(
      moveMarkdownSection(
        "# One\nIntro.\n## Child\nChild body.\n# Two\nOther.\n",
        0,
        2,
      ),
    ).toBe("# One\nIntro.\n## Child\nChild body.\n# Two\nOther.\n");
    expect(
      moveMarkdownSection(
        "# One\nIntro.\n## Child\nChild body.\n# Two\nOther.\n",
        2,
        0,
      ),
    ).toBe("# Two\nOther.\n# One\nIntro.\n## Child\nChild body.\n");
  });

  it("retains stable anchors for renames and matches titles after insertion", () => {
    const original = stableHeadingAnchors("# Care\n## Assessment");
    expect(
      stableHeadingAnchors("# Clinical care\n## Assessment", original)["0"].id,
    ).toBe("care");
    const inserted = stableHeadingAnchors(
      "# Preface\n# Care\n## Assessment",
      original,
    );
    expect(inserted["1"].id).toBe("care");
    expect(inserted["2"].id).toBe("assessment");
  });
});
