package models

import "encoding/json"

type Setting struct {
	Base
	Key         string          `gorm:"uniqueIndex;not null" json:"key"`
	ValueJSON   json.RawMessage `gorm:"type:jsonb;column:value_json;not null" json:"value_json" swaggertype:"object"`
	Category    string          `json:"category"`
	Description string          `json:"description"`
	IsPublic    bool            `gorm:"default:false;column:is_public" json:"is_public"`
}

type Language struct {
	Base
	Code             string          `gorm:"uniqueIndex;not null" json:"code"`
	Name             string          `gorm:"not null" json:"name"`
	NativeName       string          `gorm:"column:native_name;not null" json:"native_name"`
	IsActive         bool            `gorm:"default:true;column:is_active" json:"is_active"`
	IsDefault        bool            `gorm:"default:false;column:is_default" json:"is_default"`
	TranslationsURL  string          `gorm:"column:translations_url" json:"translations_url"`
	TranslationsJSON json.RawMessage `gorm:"type:jsonb;column:translations_json" json:"translations_json,omitempty" swaggertype:"object"`
	Version          *float64        `json:"version,omitempty"`
	Status           string          `json:"status"`
	Progress         *float64        `json:"progress,omitempty"`
	EnabledForUsers  bool            `gorm:"default:true;column:enabled_for_users" json:"enabled_for_users"`
}
