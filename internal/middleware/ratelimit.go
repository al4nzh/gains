package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/time/rate"
)

type ipLimiter struct {
	limiter  *rate.Limiter
	lastSeen time.Time
}

// IPRateLimiter is a per-IP token bucket. Suitable for single-instance MVP
// deployments. Move to Redis-backed if you scale horizontally.
type IPRateLimiter struct {
	mu       sync.Mutex
	limiters map[string]*ipLimiter
	rps      rate.Limit
	burst    int
	idleTTL  time.Duration
}

func NewIPRateLimiter(rps float64, burst int) *IPRateLimiter {
	rl := &IPRateLimiter{
		limiters: make(map[string]*ipLimiter),
		rps:      rate.Limit(rps),
		burst:    burst,
		idleTTL:  10 * time.Minute,
	}
	go rl.cleanupLoop()
	return rl
}

func (r *IPRateLimiter) cleanupLoop() {
	t := time.NewTicker(time.Minute)
	defer t.Stop()
	for range t.C {
		r.mu.Lock()
		now := time.Now()
		for ip, l := range r.limiters {
			if now.Sub(l.lastSeen) > r.idleTTL {
				delete(r.limiters, ip)
			}
		}
		r.mu.Unlock()
	}
}

func (r *IPRateLimiter) get(ip string) *rate.Limiter {
	r.mu.Lock()
	defer r.mu.Unlock()
	l, ok := r.limiters[ip]
	if !ok {
		l = &ipLimiter{limiter: rate.NewLimiter(r.rps, r.burst)}
		r.limiters[ip] = l
	}
	l.lastSeen = time.Now()
	return l.limiter
}

func (r *IPRateLimiter) Middleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		if !r.get(c.ClientIP()).Allow() {
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{"error": "rate limit exceeded"})
			return
		}
		c.Next()
	}
}
