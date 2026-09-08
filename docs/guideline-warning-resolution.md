# Resolving guideline Markdown warnings

Markdown validation warnings are review work, not necessarily broken Markdown.
Do not delete clinical content or invent missing dosing details merely to make
the warning counter reach zero. Publication validation and the audited review
state are the final authority.

## Warning workflow

1. Open the writable guideline version and select **Edit Markdown**.
2. Select **Prepare for review**, inspect the diff, and apply only the proposed
   structural changes that are faithful to the source.
3. Save the draft, then run **Regenerate**. A save alone does not update
   structured content or RAG chunks.
4. Resolve warnings by category using the table below.
5. Open **Review pending blocks**. The workspace defaults to pending high-risk
   blocks; compare every block with its source page before approval.
6. Return to the Markdown editor, refresh the regeneration review, and accept
   the regenerated projection only when its outstanding count is zero.
7. Run publication validation. Publish only when it reports no blockers.

| Warning | Resolution |
| --- | --- |
| `unresolved_asset_reference` | Upload the exact image through **Assets** and replace the local Markdown reference with the returned `guideline-asset://<uuid>` reference. A unique uploaded filename also resolves a legacy relative path, but stable asset references are preferred. |
| `ambiguous_dosage_or_unit` | Compare the complete statement with the approved source. If route, frequency, interval, or patient basis was lost during conversion, restore it exactly. If the value is a diagnostic threshold, formulation strength, specimen volume, or other intentional non-regimen value, leave the clinical text unchanged and review its generated block normally. |
| `high_risk_table_review_required` | Regenerate, compare the whole table—including headers, every cell, units, footnotes and source page—and approve its table block in Editorial Review. |
| `high_risk_review_required` | Compare the warning, caution, dosage, procedure, recommendation, contraindication, algorithm reference, or referral criterion with the source and approve the generated block. |
| `missing_source_metadata` | Add the issuing organization to guideline metadata. |
| `skipped_heading_level` | Change only the Markdown heading level so hierarchy progresses one level at a time. Do not rename the clinical section unless required. |
| `multiple_h1` | Retain one document title as H1 and demote other top-level headings according to the source hierarchy. |
| `unsupported_raw_html` | Replace presentational HTML with supported Markdown. Preserve meaningful text, table content and image alternative text. |
| `unsupported_fenced_block` | Use a supported fence language or plain `text`; verify that changing the label does not change clinical content. |

Errors such as unsafe HTML, malformed tables, broken internal links, missing
image alternative text, duplicate heading anchors, and unclosed fences must be
fixed before regeneration. The validation panel links them to their source
lines.

## UCG 2023 audit

The prepared UCG Markdown has zero blocking errors. Its 1,073 warnings comprise:

| Category | Count | UCG action |
| --- | ---: | --- |
| High-risk tables | 753 | Clinical review is required; these are not formatting defects. |
| Dose or unit checks | 204 | 127 occur inside table rows already requiring whole-table review; 77 are outside tables and require source comparison. Do not automatically rewrite them. |
| High-risk callouts | 64 | Review 46 cautions and 18 warnings after regeneration. |
| Local image references | 52 | Upload and reconnect the images as version assets. |

The monorepo contains source files for 51 of the 52 local image references under
`guidelines-platform/src/content/chapters_split/*/images`. The missing source
file is:

```text
images/chapter-17-weight-for-height-girls-2-to-5-years.png
```

Obtain that chart from the authoritative UCG 2023 source before publication;
do not substitute the boys' chart or another growth chart. For the other 51
images, upload the corresponding source file, verify its preview and alternative
text, then insert the stable asset reference from the asset library.

## Definition of complete

A document is ready for publication when:

- Markdown validation has zero errors;
- every referenced image resolves to the correct reviewed asset;
- every regenerated high-risk block is approved by an authorized reviewer;
- rejected blocks have been corrected and re-approved;
- the accepted regeneration revision matches the current Markdown revision;
- publication validation reports no blockers.

The raw Markdown warning count may remain nonzero because high-risk warnings
identify review obligations. Completion is determined by the resolved asset and
block-review state, not by suppressing those safety warnings.
