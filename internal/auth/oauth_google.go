package auth

import (
	"context"
	"fmt"
	"strings"

	"google.golang.org/api/idtoken"
)

type googleClaims struct {
	Subject string
	Email   string
}

func verifyGoogleIDToken(ctx context.Context, rawToken string, audiences []string) (*googleClaims, error) {
	rawToken = strings.TrimSpace(rawToken)
	if rawToken == "" {
		return nil, ErrInvalidOAuthToken
	}
	if len(audiences) == 0 {
		return nil, ErrOAuthNotConfigured
	}

	var payload *idtoken.Payload
	var err error
	for _, aud := range audiences {
		payload, err = idtoken.Validate(ctx, rawToken, aud)
		if err == nil {
			break
		}
	}
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrInvalidOAuthToken, err)
	}

	email, _ := payload.Claims["email"].(string)
	emailVerified, _ := payload.Claims["email_verified"].(bool)
	if email == "" || !emailVerified {
		return nil, ErrInvalidOAuthToken
	}

	return &googleClaims{
		Subject: payload.Subject,
		Email:   strings.ToLower(strings.TrimSpace(email)),
	}, nil
}
