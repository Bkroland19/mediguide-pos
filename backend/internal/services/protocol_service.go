package services

import (
	"encoding/json"
	"errors"

	"mediguide/internal/models"

	"github.com/google/uuid"
	"gopkg.in/yaml.v3"
	"gorm.io/gorm"
)

type ProtocolService struct{ DB *gorm.DB }

type ProtocolDefinition struct {
	ID      string         `yaml:"id" json:"id"`
	Title   string         `yaml:"title" json:"title"`
	Source  string         `yaml:"source" json:"source"`
	Version string         `yaml:"version" json:"version"`
	Steps   []ProtocolStep `yaml:"steps" json:"steps"`
}

type ProtocolStep struct {
	ID       string            `yaml:"id" json:"id"`
	Type     string            `yaml:"type" json:"type"`
	Question string            `yaml:"question" json:"question"`
	Message  string            `yaml:"message" json:"message"`
	Options  []string          `yaml:"options" json:"options"`
	Next     map[string]any    `yaml:"next" json:"next"`
	Citation map[string]string `yaml:"citation" json:"citation"`
}

type CreateProtocolInput struct {
	Code           string `json:"code"`
	Title          string `json:"title"`
	ProgramArea    string `json:"program_area"`
	Version        string `json:"version"`
	Language       string `json:"language"`
	DefinitionYAML string `json:"definition_yaml"`
}

type RunProtocolResult struct {
	Protocol    string         `json:"protocol"`
	CurrentStep ProtocolStep   `json:"current_step"`
	Input       map[string]any `json:"input"`
	Note        string         `json:"note"`
}

func (s ProtocolService) Create(in CreateProtocolInput) (*models.ClinicalProtocol, error) {
	var def ProtocolDefinition
	if in.DefinitionYAML != "" {
		if err := yaml.Unmarshal([]byte(in.DefinitionYAML), &def); err != nil {
			return nil, err
		}
	}
	j, _ := json.Marshal(def)
	p := models.ClinicalProtocol{Code: in.Code, Title: in.Title, ProgramArea: in.ProgramArea, Version: in.Version, Language: in.Language, Status: "draft", DefinitionYAML: in.DefinitionYAML, DefinitionJSON: string(j)}
	if p.Language == "" {
		p.Language = "en"
	}
	return &p, s.DB.Create(&p).Error
}
func (s ProtocolService) List() ([]models.ClinicalProtocol, error) {
	var rows []models.ClinicalProtocol
	return rows, s.DB.Order("created_at desc").Find(&rows).Error
}
func (s ProtocolService) Get(id uuid.UUID) (*models.ClinicalProtocol, error) {
	var p models.ClinicalProtocol
	return &p, s.DB.First(&p, "id = ?", id).Error
}
func (s ProtocolService) Run(id uuid.UUID, input map[string]any) (*RunProtocolResult, error) {
	p, err := s.Get(id)
	if err != nil {
		return nil, err
	}
	var def ProtocolDefinition
	if p.DefinitionYAML != "" {
		if err := yaml.Unmarshal([]byte(p.DefinitionYAML), &def); err != nil {
			return nil, err
		}
	}
	if len(def.Steps) == 0 {
		return nil, errors.New("protocol has no steps")
	}
	// MVP engine: returns first recommendation/message or first step to show.
	out := &RunProtocolResult{
		Protocol:    def.Title,
		CurrentStep: def.Steps[0],
		Input:       input,
		Note:        "MVP protocol engine. Extend rules in internal/services/protocol_service.go",
	}
	return out, nil
}
