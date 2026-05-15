package handlers

import (
	"mediguide/internal/models"
	"mediguide/internal/services"
)

type RegisterRequest struct {
	Name     string `json:"name" example:"Admin User"`
	Email    string `json:"email" example:"admin@mediguide.local"`
	Password string `json:"password" example:"Admin123!"`
}

type LoginRequest struct {
	Email    string `json:"email" example:"admin@mediguide.local"`
	Password string `json:"password" example:"Admin123!"`
}

type PublishResult struct {
	Published bool `json:"published" example:"true"`
}

type DownloadURLResult struct {
	URL string `json:"url" example:"https://storage.example.com/path/to/package.zip"`
}

type JSONMap map[string]any

type HealthResult struct {
	OK      bool   `json:"ok" example:"true"`
	Service string `json:"service" example:"mediguide-backend"`
}

type ErrorResponse struct {
	Success bool   `json:"success" example:"false"`
	Error   string `json:"error" example:"invalid request"`
}

type UserEnvelope struct {
	Success bool        `json:"success" example:"true"`
	Data    models.User `json:"data"`
}

type LoginEnvelope struct {
	Success bool                 `json:"success" example:"true"`
	Data    services.LoginResult `json:"data"`
}

type GuidelineDocumentEnvelope struct {
	Success bool                     `json:"success" example:"true"`
	Data    models.GuidelineDocument `json:"data"`
}

type GuidelineDocumentsEnvelope struct {
	Success bool                       `json:"success" example:"true"`
	Data    []models.GuidelineDocument `json:"data"`
}

type GuidelineVersionEnvelope struct {
	Success bool                    `json:"success" example:"true"`
	Data    models.GuidelineVersion `json:"data"`
}

type IngestionJobEnvelope struct {
	Success bool                `json:"success" example:"true"`
	Data    models.IngestionJob `json:"data"`
}

type PublishEnvelope struct {
	Success bool          `json:"success" example:"true"`
	Data    PublishResult `json:"data"`
}

type GuidelineSectionsEnvelope struct {
	Success bool                      `json:"success" example:"true"`
	Data    []models.GuidelineSection `json:"data"`
}

type GuidelineChunksEnvelope struct {
	Success bool                    `json:"success" example:"true"`
	Data    []models.GuidelineChunk `json:"data"`
}

type SearchResultsEnvelope struct {
	Success bool                    `json:"success" example:"true"`
	Data    []services.SearchResult `json:"data"`
}

type AskEnvelope struct {
	Success bool                 `json:"success" example:"true"`
	Data    services.AskResponse `json:"data"`
}

type ClinicalProtocolEnvelope struct {
	Success bool                    `json:"success" example:"true"`
	Data    models.ClinicalProtocol `json:"data"`
}

type ClinicalProtocolsEnvelope struct {
	Success bool                      `json:"success" example:"true"`
	Data    []models.ClinicalProtocol `json:"data"`
}

type ProtocolRunEnvelope struct {
	Success bool                       `json:"success" example:"true"`
	Data    services.RunProtocolResult `json:"data"`
}

type ManifestEnvelope struct {
	Success bool                    `json:"success" example:"true"`
	Data    services.ManifestResult `json:"data"`
}

type SyncPackageEnvelope struct {
	Success bool               `json:"success" example:"true"`
	Data    models.SyncPackage `json:"data"`
}

type DownloadURLEnvelope struct {
	Success bool              `json:"success" example:"true"`
	Data    DownloadURLResult `json:"data"`
}

type UserResponse = models.User
type GuidelineDocumentResponse = models.GuidelineDocument
type GuidelineVersionResponse = models.GuidelineVersion
type GuidelineSectionResponse = models.GuidelineSection
type GuidelineChunkResponse = models.GuidelineChunk
type IngestionJobResponse = models.IngestionJob
type ClinicalProtocolResponse = models.ClinicalProtocol
type SyncPackageResponse = models.SyncPackage
type LoginResult = services.LoginResult
type GuidelineInput = services.CreateGuidelineInput
type GuidelineVersionInput = services.CreateVersionInput
type AskRequest = services.AskRequest
type AskResponse = services.AskResponse
type CreateProtocolInput = services.CreateProtocolInput
type RunProtocolResult = services.RunProtocolResult
type CreateSyncPackageInput = services.CreateSyncPackageInput
type ManifestResult = services.ManifestResult
