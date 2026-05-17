package routine

import (
	"context"
	"errors"
	"strings"
	"unicode/utf8"

	"github.com/jackc/pgx/v5/pgconn"
)

const (
	maxRoutineNameLen        = 200
	maxRoutineDescLen      = 5000
	maxRoutineExerciseNotes = 2000
)

type Service struct {
	repo *Repository
}

func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

func (s *Service) CreateRoutine(ctx context.Context, userID, name string, description *string) (*Routine, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		name = "Untitled routine"
	}
	if utf8.RuneCountInString(name) > maxRoutineNameLen {
		return nil, errors.New("name too long")
	}
	if description != nil {
		*description = strings.TrimSpace(*description)
		if *description == "" {
			description = nil
		} else if utf8.RuneCountInString(*description) > maxRoutineDescLen {
			return nil, errors.New("description too long")
		}
	}
	return s.repo.CreateRoutine(ctx, userID, name, description)
}

func (s *Service) ListMyRoutines(ctx context.Context, userID string) ([]Routine, error) {
	return s.repo.ListRoutinesByUser(ctx, userID)
}

func (s *Service) GetRoutineDetail(ctx context.Context, userID, routineID string) (*Routine, error) {
	r, err := s.repo.GetRoutineForUser(ctx, userID, routineID)
	if err != nil {
		return nil, err
	}
	ex, err := s.repo.ListRoutineExercises(ctx, routineID)
	if err != nil {
		return nil, err
	}
	if ex == nil {
		ex = []RoutineExerciseOut{}
	}
	r.Exercises = ex
	return r, nil
}

func (s *Service) UpdateRoutine(ctx context.Context, userID, routineID string, name *string, description *string) (*Routine, error) {
	cur, err := s.repo.GetRoutineForUser(ctx, userID, routineID)
	if err != nil {
		return nil, err
	}
	newName := cur.Name
	if name != nil {
		t := strings.TrimSpace(*name)
		if t == "" {
			return nil, errors.New("name cannot be empty")
		}
		if utf8.RuneCountInString(t) > maxRoutineNameLen {
			return nil, errors.New("name too long")
		}
		newName = t
	}
	var newDesc *string
	if description != nil {
		t := strings.TrimSpace(*description)
		if t == "" {
			newDesc = nil
		} else {
			if utf8.RuneCountInString(t) > maxRoutineDescLen {
				return nil, errors.New("description too long")
			}
			newDesc = &t
		}
	} else {
		newDesc = cur.Description
	}
	if err := s.repo.UpdateRoutineMeta(ctx, userID, routineID, newName, newDesc); err != nil {
		return nil, err
	}
	return s.repo.GetRoutineForUser(ctx, userID, routineID)
}

type AddRoutineExerciseInput struct {
	ExerciseID   string
	TargetSets   *int
	TargetRepMin *int
	TargetRepMax *int
	TargetRPE    *float64
	RestSeconds  *int
	Notes        *string
	Position     *int
}

func (s *Service) AddRoutineExercise(ctx context.Context, userID, routineID string, in AddRoutineExerciseInput) (*RoutineExerciseOut, error) {
	if _, err := s.repo.GetRoutineForUser(ctx, userID, routineID); err != nil {
		return nil, err
	}
	in.ExerciseID = strings.TrimSpace(in.ExerciseID)
	if in.ExerciseID == "" {
		return nil, errors.New("exercise_id is required")
	}
	if err := validateRepRange(in.TargetRepMin, in.TargetRepMax); err != nil {
		return nil, err
	}
	if in.Notes != nil {
		t := strings.TrimSpace(*in.Notes)
		if t == "" {
			in.Notes = nil
		} else {
			if utf8.RuneCountInString(t) > maxRoutineExerciseNotes {
				return nil, errors.New("notes too long")
			}
			in.Notes = &t
		}
	}
	ok, err := s.repo.ExerciseExists(ctx, in.ExerciseID)
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, ErrExerciseNotFound
	}
	out, err := s.repo.AddRoutineExercise(ctx, routineID, in.ExerciseID, in.TargetSets, in.TargetRepMin, in.TargetRepMax, in.RestSeconds, in.TargetRPE, in.Notes, in.Position)
	if err != nil {
		if isFKViolation(err) {
			return nil, ErrExerciseNotFound
		}
		return nil, err
	}
	return out, nil
}

type UpdateRoutineExerciseInput struct {
	TargetSets   *int
	TargetRepMin *int
	TargetRepMax *int
	TargetRPE    *float64
	RestSeconds  *int
	Notes        *string
	ClearNotes   bool
	Position     *int
}

func (s *Service) UpdateRoutineExercise(ctx context.Context, userID, routineID, rowID string, in UpdateRoutineExerciseInput) (*RoutineExerciseOut, error) {
	if _, err := s.repo.GetRoutineForUser(ctx, userID, routineID); err != nil {
		return nil, err
	}
	if err := validateRepRange(in.TargetRepMin, in.TargetRepMax); err != nil {
		return nil, err
	}
	if in.Notes != nil {
		t := strings.TrimSpace(*in.Notes)
		if t == "" {
			in.ClearNotes = true
			in.Notes = nil
		} else {
			if utf8.RuneCountInString(t) > maxRoutineExerciseNotes {
				return nil, errors.New("notes too long")
			}
			in.Notes = &t
		}
	}
	p := patchRoutineExercise{
		TargetSets:  in.TargetSets,
		RepMin:      in.TargetRepMin,
		RepMax:      in.TargetRepMax,
		TargetRPE:   in.TargetRPE,
		RestSeconds: in.RestSeconds,
		Notes:       in.Notes,
		ClearNotes:  in.ClearNotes,
		Position:    in.Position,
	}
	return s.repo.UpdateRoutineExercise(ctx, routineID, rowID, p)
}

func (s *Service) DeleteRoutineExercise(ctx context.Context, userID, routineID, rowID string) error {
	return s.repo.DeleteRoutineExercise(ctx, userID, routineID, rowID)
}

func (s *Service) ReplaceRoutineExercise(ctx context.Context, userID, routineID, rowID, newExerciseID string) (*RoutineExerciseOut, error) {
	return s.repo.ReplaceRoutineExercise(ctx, userID, routineID, rowID, newExerciseID)
}

func (s *Service) ListTemplates(ctx context.Context) ([]RoutineTemplate, error) {
	return s.repo.ListRoutineTemplates(ctx)
}

func (s *Service) GetTemplateDetail(ctx context.Context, templateID string) (*RoutineTemplate, error) {
	t, err := s.repo.GetRoutineTemplate(ctx, templateID)
	if err != nil {
		return nil, err
	}
	ex, err := s.repo.ListTemplateExercises(ctx, templateID)
	if err != nil {
		return nil, err
	}
	if ex == nil {
		ex = []RoutineTemplateExerciseOut{}
	}
	t.Exercises = ex
	t.ExerciseCount = len(ex)
	return t, nil
}

func (s *Service) CopyTemplate(ctx context.Context, userID, templateID string, nameOverride *string) (*Routine, error) {
	var override string
	if nameOverride != nil {
		override = strings.TrimSpace(*nameOverride)
		if utf8.RuneCountInString(override) > maxRoutineNameLen {
			return nil, errors.New("name too long")
		}
	}
	return s.repo.CopyTemplateToUserRoutine(ctx, userID, templateID, override)
}

func validateRepRange(min, max *int) error {
	if min == nil || max == nil {
		return nil
	}
	if *min < 0 || *max < 0 {
		return errors.New("rep range must be non-negative")
	}
	if *min > *max {
		return errors.New("target_rep_min cannot exceed target_rep_max")
	}
	return nil
}

func isFKViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23503"
}
