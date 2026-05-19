package models

import (
	"time"

	"github.com/google/uuid"
)

type AuthSession struct {
	Base
	UserID           uuid.UUID  `gorm:"type:uuid;index;not null" json:"user_id"`
	RefreshTokenHash string     `gorm:"not null;uniqueIndex" json:"-"`
	ExpiresAt        time.Time  `gorm:"not null;index" json:"expires_at"`
	LastUsedAt       *time.Time `json:"last_used_at,omitempty"`
	RevokedAt        *time.Time `gorm:"index" json:"revoked_at,omitempty"`
	UserAgent        *string    `json:"user_agent,omitempty"`
	IPAddress        *string    `json:"ip_address,omitempty"`
}
