package swaggerui

import (
	"net/http"
	"os"
	"path/filepath"

	"github.com/gin-gonic/gin"
)

func Register(r gin.IRoutes) {
	r.GET("/swagger", func(c *gin.Context) {
		c.Redirect(http.StatusMovedPermanently, "/swagger/")
	})
	r.GET("/swagger/", func(c *gin.Context) {
		data, err := os.ReadFile(filepath.Join("docs", "swagger.html"))
		if err != nil {
			c.String(http.StatusInternalServerError, "swagger ui unavailable")
			return
		}
		c.Data(http.StatusOK, "text/html; charset=utf-8", data)
	})
	r.GET("/swagger/doc.json", func(c *gin.Context) {
		data, err := os.ReadFile(filepath.Join("docs", "swagger.json"))
		if err != nil {
			c.String(http.StatusInternalServerError, "swagger doc unavailable")
			return
		}
		c.Data(http.StatusOK, "application/json; charset=utf-8", data)
	})
}
