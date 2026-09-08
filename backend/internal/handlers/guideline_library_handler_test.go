package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"mediguide/internal/config"
	"mediguide/internal/middleware"
	"mediguide/internal/models"
	"mediguide/internal/security"
	"mediguide/internal/services"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func TestGuidelineLibraryRoutesRequireAuthentication(t *testing.T) {
	router := gin.New()
	router.Use(middleware.AuthRequired(config.Config{}, nil))
	router.GET("/api/v2/library/collections", func(c *gin.Context) {
		c.Status(http.StatusNoContent)
	})

	response := httptest.NewRecorder()
	router.ServeHTTP(
		response,
		httptest.NewRequest(http.MethodGet, "/api/v2/library/collections", nil),
	)
	if response.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d: %s", response.Code, response.Body.String())
	}
}

func TestGuidelineLibraryHandlerValidationConflictsOwnershipAndEnvelopes(t *testing.T) {
	database := newGuidelineLibraryHandlerDB(t)
	owner := createGuidelineLibraryHandlerUser(t, database, "handler-owner@example.test")
	other := createGuidelineLibraryHandlerUser(t, database, "handler-other@example.test")
	guideline := createPublishedGuidelineLibraryHandlerDocument(t, database)
	handler := GuidelineLibraryHandler{
		Service: services.GuidelineLibraryService{DB: database},
	}
	ownerRouter := guidelineLibraryHandlerRouter(handler, owner)

	created := performGuidelineLibraryRequest(
		t,
		ownerRouter,
		http.MethodPost,
		"/api/v2/library/collections",
		`{"name":"  Ward round  ","description":"  Daily care  "}`,
	)
	if created.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d: %s", created.Code, created.Body.String())
	}
	var createdEnvelope struct {
		Success bool `json:"success"`
		Data    struct {
			ID          string `json:"id"`
			Name        string `json:"name"`
			Description string `json:"description"`
		} `json:"data"`
	}
	decodeGuidelineLibraryResponse(t, created, &createdEnvelope)
	if !createdEnvelope.Success || createdEnvelope.Data.Name != "Ward round" || createdEnvelope.Data.Description != "Daily care" {
		t.Fatalf("unexpected create envelope: %+v", createdEnvelope)
	}
	collectionID := createdEnvelope.Data.ID

	tests := []struct {
		name   string
		method string
		path   string
		body   string
		status int
	}{
		{name: "invalid uuid", method: http.MethodGet, path: "/api/v2/library/collections/not-a-uuid", status: http.StatusBadRequest},
		{name: "invalid payload", method: http.MethodPost, path: "/api/v2/library/collections", body: `{`, status: http.StatusBadRequest},
		{name: "validation error", method: http.MethodPost, path: "/api/v2/library/collections", body: `{"name":"   "}`, status: http.StatusBadRequest},
		{name: "duplicate name", method: http.MethodPost, path: "/api/v2/library/collections", body: `{"name":"WARD ROUND"}`, status: http.StatusConflict},
		{name: "missing collection", method: http.MethodGet, path: "/api/v2/library/collections/" + uuid.NewString(), status: http.StatusNotFound},
		{name: "invalid guideline uuid", method: http.MethodDelete, path: "/api/v2/library/collections/" + collectionID + "/items/not-a-uuid", status: http.StatusBadRequest},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			response := performGuidelineLibraryRequest(t, ownerRouter, tt.method, tt.path, tt.body)
			if response.Code != tt.status {
				t.Fatalf("expected %d, got %d: %s", tt.status, response.Code, response.Body.String())
			}
		})
	}

	foreign := performGuidelineLibraryRequest(
		t,
		guidelineLibraryHandlerRouter(handler, other),
		http.MethodPatch,
		"/api/v2/library/collections/"+collectionID,
		`{"name":"Foreign edit"}`,
	)
	if foreign.Code != http.StatusNotFound {
		t.Fatalf("expected foreign collection to return 404, got %d: %s", foreign.Code, foreign.Body.String())
	}

	updated := performGuidelineLibraryRequest(
		t,
		ownerRouter,
		http.MethodPatch,
		"/api/v2/library/collections/"+collectionID,
		`{"name":"Critical care","description":"Updated"}`,
	)
	if updated.Code != http.StatusOK {
		t.Fatalf("expected 200 update, got %d: %s", updated.Code, updated.Body.String())
	}

	added := performGuidelineLibraryRequest(
		t,
		ownerRouter,
		http.MethodPost,
		"/api/v2/library/collections/"+collectionID+"/items",
		`{"guideline_id":"`+guideline.ID.String()+`","sort_order":2}`,
	)
	if added.Code != http.StatusNoContent {
		t.Fatalf("expected 204 add, got %d: %s", added.Code, added.Body.String())
	}

	items := performGuidelineLibraryRequest(
		t,
		ownerRouter,
		http.MethodGet,
		"/api/v2/library/collections/"+collectionID+"/items?page=1&per_page=20",
		"",
	)
	if items.Code != http.StatusOK {
		t.Fatalf("expected 200 items, got %d: %s", items.Code, items.Body.String())
	}
	var itemEnvelope struct {
		Success bool `json:"success"`
		Data    struct {
			Items      []json.RawMessage `json:"items"`
			TotalItems int               `json:"total_items"`
		} `json:"data"`
	}
	decodeGuidelineLibraryResponse(t, items, &itemEnvelope)
	if !itemEnvelope.Success || len(itemEnvelope.Data.Items) != 1 || itemEnvelope.Data.TotalItems != 1 {
		t.Fatalf("unexpected item envelope: %+v", itemEnvelope)
	}

	removed := performGuidelineLibraryRequest(
		t,
		ownerRouter,
		http.MethodDelete,
		"/api/v2/library/collections/"+collectionID+"/items/"+guideline.ID.String(),
		"",
	)
	if removed.Code != http.StatusNoContent {
		t.Fatalf("expected 204 remove, got %d: %s", removed.Code, removed.Body.String())
	}

	list := performGuidelineLibraryRequest(
		t,
		ownerRouter,
		http.MethodGet,
		"/api/v2/library/collections?page=1&per_page=20&sort=name&order=asc",
		"",
	)
	if list.Code != http.StatusOK || !strings.Contains(list.Body.String(), `"total_items":1`) {
		t.Fatalf("unexpected list envelope: %d %s", list.Code, list.Body.String())
	}

	deleted := performGuidelineLibraryRequest(
		t,
		ownerRouter,
		http.MethodDelete,
		"/api/v2/library/collections/"+collectionID,
		"",
	)
	if deleted.Code != http.StatusNoContent {
		t.Fatalf("expected 204 delete, got %d: %s", deleted.Code, deleted.Body.String())
	}
	missingAfterDelete := performGuidelineLibraryRequest(
		t,
		ownerRouter,
		http.MethodGet,
		"/api/v2/library/collections/"+collectionID,
		"",
	)
	if missingAfterDelete.Code != http.StatusNotFound {
		t.Fatalf("expected deleted collection to return 404, got %d", missingAfterDelete.Code)
	}
}

func guidelineLibraryHandlerRouter(handler GuidelineLibraryHandler, userID uuid.UUID) *gin.Engine {
	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set(middleware.ClaimsKey, &security.Claims{UserID: userID})
		c.Next()
	})
	router.GET("/api/v2/library/collections", handler.ListCollections)
	router.POST("/api/v2/library/collections", handler.CreateCollection)
	router.GET("/api/v2/library/collections/:id", handler.GetCollection)
	router.PATCH("/api/v2/library/collections/:id", handler.UpdateCollection)
	router.DELETE("/api/v2/library/collections/:id", handler.DeleteCollection)
	router.POST("/api/v2/library/collections/:id/items", handler.AddCollectionItem)
	router.GET("/api/v2/library/collections/:id/items", handler.ListCollectionItems)
	router.DELETE("/api/v2/library/collections/:id/items/:guidelineId", handler.RemoveCollectionItem)
	return router
}

func performGuidelineLibraryRequest(
	t *testing.T,
	router http.Handler,
	method string,
	path string,
	body string,
) *httptest.ResponseRecorder {
	t.Helper()
	request := httptest.NewRequest(method, path, strings.NewReader(body))
	if body != "" {
		request.Header.Set("Content-Type", "application/json")
	}
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)
	return response
}

func decodeGuidelineLibraryResponse(t *testing.T, response *httptest.ResponseRecorder, target any) {
	t.Helper()
	if err := json.Unmarshal(response.Body.Bytes(), target); err != nil {
		t.Fatalf("decode response: %v: %s", err, response.Body.String())
	}
}

func newGuidelineLibraryHandlerDB(t *testing.T) *gorm.DB {
	t.Helper()
	database, err := gorm.Open(
		sqlite.Open("file:"+uuid.NewString()+"?mode=memory&cache=shared"),
		&gorm.Config{},
	)
	if err != nil {
		t.Fatal(err)
	}
	if err := database.AutoMigrate(
		&models.User{},
		&models.GuidelineDocument{},
		&models.GuidelineVersion{},
		&models.GuidelineCollection{},
		&models.GuidelineCollectionItem{},
	); err != nil {
		t.Fatal(err)
	}
	return database
}

func createGuidelineLibraryHandlerUser(t *testing.T, database *gorm.DB, email string) uuid.UUID {
	t.Helper()
	id := uuid.New()
	if err := database.Create(&models.User{
		Base:         models.Base{ID: id},
		Name:         "Reader",
		Email:        email,
		PasswordHash: "hash",
	}).Error; err != nil {
		t.Fatal(err)
	}
	return id
}

func createPublishedGuidelineLibraryHandlerDocument(t *testing.T, database *gorm.DB) models.GuidelineDocument {
	t.Helper()
	document := models.GuidelineDocument{Title: "Published handler guideline"}
	if err := database.Create(&document).Error; err != nil {
		t.Fatal(err)
	}
	version := models.GuidelineVersion{
		DocumentID:      document.ID,
		Version:         "1",
		Status:          "published",
		OriginalFileKey: "source/handler.pdf",
	}
	if err := database.Create(&version).Error; err != nil {
		t.Fatal(err)
	}
	document.CurrentVersionID = &version.ID
	if err := database.Save(&document).Error; err != nil {
		t.Fatal(err)
	}
	return document
}
