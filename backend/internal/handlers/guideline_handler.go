package handlers

import (
	"errors"
	"net/http"

	"mediguide/internal/httpx"
	"mediguide/internal/middleware"
	"mediguide/internal/security"
	"mediguide/internal/services"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type GuidelineHandler struct {
	Service     services.GuidelineService
	MaxUploadMB int64
}

// Create godoc
// @Summary Create a guideline document
// @Tags guidelines
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param payload body services.CreateGuidelineInput true "Guideline document payload"
// @Success 201 {object} handlers.GuidelineDocumentEnvelope
// @Failure 400 {object} handlers.ErrorResponse
// @Failure 401 {object} handlers.ErrorResponse
// @Failure 403 {object} handlers.ErrorResponse
// @Router /api/v2/guidelines [post]
func (h GuidelineHandler) Create(c *gin.Context) {
	var in services.CreateGuidelineInput
	if err := c.ShouldBindJSON(&in); err != nil {
		httpx.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	d, err := h.Service.CreateDocument(in)
	if err != nil {
		httpx.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	httpx.Created(c, d)
}

// List godoc
// @Summary List guideline documents
// @Tags guidelines
// @Produce json
// @Security BearerAuth
// @Param program_area query string false "Program area filter"
// @Param page query int false "Page number" minimum(1)
// @Param per_page query int false "Page size" minimum(1) maximum(100)
// @Success 200 {object} handlers.PaginatedGuidelineDocumentsEnvelope
// @Failure 401 {object} handlers.ErrorResponse
// @Failure 403 {object} handlers.ErrorResponse
// @Failure 500 {object} handlers.ErrorResponse
// @Router /api/v2/guidelines [get]
func (h GuidelineHandler) List(c *gin.Context) {
	page, err := parsePageQuery(c, 20, 100)
	if err != nil {
		httpx.Error(c, http.StatusBadRequest, "invalid pagination parameters")
		return
	}

	rows, err := h.Service.ListDocuments(c.Query("program_area"), page)
	if err != nil {
		httpx.Error(c, 500, "internal server error")
		return
	}
	httpx.OK(c, rows)
}

// Get godoc
// @Summary Get a guideline document
// @Tags guidelines
// @Produce json
// @Security BearerAuth
// @Param id path string true "Document ID" format(uuid)
// @Success 200 {object} handlers.GuidelineDocumentEnvelope
// @Failure 401 {object} handlers.ErrorResponse
// @Failure 403 {object} handlers.ErrorResponse
// @Failure 404 {object} handlers.ErrorResponse
// @Router /api/v2/guidelines/{id} [get]
func (h GuidelineHandler) Get(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		httpx.Error(c, http.StatusBadRequest, "invalid id")
		return
	}
	d, err := h.Service.GetDocument(id)
	if err != nil {
		httpx.Error(c, 404, "not found")
		return
	}
	httpx.OK(c, d)
}

// CreateVersion godoc
// @Summary Create a guideline version
// @Tags guidelines
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param id path string true "Document ID" format(uuid)
// @Param payload body services.CreateVersionInput true "Guideline version payload"
// @Success 201 {object} handlers.GuidelineVersionEnvelope
// @Failure 400 {object} handlers.ErrorResponse
// @Failure 401 {object} handlers.ErrorResponse
// @Failure 403 {object} handlers.ErrorResponse
// @Router /api/v2/guidelines/{id}/versions [post]
func (h GuidelineHandler) CreateVersion(c *gin.Context) {
	docID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		httpx.Error(c, http.StatusBadRequest, "invalid id")
		return
	}
	var in services.CreateVersionInput
	if err := c.ShouldBindJSON(&in); err != nil {
		httpx.Error(c, 400, err.Error())
		return
	}
	v, err := h.Service.CreateVersion(docID, in)
	if err != nil {
		httpx.Error(c, 400, err.Error())
		return
	}
	httpx.Created(c, v)
}

// UploadPDF godoc
// @Summary Upload a guideline PDF
// @Tags guidelines
// @Accept mpfd
// @Produce json
// @Security BearerAuth
// @Param id path string true "Guideline version ID" format(uuid)
// @Param file formData file true "PDF file"
// @Success 201 {object} handlers.IngestionJobEnvelope
// @Failure 400 {object} handlers.ErrorResponse
// @Failure 401 {object} handlers.ErrorResponse
// @Failure 403 {object} handlers.ErrorResponse
// @Failure 500 {object} handlers.ErrorResponse
// @Router /api/v2/guideline-versions/{id}/upload [post]
func (h GuidelineHandler) UploadPDF(c *gin.Context) {
	versionID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		httpx.Error(c, http.StatusBadRequest, "invalid id")
		return
	}
	if err := c.Request.ParseMultipartForm(h.MaxUploadMB << 20); err != nil {
		httpx.Error(c, 400, err.Error())
		return
	}
	file, header, err := c.Request.FormFile("file")
	if err != nil {
		httpx.Error(c, 400, "file is required")
		return
	}
	defer file.Close()
	job, err := h.Service.UploadPDF(c.Request.Context(), versionID, file, header)
	if err != nil {
		httpx.Error(c, 500, "internal server error")
		return
	}
	httpx.Created(c, job)
}

// Publish godoc
// @Summary Publish a guideline version
// @Tags guidelines
// @Produce json
// @Security BearerAuth
// @Param id path string true "Guideline version ID" format(uuid)
// @Success 200 {object} handlers.PublishEnvelope
// @Failure 400 {object} handlers.ErrorResponse
// @Failure 409 {object} handlers.ErrorResponse
// @Failure 401 {object} handlers.ErrorResponse
// @Failure 403 {object} handlers.ErrorResponse
// @Router /api/v2/guideline-versions/{id}/publish [post]
func (h GuidelineHandler) Publish(c *gin.Context) {
	versionID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		httpx.Error(c, http.StatusBadRequest, "invalid id")
		return
	}
	claims := c.MustGet(middleware.ClaimsKey).(*security.Claims)
	if err := h.Service.PublishVersion(versionID, claims.UserID); err != nil {
		if errors.Is(err, services.ErrGuidelineIngestionIncomplete) || errors.Is(err, services.ErrGuidelineIngestionFailed) {
			httpx.Error(c, http.StatusConflict, err.Error())
			return
		}
		httpx.Error(c, 400, err.Error())
		return
	}
	httpx.OK(c, PublishResult{Published: true})
}

// Sections godoc
// @Summary List sections for a guideline version
// @Tags guidelines
// @Produce json
// @Security BearerAuth
// @Param id path string true "Guideline version ID" format(uuid)
// @Param page query int false "Page number" minimum(1)
// @Param per_page query int false "Page size" minimum(1) maximum(500)
// @Param limit query int false "Maximum results" minimum(1) maximum(500)
// @Param offset query int false "Offset" minimum(0)
// @Success 200 {object} handlers.PaginatedGuidelineSectionsEnvelope
// @Failure 400 {object} handlers.ErrorResponse
// @Failure 401 {object} handlers.ErrorResponse
// @Failure 403 {object} handlers.ErrorResponse
// @Failure 500 {object} handlers.ErrorResponse
// @Router /api/v2/guideline-versions/{id}/sections [get]
func (h GuidelineHandler) Sections(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		httpx.Error(c, http.StatusBadRequest, "invalid id")
		return
	}
	page, err := parsePageOrOffsetQuery(c, 100, 500)
	if err != nil {
		httpx.Error(c, http.StatusBadRequest, "invalid pagination parameters")
		return
	}
	rows, err := h.Service.Sections(id, page)
	if err != nil {
		httpx.Error(c, 500, "failed to load sections")
		return
	}
	httpx.OK(c, rows)
}

// Chunks godoc
// @Summary List chunks for a guideline version
// @Tags guidelines
// @Produce json
// @Security BearerAuth
// @Param id path string true "Guideline version ID" format(uuid)
// @Param page query int false "Page number" minimum(1)
// @Param per_page query int false "Page size" minimum(1) maximum(500)
// @Param limit query int false "Maximum results" minimum(1) maximum(500)
// @Param offset query int false "Offset" minimum(0)
// @Success 200 {object} handlers.PaginatedGuidelineChunksEnvelope
// @Failure 400 {object} handlers.ErrorResponse
// @Failure 401 {object} handlers.ErrorResponse
// @Failure 403 {object} handlers.ErrorResponse
// @Failure 500 {object} handlers.ErrorResponse
// @Router /api/v2/guideline-versions/{id}/chunks [get]
func (h GuidelineHandler) Chunks(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		httpx.Error(c, http.StatusBadRequest, "invalid id")
		return
	}
	page, err := parsePageOrOffsetQuery(c, 100, 500)
	if err != nil {
		httpx.Error(c, http.StatusBadRequest, "invalid pagination parameters")
		return
	}
	rows, err := h.Service.Chunks(id, page)
	if err != nil {
		httpx.Error(c, 500, "failed to load chunks")
		return
	}
	httpx.OK(c, rows)
}
