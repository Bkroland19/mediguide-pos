package handlers

import (
	"net/http"

	"mediguide/internal/httpx"
	"mediguide/internal/middleware"
	"mediguide/internal/security"
	"mediguide/internal/services"

	"github.com/gin-gonic/gin"
)

type AuthHandler struct{ Service services.AuthService }

// Register godoc
// @Summary Register a user
// @Description Create a new backend user account.
// @Tags auth
// @Accept json
// @Produce json
// @Param payload body handlers.RegisterRequest true "Registration payload"
// @Success 201 {object} handlers.UserEnvelope
// @Failure 400 {object} handlers.ErrorResponse
// @Router /api/v2/auth/register [post]
func (h AuthHandler) Register(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	u, err := h.Service.Register(services.RegisterInput(req))
	if err != nil {
		httpx.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	httpx.Created(c, u)
}

// Login godoc
// @Summary Log in a user
// @Description Authenticate a user and return a JWT bearer token.
// @Tags auth
// @Accept json
// @Produce json
// @Param payload body handlers.LoginRequest true "Login payload"
// @Success 200 {object} handlers.LoginEnvelope
// @Failure 400 {object} handlers.ErrorResponse
// @Failure 401 {object} handlers.ErrorResponse
// @Router /api/v2/auth/login [post]
func (h AuthHandler) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.Error(c, http.StatusBadRequest, err.Error())
		return
	}
	res, err := h.Service.Login(req.Email, req.Password)
	if err != nil {
		httpx.Error(c, http.StatusUnauthorized, err.Error())
		return
	}
	httpx.OK(c, res)
}

// Me godoc
// @Summary Get current user
// @Description Return the currently authenticated user.
// @Tags auth
// @Produce json
// @Security BearerAuth
// @Success 200 {object} handlers.UserEnvelope
// @Failure 404 {object} handlers.ErrorResponse
// @Failure 401 {object} handlers.ErrorResponse
// @Router /api/v2/me [get]
func (h AuthHandler) Me(c *gin.Context) {
	claims := c.MustGet(middleware.ClaimsKey).(*security.Claims)
	u, err := h.Service.Me(claims.UserID)
	if err != nil {
		httpx.Error(c, http.StatusNotFound, "user not found")
		return
	}
	httpx.OK(c, u)
}
