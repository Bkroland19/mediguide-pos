package services

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"mediguide/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

var ErrGuidelineManifestUnavailable = errors.New("guideline manifest is unavailable")

type guidelineTypeCount struct {
	Type  string
	Count int64
}

type guidelineReviewCount struct {
	ReviewStatus string
	Count        int64
}

type guidelineManifestChecksumPayload struct {
	GuidelineID              uuid.UUID                         `json:"guideline_id"`
	VersionID                uuid.UUID                         `json:"version_id"`
	Version                  string                            `json:"version"`
	SchemaVersion            int                               `json:"schema_version"`
	PackageVersion           int                               `json:"package_version"`
	ExtractionQuality        models.GuidelineExtractionQuality `json:"extraction_quality"`
	HasChapters              bool                              `json:"has_chapters"`
	HasKeyPoints             bool                              `json:"has_key_points"`
	HasTables                bool                              `json:"has_tables"`
	HasFigures               bool                              `json:"has_figures"`
	HasAlgorithms            bool                              `json:"has_algorithms"`
	HasOriginalPDF           bool                              `json:"has_original_pdf"`
	HasOfflinePackage        bool                              `json:"has_offline_package"`
	SectionCount             int                               `json:"section_count"`
	ReviewedSectionCount     int                               `json:"reviewed_section_count"`
	LeafSectionCount         int                               `json:"leaf_section_count"`
	ReviewedLeafSectionCount int                               `json:"reviewed_leaf_section_count"`
	EmptyLeafSectionCount    int                               `json:"empty_leaf_section_count"`
	BlockCount               int                               `json:"block_count"`
	ReviewedParagraphCount   int                               `json:"reviewed_paragraph_count"`
	TableCount               int                               `json:"table_count"`
	FigureCount              int                               `json:"figure_count"`
	AlgorithmCount           int                               `json:"algorithm_count"`
}

func (s GuidelineService) RegenerateManifest(versionID uuid.UUID) (*models.GuidelineVersionManifest, error) {
	return s.regenerateManifest(versionID, nil, "")
}

func (s GuidelineService) RegenerateManifestForAdmin(versionID, actorID uuid.UUID, ip string) (*models.GuidelineVersionManifest, error) {
	return s.regenerateManifest(versionID, &actorID, ip)
}

func (s GuidelineService) regenerateManifest(versionID uuid.UUID, actorID *uuid.UUID, ip string) (*models.GuidelineVersionManifest, error) {
	var manifest *models.GuidelineVersionManifest
	err := s.DB.Transaction(func(tx *gorm.DB) error {
		var err error
		manifest, err = generateGuidelineVersionManifest(tx, versionID, time.Now().UTC())
		if err != nil {
			return err
		}
		if actorID != nil {
			return writeGuidelineAudit(tx, *actorID, "guideline.manifest.regenerated", "guideline_version", versionID, ip, map[string]any{"schema_version": manifest.SchemaVersion, "package_version": manifest.PackageVersion})
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	s.invalidatePublishedCaches(context.Background())
	return manifest, nil
}

func generateGuidelineVersionManifest(tx *gorm.DB, versionID uuid.UUID, generatedAt time.Time) (*models.GuidelineVersionManifest, error) {
	var version models.GuidelineVersion
	if err := tx.First(&version, "id = ?", versionID).Error; err != nil {
		return nil, err
	}
	if !strings.EqualFold(strings.TrimSpace(version.Status), "published") {
		return nil, ErrGuidelineManifestUnavailable
	}

	blockCounts, reviewCounts, completeness, err := guidelineManifestBlockCounts(tx, versionID)
	if err != nil {
		return nil, err
	}
	assetCounts, err := guidelineManifestAssetCounts(tx, versionID)
	if err != nil {
		return nil, err
	}

	reviewedCount := reviewCounts[string(models.GuidelineBlockReviewed)]
	// Rejected blocks are deliberately outside the public projection and must
	// not make an otherwise complete review appear partial.
	totalBlocks := reviewedCount + reviewCounts[string(models.GuidelineBlockDraft)]
	quality := guidelineExtractionQuality(totalBlocks, reviewedCount)

	manifest := &models.GuidelineVersionManifest{
		GuidelineID:              version.DocumentID,
		VersionID:                version.ID,
		Version:                  version.Version,
		SchemaVersion:            models.GuidelineManifestSchemaVersion,
		PackageVersion:           models.GuidelinePackageFormatVersion,
		ExtractionQuality:        quality,
		HasChapters:              completeness.sectionCount > 0 || blockCounts[string(models.GuidelineBlockHeading)] > 0,
		HasKeyPoints:             blockCounts[string(models.GuidelineBlockKeyPoint)] > 0,
		HasTables:                blockCounts[string(models.GuidelineBlockTable)] > 0,
		HasFigures:               blockCounts[string(models.GuidelineBlockFigure)] > 0,
		HasAlgorithms:            blockCounts[string(models.GuidelineBlockAlgorithm)] > 0,
		HasOriginalPDF:           strings.TrimSpace(version.OriginalFileKey) != "" || assetCounts[string(models.GuidelineAssetOriginalPDF)] > 0,
		HasOfflinePackage:        assetCounts[string(models.GuidelineAssetOfflinePackage)] > 0,
		SectionCount:             completeness.sectionCount,
		ReviewedSectionCount:     completeness.reviewedSectionCount,
		LeafSectionCount:         completeness.leafSectionCount,
		ReviewedLeafSectionCount: completeness.reviewedLeafSectionCount,
		EmptyLeafSectionCount:    completeness.emptyLeafSectionCount,
		BlockCount:               int(reviewedCount),
		ReviewedParagraphCount:   int(blockCounts[string(models.GuidelineBlockParagraph)]),
		TableCount:               int(blockCounts[string(models.GuidelineBlockTable)]),
		FigureCount:              int(blockCounts[string(models.GuidelineBlockFigure)]),
		AlgorithmCount:           int(blockCounts[string(models.GuidelineBlockAlgorithm)]),
		GeneratedAt:              generatedAt.UTC(),
	}
	checksum, err := guidelineManifestChecksum(manifest)
	if err != nil {
		return nil, err
	}
	manifest.Checksum = checksum
	manifest.ETag = fmt.Sprintf(`"sha256-%s"`, checksum)

	err = tx.Clauses(clause.OnConflict{
		Columns: []clause.Column{{Name: "version_id"}},
		DoUpdates: clause.Assignments(map[string]any{
			"guideline_id":                manifest.GuidelineID,
			"version":                     manifest.Version,
			"schema_version":              manifest.SchemaVersion,
			"package_version":             manifest.PackageVersion,
			"extraction_quality":          manifest.ExtractionQuality,
			"has_chapters":                manifest.HasChapters,
			"has_key_points":              manifest.HasKeyPoints,
			"has_tables":                  manifest.HasTables,
			"has_figures":                 manifest.HasFigures,
			"has_algorithms":              manifest.HasAlgorithms,
			"has_original_pdf":            manifest.HasOriginalPDF,
			"has_offline_package":         manifest.HasOfflinePackage,
			"section_count":               manifest.SectionCount,
			"reviewed_section_count":      manifest.ReviewedSectionCount,
			"leaf_section_count":          manifest.LeafSectionCount,
			"reviewed_leaf_section_count": manifest.ReviewedLeafSectionCount,
			"empty_leaf_section_count":    manifest.EmptyLeafSectionCount,
			"block_count":                 manifest.BlockCount,
			"reviewed_paragraph_count":    manifest.ReviewedParagraphCount,
			"table_count":                 manifest.TableCount,
			"figure_count":                manifest.FigureCount,
			"algorithm_count":             manifest.AlgorithmCount,
			"checksum":                    manifest.Checksum,
			"etag":                        manifest.ETag,
			"generated_at":                manifest.GeneratedAt,
			"updated_at":                  manifest.GeneratedAt,
			"deleted_at":                  nil,
		}),
	}).Create(manifest).Error
	if err != nil {
		return nil, err
	}

	var persisted models.GuidelineVersionManifest
	if err := tx.Where("version_id = ?", versionID).First(&persisted).Error; err != nil {
		return nil, err
	}
	return &persisted, nil
}

type guidelineManifestCompleteness struct {
	sectionCount, reviewedSectionCount, leafSectionCount int
	reviewedLeafSectionCount, emptyLeafSectionCount      int
}

func guidelineManifestBlockCounts(tx *gorm.DB, versionID uuid.UUID) (map[string]int64, map[string]int64, guidelineManifestCompleteness, error) {
	typeCounts := []guidelineTypeCount{}
	if err := tx.Model(&models.GuidelineContentBlock{}).
		Select("type, COUNT(*) AS count").
		Where("version_id = ? AND deleted_at IS NULL AND review_status = ?", versionID, models.GuidelineBlockReviewed).
		Group("type").
		Scan(&typeCounts).Error; err != nil {
		return nil, nil, guidelineManifestCompleteness{}, err
	}

	reviews := []guidelineReviewCount{}
	if err := tx.Model(&models.GuidelineContentBlock{}).
		Select("review_status, COUNT(*) AS count").
		Where("version_id = ? AND deleted_at IS NULL", versionID).
		Group("review_status").
		Scan(&reviews).Error; err != nil {
		return nil, nil, guidelineManifestCompleteness{}, err
	}

	var reviewedSectionIDs []uuid.UUID
	if err := tx.Model(&models.GuidelineContentBlock{}).
		Where("version_id = ? AND deleted_at IS NULL AND review_status = ? AND section_id IS NOT NULL", versionID, models.GuidelineBlockReviewed).
		Distinct("section_id").Pluck("section_id", &reviewedSectionIDs).Error; err != nil {
		return nil, nil, guidelineManifestCompleteness{}, err
	}
	var sections []models.GuidelineSection
	if err := tx.Where("version_id = ?", versionID).Find(&sections).Error; err != nil {
		return nil, nil, guidelineManifestCompleteness{}, err
	}
	reviewed := make(map[uuid.UUID]struct{}, len(reviewedSectionIDs))
	for _, id := range reviewedSectionIDs {
		reviewed[id] = struct{}{}
	}
	parents := make(map[uuid.UUID]struct{}, len(sections))
	for _, section := range sections {
		if section.ParentID != nil {
			parents[*section.ParentID] = struct{}{}
		}
	}
	counts := guidelineManifestCompleteness{sectionCount: len(sections), reviewedSectionCount: len(reviewed)}
	for _, section := range sections {
		if _, isParent := parents[section.ID]; isParent {
			continue
		}
		counts.leafSectionCount++
		if _, ok := reviewed[section.ID]; ok {
			counts.reviewedLeafSectionCount++
		} else {
			counts.emptyLeafSectionCount++
		}
	}
	return guidelineCountMap(typeCounts), guidelineReviewCountMap(reviews), counts, nil
}

func guidelineManifestAssetCounts(tx *gorm.DB, versionID uuid.UUID) (map[string]int64, error) {
	rows := []guidelineTypeCount{}
	if err := tx.Model(&models.GuidelineAsset{}).
		Select("type, COUNT(*) AS count").
		Where("version_id = ? AND deleted_at IS NULL AND review_status = ?", versionID, models.GuidelineBlockReviewed).
		Group("type").
		Scan(&rows).Error; err != nil {
		return nil, err
	}
	return guidelineCountMap(rows), nil
}

func guidelineCountMap(rows []guidelineTypeCount) map[string]int64 {
	result := make(map[string]int64, len(rows))
	for _, row := range rows {
		result[row.Type] = row.Count
	}
	return result
}

func guidelineReviewCountMap(rows []guidelineReviewCount) map[string]int64 {
	result := make(map[string]int64, len(rows))
	for _, row := range rows {
		result[row.ReviewStatus] = row.Count
	}
	return result
}

func guidelineExtractionQuality(total, reviewed int64) models.GuidelineExtractionQuality {
	switch {
	case total == 0:
		return models.GuidelineExtractionMarkdownFallback
	case reviewed == total:
		return models.GuidelineExtractionReviewed
	case reviewed > 0:
		return models.GuidelineExtractionPartiallyReviewed
	default:
		return models.GuidelineExtractionUnreviewed
	}
}

func guidelineManifestChecksum(manifest *models.GuidelineVersionManifest) (string, error) {
	payload := guidelineManifestChecksumPayload{
		GuidelineID:              manifest.GuidelineID,
		VersionID:                manifest.VersionID,
		Version:                  manifest.Version,
		SchemaVersion:            manifest.SchemaVersion,
		PackageVersion:           manifest.PackageVersion,
		ExtractionQuality:        manifest.ExtractionQuality,
		HasChapters:              manifest.HasChapters,
		HasKeyPoints:             manifest.HasKeyPoints,
		HasTables:                manifest.HasTables,
		HasFigures:               manifest.HasFigures,
		HasAlgorithms:            manifest.HasAlgorithms,
		HasOriginalPDF:           manifest.HasOriginalPDF,
		HasOfflinePackage:        manifest.HasOfflinePackage,
		SectionCount:             manifest.SectionCount,
		ReviewedSectionCount:     manifest.ReviewedSectionCount,
		LeafSectionCount:         manifest.LeafSectionCount,
		ReviewedLeafSectionCount: manifest.ReviewedLeafSectionCount,
		EmptyLeafSectionCount:    manifest.EmptyLeafSectionCount,
		BlockCount:               manifest.BlockCount,
		ReviewedParagraphCount:   manifest.ReviewedParagraphCount,
		TableCount:               manifest.TableCount,
		FigureCount:              manifest.FigureCount,
		AlgorithmCount:           manifest.AlgorithmCount,
	}
	content, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}
	sum := sha256.Sum256(content)
	return hex.EncodeToString(sum[:]), nil
}
