package auth

import (
	"testing"

	"github.com/golang-jwt/jwt/v5"
)

func TestAppleEmailVerified(t *testing.T) {
	if !appleEmailVerified(jwt.MapClaims{"email_verified": true}) {
		t.Fatal("expected true bool")
	}
	if !appleEmailVerified(jwt.MapClaims{"email_verified": "true"}) {
		t.Fatal("expected true string")
	}
	if appleEmailVerified(jwt.MapClaims{"email_verified": false}) {
		t.Fatal("expected false bool")
	}
	if appleEmailVerified(jwt.MapClaims{}) {
		t.Fatal("expected false when missing")
	}
}
