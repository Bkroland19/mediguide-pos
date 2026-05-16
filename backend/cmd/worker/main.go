package main

import (
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"mediguide/internal/config"
	"mediguide/internal/db"
	"mediguide/internal/models"

	"github.com/rs/zerolog/log"
	"gorm.io/gorm"
)

func main() {
	cfg := config.Load()
	database, err := db.Connect(cfg.DatabaseURL)
	if err != nil {
		log.Fatal().Err(err).Msg("db connect failed")
	}

	baseURL := strings.TrimSpace(cfg.AIWorkerWebhook)
	if baseURL == "" {
		log.Fatal().Msg("AI worker URL is not configured")
	}

	client := &http.Client{Timeout: 15 * time.Minute}
	log.Info().Str("worker_url", baseURL).Msg("ingestion dispatcher started")

	for {
		job, claimed, err := claimQueuedJob(database)
		if err != nil {
			log.Error().Err(err).Msg("failed to claim ingestion job")
			time.Sleep(10 * time.Second)
			continue
		}
		if !claimed {
			time.Sleep(10 * time.Second)
			continue
		}

		log.Info().Str("job_id", job.ID.String()).Msg("dispatching ingestion job to ai-worker")
		if err := dispatchIngestionJob(client, baseURL, job.ID.String()); err != nil {
			log.Error().Err(err).Str("job_id", job.ID.String()).Msg("ai-worker dispatch failed")
			markJobFailed(database, job.ID.String(), err.Error())
		}
	}
}

func claimQueuedJob(database *gorm.DB) (*models.IngestionJob, bool, error) {
	var job models.IngestionJob
	if err := database.Where("status = ? AND job_type = ?", "queued", "pdf_ingestion").Order("created_at asc").First(&job).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, false, nil
		}
		return nil, false, err
	}

	res := database.Model(&models.IngestionJob{}).
		Where("id = ? AND status = ?", job.ID, "queued").
		Updates(map[string]any{
			"status":     "waiting_external_worker",
			"started_at": time.Now(),
		})
	if res.Error != nil {
		return nil, false, res.Error
	}
	if res.RowsAffected == 0 {
		return nil, false, nil
	}
	return &job, true, nil
}

func dispatchIngestionJob(client *http.Client, baseURL, jobID string) error {
	url := strings.TrimRight(baseURL, "/")
	if !strings.HasSuffix(url, "/api/v1/ingestion/jobs/"+jobID+"/run") {
		url += "/api/v1/ingestion/jobs/" + jobID + "/run"
	}

	req, err := http.NewRequest(http.MethodPost, url, nil)
	if err != nil {
		return err
	}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return fmt.Errorf("AI worker request failed: %s: %s", resp.Status, strings.TrimSpace(string(body)))
	}
	return nil
}

func markJobFailed(database *gorm.DB, jobID string, message string) {
	if err := database.Model(&models.IngestionJob{}).
		Where("id = ?", jobID).
		Updates(map[string]any{
			"status":       "failed",
			"error":        truncateError(message),
			"completed_at": time.Now(),
		}).Error; err != nil {
		log.Error().Err(err).Str("job_id", jobID).Msg("failed to mark ingestion job as failed")
	}
}

func truncateError(message string) string {
	message = strings.TrimSpace(message)
	if len(message) <= 4000 {
		return message
	}
	return message[:4000]
}
