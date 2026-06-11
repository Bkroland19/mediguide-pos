package handlers

import (
	"strconv"
	"strings"

	"mediguide/internal/services"

	"github.com/gin-gonic/gin"
)

func parsePageQuery(c *gin.Context, defaultPerPage, maxPerPage int) (services.PageInput, error) {
	page, err := intQueryWithFallback(c, "page", 1)
	if err != nil {
		return services.PageInput{}, err
	}

	perPage, err := intQueryAnyWithFallback(c, []string{"per_page", "perPage"}, defaultPerPage)
	if err != nil {
		return services.PageInput{}, err
	}

	return services.PageInput{
		Page:    page,
		PerPage: perPage,
	}.Normalize(defaultPerPage, maxPerPage), nil
}

func parsePageOrOffsetQuery(c *gin.Context, defaultPerPage, maxPerPage int) (services.PageInput, error) {
	if strings.TrimSpace(c.Query("page")) != "" ||
		strings.TrimSpace(c.Query("per_page")) != "" ||
		strings.TrimSpace(c.Query("perPage")) != "" {
		return parsePageQuery(c, defaultPerPage, maxPerPage)
	}

	limit, err := intQueryWithFallback(c, "limit", defaultPerPage)
	if err != nil {
		return services.PageInput{}, err
	}
	offset, err := intQueryWithFallback(c, "offset", 0)
	if err != nil {
		return services.PageInput{}, err
	}

	normalized := services.PageInput{Page: 1, PerPage: limit}.Normalize(defaultPerPage, maxPerPage)
	if offset < 0 {
		offset = 0
	}

	return services.PageInput{
		Page:    (offset / normalized.PerPage) + 1,
		PerPage: normalized.PerPage,
	}, nil
}

func intQueryWithFallback(c *gin.Context, key string, fallback int) (int, error) {
	raw := strings.TrimSpace(c.Query(key))
	if raw == "" {
		return fallback, nil
	}
	return strconv.Atoi(raw)
}

func intQueryAnyWithFallback(c *gin.Context, keys []string, fallback int) (int, error) {
	for _, key := range keys {
		if strings.TrimSpace(c.Query(key)) == "" {
			continue
		}
		return intQueryWithFallback(c, key, fallback)
	}
	return fallback, nil
}
