package main

import (
	"time"

	"mediguide/internal/config"
	"mediguide/internal/db"
	"mediguide/internal/models"

	"github.com/rs/zerolog/log"
)

func main() {
	cfg := config.Load()
	database, err := db.Connect(cfg.DatabaseURL)
	if err != nil {
		log.Fatal().Err(err).Msg("db connect failed")
	}

	log.Info().Msg("ingestion worker started")
	for {
		var job models.IngestionJob
		res := database.Where("status = ?", "queued").Order("created_at asc").First(&job)
		if res.Error == nil {
			log.Info().Str("job_id", job.ID.String()).Msg("picked ingestion job")
			database.Model(&job).Updates(map[string]any{"status": "running", "started_at": time.Now()})
			// Production: call Python AI worker here.
			// The worker should extract HTML, sections, tables, chunks and embeddings.
			database.Model(&job).Updates(map[string]any{"status": "waiting_external_worker"})
		}
		time.Sleep(10 * time.Second)
	}
}
