package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"mediguide/internal/middleware"
	"mediguide/internal/security"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func TestGuidelineDraftReviewRequiresExplicitReviewPermission(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(claimsForReviewTest([]string{"guideline.read"}))
	router.GET("/review/:id", middleware.RequirePermission("guideline.review"), func(c *gin.Context) { c.Status(http.StatusOK) })

	response := httptest.NewRecorder()
	router.ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/review/"+uuid.NewString(), nil))
	if response.Code != http.StatusForbidden {
		t.Fatalf("reader accessed draft review: status=%d body=%s", response.Code, response.Body.String())
	}
}

func TestGuidelineBlockApprovalRequiresHighRiskPermission(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(claimsForReviewTest([]string{"guideline.read", "guideline.write"}))
	router.POST("/review/:id/blocks/:blockId", middleware.RequirePermission("guideline.high_risk.approve"), func(c *gin.Context) { c.Status(http.StatusOK) })

	response := httptest.NewRecorder()
	router.ServeHTTP(response, httptest.NewRequest(http.MethodPost, "/review/"+uuid.NewString()+"/blocks/"+uuid.NewString(), nil))
	if response.Code != http.StatusForbidden {
		t.Fatalf("editor approved clinical content without publisher permission: status=%d body=%s", response.Code, response.Body.String())
	}
}

func TestGuidelineBulkReviewRequiresGuidelineReviewPermission(t *testing.T) {
	gin.SetMode(gin.TestMode)
	for _, test := range []struct {
		name        string
		permissions []string
		wantStatus  int
	}{
		{name: "reader rejected", permissions: []string{"guideline.read"}, wantStatus: http.StatusForbidden},
		{name: "reviewer accepted", permissions: []string{"guideline.review"}, wantStatus: http.StatusOK},
	} {
		t.Run(test.name, func(t *testing.T) {
			router := gin.New()
			router.Use(claimsForReviewTest(test.permissions))
			router.POST("/review/:id/blocks/bulk-review", middleware.RequirePermission("guideline.review"), func(c *gin.Context) { c.Status(http.StatusOK) })
			response := httptest.NewRecorder()
			router.ServeHTTP(response, httptest.NewRequest(http.MethodPost, "/review/"+uuid.NewString()+"/blocks/bulk-review", nil))
			if response.Code != test.wantStatus {
				t.Fatalf("status=%d want=%d body=%s", response.Code, test.wantStatus, response.Body.String())
			}
		})
	}
}

func TestRegenerationAcceptanceRequiresHighRiskPermission(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(claimsForReviewTest([]string{"guideline.read", "guideline.write"}))
	router.POST("/review/:id/regeneration/:jobId/accept", middleware.RequirePermission("guideline.high_risk.approve"), func(c *gin.Context) { c.Status(http.StatusOK) })

	response := httptest.NewRecorder()
	router.ServeHTTP(response, httptest.NewRequest(http.MethodPost, "/review/"+uuid.NewString()+"/regeneration/"+uuid.NewString()+"/accept", nil))
	if response.Code != http.StatusForbidden {
		t.Fatalf("editor accepted regeneration without publisher permission: status=%d body=%s", response.Code, response.Body.String())
	}
}

func claimsForReviewTest(perms []string) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Set(middleware.ClaimsKey, &security.Claims{UserID: uuid.New(), Perms: perms})
		c.Next()
	}
}
