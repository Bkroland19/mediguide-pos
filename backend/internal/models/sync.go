package models

type SyncPackage struct {
	Base
	Name         string `gorm:"not null" json:"name"`
	Version      string `gorm:"not null" json:"version"`
	Status       string `gorm:"default:'draft';index" json:"status"`
	FileKey      string `json:"file_key"`
	ManifestJSON string `gorm:"type:jsonb" json:"manifest_json"`
	Checksum     string `json:"checksum"`
	SizeBytes    int64  `json:"size_bytes"`
}

type DeviceRegistration struct {
	Base
	DeviceID   string  `gorm:"uniqueIndex;not null" json:"device_id"`
	UserID     string  `gorm:"type:uuid;index" json:"user_id"`
	Platform   string  `json:"platform"`
	AppVersion string  `json:"app_version"`
	LastSyncAt *string `json:"last_sync_at"`
}

type DeviceSyncLog struct {
	Base
	DeviceID  string `gorm:"index" json:"device_id"`
	PackageID string `gorm:"type:uuid;index" json:"package_id"`
	Status    string `json:"status"`
}
