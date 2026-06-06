package auth

import (
	"testing"
	"time"

	"gainsai/internal/user"
)

func TestEmailAccountNeedsVerification(t *testing.T) {
	verified := time.Now()
	tests := []struct {
		name string
		u    *user.User
		want bool
	}{
		{"nil", nil, false},
		{"google", &user.User{AuthProvider: user.AuthProviderGoogle}, false},
		{"email unverified", &user.User{AuthProvider: user.AuthProviderEmail}, true},
		{"email verified", &user.User{AuthProvider: user.AuthProviderEmail, EmailVerifiedAt: &verified}, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := emailAccountNeedsVerification(tt.u); got != tt.want {
				t.Fatalf("got %v want %v", got, tt.want)
			}
		})
	}
}
