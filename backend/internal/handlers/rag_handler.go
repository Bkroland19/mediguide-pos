package handlers

import (
	"net/http"

	"mediguide/internal/httpx"
	"mediguide/internal/middleware"
	"mediguide/internal/security"
	"mediguide/internal/services"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type RAGHandler struct{ Service services.RAGService }

// Ask godoc
// @Summary Ask the guideline assistant
// @Tags chat
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param payload body services.AskRequest true "Question payload"
// @Success 200 {object} handlers.AskEnvelope
// @Failure 400 {object} handlers.ErrorResponse
// @Failure 401 {object} handlers.ErrorResponse
// @Failure 403 {object} handlers.ErrorResponse
// @Failure 500 {object} handlers.ErrorResponse
// @Router /api/v1/chat/ask [post]
func (h RAGHandler) Ask(c *gin.Context) {
	var req services.AskRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	var uid *uuid.UUID
	if v, ok := c.Get(middleware.ClaimsKey); ok {
		id := v.(*security.Claims).UserID
		uid = &id
	}
	res, err := h.Service.Ask(uid, req)
	if err != nil {
		httpx.Error(c, 500, err.Error())
		return
	}
	httpx.OK(c, res)
}
