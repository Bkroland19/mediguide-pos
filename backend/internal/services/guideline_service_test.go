package services

import (
	"testing"

	"mediguide/internal/models"
)

func TestGeneratedProtocolDefinitionUsesGuidelineMetadata(t *testing.T) {
	document := &models.GuidelineDocument{
		Title:       "Uganda Malaria Guideline",
		SourceOrg:   "Ministry of Health",
		ProgramArea: "Malaria",
		Language:    "en",
	}
	version := &models.GuidelineVersion{Version: "2026"}

	definition := generatedProtocolDefinition(document, version)

	if definition.ID != "malaria-2026" {
		t.Fatalf("unexpected protocol id: %s", definition.ID)
	}
	if definition.Title != "Malaria Protocol" {
		t.Fatalf("unexpected protocol title: %s", definition.Title)
	}
	if definition.Source != "Ministry of Health" {
		t.Fatalf("unexpected protocol source: %s", definition.Source)
	}
	if len(definition.Steps) != 1 {
		t.Fatalf("expected one starter step, got %d", len(definition.Steps))
	}
	if definition.Steps[0].Type != "recommendation" {
		t.Fatalf("unexpected starter step type: %s", definition.Steps[0].Type)
	}
	if definition.Steps[0].Citation["document"] != document.Title {
		t.Fatalf("unexpected citation document: %s", definition.Steps[0].Citation["document"])
	}
}

func TestProtocolProgramAreaFallsBackToTitle(t *testing.T) {
	document := &models.GuidelineDocument{Title: "HIV Guideline"}

	if got := protocolProgramArea(document); got != "HIV Guideline" {
		t.Fatalf("unexpected fallback program area: %s", got)
	}
}
