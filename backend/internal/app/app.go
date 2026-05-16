package app

import (
	"net/http"

	"mediguide/internal/config"
	"mediguide/internal/db"
	"mediguide/internal/handlers"
	"mediguide/internal/middleware"
	"mediguide/internal/services"
	"mediguide/internal/storage"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"
)

type App struct {
	Router *gin.Engine
	DB     *gorm.DB
}

func New(cfg config.Config) (*App, error) {
	database, err := db.Connect(cfg.DatabaseURL)
	if err != nil {
		return nil, err
	}
	store, err := storage.NewMinioStore(cfg)
	if err != nil {
		return nil, err
	}

	r := gin.New()
	r.Use(gin.Recovery(), middleware.RequestLogger())
	r.Use(cors.New(cors.Config{AllowOrigins: []string{"*"}, AllowHeaders: []string{"Authorization", "Content-Type"}, AllowMethods: []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"}}))

	r.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))

	r.GET("/api/healthz", func(c *gin.Context) { c.JSON(http.StatusOK, gin.H{"ok": true, "service": cfg.AppName}) })

	authSvc := services.AuthService{DB: database, Cfg: cfg}
	guidelineSvc := services.GuidelineService{DB: database, Store: store}
	searchSvc := services.SearchService{DB: database}
	ragSvc := services.RAGService{DB: database, Search: searchSvc, Cfg: cfg}
	protocolSvc := services.ProtocolService{DB: database}
	syncSvc := services.SyncService{DB: database, Store: store, Cfg: cfg}

	authH := handlers.AuthHandler{Service: authSvc}
	guidelineH := handlers.GuidelineHandler{Service: guidelineSvc, MaxUploadMB: cfg.MaxUploadMB}
	searchH := handlers.SearchHandler{Service: searchSvc}
	ragH := handlers.RAGHandler{Service: ragSvc}
	protocolH := handlers.ProtocolHandler{Service: protocolSvc}
	syncH := handlers.SyncHandler{Service: syncSvc}

	v1 := r.Group("/api/v1")
	{
		v1.POST("/auth/register", authH.Register)
		v1.POST("/auth/login", authH.Login)
		protected := v1.Group("")
		protected.Use(middleware.AuthRequired(cfg))
		protected.GET("/me", authH.Me)

		protected.POST("/guidelines", middleware.RequirePermission("guideline.write"), guidelineH.Create)
		protected.GET("/guidelines", middleware.RequirePermission("guideline.read"), guidelineH.List)
		protected.GET("/guidelines/:id", middleware.RequirePermission("guideline.read"), guidelineH.Get)
		protected.POST("/guidelines/:id/versions", middleware.RequirePermission("guideline.write"), guidelineH.CreateVersion)
		protected.POST("/guideline-versions/:id/upload", middleware.RequirePermission("guideline.write"), guidelineH.UploadPDF)
		protected.POST("/guideline-versions/:id/publish", middleware.RequirePermission("guideline.publish"), guidelineH.Publish)
		protected.GET("/guideline-versions/:id/sections", middleware.RequirePermission("guideline.read"), guidelineH.Sections)
		protected.GET("/guideline-versions/:id/chunks", middleware.RequirePermission("guideline.read"), guidelineH.Chunks)

		protected.GET("/search", middleware.RequirePermission("guideline.read"), searchH.Search)
		protected.POST("/chat/ask", middleware.RequirePermission("chat.ask"), ragH.Ask)

		protected.POST("/protocols", middleware.RequirePermission("protocol.write"), protocolH.Create)
		protected.GET("/protocols", middleware.RequirePermission("protocol.read"), protocolH.List)
		protected.GET("/protocols/:id", middleware.RequirePermission("protocol.read"), protocolH.Get)
		protected.POST("/protocols/:id/run", middleware.RequirePermission("protocol.read"), protocolH.Run)

		protected.GET("/sync/manifest", middleware.RequirePermission("sync.read"), syncH.Manifest)
		protected.POST("/sync/packages", middleware.RequirePermission("admin.all"), syncH.CreatePackage)
		protected.GET("/sync/packages/:id/download", middleware.RequirePermission("sync.read"), syncH.Download)
	}
	return &App{Router: r, DB: database}, nil
}
