# Exercise catalog & ExerciseDB

Gains ships a **system catalog** (`migrations/000004_seed_exercises.up.sql` plus expansions like `000024_expand_seed_exercises.up.sql`) used in routines, workouts, strength benchmarks, and adaptive rules. Demo GIFs come from the free [ExerciseDB OSS API](https://oss.exercisedb.dev) via `POST /exercises/gifs`.

## How GIF matching works

1. **Static overrides** — `internal/exercisedb/catalog_gifs.go` for very short/ambiguous names (`Dip`, `Curls`).
2. **Alias names** — `catalogAliasNames` maps catalog labels to ExerciseDB exercise titles (e.g. `Bench Press` → `barbell bench press`).
3. **Full index** — On first GIF lookup, the API downloads the ~1,500 ExerciseDB entries once (cursor pagination, cached in memory) and matches by **exact normalized title**, then equipment-aware scoring.

Custom user exercises are not in the seed list; matching is best-effort only.

## Catalog vs ExerciseDB (no naming collision)

| Topic | Approach |
|--------|----------|
| **Your DB** | `exercises` table: display names for lifters (`OHP`, `Incline DB Press`). |
| **ExerciseDB** | Separate dataset; we never import or merge their rows into Postgres. |
| **Link** | Runtime lookup only (GIF URL), not a foreign key. |

## Duplicates removed (migration `000020`)

These pairs were redundant and caused duplicate GIFs / fuzzy mismatches:

| Removed | Kept | Why |
|---------|------|-----|
| `Overhead Press` | `OHP` | Same barbell shoulder press; Elo/adaptive already treat `ohp` as benchmark. |
| `Row` | `Cable Row` | Same cable row demo; `Row` was too vague for search. |

Existing routines/workouts/history are **repointed** to the kept exercise id, then the duplicate row is deleted.

Fresh installs from `000004` no longer insert the removed names.

## Env

No API key for OSS ExerciseDB. Optional: `EXERCISEDB_ENABLED=false` to disable GIFs.

## Verify locally

```bash
VERIFY_EXERCISEDB=1 go test ./internal/exercisedb -run TestVerifyGainsCatalogAgainstExerciseDB -v
```

Run `go run ./cmd/migrate up` to apply `000020` on existing databases.
