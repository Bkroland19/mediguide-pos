package handlers

import (
	"net/http"
	"strings"
	"time"

	"mediguide/internal/config"
	"mediguide/internal/security"
	"mediguide/internal/services"

	"github.com/gin-gonic/gin"
)

type LegacyAPIHandler struct {
	Service services.LegacyAPIService
	Cfg     config.Config
}

func (h LegacyAPIHandler) ConsultantsTree(c *gin.Context) {
	level, filters := services.ParseTreeRequest(c.Query("level"), c.Query("filters"), 2, []string{"region", "city", "specialty", "status", "verified"})
	result, err := h.Service.ConsultantsTree(level, filters)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to load consultants tree"})
		return
	}
	c.JSON(http.StatusOK, result)
}

func (h LegacyAPIHandler) HealthFacilitiesTree(c *gin.Context) {
	level, filters := services.ParseTreeRequest(c.Query("level"), c.Query("filters"), 2, []string{"region", "district", "facility_level"})
	result, err := h.Service.HealthFacilitiesTree(level, filters)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to load health facilities tree"})
		return
	}
	c.JSON(http.StatusOK, result)
}

func (h LegacyAPIHandler) MinistryDirectoryTree(c *gin.Context) {
	level, filters := services.ParseTreeRequest(c.Query("level"), c.Query("filters"), 2, []string{"region", "district", "ministry", "department", "status"})
	result, err := h.Service.MinistryDirectoryTree(level, filters)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to load ministry directory tree"})
		return
	}
	c.JSON(http.StatusOK, result)
}

func (h LegacyAPIHandler) Overview(c *gin.Context) {
	result, err := h.Service.Overview()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success":   false,
			"error":     "Failed to fetch overview data",
			"cached_at": time.Now().UTC().Format(time.RFC3339),
		})
		return
	}
	c.JSON(http.StatusOK, result)
}

func (h LegacyAPIHandler) Stats(c *gin.Context) {
	userID := ""
	if claims := h.optionalClaims(c.GetHeader("Authorization")); claims != nil {
		userID = claims.UserID.String()
	}
	result, err := h.Service.Stats(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success":   false,
			"error":     "Failed to fetch statistics",
			"cached_at": time.Now().UTC().Format(time.RFC3339),
		})
		return
	}
	c.JSON(http.StatusOK, result)
}

func (h LegacyAPIHandler) optionalClaims(header string) *security.Claims {
	if header == "" || !strings.HasPrefix(header, "Bearer ") {
		return nil
	}
	claims, err := security.ParseJWT(h.Cfg.JWTSecret, strings.TrimPrefix(header, "Bearer "))
	if err != nil {
		return nil
	}
	return claims
}
