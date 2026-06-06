package auth

import "gainsai/internal/user"

// oauthLinkConflict reports whether OAuth sign-in may attach to an existing user by email.
// Email/password accounts must sign in with password first — never auto-link from OAuth alone.
func oauthLinkConflict(existingProvider, oauthProvider string) error {
	if existingProvider == user.AuthProviderEmail {
		return ErrOAuthEmailConflict
	}
	if existingProvider != oauthProvider {
		return ErrOAuthEmailConflict
	}
	return nil
}
