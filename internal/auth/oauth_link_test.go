package auth

import (
	"errors"
	"testing"

	"gainsai/internal/user"
)

func TestOAuthLinkConflict(t *testing.T) {
	tests := []struct {
		existing, oauth string
		wantErr         error
	}{
		{user.AuthProviderEmail, user.AuthProviderGoogle, ErrOAuthEmailConflict},
		{user.AuthProviderEmail, user.AuthProviderApple, ErrOAuthEmailConflict},
		{user.AuthProviderGoogle, user.AuthProviderApple, ErrOAuthEmailConflict},
		{user.AuthProviderApple, user.AuthProviderGoogle, ErrOAuthEmailConflict},
		{user.AuthProviderGoogle, user.AuthProviderGoogle, nil},
		{user.AuthProviderApple, user.AuthProviderApple, nil},
	}
	for _, tt := range tests {
		err := oauthLinkConflict(tt.existing, tt.oauth)
		if tt.wantErr == nil && err != nil {
			t.Fatalf("%s + %s: unexpected %v", tt.existing, tt.oauth, err)
		}
		if tt.wantErr != nil && !errors.Is(err, tt.wantErr) {
			t.Fatalf("%s + %s: got %v want %v", tt.existing, tt.oauth, err, tt.wantErr)
		}
	}
}
