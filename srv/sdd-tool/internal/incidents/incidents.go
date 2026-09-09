// Package incidents provides an SQLite-backed repository for orchestrator-
// observed failures. Summaries are privacy-scrubbed (D3). Resolved incidents
// bind a direct Engram observation id or a fallback_path (Engram off).
// Write failures exit non-zero with a loud FAIL-OPEN marker (D2).
package incidents

import (
	"database/sql"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"sdd-tool/internal/scrub"

	_ "modernc.org/sqlite"
)

// Incident represents one recorded incident.
type Incident struct {
	ID               int        `json:"id"`
	ChangeName       string     `json:"change_name"`
	Kind             string     `json:"kind"`
	Summary          string     `json:"summary"`
	Status           string     `json:"status"`
	FallbackPath     *string    `json:"fallback_path,omitempty"`
	ResolvedEngramID *int       `json:"resolved_engram_id,omitempty"`
	ResolvedAt       *time.Time `json:"resolved_at,omitempty"`
	CreatedAt        time.Time  `json:"created_at"`
}

// Repository wraps the SQLite incidents database.
type Repository struct {
	db   *sql.DB
	path string
}

// NewRepository opens (or creates) the incidents database.
// If dbPath is empty, uses ~/.config/sdd-own/srv/sdd-tool/incidents.db.
func NewRepository(dbPath string) (*Repository, error) {
	if dbPath == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return nil, fmt.Errorf("cannot determine home: %w", err)
		}
		dbPath = filepath.Join(home, ".config", "sdd-own", "srv", "sdd-tool", "incidents.db")
	}
	os.MkdirAll(filepath.Dir(dbPath), 0o755)

	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return nil, fmt.Errorf("open incidents db: %w", err)
	}
	if err := initSchema(db); err != nil {
		db.Close()
		return nil, err
	}
	return &Repository{db: db, path: dbPath}, nil
}

func initSchema(db *sql.DB) error {
	schema := `CREATE TABLE IF NOT EXISTS incidents (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		change_name TEXT NOT NULL,
		kind TEXT NOT NULL CHECK(kind IN ('blocker','test_failure','transport','other')),
		summary TEXT NOT NULL,
		status TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open','resolved')),
		fallback_path TEXT,
		resolved_engram_id INTEGER,
		resolved_at TEXT,
		created_at TEXT NOT NULL DEFAULT (datetime('now'))
	);`
	_, err := db.Exec(schema)
	return err
}

// Record creates a new incident with a scrubbed summary.
// Returns the new incident id.
func (r *Repository) Record(changeName, summary, kind string) (int, error) {
	summary = scrub.Scrub(summary)
	res, err := r.db.Exec(
		`INSERT INTO incidents (change_name, kind, summary) VALUES (?, ?, ?)`,
		changeName, kind, summary,
	)
	if err != nil {
		return 0, fmt.Errorf("insert incident: %w", err)
	}
	id, err := res.LastInsertId()
	if err != nil {
		return 0, err
	}
	return int(id), nil
}

// Resolve marks an incident as resolved, binding a fix observation or
// fallback_path. Engram off → fallback_path, never fabricate.
func (r *Repository) Resolve(id, engramID int) error {
	now := time.Now().UTC().Format(time.RFC3339)
	if engramID > 0 {
		if err := verifyEngramID(engramID); err != nil {
			fallback := fmt.Sprintf("openspec/changes/*/retrospective.md (engram-id %d not verified)", engramID)
			_, err := r.db.Exec(
				`UPDATE incidents SET status='resolved', fallback_path=?, resolved_at=? WHERE id=?`,
				fallback, now, id,
			)
			return err
		}
		_, err := r.db.Exec(
			`UPDATE incidents SET status='resolved', resolved_engram_id=?, resolved_at=? WHERE id=?`,
			engramID, now, id,
		)
		return err
	}
	_, err := r.db.Exec(
		`UPDATE incidents SET status='resolved', fallback_path='openspec/changes/*/retrospective.md', resolved_at=? WHERE id=?`,
		now, id,
	)
	return err
}

// List returns all incidents.
func (r *Repository) List() ([]Incident, error) {
	rows, err := r.db.Query(
		`SELECT id, change_name, kind, summary, status, fallback_path, resolved_engram_id, resolved_at, created_at
		 FROM incidents ORDER BY id DESC`,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var incidents []Incident
	for rows.Next() {
		var inc Incident
		var resolvedAtStr sql.NullString
		var fallbackPath sql.NullString
		var resolvedEngramID sql.NullInt64
		var createdAtStr string
		err := rows.Scan(
			&inc.ID, &inc.ChangeName, &inc.Kind, &inc.Summary, &inc.Status,
			&fallbackPath, &resolvedEngramID, &resolvedAtStr, &createdAtStr,
		)
		if err != nil {
			return nil, err
		}
		if t, err := time.Parse("2006-01-02 15:04:05", createdAtStr); err == nil {
			inc.CreatedAt = t
		} else if t, err := time.Parse(time.RFC3339, createdAtStr); err == nil {
			inc.CreatedAt = t
		}
		if fallbackPath.Valid {
			inc.FallbackPath = &fallbackPath.String
		}
		if resolvedEngramID.Valid {
			id := int(resolvedEngramID.Int64)
			inc.ResolvedEngramID = &id
		}
		if resolvedAtStr.Valid {
			t, err := time.Parse(time.RFC3339, resolvedAtStr.String)
			if err == nil {
				inc.ResolvedAt = &t
			}
		}
		incidents = append(incidents, inc)
	}
	return incidents, nil
}

// verifyEngramID checks if an Engram observation id exists via subprocess.
func verifyEngramID(id int) error {
	out, err := exec.Command("engram", "timeline", fmt.Sprintf("%d", id)).CombinedOutput()
	if err != nil {
		return fmt.Errorf("engram timeline %d: %s: %w", id, string(out), err)
	}
	return nil
}
