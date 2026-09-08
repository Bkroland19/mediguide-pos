import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { cleanup, render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { GuidelineBulkReviewPanel } from "./guideline-bulk-review-panel";
import { BackendRequestError } from "@/lib/backend-client";
import { showToast } from "@/lib/toast";
import { GuidelineDocumentsService } from "@/services/guideline-documents.service";

vi.mock("@/lib/toast", () => ({
  showToast: { success: vi.fn(), error: vi.fn() },
}));

const paragraph = {
  id: "block-paragraph",
  version_id: "version-1",
  section_id: "section-1",
  type: "paragraph" as const,
  sort_order: 1,
  content: { type: "paragraph", text: "Verified prose" },
  review_status: "draft" as const,
};
const table = {
  ...paragraph,
  id: "block-table",
  type: "table" as const,
  sort_order: 2,
  content: { type: "table", title: "Clinical doses" },
};

describe("GuidelineBulkReviewPanel", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    vi.spyOn(GuidelineDocumentsService, "getReviewBlocks").mockResolvedValue({
      items: [paragraph, table],
      page: 1,
      per_page: 50,
      total_items: 2,
      total_pages: 1,
      markdown_revision_id: "revision-1",
      regeneration_job_id: "job-1",
      progress: {
        total_blocks: 12,
        reviewed_blocks: 4,
        pending_low_risk_blocks: 6,
        pending_high_risk_blocks: 2,
        rejected_blocks: 0,
        sections_with_reviewed_content: 3,
        empty_clinical_leaf_sections: 5,
      },
    });
  });

  afterEach(cleanup);

  it("filters, reports progress, and excludes high-risk blocks from selection", async () => {
    renderPanel();
    expect(await screen.findByText("Pending low risk")).toBeInTheDocument();
    expect(screen.getByLabelText("Status")).toBeInTheDocument();
    expect(screen.getByLabelText("Risk")).toBeInTheDocument();
    expect(screen.getByLabelText("Block type")).toBeInTheDocument();
    expect(screen.getByLabelText("Section or chapter")).toBeInTheDocument();
    expect(screen.getByRole("checkbox", { name: "Select paragraph block" })).toBeInTheDocument();
    expect(screen.queryByRole("checkbox", { name: "Select table block" })).not.toBeInTheDocument();
    expect(screen.getByText("individual review")).toBeInTheDocument();
  });

  it("requires attestation and sends exact revision identities", async () => {
    const user = userEvent.setup();
    const bulkReview = vi.spyOn(GuidelineDocumentsService, "bulkReviewBlocks").mockResolvedValue({
      reviewed_count: 1, skipped_count: 0, rejected_count: 0,
      reviewed_ids: [paragraph.id], skipped_ids: [], reasons: [],
    });
    renderPanel();
    await user.click(await screen.findByRole("checkbox", { name: "Select paragraph block" }));
    await user.click(screen.getByRole("button", { name: "Approve selected low-risk blocks" }));
    const dialog = screen.getByRole("dialog", { name: "Approve 1 low-risk blocks?" });
    const confirm = within(dialog).getByRole("button", { name: "Confirm approval" });
    expect(confirm).toBeDisabled();
    await user.click(within(dialog).getByRole("checkbox"));
    await user.click(confirm);
    await waitFor(() => expect(bulkReview).toHaveBeenCalledWith("version-1", {
      block_ids: [paragraph.id],
      status: "reviewed",
      confirmation: "I verified these blocks against the authoritative source.",
      expected_markdown_revision_id: "revision-1",
      expected_regeneration_job_id: "job-1",
    }));
  });

  it("surfaces structured stale-review failure guidance without partial success", async () => {
    const user = userEvent.setup();
    vi.spyOn(GuidelineDocumentsService, "bulkReviewBlocks").mockRejectedValue(
      new BackendRequestError("guideline bulk review rejected", 422, undefined, {
        reviewed_count: 0,
        rejected_count: 1,
        reasons: [{ code: "stale_markdown_revision", message: "The Markdown changed. Refresh the review workspace." }],
      }),
    );
    renderPanel();
    await user.click(await screen.findByRole("checkbox", { name: "Select paragraph block" }));
    await user.click(screen.getByRole("button", { name: "Approve selected low-risk blocks" }));
    const dialog = screen.getByRole("dialog");
    await user.click(within(dialog).getByRole("checkbox"));
    await user.click(within(dialog).getByRole("button", { name: "Confirm approval" }));
    await waitFor(() => expect(showToast.error).toHaveBeenCalledWith(
      "Bulk review failed",
      "The Markdown changed. Refresh the review workspace.",
    ));
  });
});

function renderPanel() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <GuidelineBulkReviewPanel
        versionId="version-1"
        sections={[{ id: "section-1", version_id: "version-1", title: "Care", slug: "care", level: 2, html: "", text: "", sort_order: 1 }]}
        eligibleTypes={["paragraph", "heading", "ordered_list", "unordered_list", "reference", "page_break"]}
        availableTypes={["paragraph", "heading", "ordered_list", "unordered_list", "table", "figure", "reference", "page_break", "unknown"]}
        onSelectBlock={vi.fn()}
        onReviewed={vi.fn()}
      />
    </QueryClientProvider>,
  );
}
