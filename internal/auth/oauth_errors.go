package auth

import "errors"

var (
	ErrOAuthNotConfigured   = errors.New("oauth provider is not configured")
	ErrInvalidOAuthToken    = errors.New("invalid oauth token")
	ErrOAuthEmailConflict   = errors.New("email already registered with a different sign-in method")
	ErrOAuthEmailRequired   = errors.New("email is required for first-time apple sign-in")
)
