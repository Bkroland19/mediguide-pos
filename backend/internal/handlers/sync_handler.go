package handlers

import (
	"mediguide/internal/httpx"
	"mediguide/internal/services"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type SyncHandler struct{ Service services.SyncService }

// Manifest godoc
// @Summary Get published sync package manifest
// @Tags sync
// @Produce json
// @Security BearerAuth
// @Success 200 {object} handlers.ManifestEnvelope
// @Failure 401 {object} handlers.ErrorResponse
// @Failure 403 {object} handlers.ErrorResponse
// @Failure 500 {object} handlers.ErrorResponse
// @Router /api/v2/sync/manifest [get]
func (h SyncHandler) Manifest(c *gin.Context) {
	m, err := h.Service.Manifest()
	if err != nil {
		httpx.Error(c, 500, err.Error())
		return
	}
	httpx.OK(c, m)
}

// CreatePackage godoc
// @Summary Create a sync package record
// @Tags sync
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param payload body services.CreateSyncPackageInput true "Sync package payload"
// @Success 201 {object} handlers.SyncPackageEnvelope
// @Failure 400 {object} handlers.ErrorResponse
// @Failure 401 {object} handlers.ErrorResponse
// @Failure 403 {object} handlers.ErrorResponse
// @Router /api/v2/sync/packages [post]
func (h SyncHandler) CreatePackage(c *gin.Context) {
	var in services.CreateSyncPackageInput
	if err := c.ShouldBindJSON(&in); err != nil {
		httpx.Error(c, 400, err.Error())
		return
	}
	p, err := h.Service.CreatePackage(in)
	if err != nil {
		httpx.Error(c, 400, err.Error())
		return
	}
	httpx.Created(c, p)
}

// Download godoc
// @Summary Get a sync package download URL
// @Tags sync
// @Produce json
// @Security BearerAuth
// @Param id path string true "Sync package ID" format(uuid)
// @Success 200 {object} handlers.DownloadURLEnvelope
// @Failure 401 {object} handlers.ErrorResponse
// @Failure 403 {object} handlers.ErrorResponse
// @Failure 404 {object} handlers.ErrorResponse
// @Router /api/v2/sync/packages/{id}/download [get]
func (h SyncHandler) Download(c *gin.Context) {
	id, _ := uuid.Parse(c.Param("id"))
	u, err := h.Service.DownloadURL(c.Request.Context(), id)
	if err != nil {
		httpx.Error(c, 404, err.Error())
		return
	}
	httpx.OK(c, DownloadURLResult{URL: u})
}
