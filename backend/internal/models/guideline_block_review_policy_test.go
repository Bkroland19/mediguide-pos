package models

import "testing"

func TestGuidelineBlockReviewPolicy(t *testing.T) {
	t.Parallel()

	highRisk := []GuidelineBlockType{
		GuidelineBlockTable, GuidelineBlockRecommendation, GuidelineBlockWarning,
		GuidelineBlockCaution, GuidelineBlockContraindication, GuidelineBlockDosage,
		GuidelineBlockProcedure, GuidelineBlockAlgorithm, GuidelineBlockAlgorithmReference,
		GuidelineBlockReferralCriteria,
	}
	for _, blockType := range highRisk {
		if got := GuidelineBlockReviewRiskFor(blockType); got != GuidelineBlockReviewRiskHigh {
			t.Errorf("risk for %s = %s, want high", blockType, got)
		}
		if GuidelineBlockEligibleForBulkReview(blockType) {
			t.Errorf("high-risk block %s must not be bulk-review eligible", blockType)
		}
	}

	lowRisk := []GuidelineBlockType{
		GuidelineBlockParagraph, GuidelineBlockHeading, GuidelineBlockOrderedList,
		GuidelineBlockUnorderedList, GuidelineBlockReference, GuidelineBlockPageBreak,
	}
	for _, blockType := range lowRisk {
		if got := GuidelineBlockReviewRiskFor(blockType); got != GuidelineBlockReviewRiskLow {
			t.Errorf("risk for %s = %s, want low", blockType, got)
		}
		if !GuidelineBlockEligibleForBulkReview(blockType) {
			t.Errorf("low-risk block %s should be bulk-review eligible", blockType)
		}
	}

	if got := GuidelineBlockReviewRiskFor(GuidelineBlockFigure); got != GuidelineBlockReviewRiskConditional {
		t.Fatalf("figure risk = %s, want conditional", got)
	}
	if GuidelineBlockEligibleForBulkReview(GuidelineBlockFigure) {
		t.Fatal("figure blocks must not be bulk-review eligible")
	}
	if got := GuidelineBlockReviewRiskFor(GuidelineBlockUnknown); got != GuidelineBlockReviewRiskIneligible {
		t.Fatalf("unknown risk = %s, want ineligible", got)
	}
	if GuidelineBlockEligibleForBulkReview(GuidelineBlockUnknown) {
		t.Fatal("unknown blocks must not be bulk-review eligible")
	}
	for _, blockType := range []GuidelineBlockType{GuidelineBlockTable, GuidelineBlockFigure, GuidelineBlockUnknown} {
		if !containsBlockReviewPolicyType(GuidelineIneligibleBulkReviewBlockTypes(), blockType) {
			t.Errorf("%s missing from ineligible bulk-review capability", blockType)
		}
	}

	sensitive := GuidelineAsset{ClinicallySensitive: true}
	if !GuidelineAssetRequiresIndividualReview(sensitive) {
		t.Fatal("clinically sensitive asset must require individual review")
	}
}

func containsBlockReviewPolicyType(values []GuidelineBlockType, expected GuidelineBlockType) bool {
	for _, value := range values {
		if value == expected {
			return true
		}
	}
	return false
}
