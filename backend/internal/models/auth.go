package models

type User struct {
	Base
	Name         string  `gorm:"not null" json:"name"`
	Email        string  `gorm:"uniqueIndex;not null" json:"email"`
	Phone        string  `json:"phone"`
	PasswordHash string  `gorm:"not null" json:"-"`
	FacilityID   *string `json:"facility_id"`
	IsActive     bool    `gorm:"default:true" json:"is_active"`
	Roles        []Role  `gorm:"many2many:user_roles;" json:"roles,omitempty"`
}

type Role struct {
	Base
	Name        string       `gorm:"uniqueIndex;not null" json:"name"`
	Description string       `json:"description"`
	Permissions []Permission `gorm:"many2many:role_permissions;" json:"permissions,omitempty"`
}

type Permission struct {
	Base
	Code string `gorm:"uniqueIndex;not null" json:"code"`
	Name string `json:"name"`
}
