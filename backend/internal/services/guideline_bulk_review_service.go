package services

import (
	"errors"
	"fmt"
	"strings"
	"time"

	"mediguide/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

const (
	GuidelineBulkReviewConfirmation = "I verified these blocks against the authoritative source."
	GuidelineBulkReviewMaxBatchSize = 500
)

var ErrGuidelineBulkReviewRejected = errors.New("guideline bulk review rejected")

type BulkReviewGuidelineBlocksInput struct {
	BlockIDs                   []uuid.UUID                       `json:"block_ids" binding:"required"`
	Status                     models.GuidelineBlockReviewStatus `json:"status" binding:"required"`
	Confirmation               string                            `json:"confirmation" binding:"required"`
	ExpectedMarkdownRevisionID uuid.UUID                         `json:"expected_markdown_revision_id" binding:"required"`
	ExpectedRegenerationJobID  uuid.UUID                         `json:"expected_regeneration_job_id" binding:"required"`
}

type GuidelineBulkReviewReason struct {
	Code    string                    `json:"code"`
	Message string                    `json:"message"`
	BlockID *uuid.UUID                `json:"block_id,omitempty"`
	Type    models.GuidelineBlockType `json:"type,omitempty"`
}

type GuidelineBulkReviewResult struct {
	ReviewedCount int                         `json:"reviewed_count"`
	SkippedCount  int                         `json:"skipped_count"`
	RejectedCount int                         `json:"rejected_count"`
	ReviewedIDs   []uuid.UUID                 `json:"reviewed_ids"`
	SkippedIDs    []uuid.UUID                 `json:"skipped_ids"`
	Reasons       []GuidelineBulkReviewReason `json:"reasons"`
}

type GuidelineReviewProgress struct {
	TotalBlocks                 int64 `json:"total_blocks"`
	ReviewedBlocks              int64 `json:"reviewed_blocks"`
	PendingLowRiskBlocks        int64 `json:"pending_low_risk_blocks"`
	PendingHighRiskBlocks       int64 `json:"pending_high_risk_blocks"`
	RejectedBlocks              int64 `json:"rejected_blocks"`
	SectionsWithReviewedContent int64 `json:"sections_with_reviewed_content"`
	EmptyClinicalLeafSections   int64 `json:"empty_clinical_leaf_sections"`
}

type GuidelineReviewBlocksPage struct {
	Items              []models.GuidelineContentBlock `json:"items"`
	Page               int                            `json:"page"`
	PerPage            int                            `json:"per_page"`
	TotalItems         int64                          `json:"total_items"`
	TotalPages         int                            `json:"total_pages"`
	Progress           GuidelineReviewProgress        `json:"progress"`
	MarkdownRevisionID *uuid.UUID                     `json:"markdown_revision_id,omitempty"`
	RegenerationJobID  *uuid.UUID                     `json:"regeneration_job_id,omitempty"`
}

type GuidelineReviewBlocksFilter struct {
	Page      PageInput
	Status    string
	Risk      string
	BlockType string
	SectionID *uuid.UUID
}

func (s GuidelineService) ListReviewBlocks(versionID uuid.UUID, filter GuidelineReviewBlocksFilter) (*GuidelineReviewBlocksPage, error) {
	var version models.GuidelineVersion
	if err := s.DB.First(&version, "id = ?", versionID).Error; err != nil {
		return nil, err
	}
	page := filter.Page.Normalize(50, 100)
	query := s.DB.Model(&models.GuidelineContentBlock{}).Where("version_id = ? AND deleted_at IS NULL", versionID)
	if filter.SectionID != nil {
		query = query.Where("section_id = ?", *filter.SectionID)
	}
	if value := strings.TrimSpace(filter.BlockType); value != "" && value != "all" {
		query = query.Where("type = ?", value)
	}
	switch strings.TrimSpace(filter.Status) {
	case "", "all":
	case "pending":
		query = query.Where("review_status = ?", models.GuidelineBlockDraft)
	case "reviewed":
		query = query.Where("review_status = ?", models.GuidelineBlockReviewed)
	case "rejected":
		query = query.Where("review_status = ?", models.GuidelineBlockRejected)
	default:
		return nil, fmt.Errorf("%w: unsupported review status filter", ErrGuidelineReviewConflict)
	}
	switch strings.TrimSpace(filter.Risk) {
	case "", "all":
	case "low-risk-pending":
		query = query.Where("type IN ? AND review_status = ?", models.GuidelineBulkReviewEligibleBlockTypes(), models.GuidelineBlockDraft)
	case "high-risk":
		query = query.Where("type IN ?", models.GuidelineHighRiskBlockTypes())
	case "pending-high-risk":
		query = query.Where("type IN ? AND review_status <> ?", models.GuidelineHighRiskBlockTypes(), models.GuidelineBlockReviewed)
	default:
		return nil, fmt.Errorf("%w: unsupported risk filter", ErrGuidelineReviewConflict)
	}
	var total int64
	if err := query.Count(&total).Error; err != nil {
		return nil, err
	}
	items := make([]models.GuidelineContentBlock, 0)
	if err := query.Order("sort_order ASC, id ASC").Offset(page.Offset()).Limit(page.PerPage).Find(&items).Error; err != nil {
		return nil, err
	}
	progress, err := guidelineReviewProgress(s.DB, versionID)
	if err != nil {
		return nil, err
	}
	result := NewPageResult(items, page, total)
	response := &GuidelineReviewBlocksPage{
		Items: result.Items, Page: result.Page, PerPage: result.PerPage,
		TotalItems: result.TotalItems, TotalPages: result.TotalPages, Progress: progress,
		MarkdownRevisionID: version.CurrentMarkdownRevisionID,
	}
	if version.CurrentMarkdownRevisionID != nil {
		var revision models.GuidelineMarkdownRevision
		if err := s.DB.Select("regeneration_job_id").First(&revision, "id = ? AND version_id = ?", *version.CurrentMarkdownRevisionID, versionID).Error; err == nil {
			response.RegenerationJobID = revision.RegenerationJobID
		} else if !errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, err
		}
	}
	return response, nil
}

func (s GuidelineService) BulkReviewBlocks(versionID, actorID uuid.UUID, ip string, in BulkReviewGuidelineBlocksInput) (*GuidelineBulkReviewResult, error) {
	result := &GuidelineBulkReviewResult{ReviewedIDs: []uuid.UUID{}, SkippedIDs: []uuid.UUID{}, Reasons: []GuidelineBulkReviewReason{}}
	reject := func(code, message string, blockID *uuid.UUID, blockType models.GuidelineBlockType) error {
		result.Reasons = append(result.Reasons, GuidelineBulkReviewReason{Code: code, Message: message, BlockID: blockID, Type: blockType})
		result.RejectedCount = len(in.BlockIDs)
		return ErrGuidelineBulkReviewRejected
	}
	if len(in.BlockIDs) == 0 {
		return result, reject("empty_selection", "Select at least one low-risk block.", nil, "")
	}
	if len(in.BlockIDs) > GuidelineBulkReviewMaxBatchSize {
		return result, reject("batch_too_large", fmt.Sprintf("A bulk review may contain at most %d blocks.", GuidelineBulkReviewMaxBatchSize), nil, "")
	}
	if in.Status != models.GuidelineBlockReviewed {
		return result, reject("unsupported_status", "Bulk review only supports explicit approval to reviewed.", nil, "")
	}
	if strings.TrimSpace(in.Confirmation) != GuidelineBulkReviewConfirmation {
		return result, reject("confirmation_required", "Confirm that every selected block was verified against the authoritative source.", nil, "")
	}
	seen := make(map[uuid.UUID]bool, len(in.BlockIDs))
	for _, id := range in.BlockIDs {
		if id == uuid.Nil || seen[id] {
			return result, reject("invalid_selection", "Block IDs must be unique, valid UUIDs.", &id, "")
		}
		seen[id] = true
	}

	err := s.DB.Transaction(func(tx *gorm.DB) error {
		if err := requireEditableGuidelineVersion(tx, versionID); err != nil {
			return err
		}
		var version models.GuidelineVersion
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).First(&version, "id = ?", versionID).Error; err != nil {
			return err
		}
		if version.CurrentMarkdownRevisionID == nil || version.StructuredMarkdownRevisionID == nil ||
			*version.CurrentMarkdownRevisionID != in.ExpectedMarkdownRevisionID ||
			*version.StructuredMarkdownRevisionID != in.ExpectedMarkdownRevisionID {
			return reject("stale_markdown_revision", "The Markdown or structured projection changed. Refresh the review workspace before approving blocks.", nil, "")
		}
		var revision models.GuidelineMarkdownRevision
		if err := tx.First(&revision, "id = ? AND version_id = ?", in.ExpectedMarkdownRevisionID, versionID).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return reject("stale_markdown_revision", "The expected Markdown revision is no longer current.", nil, "")
			}
			return err
		}
		if revision.RegenerationJobID == nil || *revision.RegenerationJobID != in.ExpectedRegenerationJobID {
			return reject("stale_regeneration_job", "The regenerated projection changed. Refresh before approving blocks.", nil, "")
		}

		var blocks []models.GuidelineContentBlock
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Where("version_id = ? AND id IN ?", versionID, in.BlockIDs).Find(&blocks).Error; err != nil {
			return err
		}
		if len(blocks) != len(in.BlockIDs) {
			return reject("block_not_in_version", "Every selected block must exist in the requested guideline version.", nil, "")
		}
		byID := make(map[uuid.UUID]models.GuidelineContentBlock, len(blocks))
		for _, block := range blocks {
			byID[block.ID] = block
		}
		countsByType := make(map[string]int)
		previousStates := make(map[string]string, len(blocks))
		resultingStates := make(map[string]string, len(blocks))
		for _, id := range in.BlockIDs {
			block := byID[id]
			if !models.GuidelineBlockEligibleForBulkReview(block.Type) {
				return reject("block_ineligible", fmt.Sprintf("The %s block requires individual review or is not eligible for bulk approval.", block.Type), &block.ID, block.Type)
			}
			if err := validateGuidelineBlockPayload(tx, versionID, block.Type, block.ContentJSON); err != nil {
				return reject("invalid_block_payload", err.Error(), &block.ID, block.Type)
			}
			countsByType[string(block.Type)]++
			previousStates[block.ID.String()] = string(block.ReviewStatus)
			resultingStates[block.ID.String()] = string(models.GuidelineBlockReviewed)
			if block.ReviewStatus == models.GuidelineBlockReviewed {
				result.SkippedIDs = append(result.SkippedIDs, block.ID)
			}
		}
		toReview := make([]uuid.UUID, 0, len(blocks)-len(result.SkippedIDs))
		for _, block := range blocks {
			if block.ReviewStatus != models.GuidelineBlockReviewed {
				toReview = append(toReview, block.ID)
			}
		}
		now := time.Now().UTC()
		if len(toReview) > 0 {
			if err := tx.Model(&models.GuidelineContentBlock{}).Where("version_id = ? AND id IN ?", versionID, toReview).Updates(map[string]any{
				"review_status": models.GuidelineBlockReviewed, "reviewed_by": actorID, "reviewed_at": now,
			}).Error; err != nil {
				return err
			}
			// Reviewed chunks remain draft until publication atomically promotes
			// reviewed content to approved/searchable. Content did not change, so
			// existing embeddings do not need to be cleared.
			if err := tx.Model(&models.GuidelineChunk{}).Where("version_id = ? AND block_id IN ?", versionID, toReview).Update("review_status", "draft").Error; err != nil {
				return err
			}
		}
		result.ReviewedIDs = append(result.ReviewedIDs, toReview...)
		result.ReviewedCount = len(toReview)
		result.SkippedCount = len(result.SkippedIDs)
		metadata := map[string]any{
			"version_id": versionID, "revision_id": in.ExpectedMarkdownRevisionID,
			"regeneration_job_id": in.ExpectedRegenerationJobID, "reviewer_id": actorID,
			"block_ids": in.BlockIDs, "counts_by_type": countsByType,
			"previous_states": previousStates, "resulting_states": resultingStates,
			"confirmation": strings.TrimSpace(in.Confirmation),
		}
		return writeGuidelineAudit(tx, actorID, "guideline.blocks.bulk_reviewed", "guideline_version", versionID, ip, metadata)
	})
	return result, err
}

func guidelineReviewProgress(db *gorm.DB, versionID uuid.UUID) (GuidelineReviewProgress, error) {
	type blockState struct {
		SectionID    *uuid.UUID
		Type         models.GuidelineBlockType
		ReviewStatus models.GuidelineBlockReviewStatus
	}
	var blocks []blockState
	if err := db.Model(&models.GuidelineContentBlock{}).Select("section_id", "type", "review_status").Where("version_id = ? AND deleted_at IS NULL", versionID).Find(&blocks).Error; err != nil {
		return GuidelineReviewProgress{}, err
	}
	var sections []models.GuidelineSection
	if err := db.Select("id", "parent_id", "level", "title").Where("version_id = ? AND deleted_at IS NULL", versionID).Find(&sections).Error; err != nil {
		return GuidelineReviewProgress{}, err
	}
	progress := GuidelineReviewProgress{TotalBlocks: int64(len(blocks))}
	reviewedSections := map[uuid.UUID]bool{}
	activeBySection := map[uuid.UUID]int{}
	for _, block := range blocks {
		if block.SectionID != nil && block.ReviewStatus != models.GuidelineBlockRejected {
			activeBySection[*block.SectionID]++
		}
		switch block.ReviewStatus {
		case models.GuidelineBlockReviewed:
			progress.ReviewedBlocks++
			if block.SectionID != nil {
				reviewedSections[*block.SectionID] = true
			}
		case models.GuidelineBlockRejected:
			progress.RejectedBlocks++
		default:
			if models.GuidelineBlockRequiresIndividualReview(block.Type) {
				progress.PendingHighRiskBlocks++
			} else if models.GuidelineBlockEligibleForBulkReview(block.Type) {
				progress.PendingLowRiskBlocks++
			}
		}
	}
	progress.SectionsWithReviewedContent = int64(len(reviewedSections))
	parents := map[uuid.UUID]bool{}
	for _, section := range sections {
		if section.ParentID != nil {
			parents[*section.ParentID] = true
		}
	}
	for _, section := range sections {
		if !parents[section.ID] && section.Level > 1 && !guidelineLeafReviewExempt(section.Title) && activeBySection[section.ID] > 0 && !reviewedSections[section.ID] {
			progress.EmptyClinicalLeafSections++
		}
	}
	return progress, nil
}
