package main

import (
	"mediguide/internal/config"
	"mediguide/internal/db"
	"mediguide/internal/models"
	"mediguide/internal/security"

	"github.com/rs/zerolog/log"
)

func main() {
	cfg := config.Load()
	database, err := db.Connect(cfg.DatabaseURL)
	if err != nil {
		log.Fatal().Err(err).Msg("db connect failed")
	}

	permissions := []models.Permission{
		{Code: "guideline.read", Name: "Read guidelines"},
		{Code: "guideline.write", Name: "Create/update guidelines"},
		{Code: "guideline.publish", Name: "Publish guidelines"},
		{Code: "protocol.read", Name: "Read protocols"},
		{Code: "protocol.write", Name: "Create/update protocols"},
		{Code: "chat.ask", Name: "Ask RAG chatbot"},
		{Code: "sync.read", Name: "Read sync packages"},
		{Code: "admin.all", Name: "All administration permissions"},
	}
	for _, p := range permissions {
		database.FirstOrCreate(&p, models.Permission{Code: p.Code})
	}

	adminRole := models.Role{Name: "admin", Description: "System administrator"}
	database.FirstOrCreate(&adminRole, models.Role{Name: "admin"})
	database.Model(&adminRole).Association("Permissions").Replace(&permissions)

	clinicianRole := models.Role{Name: "clinician", Description: "Frontline clinician"}
	database.FirstOrCreate(&clinicianRole, models.Role{Name: "clinician"})

	hash, _ := security.HashPassword("Admin123!")
	admin := models.User{
		Name:         "MediGuide Admin",
		Email:        "admin@mediguide.local",
		PasswordHash: hash,
		IsActive:     true,
	}
	database.FirstOrCreate(&admin, models.User{Email: admin.Email})
	database.Model(&admin).Association("Roles").Replace(&adminRole)

	log.Info().Msg("seed completed")
}
