package services

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"mime/multipart"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"mediguide/internal/models"
	"mediguide/internal/storage"

	"github.com/google/uuid"
	"gopkg.in/yaml.v3"
	"gorm.io/gorm"
)

type GuidelineService struct {
	DB    *gorm.DB
	Store storage.ObjectStore
}

type CreateGuidelineInput struct {
	Title       string `json:"title"`
	Country     string `json:"country"`
	SourceOrg   string `json:"source_org"`
	ProgramArea string `json:"program_area"`
	Language    string `json:"language"`
	Description string `json:"description"`
}

type CreateVersionInput struct {
	Version         string `json:"version"`
	PublicationDate string `json:"publication_date"`
	ReviewDate      string `json:"review_date"`
}

var (
	ErrGuidelineIngestionIncomplete = errors.New("guideline ingestion is not complete")
	ErrGuidelineIngestionFailed     = errors.New("guideline ingestion failed")
)

func (s GuidelineService) CreateDocument(in CreateGuidelineInput) (*models.GuidelineDocument, error) {
	d := models.GuidelineDocument{Title: in.Title, Country: in.Country, SourceOrg: in.SourceOrg, ProgramArea: in.ProgramArea, Language: in.Language, Description: in.Description}
	if d.Language == "" {
		d.Language = "en"
	}
	return &d, s.DB.Create(&d).Error
}
func (s GuidelineService) ListDocuments(programArea string) ([]models.GuidelineDocument, error) {
	var docs []models.GuidelineDocument
	q := s.DB.Preload("Versions").Order("created_at desc")
	if programArea != "" {
		q = q.Where("program_area = ?", programArea)
	}
	return docs, q.Find(&docs).Error
}
func (s GuidelineService) GetDocument(id uuid.UUID) (*models.GuidelineDocument, error) {
	var d models.GuidelineDocument
	return &d, s.DB.Preload("Versions").First(&d, "id = ?", id).Error
}
func (s GuidelineService) CreateVersion(docID uuid.UUID, in CreateVersionInput) (*models.GuidelineVersion, error) {
	v := models.GuidelineVersion{DocumentID: docID, Version: in.Version, PublicationDate: in.PublicationDate, ReviewDate: in.ReviewDate, Status: "draft"}
	return &v, s.DB.Create(&v).Error
}
func (s GuidelineService) UploadPDF(ctx context.Context, versionID uuid.UUID, file multipart.File, header *multipart.FileHeader) (*models.IngestionJob, error) {
	key := fmt.Sprintf("guidelines/%s/original/%d_%s", versionID.String(), time.Now().Unix(), filepath.Base(header.Filename))
	if err := s.Store.Put(ctx, key, file, header.Size, header.Header.Get("Content-Type")); err != nil {
		return nil, err
	}
	var job models.IngestionJob
	err := s.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Model(&models.GuidelineVersion{}).Where("id = ?", versionID).Update("original_file_key", key).Error; err != nil {
			return err
		}

		version, document, err := s.loadVersionDocument(tx, versionID)
		if err != nil {
			return err
		}
		if err := ensureDraftProtocol(tx, document, version); err != nil {
			return err
		}

		job = models.IngestionJob{VersionID: versionID, JobType: "pdf_ingestion", Status: "queued", PayloadJSON: fmt.Sprintf(`{"file_key":"%s"}`, key)}
		return tx.Create(&job).Error
	})
	if err != nil {
		return nil, err
	}
	return &job, nil
}
func (s GuidelineService) PublishVersion(versionID uuid.UUID, userID uuid.UUID) error {
	now := time.Now().Format(time.RFC3339)
	return s.DB.Transaction(func(tx *gorm.DB) error {
		var v models.GuidelineVersion
		if err := tx.First(&v, "id = ?", versionID).Error; err != nil {
			return err
		}
		if err := ensureVersionReadyForPublish(tx, &v); err != nil {
			return err
		}
		if err := tx.Model(&v).Updates(map[string]any{"status": "published", "approved_by": userID, "approved_at": now}).Error; err != nil {
			return err
		}
		if err := tx.Model(&models.GuidelineChunk{}).Where("version_id = ?", versionID).Update("review_status", "approved").Error; err != nil {
			return err
		}
		return tx.Model(&models.GuidelineDocument{}).Where("id = ?", v.DocumentID).Update("current_version_id", versionID).Error
	})
}
func (s GuidelineService) Sections(versionID uuid.UUID) ([]models.GuidelineSection, error) {
	var rows []models.GuidelineSection
	return rows, s.DB.Where("version_id = ?", versionID).Order("sort_order asc").Find(&rows).Error
}
func (s GuidelineService) Chunks(versionID uuid.UUID) ([]models.GuidelineChunk, error) {
	var rows []models.GuidelineChunk
	return rows, s.DB.Where("version_id = ?", versionID).Order("created_at asc").Find(&rows).Error
}

func (s GuidelineService) loadVersionDocument(tx *gorm.DB, versionID uuid.UUID) (*models.GuidelineVersion, *models.GuidelineDocument, error) {
	var version models.GuidelineVersion
	if err := tx.First(&version, "id = ?", versionID).Error; err != nil {
		return nil, nil, err
	}
	var document models.GuidelineDocument
	if err := tx.First(&document, "id = ?", version.DocumentID).Error; err != nil {
		return nil, nil, err
	}
	return &version, &document, nil
}

func ensureDraftProtocol(tx *gorm.DB, document *models.GuidelineDocument, version *models.GuidelineVersion) error {
	code := protocolCode(document, version)
	var existing models.ClinicalProtocol
	err := tx.Where("code = ?", code).First(&existing).Error
	if err == nil {
		return nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
	}

	definition := generatedProtocolDefinition(document, version)
	definitionYAMLBytes, err := yaml.Marshal(definition)
	if err != nil {
		return err
	}
	definitionJSONBytes, err := json.Marshal(definition)
	if err != nil {
		return err
	}
	protocol := models.ClinicalProtocol{
		Code:           code,
		Title:          protocolTitle(document),
		ProgramArea:    protocolProgramArea(document),
		Version:        version.Version,
		Language:       protocolLanguage(document),
		Status:         "draft",
		DefinitionYAML: strings.TrimSpace(string(definitionYAMLBytes)),
		DefinitionJSON: string(definitionJSONBytes),
	}
	return tx.Create(&protocol).Error
}

func ensureVersionReadyForPublish(tx *gorm.DB, version *models.GuidelineVersion) error {
	if strings.TrimSpace(version.OriginalFileKey) == "" {
		return fmt.Errorf("%w: no PDF has been uploaded for this version", ErrGuidelineIngestionIncomplete)
	}
	if strings.TrimSpace(version.HTMLFileKey) == "" || strings.TrimSpace(version.MarkdownFileKey) == "" {
		return fmt.Errorf("%w: extracted HTML/Markdown assets are missing", ErrGuidelineIngestionIncomplete)
	}

	var latestJob models.IngestionJob
	jobErr := tx.Where("version_id = ? AND deleted_at IS NULL", version.ID).Order("created_at desc").First(&latestJob).Error
	if jobErr == nil {
		switch strings.ToLower(strings.TrimSpace(latestJob.Status)) {
		case "completed":
		case "failed":
			msg := strings.TrimSpace(latestJob.Error)
			if msg == "" {
				msg = "the ingestion worker reported a failure"
			}
			return fmt.Errorf("%w: %s", ErrGuidelineIngestionFailed, msg)
		default:
			return fmt.Errorf("%w: latest ingestion job status is %s", ErrGuidelineIngestionIncomplete, latestJob.Status)
		}
	} else if !errors.Is(jobErr, gorm.ErrRecordNotFound) {
		return jobErr
	}

	var sectionCount int64
	if err := tx.Model(&models.GuidelineSection{}).Where("version_id = ?", version.ID).Count(&sectionCount).Error; err != nil {
		return err
	}
	if sectionCount == 0 {
		return fmt.Errorf("%w: no extracted sections were generated from the uploaded PDF", ErrGuidelineIngestionIncomplete)
	}

	var chunkCount int64
	if err := tx.Model(&models.GuidelineChunk{}).Where("version_id = ?", version.ID).Count(&chunkCount).Error; err != nil {
		return err
	}
	if chunkCount == 0 {
		return fmt.Errorf("%w: no vectorized chunks were generated from the uploaded PDF", ErrGuidelineIngestionIncomplete)
	}

	return nil
}

func protocolCode(document *models.GuidelineDocument, version *models.GuidelineVersion) string {
	base := slug(protocolProgramArea(document))
	if base == "" {
		base = slug(document.Title)
	}
	if base == "" {
		base = "guideline"
	}
	return fmt.Sprintf("%s-%s", base, slug(version.Version))
}

func protocolTitle(document *models.GuidelineDocument) string {
	disease := protocolProgramArea(document)
	if disease == "" {
		disease = document.Title
	}
	if disease == "" {
		disease = "Guideline"
	}
	return fmt.Sprintf("%s Protocol", disease)
}

func protocolProgramArea(document *models.GuidelineDocument) string {
	if strings.TrimSpace(document.ProgramArea) != "" {
		return strings.TrimSpace(document.ProgramArea)
	}
	return strings.TrimSpace(document.Title)
}

func protocolLanguage(document *models.GuidelineDocument) string {
	if strings.TrimSpace(document.Language) != "" {
		return document.Language
	}
	return "en"
}

func generatedProtocolDefinition(document *models.GuidelineDocument, version *models.GuidelineVersion) ProtocolDefinition {
	disease := protocolProgramArea(document)
	if disease == "" {
		disease = "disease"
	}
	source := document.SourceOrg
	if strings.TrimSpace(source) == "" {
		source = document.Title
	}
	stepID := slug(disease)
	if stepID == "" {
		stepID = "guideline"
	}

	return ProtocolDefinition{
		ID:      protocolCode(document, version),
		Title:   protocolTitle(document),
		Source:  source,
		Version: version.Version,
		Steps: []ProtocolStep{
			{
				ID:      stepID + "_assessment",
				Type:    "recommendation",
				Message: fmt.Sprintf("Use the uploaded %s guideline to assess and manage %s. Review the extracted guideline sections before finalizing this protocol.", disease, disease),
				Citation: map[string]string{
					"document": document.Title,
					"section":  "Initial assessment",
				},
			},
		},
	}
}

var nonSlugPattern = regexp.MustCompile(`[^a-z0-9]+`)

func slug(value string) string {
	s := strings.ToLower(strings.TrimSpace(value))
	s = nonSlugPattern.ReplaceAllString(s, "-")
	s = strings.Trim(s, "-")
	if s == "" {
		return ""
	}
	return s
}
