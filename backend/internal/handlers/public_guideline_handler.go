package handlers

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"time"

	"mediguide/internal/httpx"
	"mediguide/internal/services"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type PublicGuidelineReader interface {
	List(context.Context, services.PublicGuidelineFilter) (*services.PageResult[services.PublicGuideline], error)
	Get(context.Context, uuid.UUID) (*services.PublicGuideline, error)
	Markdown(context.Context, uuid.UUID) (*services.PublicGuidelineMarkdown, error)
}

type PublicGuidelineHandler struct {
	Service PublicGuidelineReader
}

func (h PublicGuidelineHandler) List(c *gin.Context) {
	page, err := parsePageQuery(c, 20, 100)
	if err != nil {
		httpx.Error(c, http.StatusBadRequest, "invalid pagination")
		return
	}
	filter := services.PublicGuidelineFilter{
		Search:      c.Query("search"),
		ProgramArea: c.Query("program_area"),
		Country:     c.Query("country"),
		Language:    c.Query("language"),
		Page:        page,
	}
	if value := strings.TrimSpace(c.Query("updated_from")); value != "" {
		updatedFrom, parseErr := time.Parse(time.RFC3339, value)
		if parseErr != nil {
			httpx.Error(c, http.StatusBadRequest, "invalid updated_from")
			return
		}
		filter.UpdatedFrom = &updatedFrom
	}

	result, err := h.Service.List(c.Request.Context(), filter)
	if err != nil {
		httpx.Error(c, http.StatusInternalServerError, "unable to load guidelines")
		return
	}
	httpx.OK(c, result)
}

func (h PublicGuidelineHandler) Get(c *gin.Context) {
	id, ok := publicGuidelineID(c)
	if !ok {
		return
	}
	result, err := h.Service.Get(c.Request.Context(), id)
	if err != nil {
		publicGuidelineError(c, err)
		return
	}
	httpx.OK(c, result)
}

func (h PublicGuidelineHandler) Markdown(c *gin.Context) {
	id, ok := publicGuidelineID(c)
	if !ok {
		return
	}
	result, err := h.Service.Markdown(c.Request.Context(), id)
	if err != nil {
		publicGuidelineError(c, err)
		return
	}

	c.Header("Content-Type", "text/markdown; charset=utf-8")
	c.Header("Content-Disposition", `inline; filename="`+result.Filename+`"`)
	c.Header("Cache-Control", "public, max-age=300, stale-while-revalidate=86400")
	c.Header("ETag", result.ETag)
	if !result.LastModified.IsZero() {
		c.Header("Last-Modified", result.LastModified.Format(http.TimeFormat))
	}
	if etagMatches(c.GetHeader("If-None-Match"), result.ETag) {
		c.Status(http.StatusNotModified)
		return
	}
	c.Data(http.StatusOK, "text/markdown; charset=utf-8", result.Content)
}

func publicGuidelineID(c *gin.Context) (uuid.UUID, bool) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		httpx.Error(c, http.StatusNotFound, "guideline not found")
		return uuid.Nil, false
	}
	return id, true
}

func publicGuidelineError(c *gin.Context, err error) {
	if errors.Is(err, services.ErrPublicGuidelineNotFound) {
		httpx.Error(c, http.StatusNotFound, "guideline not found")
		return
	}
	httpx.Error(c, http.StatusInternalServerError, "unable to load guideline")
}

func etagMatches(header, current string) bool {
	for _, candidate := range strings.Split(header, ",") {
		value := strings.TrimSpace(candidate)
		if value == "*" || value == current || strings.TrimPrefix(value, "W/") == current {
			return true
		}
	}
	return false
}
