package handlers

import (
	"net/http"

	"mediguide/internal/httpx"
	"mediguide/internal/services"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type ProtocolHandler struct{ Service services.ProtocolService }

// Create godoc
// @Summary Create a clinical protocol
// @Tags protocols
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param payload body services.CreateProtocolInput true "Protocol payload"
// @Success 201 {object} handlers.ClinicalProtocolEnvelope
// @Failure 400 {object} handlers.ErrorResponse
// @Failure 401 {object} handlers.ErrorResponse
// @Failure 403 {object} handlers.ErrorResponse
// @Router /api/v2/protocols [post]
func (h ProtocolHandler) Create(c *gin.Context) {
	var in services.CreateProtocolInput
	if err := c.ShouldBindJSON(&in); err != nil {
		httpx.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	p, err := h.Service.Create(in)
	if err != nil {
		httpx.Error(c, 400, err.Error())
		return
	}
	httpx.Created(c, p)
}

// List godoc
// @Summary List clinical protocols
// @Tags protocols
// @Produce json
// @Security BearerAuth
// @Success 200 {object} handlers.ClinicalProtocolsEnvelope
// @Failure 401 {object} handlers.ErrorResponse
// @Failure 403 {object} handlers.ErrorResponse
// @Failure 500 {object} handlers.ErrorResponse
// @Router /api/v2/protocols [get]
func (h ProtocolHandler) List(c *gin.Context) {
	rows, err := h.Service.List()
	if err != nil {
		httpx.Error(c, 500, err.Error())
		return
	}
	httpx.OK(c, rows)
}

// Get godoc
// @Summary Get a clinical protocol
// @Tags protocols
// @Produce json
// @Security BearerAuth
// @Param id path string true "Protocol ID" format(uuid)
// @Success 200 {object} handlers.ClinicalProtocolEnvelope
// @Failure 401 {object} handlers.ErrorResponse
// @Failure 403 {object} handlers.ErrorResponse
// @Failure 404 {object} handlers.ErrorResponse
// @Router /api/v2/protocols/{id} [get]
func (h ProtocolHandler) Get(c *gin.Context) {
	id, _ := uuid.Parse(c.Param("id"))
	p, err := h.Service.Get(id)
	if err != nil {
		httpx.Error(c, 404, "not found")
		return
	}
	httpx.OK(c, p)
}

// Run godoc
// @Summary Run a clinical protocol
// @Tags protocols
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param id path string true "Protocol ID" format(uuid)
// @Param payload body handlers.JSONMap true "Protocol input payload"
// @Success 200 {object} handlers.ProtocolRunEnvelope
// @Failure 400 {object} handlers.ErrorResponse
// @Failure 401 {object} handlers.ErrorResponse
// @Failure 403 {object} handlers.ErrorResponse
// @Router /api/v2/protocols/{id}/run [post]
func (h ProtocolHandler) Run(c *gin.Context) {
	id, _ := uuid.Parse(c.Param("id"))
	var input JSONMap
	if err := c.ShouldBindJSON(&input); err != nil {
		httpx.Error(c, 400, err.Error())
		return
	}
	out, err := h.Service.Run(id, map[string]any(input))
	if err != nil {
		httpx.Error(c, 400, err.Error())
		return
	}
	httpx.OK(c, out)
}
