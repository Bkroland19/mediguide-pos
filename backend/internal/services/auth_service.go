package services

import (
	"errors"

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

func (s AuthService) Register(name, email, password string) (*models.User, error) {
	hash, err := security.HashPassword(password)
	if err != nil {
		return nil, err
	}
	u := models.User{Name: name, Email: email, PasswordHash: hash, IsActive: true}
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
