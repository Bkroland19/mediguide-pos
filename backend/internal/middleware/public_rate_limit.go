package middleware

import (
	"net/http"
	"strconv"
	"sync"
	"time"

	"mediguide/internal/httpx"

	"github.com/gin-gonic/gin"
)

type publicRateWindow struct {
	start time.Time
	count int
}

func PublicRateLimit(limit int, window time.Duration) gin.HandlerFunc {
	var mutex sync.Mutex
	visitors := make(map[string]publicRateWindow)

	return func(c *gin.Context) {
		now := time.Now()
		key := c.ClientIP()

		mutex.Lock()
		if len(visitors) > 10_000 {
			for visitorKey, visitor := range visitors {
				if now.Sub(visitor.start) >= window {
					delete(visitors, visitorKey)
				}
			}
		}
		entry := visitors[key]
		if entry.start.IsZero() || now.Sub(entry.start) >= window {
			entry = publicRateWindow{start: now}
		}
		entry.count++
		visitors[key] = entry
		retryAfter := window - now.Sub(entry.start)
		limited := entry.count > limit
		mutex.Unlock()

		if limited {
			c.Header("Retry-After", retryAfterSeconds(retryAfter))
			httpx.Error(c, http.StatusTooManyRequests, "rate limit exceeded")
			c.Abort()
			return
		}
		c.Next()
	}
}

func retryAfterSeconds(duration time.Duration) string {
	seconds := int(duration.Round(time.Second) / time.Second)
	if seconds < 1 {
		seconds = 1
	}
	return strconv.Itoa(seconds)
}
