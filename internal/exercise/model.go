package exercise

import "time"

type Exercise struct {
	ID          string    `json:"id"           db:"id"`
	Name        string    `json:"name"         db:"name"`
	MuscleGroup *string   `json:"muscle_group,omitempty" db:"muscle_group"`
	Equipment   *string   `json:"equipment,omitempty"    db:"equipment"`
	IsCustom    bool      `json:"is_custom"    db:"is_custom"`
	CreatedBy   *string   `json:"created_by,omitempty" db:"created_by"`
	CreatedAt   time.Time `json:"created_at"   db:"created_at"`
}
