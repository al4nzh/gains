package auth

import (
	"fmt"
	"strings"
	"sync"

	"github.com/MicahParks/keyfunc/v3"
	"github.com/golang-jwt/jwt/v5"
)

const appleJWKSURL = "https://appleid.apple.com/auth/keys"
const appleIssuer = "https://appleid.apple.com"

var (
	appleJWKS     keyfunc.Keyfunc
	appleJWKSOnce sync.Once
	appleJWKErr   error
)

type appleClaims struct {
	Subject string
	Email   string
}

func verifyAppleIDToken(rawToken, clientID string, fallbackEmail string) (*appleClaims, error) {
	rawToken = strings.TrimSpace(rawToken)
	clientID = strings.TrimSpace(clientID)
	if rawToken == "" || clientID == "" {
		return nil, ErrInvalidOAuthToken
	}

	kf, err := getAppleJWKS()
	if err != nil {
		return nil, err
	}

	token, err := jwt.Parse(rawToken, kf.Keyfunc,
		jwt.WithIssuer(appleIssuer),
		jwt.WithAudience(clientID),
		jwt.WithValidMethods([]string{jwt.SigningMethodRS256.Alg()}),
	)
	if err != nil || !token.Valid {
		return nil, fmt.Errorf("%w: %v", ErrInvalidOAuthToken, err)
	}

	mapClaims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return nil, ErrInvalidOAuthToken
	}

	sub, _ := mapClaims["sub"].(string)
	if sub == "" {
		return nil, ErrInvalidOAuthToken
	}

	email, _ := mapClaims["email"].(string)
	email = strings.ToLower(strings.TrimSpace(email))
	if email == "" {
		email = strings.ToLower(strings.TrimSpace(fallbackEmail))
	}

	return &appleClaims{Subject: sub, Email: email}, nil
}

func getAppleJWKS() (keyfunc.Keyfunc, error) {
	appleJWKSOnce.Do(func() {
		appleJWKS, appleJWKErr = keyfunc.NewDefault([]string{appleJWKSURL})
	})
	return appleJWKS, appleJWKErr
}
