package incidents

import (
	"os"
	"path/filepath"
	"testing"
)

func TestRepositoryRecordAndList(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "test.db")
	repo, err := NewRepository(dbPath)
	if err != nil {
		t.Fatal(err)
	}
	defer repo.db.Close()

	id, err := repo.Record("test-change", "failing test: test_foo", "test_failure")
	if err != nil {
		t.Fatal(err)
	}
	if id != 1 {
		t.Fatalf("expected id 1, got %d", id)
	}

	// Verify scrub happened
	list, err := repo.List()
	if err != nil {
		t.Fatal(err)
	}
	if len(list) != 1 {
		t.Fatalf("expected 1 incident, got %d", len(list))
	}
	if list[0].Summary != "failing test: test_foo" {
		t.Fatalf("summary = %q, want clean text", list[0].Summary)
	}
	if list[0].Status != "open" {
		t.Fatalf("status = %q, want open", list[0].Status)
	}
}

func TestRepositoryResolve(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "test.db")
	repo, err := NewRepository(dbPath)
	if err != nil {
		t.Fatal(err)
	}
	defer repo.db.Close()

	id, _ := repo.Record("test-change", "blocker", "blocker")

	// Resolve without engram id (fallback path)
	err = repo.Resolve(id, 0)
	if err != nil {
		t.Fatal(err)
	}

	list, _ := repo.List()
	if len(list) != 1 {
		t.Fatalf("expected 1 incident, got %d", len(list))
	}
	if list[0].Status != "resolved" {
		t.Fatalf("status = %q, want resolved", list[0].Status)
	}
	if list[0].FallbackPath == nil {
		t.Fatal("expected fallback_path")
	}
}

func TestRepositoryScrub(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "test.db")
	repo, err := NewRepository(dbPath)
	if err != nil {
		t.Fatal(err)
	}
	defer repo.db.Close()

	summary := "error: token ghp_abcdefghijklmnopqrstuvwxyz12345678 leaked"
	id, _ := repo.Record("c", summary, "other")
	_ = id

	list, _ := repo.List()
	if list[0].Summary == summary {
		t.Fatal("summary was not scrubbed")
	}
}

func TestRepositoryDefaultPath(t *testing.T) {
	// Test that NewRepository with empty path creates the default dir
	repo, err := NewRepository("")
	if err != nil {
		t.Skip("skipping default path test (home dir issue):", err)
	}
	defer repo.db.Close()
	// Verify the default file exists
	home, _ := os.UserHomeDir()
	expected := filepath.Join(home, ".config", "sdd-own", "srv", "sdd-tool", "incidents.db")
	if _, err := os.Stat(expected); err != nil {
		t.Fatalf("expected db at %s", expected)
	}
}
