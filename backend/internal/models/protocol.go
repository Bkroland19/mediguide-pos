package models

type ClinicalProtocol struct {
	Base
	Code           string `gorm:"uniqueIndex;not null" json:"code"`
	Title          string `gorm:"not null" json:"title"`
	ProgramArea    string `json:"program_area"`
	Version        string `json:"version"`
	Language       string `gorm:"default:'en'" json:"language"`
	Status         string `gorm:"default:'draft';index" json:"status"`
	DefinitionYAML string `gorm:"type:text" json:"definition_yaml"`
	DefinitionJSON string `gorm:"type:jsonb" json:"definition_json"`
}

type ProtocolRun struct {
	Base
	ProtocolID string `gorm:"type:uuid;index" json:"protocol_id"`
	UserID     string `gorm:"type:uuid;index" json:"user_id"`
	InputJSON  string `gorm:"type:jsonb" json:"input_json"`
	OutputJSON string `gorm:"type:jsonb" json:"output_json"`
}
