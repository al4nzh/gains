package user

import "time"

const (
	AuthProviderEmail  = "email"
	AuthProviderGoogle = "google"
	AuthProviderApple  = "apple"
)

type User struct {
	ID              string     `json:"id"           db:"id"`
	Email           string     `json:"email"        db:"email"`
	PasswordHash    *string    `json:"-"            db:"password_hash"`
	AuthProvider    string     `json:"auth_provider" db:"auth_provider"`
	EmailVerifiedAt *time.Time `json:"email_verified_at,omitempty" db:"email_verified_at"`
	CreatedAt       time.Time  `json:"created_at"   db:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"   db:"updated_at"`
}

func (u *User) EmailVerified() bool {
	return u.EmailVerifiedAt != nil
}
