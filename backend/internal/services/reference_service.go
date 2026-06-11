package services

import (
	"encoding/json"

	"mediguide/internal/models"

	"gorm.io/gorm"
)

type ReferenceService struct {
	DB *gorm.DB
}

type CreateSettingInput struct {
	Key         string          `json:"key"`
	ValueJSON   json.RawMessage `json:"value_json" swaggertype:"object"`
	Category    string          `json:"category"`
	Description string          `json:"description"`
	IsPublic    bool            `json:"is_public"`
}

type CreateLanguageInput struct {
	Code             string          `json:"code"`
	Name             string          `json:"name"`
	NativeName       string          `json:"native_name"`
	IsActive         bool            `json:"is_active"`
	IsDefault        bool            `json:"is_default"`
	TranslationsURL  string          `json:"translations_url"`
	TranslationsJSON json.RawMessage `json:"translations_json" swaggertype:"object"`
	Version          *float64        `json:"version"`
	Status           string          `json:"status"`
	Progress         *float64        `json:"progress"`
	EnabledForUsers  bool            `json:"enabled_for_users"`
}

func (s ReferenceService) CreateSetting(in CreateSettingInput) (*models.Setting, error) {
	if len(in.ValueJSON) == 0 {
		in.ValueJSON = json.RawMessage(`{}`)
	}
	setting := models.Setting{
		Key:         in.Key,
		ValueJSON:   in.ValueJSON,
		Category:    in.Category,
		Description: in.Description,
		IsPublic:    in.IsPublic,
	}
	return &setting, s.DB.Create(&setting).Error
}

func (s ReferenceService) ListSettings(category string, publicOnly *bool, page PageInput) (*PageResult[models.Setting], error) {
	var rows []models.Setting
	q := s.DB.Model(&models.Setting{})
	if category != "" {
		q = q.Where("category = ?", category)
	}
	if publicOnly != nil {
		q = q.Where("is_public = ?", *publicOnly)
	}

	var total int64
	normalized := page.Normalize(20, 100)
	if err := q.Session(&gorm.Session{}).Count(&total).Error; err != nil {
		return nil, err
	}
	if err := q.Session(&gorm.Session{}).Order("key asc").Limit(normalized.PerPage).Offset(normalized.Offset()).Find(&rows).Error; err != nil {
		return nil, err
	}
	return NewPageResult(rows, normalized, total), nil
}

func (s ReferenceService) CreateLanguage(in CreateLanguageInput) (*models.Language, error) {
	lang := models.Language{
		Code:             in.Code,
		Name:             in.Name,
		NativeName:       in.NativeName,
		IsActive:         in.IsActive,
		IsDefault:        in.IsDefault,
		TranslationsURL:  in.TranslationsURL,
		TranslationsJSON: in.TranslationsJSON,
		Version:          in.Version,
		Status:           in.Status,
		Progress:         in.Progress,
		EnabledForUsers:  in.EnabledForUsers,
	}
	return &lang, s.DB.Create(&lang).Error
}

func (s ReferenceService) ListLanguages(activeOnly *bool, page PageInput) (*PageResult[models.Language], error) {
	var rows []models.Language
	q := s.DB.Model(&models.Language{})
	if activeOnly != nil {
		q = q.Where("is_active = ?", *activeOnly)
	}

	var total int64
	normalized := page.Normalize(20, 100)
	if err := q.Session(&gorm.Session{}).Count(&total).Error; err != nil {
		return nil, err
	}
	if err := q.Session(&gorm.Session{}).Order("is_default desc, name asc").Limit(normalized.PerPage).Offset(normalized.Offset()).Find(&rows).Error; err != nil {
		return nil, err
	}
	return NewPageResult(rows, normalized, total), nil
}
