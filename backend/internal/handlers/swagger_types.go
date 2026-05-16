package handlers

import (
	"mediguide/internal/models"
	"mediguide/internal/services"
)

type RegisterRequest struct {
	Name              string `json:"name" example:"Admin User"`
	Email             string `json:"email" example:"admin@mediguide.local"`
	Password          string `json:"password" example:"Admin123!"`
	Phone             string `json:"phone" example:"+256700000001"`
	AlternativePhone  string `json:"alternative_phone" example:"+256700000002"`
	FacilityID        string `json:"facility_id" example:"3fa85f64-5717-4562-b3fc-2c963f66afa6"`
	Address           string `json:"address" example:"Plot 12 Kampala Road"`
	City              string `json:"city" example:"Kampala"`
	Country           string `json:"country" example:"Uganda"`
	PostalCode        string `json:"postal_code" example:"256"`
	LicenseNumber     string `json:"license_number" example:"MD-12345"`
	Organization      string `json:"organization" example:"Mulago Hospital"`
	Department        string `json:"department" example:"Emergency"`
	JobTitle          string `json:"job_title" example:"Medical Officer"`
	PreferredLanguage string `json:"preferred_language" example:"en"`
	Timezone          string `json:"timezone" example:"Africa/Kampala"`
	Notes             string `json:"notes" example:"Night shift clinician"`
	Specialization    string `json:"specialization" example:"Internal Medicine"`
	Avatar            string `json:"avatar" example:"https://example.com/avatar.png"`
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

type SettingEnvelope struct {
	Success bool           `json:"success" example:"true"`
	Data    models.Setting `json:"data"`
}

type SettingsEnvelope struct {
	Success bool             `json:"success" example:"true"`
	Data    []models.Setting `json:"data"`
}

type LanguageEnvelope struct {
	Success bool            `json:"success" example:"true"`
	Data    models.Language `json:"data"`
}

type LanguagesEnvelope struct {
	Success bool              `json:"success" example:"true"`
	Data    []models.Language `json:"data"`
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
type CreateSettingInput = services.CreateSettingInput
type CreateLanguageInput = services.CreateLanguageInput
