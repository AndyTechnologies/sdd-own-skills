package main

import (
	"encoding/json"
	"fmt"
	"os"

	"sdd-tool/internal/incidents"

	"github.com/spf13/cobra"
)

func newBugCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "bug",
		Short: "Incident recording: record, resolve, and list bugs",
	}
	cmd.AddCommand(newBugRecordCmd())
	cmd.AddCommand(newBugResolveCmd())
	cmd.AddCommand(newBugListCmd())
	return cmd
}

func newBugRecordCmd() *cobra.Command {
	var (
		changeName string
		summary    string
		kind       string
	)
	cmd := &cobra.Command{
		Use:   "record",
		Short: "Record an orchestrator-observed failure",
		RunE: func(cmd *cobra.Command, args []string) error {
			if changeName == "" {
				return fmt.Errorf("--change is required")
			}
			if summary == "" {
				return fmt.Errorf("--summary is required")
			}
			if kind == "" {
				kind = "other"
			}
			repo, err := incidents.NewRepository("")
			if err != nil {
				// D2: write failure → loud FAIL-OPEN marker
				fmt.Fprintf(os.Stderr, "FAIL-OPEN: bug record lost write — repository init failed: %v\n", err)
				os.Exit(1)
			}
			id, err := repo.Record(changeName, summary, kind)
			if err != nil {
				fmt.Fprintf(os.Stderr, "FAIL-OPEN: bug record lost write: %v\n", err)
				os.Exit(1)
			}
			fmt.Printf("Incident #%d recorded.\n", id)
			return nil
		},
	}
	cmd.Flags().StringVar(&changeName, "change", "", "change name (required)")
	cmd.Flags().StringVar(&summary, "summary", "", "failure description (required)")
	cmd.Flags().StringVar(&kind, "kind", "other", "kind: blocker|test_failure|transport|other")
	return cmd
}

func newBugResolveCmd() *cobra.Command {
	var (
		id         int
		engramID   int
	)
	cmd := &cobra.Command{
		Use:   "resolve",
		Short: "Resolve an incident (binds fix observation or fallback_path)",
		RunE: func(cmd *cobra.Command, args []string) error {
			if id == 0 {
				return fmt.Errorf("--id is required")
			}
			repo, err := incidents.NewRepository("")
			if err != nil {
				fmt.Fprintf(os.Stderr, "FAIL-OPEN: bug resolve lost write — repository init failed: %v\n", err)
				os.Exit(1)
			}
			if err := repo.Resolve(id, engramID); err != nil {
				fmt.Fprintf(os.Stderr, "FAIL-OPEN: bug resolve lost write: %v\n", err)
				os.Exit(1)
			}
			fmt.Printf("Incident #%d resolved.\n", id)
			return nil
		},
	}
	cmd.Flags().IntVar(&id, "id", 0, "incident id (required)")
	cmd.Flags().IntVar(&engramID, "engram-id", 0, "direct Engram observation id of the fix")
	return cmd
}

func newBugListCmd() *cobra.Command {
	var jsonOut bool
	cmd := &cobra.Command{
		Use:   "list",
		Short: "List recorded incidents",
		RunE: func(cmd *cobra.Command, args []string) error {
			repo, err := incidents.NewRepository("")
			if err != nil {
				fmt.Fprintf(os.Stderr, "[warn] bug list failed (fail-open): %v\n", err)
				return nil
			}
			list, err := repo.List()
			if err != nil {
				fmt.Fprintf(os.Stderr, "[warn] bug list failed (fail-open): %v\n", err)
				return nil
			}
			if jsonOut {
				return json.NewEncoder(os.Stdout).Encode(list)
			}
			if len(list) == 0 {
				fmt.Println("No incidents recorded.")
				return nil
			}
			for _, inc := range list {
				fmt.Printf("#%-4d %-12s %-12s %s\n", inc.ID, inc.Kind, inc.Status, inc.Summary)
			}
			return nil
		},
	}
	cmd.Flags().BoolVar(&jsonOut, "json", false, "emit structured JSON")
	return cmd
}
