package models

// GuidelineBlockReviewRisk describes the review treatment for one structured
// block type. It is intentionally independent from a block's current review
// status.
type GuidelineBlockReviewRisk string

const (
	GuidelineBlockReviewRiskLow         GuidelineBlockReviewRisk = "low"
	GuidelineBlockReviewRiskHigh        GuidelineBlockReviewRisk = "high"
	GuidelineBlockReviewRiskConditional GuidelineBlockReviewRisk = "conditional"
	GuidelineBlockReviewRiskIneligible  GuidelineBlockReviewRisk = "ineligible"
)

var guidelineHighRiskBlockTypes = []GuidelineBlockType{
	GuidelineBlockTable,
	GuidelineBlockRecommendation,
	GuidelineBlockWarning,
	GuidelineBlockCaution,
	GuidelineBlockContraindication,
	GuidelineBlockDosage,
	GuidelineBlockProcedure,
	GuidelineBlockAlgorithm,
	GuidelineBlockAlgorithmReference,
	GuidelineBlockReferralCriteria,
}

var guidelineBulkReviewEligibleBlockTypes = []GuidelineBlockType{
	GuidelineBlockParagraph,
	GuidelineBlockHeading,
	GuidelineBlockOrderedList,
	GuidelineBlockUnorderedList,
	GuidelineBlockReference,
	GuidelineBlockPageBreak,
}

// GuidelineBlockReviewRiskFor is the authoritative block-type risk policy used
// by publication validation, regeneration review, and editor capabilities.
// Figures are conditional because the referenced asset determines whether an
// individual clinical decision is required. Unknown types are never eligible
// for bulk review.
func GuidelineBlockReviewRiskFor(value GuidelineBlockType) GuidelineBlockReviewRisk {
	if GuidelineBlockRequiresIndividualReview(value) {
		return GuidelineBlockReviewRiskHigh
	}
	if GuidelineBlockEligibleForBulkReview(value) {
		return GuidelineBlockReviewRiskLow
	}
	switch value {
	case GuidelineBlockFigure:
		return GuidelineBlockReviewRiskConditional
	case GuidelineBlockUnknown:
		return GuidelineBlockReviewRiskIneligible
	default:
		return GuidelineBlockReviewRiskIneligible
	}
}

func GuidelineBlockRequiresIndividualReview(value GuidelineBlockType) bool {
	for _, blockType := range guidelineHighRiskBlockTypes {
		if value == blockType {
			return true
		}
	}
	return false
}

func GuidelineBlockEligibleForBulkReview(value GuidelineBlockType) bool {
	for _, blockType := range guidelineBulkReviewEligibleBlockTypes {
		if value == blockType {
			return true
		}
	}
	return false
}

func GuidelineHighRiskBlockTypes() []GuidelineBlockType {
	return append([]GuidelineBlockType(nil), guidelineHighRiskBlockTypes...)
}

func GuidelineBulkReviewEligibleBlockTypes() []GuidelineBlockType {
	return append([]GuidelineBlockType(nil), guidelineBulkReviewEligibleBlockTypes...)
}

func GuidelineConditionalRiskBlockTypes() []GuidelineBlockType {
	return []GuidelineBlockType{GuidelineBlockFigure}
}

func GuidelineIneligibleBulkReviewBlockTypes() []GuidelineBlockType {
	result := append([]GuidelineBlockType(nil), guidelineHighRiskBlockTypes...)
	result = append(result, GuidelineBlockFigure)
	return append(result,
		GuidelineBlockKeyPoint,
		GuidelineBlockEvidence,
		GuidelineBlockDefinition,
		GuidelineBlockClinicalNote,
		GuidelineBlockUnknown,
	)
}

// GuidelineAssetRequiresIndividualReview centralizes the asset-side portion of
// the policy. A figure block is conditional; its clinically-sensitive asset is
// always reviewed individually.
func GuidelineAssetRequiresIndividualReview(asset GuidelineAsset) bool {
	return asset.ClinicallySensitive
}
