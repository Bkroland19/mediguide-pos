import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { cleanup, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { GuidelineCompletenessReport } from "./guideline-completeness-report";
import { showToast } from "@/lib/toast";
import { GuidelineDocumentsService } from "@/services/guideline-documents.service";

vi.mock("@/lib/toast", () => ({
  showToast: { success: vi.fn(), error: vi.fn() },
}));

const report = {
  generated_at: "2026-09-09T00:00:00Z", read_only: true,
  guideline_id: "guideline-1", guideline_title: "Diabetes", version_id: "version-1", version: "2026.10.01", version_status: "review_required",
  total_blocks: 100, active_blocks: 98, reviewed_blocks: 40, reviewed_percentage: 40.816,
  block_counts: [
    { block_type: "paragraph", total: 80, draft: 40, reviewed: 40, rejected: 0 },
    { block_type: "table", total: 20, draft: 18, reviewed: 0, rejected: 2 },
  ],
  sections: { total_sections: 30, reviewed_sections: 12, leaf_sections: 20, reviewed_leaf_sections: 8, empty_leaf_sections: 12 },
  empty_leaf_sections: [{ id: "section-1", title: "Treatment", level: 3, active_block_count: 2, review_exempt: false }],
  sources: { original_pdf_available: false, original_pdf_reviewed: false, offline_package_available: false, offline_package_reviewed: false, reviewed_fallback_available: false },
  regeneration: { identities_match: true, review_status: "accepted" },
  rag: { total_chunks: 40, approved_chunks: 40, draft_chunks: 0, rejected_chunks: 0, reviewed_blocks_with_chunks: 39, reviewed_blocks_without_chunks: 1, embedding_column_available: true, embedded_approved_chunks: 38, missing_approved_embeddings: 2, reviewed_block_chunks: 39, embedded_reviewed_block_chunks: 37, missing_reviewed_embeddings: 2, ready: false },
  current_comparison: { current_version_id: "published-1", current_version: "2026.09.01", same_version: false, metrics: [{ name: "reviewed_blocks", current: 16, candidate: 40, delta: 24 }] },
  validation: { valid: false, errors: [{ code: "empty_clinical_leaf_sections", message: "Too many empty leaves" }], warnings: [] },
};

describe("GuidelineCompletenessReport", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    vi.spyOn(GuidelineDocumentsService, "getCompletenessReport").mockResolvedValue(report);
  });
  afterEach(cleanup);

  it("shows total versus reviewed coverage, recovery blockers and current comparison", async () => {
    renderReport();
    expect(await screen.findByTestId("completeness-report")).toBeInTheDocument();
    expect(screen.getByText("30")).toBeInTheDocument();
    expect(screen.getAllByText("12", { selector: ".font-semibold" })).toHaveLength(2);
    expect(screen.getByText("8 / 20")).toBeInTheDocument();
    expect(screen.getByText("1 blocking issue(s)")).toBeInTheDocument();
    expect(screen.getByText("No reviewed fallback available")).toBeInTheDocument();
    expect(screen.getByText(/1 blocks without chunks; 2 reviewed embeddings missing/u)).toBeInTheDocument();
    expect(screen.getByText("reviewed blocks: 16 → 40")).toBeInTheDocument();
  });

  it("exports the report using the shared user-message convention", async () => {
    const user = userEvent.setup();
    const download = vi.spyOn(GuidelineDocumentsService, "downloadCompletenessReport").mockResolvedValue();
    renderReport();
    await user.click(await screen.findByRole("button", { name: /CSV/u }));
    await waitFor(() => expect(download).toHaveBeenCalledWith("version-1", "csv"));
    expect(showToast.success).toHaveBeenCalledWith("Completeness report downloaded", "The read-only CSV report is ready.");
  });
});

function renderReport() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(<QueryClientProvider client={client}><GuidelineCompletenessReport versionId="version-1" /></QueryClientProvider>);
}
