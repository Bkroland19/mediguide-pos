package security

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

type Claims struct {
	UserID    uuid.UUID `json:"user_id"`
	SessionID string    `json:"sid,omitempty"`
	Email     string    `json:"email"`
	Roles     []string  `json:"roles"`
	Perms     []string  `json:"perms"`
	jwt.RegisteredClaims
}

func GenerateJWT(secret, issuer string, ttlMinutes int, userID, sessionID uuid.UUID, email string, roles, perms []string) (string, error) {
	now := time.Now()
	claims := Claims{
		UserID:    userID,
		SessionID: sessionID.String(),
		Email:     email,
		Roles:     roles,
		Perms:     perms,
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    issuer,
			Subject:   userID.String(),
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(time.Duration(ttlMinutes) * time.Minute)),
		},
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(secret))
}

func ParseJWT(secret, tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return []byte(secret), nil
	})
	if err != nil {
		return nil, err
	}
	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, errors.New("invalid token")
	}
	return claims, nil
}

func HasPerm(claims *Claims, perm string) bool {
	for _, p := range claims.Perms {
		if p == perm || p == "admin.all" || p == "*" {
			return true
		}
	}
	return false
}
