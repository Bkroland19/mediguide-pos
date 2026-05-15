package models

type AuditLog struct {
	Base
	ActorID      string `gorm:"type:uuid;index" json:"actor_id"`
	Action       string `gorm:"index" json:"action"`
	EntityType   string `gorm:"index" json:"entity_type"`
	EntityID     string `gorm:"index" json:"entity_id"`
	MetadataJSON string `gorm:"type:jsonb" json:"metadata_json"`
	IPAddress    string `json:"ip_address"`
}
