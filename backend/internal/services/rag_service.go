package services

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
	"unicode/utf8"

	"mediguide/internal/config"
	"mediguide/internal/models"
	"mediguide/internal/security"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"
	"gorm.io/gorm"
)

type RAGService struct {
	DB         *gorm.DB
	Search     SearchService
	Cfg        config.Config
	HTTPClient *http.Client
}

type AskRequest struct {
	Question    string `json:"question"`
	Language    string `json:"language"`
	ProgramArea string `json:"program_area"`
	SessionID   string `json:"session_id"`
}

type Citation struct {
	ChunkID       string `json:"chunk_id"`
	Title         string `json:"title"`
	SourceName    string `json:"source_name"`
	SourceVersion string `json:"source_version"`
	PageStart     *int   `json:"page_start"`
	PageEnd       *int   `json:"page_end"`
}
type AskResponse struct {
	Answer    string     `json:"answer"`
	Citations []Citation `json:"citations"`
	SessionID string     `json:"session_id"`
}

const assistantUserEmail = "assistant@mediguide.local"

func (s RAGService) Ask(userID *uuid.UUID, req AskRequest) (*AskResponse, error) {
	session, err := s.getOrCreateSession(userID, req)
	if err != nil {
		return nil, err
	}

	res, err := s.askWithConfiguredProvider(req)
	if err != nil {
		return nil, err
	}

	res.SessionID = session.ID.String()
	cjson, _ := json.Marshal(res.Citations)
	s.DB.Create(&models.ChatMessage{SessionID: session.ID, Role: "user", Content: req.Question})
	s.DB.Create(&models.ChatMessage{SessionID: session.ID, Role: "assistant", Content: res.Answer, CitationsJSON: string(cjson)})
	if userID != nil && *userID != uuid.Nil {
		if err := s.mirrorToLegacyConversation(*userID, req.Question, res.Answer); err != nil {
			log.Warn().Err(err).Str("user_id", userID.String()).Msg("failed to mirror RAG exchange to legacy conversations")
		}
	}
	return res, nil
}

func (s RAGService) askWithConfiguredProvider(req AskRequest) (*AskResponse, error) {
	provider := strings.ToLower(strings.TrimSpace(s.Cfg.AIRAGProvider))
	if provider == "worker" || provider == "ai-worker" {
		if res, err := s.askWorker(req); err == nil {
			return res, nil
		} else {
			log.Warn().Err(err).Msg("ai-worker RAG failed, falling back to local search")
		}
	}
	return s.askLocal(req)
}

func (s RAGService) askWorker(req AskRequest) (*AskResponse, error) {
	baseURL := strings.TrimSpace(s.Cfg.AIWorkerWebhook)
	if baseURL == "" {
		return nil, fmt.Errorf("AI worker URL is not configured")
	}
	url := strings.TrimRight(baseURL, "/")
	if !strings.HasSuffix(url, "/api/v1/rag/ask") {
		url += "/api/v1/rag/ask"
	}

	payload, err := json.Marshal(map[string]any{
		"question":     req.Question,
		"language":     req.Language,
		"program_area": req.ProgramArea,
	})
	if err != nil {
		return nil, err
	}

	httpClient := s.HTTPClient
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 45 * time.Second}
	}

	httpReq, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(payload))
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	if secret := strings.TrimSpace(s.Cfg.AIWorkerSecret); secret != "" {
		httpReq.Header.Set("X-Worker-Secret", secret)
	}

	resp, err := httpClient.Do(httpReq)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return nil, fmt.Errorf("AI worker request failed: %s: %s", resp.Status, strings.TrimSpace(string(body)))
	}

	var workerResp struct {
		Answer    string `json:"answer"`
		Citations []struct {
			ChunkID       string `json:"chunk_id"`
			Title         string `json:"title"`
			SourceName    string `json:"source_name"`
			SourceVersion string `json:"source_version"`
			PageStart     *int   `json:"page_start"`
			PageEnd       *int   `json:"page_end"`
		} `json:"citations"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&workerResp); err != nil {
		return nil, err
	}

	citations := make([]Citation, 0, len(workerResp.Citations))
	for _, c := range workerResp.Citations {
		citations = append(citations, Citation{
			ChunkID:       c.ChunkID,
			Title:         c.Title,
			SourceName:    c.SourceName,
			SourceVersion: c.SourceVersion,
			PageStart:     c.PageStart,
			PageEnd:       c.PageEnd,
		})
	}
	return &AskResponse{Answer: workerResp.Answer, Citations: citations}, nil
}

func (s RAGService) askLocal(req AskRequest) (*AskResponse, error) {
	results, err := s.Search.Search(req.Question, req.ProgramArea, 5)
	if err != nil {
		return nil, err
	}
	citations := []Citation{}
	parts := []string{}
	for _, r := range results {
		citations = append(citations, Citation{ChunkID: r.ID, Title: r.Title, SourceName: r.SourceName, SourceVersion: r.SourceVersion, PageStart: r.PageStart, PageEnd: r.PageEnd})
		parts = append(parts, "- "+r.Snippet)
	}
	answer := "I found the following approved guideline content that may answer the question. Please review the cited source sections before clinical use:\n\n" + strings.Join(parts, "\n")
	if len(results) == 0 {
		answer = "I could not find an answer in the approved guideline content. Please consult the current national guideline or refer to a senior clinician."
	}
	return &AskResponse{Answer: answer, Citations: citations}, nil
}

func (s RAGService) getOrCreateSession(userID *uuid.UUID, req AskRequest) (*models.ChatSession, error) {
	var session models.ChatSession
	if req.SessionID != "" {
		sid, _ := uuid.Parse(req.SessionID)
		s.DB.First(&session, "id = ?", sid)
	}
	if session.ID == uuid.Nil {
		session = models.ChatSession{
			UserID: s.resolveChatSessionUserID(userID),
			Title:  truncate(req.Question, 80),
		}
		if err := s.DB.Create(&session).Error; err != nil {
			return nil, err
		}
	}
	return &session, nil
}

func (s RAGService) resolveChatSessionUserID(userID *uuid.UUID) *uuid.UUID {
	if userID == nil || *userID == uuid.Nil {
		return nil
	}

	var count int64
	if err := s.DB.Model(&models.User{}).Where("id = ?", *userID).Count(&count).Error; err != nil {
		log.Warn().Err(err).Str("user_id", userID.String()).Msg("failed to validate RAG chat user; creating anonymous session")
		return nil
	}
	if count == 0 {
		log.Warn().Str("user_id", userID.String()).Msg("RAG chat user not found; creating anonymous session")
		return nil
	}

	return userID
}

func (s RAGService) mirrorToLegacyConversation(userID uuid.UUID, question, answer string) error {
	assistantID, err := s.lookupAssistantUserID()
	if err != nil {
		return err
	}

	conversationID, err := s.findOrCreateLegacyConversation(userID, assistantID)
	if err != nil {
		return err
	}

	now := time.Now().UTC()
	userReadBy := map[string]any{
		userID.String(): now.Format(time.RFC3339),
	}
	assistantReadBy := map[string]any{
		userID.String():      now.Format(time.RFC3339),
		assistantID.String(): now.Format(time.RFC3339),
	}

	userMessage := map[string]any{
		"id":               uuid.New(),
		"conversation_id":  conversationID,
		"sender_user_id":   userID,
		"content":          strings.TrimSpace(question),
		"message_type":     "text",
		"read_by_json":     userReadBy,
		"reactions_json":   map[string]any{},
		"attachments_json": []any{},
		"is_edited":        false,
		"created_at":       now,
		"updated_at":       now,
	}
	if err := s.DB.Table("messages").Create(&userMessage).Error; err != nil {
		return err
	}

	assistantMessage := map[string]any{
		"id":               uuid.New(),
		"conversation_id":  conversationID,
		"sender_user_id":   assistantID,
		"content":          strings.TrimSpace(answer),
		"message_type":     "text",
		"read_by_json":     assistantReadBy,
		"reactions_json":   map[string]any{},
		"attachments_json": []any{},
		"is_edited":        false,
		"created_at":       now,
		"updated_at":       now,
	}
	if err := s.DB.Table("messages").Create(&assistantMessage).Error; err != nil {
		return err
	}

	return s.DB.Table("conversations").
		Where("id = ?", conversationID).
		Updates(map[string]any{
			"last_activity": now.Format(time.RFC3339),
			"updated_at":    now,
		}).Error
}

func (s RAGService) lookupAssistantUserID() (uuid.UUID, error) {
	var assistant models.User
	if err := s.DB.Select("id").Where("email = ?", assistantUserEmail).First(&assistant).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			hash, hashErr := security.HashPassword("Assistant123!")
			if hashErr != nil {
				return uuid.Nil, hashErr
			}
			assistant = models.User{
				Name:         "MediGuide AI",
				Email:        assistantUserEmail,
				Phone:        "+256700000003",
				PasswordHash: hash,
				IsActive:     true,
				Verified:     true,
				Status:       "active",
			}
			if createErr := s.DB.Create(&assistant).Error; createErr != nil {
				return uuid.Nil, createErr
			}
			return assistant.ID, nil
		}
		return uuid.Nil, err
	}
	return assistant.ID, nil
}

func (s RAGService) findOrCreateLegacyConversation(userID, assistantID uuid.UUID) (uuid.UUID, error) {
	var row struct {
		ID uuid.UUID `gorm:"column:id"`
	}
	err := s.DB.Table("conversations").
		Select("id").
		Where(
			"(participant1_user_id = ? AND participant2_user_id = ?) OR (participant1_user_id = ? AND participant2_user_id = ?)",
			userID,
			assistantID,
			assistantID,
			userID,
		).
		Where("deleted_at IS NULL").
		Take(&row).Error
	if err == nil {
		return row.ID, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return uuid.Nil, err
	}

	createRow := map[string]any{
		"id":                   uuid.New(),
		"participant1_user_id": userID,
		"participant2_user_id": assistantID,
		"last_activity":        time.Now().UTC().Format(time.RFC3339),
		"created_at":           time.Now().UTC(),
		"updated_at":           time.Now().UTC(),
	}
	if err := s.DB.Table("conversations").Create(&createRow).Error; err != nil {
		return uuid.Nil, err
	}
	return createRow["id"].(uuid.UUID), nil
}

// truncate shortens s to at most n Unicode code points (runes), not bytes,
// so it is safe for multilingual content (Luganda, Swahili, etc.).
func truncate(s string, n int) string {
	if utf8.RuneCountInString(s) <= n {
		return s
	}
	runes := []rune(s)
	return string(runes[:n])
}
