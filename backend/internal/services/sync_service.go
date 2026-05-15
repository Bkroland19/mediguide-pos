package services

import (
	"context"
	"time"

	"mediguide/internal/config"
	"mediguide/internal/models"
	"mediguide/internal/storage"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type SyncService struct {
	DB    *gorm.DB
	Store storage.ObjectStore
	Cfg   config.Config
}

type CreateSyncPackageInput struct {
	Name         string `json:"name"`
	Version      string `json:"version"`
	ManifestJSON string `json:"manifest_json"`
}

type ManifestResult struct {
	Packages    []models.SyncPackage `json:"packages"`
	GeneratedAt string               `json:"generated_at"`
}

func (s SyncService) Manifest() (*ManifestResult, error) {
	var packages []models.SyncPackage
	if err := s.DB.Where("status = ?", "published").Order("created_at desc").Find(&packages).Error; err != nil {
		return nil, err
	}
	return &ManifestResult{Packages: packages, GeneratedAt: time.Now().Format(time.RFC3339)}, nil
}
func (s SyncService) CreatePackage(in CreateSyncPackageInput) (*models.SyncPackage, error) {
	p := models.SyncPackage{Name: in.Name, Version: in.Version, Status: "draft", ManifestJSON: in.ManifestJSON}
	return &p, s.DB.Create(&p).Error
}
func (s SyncService) DownloadURL(ctx context.Context, id uuid.UUID) (string, error) {
	var p models.SyncPackage
	if err := s.DB.First(&p, "id = ?", id).Error; err != nil {
		return "", err
	}
	u, err := s.Store.PresignGet(ctx, p.FileKey, time.Duration(s.Cfg.S3PresignMinutes)*time.Minute)
	if err != nil {
		return "", err
	}
	return u.String(), nil
}
