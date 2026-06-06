package aiquota

import "errors"

var (
	ErrPremiumRequired     = errors.New("premium subscription required for AI features")
	ErrDailyQuotaExceeded  = errors.New("daily AI usage limit reached")
)
