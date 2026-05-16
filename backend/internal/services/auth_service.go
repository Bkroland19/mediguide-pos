package services

import (
	"errors"
	"strings"

	"mediguide/internal/config"
	"mediguide/internal/models"
	"mediguide/internal/security"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type AuthService struct {
	DB  *gorm.DB
	Cfg config.Config
}

type LoginResult struct {
	Token string      `json:"token"`
	User  models.User `json:"user"`
}

type RegisterInput struct {
	Name              string `json:"name"`
	Email             string `json:"email"`
	Password          string `json:"password"`
	Phone             string `json:"phone"`
	AlternativePhone  string `json:"alternative_phone"`
	FacilityID        string `json:"facility_id"`
	Address           string `json:"address"`
	City              string `json:"city"`
	Country           string `json:"country"`
	PostalCode        string `json:"postal_code"`
	LicenseNumber     string `json:"license_number"`
	Organization      string `json:"organization"`
	Department        string `json:"department"`
	JobTitle          string `json:"job_title"`
	PreferredLanguage string `json:"preferred_language"`
	Timezone          string `json:"timezone"`
	Notes             string `json:"notes"`
	Specialization    string `json:"specialization"`
	Avatar            string `json:"avatar"`
}

func (s AuthService) Register(in RegisterInput) (*models.User, error) {
	hash, err := security.HashPassword(in.Password)
	if err != nil {
		return nil, err
	}
	u := models.User{
		Name:              strings.TrimSpace(in.Name),
		Email:             strings.TrimSpace(in.Email),
		Phone:             strings.TrimSpace(in.Phone),
		AlternativePhone:  optionalString(in.AlternativePhone),
		PasswordHash:      hash,
		FacilityID:        optionalString(in.FacilityID),
		IsActive:          true,
		Address:           optionalString(in.Address),
		City:              optionalString(in.City),
		Country:           optionalString(in.Country),
		PostalCode:        optionalString(in.PostalCode),
		LicenseNumber:     optionalString(in.LicenseNumber),
		Organization:      optionalString(in.Organization),
		Department:        optionalString(in.Department),
		JobTitle:          optionalString(in.JobTitle),
		PreferredLanguage: optionalString(in.PreferredLanguage),
		Timezone:          optionalString(in.Timezone),
		Notes:             optionalString(in.Notes),
		Specialization:    optionalString(in.Specialization),
		Avatar:            optionalString(in.Avatar),
		Verified:          false,
		Status:            "active",
	}
	if err := s.DB.Create(&u).Error; err != nil {
		return nil, err
	}
	return &u, nil
}

func (s AuthService) Login(email, password string) (*LoginResult, error) {
	var u models.User
	if err := s.DB.Preload("Roles.Permissions").Where("email = ?", email).First(&u).Error; err != nil {
		return nil, errors.New("invalid credentials")
	}
	if !u.IsActive || !security.CheckPassword(u.PasswordHash, password) {
		return nil, errors.New("invalid credentials")
	}
	roles := []string{}
	permsMap := map[string]bool{}
	for _, r := range u.Roles {
		roles = append(roles, r.Name)
		for _, p := range r.Permissions {
			permsMap[p.Code] = true
		}
	}
	perms := []string{}
	for p := range permsMap {
		perms = append(perms, p)
	}
	tok, err := security.GenerateJWT(s.Cfg.JWTSecret, s.Cfg.JWTIssuer, s.Cfg.JWTTTLMinutes, u.ID, u.Email, roles, perms)
	if err != nil {
		return nil, err
	}
	return &LoginResult{Token: tok, User: u}, nil
}

func (s AuthService) Me(id uuid.UUID) (*models.User, error) {
	var u models.User
	if err := s.DB.Preload("Roles.Permissions").First(&u, "id = ?", id).Error; err != nil {
		return nil, err
	}
	return &u, nil
}

func optionalString(v string) *string {
	trimmed := strings.TrimSpace(v)
	if trimmed == "" {
		return nil
	}
	return &trimmed
}
