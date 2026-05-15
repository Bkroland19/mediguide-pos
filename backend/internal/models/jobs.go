package models

import "github.com/google/uuid"

type IngestionJob struct {
	Base
	VersionID   uuid.UUID `gorm:"type:uuid;index;not null" json:"version_id"`
	JobType     string    `gorm:"default:'pdf_ingestion'" json:"job_type"`
	Status      string    `gorm:"default:'queued';index" json:"status"`
	Error       string    `gorm:"type:text" json:"error"`
	PayloadJSON string    `gorm:"type:jsonb" json:"payload_json"`
	StartedAt   any       `gorm:"-" json:"started_at,omitempty"`
	CompletedAt any       `gorm:"-" json:"completed_at,omitempty"`
}
