package models

import "github.com/google/uuid"

type ChatSession struct {
	Base
	UserID *uuid.UUID `gorm:"type:uuid;index" json:"user_id"`
	Title  string     `json:"title"`
}

type ChatMessage struct {
	Base
	SessionID     uuid.UUID `gorm:"type:uuid;index;not null" json:"session_id"`
	Role          string    `json:"role"`
	Content       string    `gorm:"type:text" json:"content"`
	CitationsJSON string    `gorm:"type:jsonb" json:"citations_json"`
}

type RetrievalLog struct {
	Base
	UserID      *uuid.UUID `gorm:"type:uuid;index" json:"user_id"`
	Question    string     `gorm:"type:text" json:"question"`
	QueryJSON   string     `gorm:"type:jsonb" json:"query_json"`
	ResultsJSON string     `gorm:"type:jsonb" json:"results_json"`
}
