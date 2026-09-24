package main

import (
	"encoding/json"
	"fmt"
	"os"

	"works-tool/internal/envelope"
	"works-tool/internal/incidents"

	"github.com/spf13/cobra"
)

func newIncidentsCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "incidents",
		Short: "Incident tracking: record, resolve, and list",
	}
	cmd.AddCommand(newIncidentsRecordCmd())
	cmd.AddCommand(newIncidentsResolveCmd())
	cmd.AddCommand(newIncidentsListCmd())
	return cmd
}

func newIncidentsRecordCmd() *cobra.Command {
	var (
		feature, summary, kind string
		jsonOut                bool
	)
	cmd := &cobra.Command{
		Use:   "record",
		Short: "Record a new incident (--feature required; summary is scrubbed)",
		RunE: func(cmd *cobra.Command, args []string) error {
			if feature == "" {
				return incidentsInvalidArgs("record: --feature is required")
			}
			if summary == "" {
				return incidentsInvalidArgs("record: --summary is required")
			}
			repo, err := incidents.NewRepository("")
			if err != nil {
				return incidentsWriteFail(jsonOut, err.Error())
			}
			defer repo.Close()
			id, err := repo.Record(feature, summary, kind)
			if err != nil {
				return incidentsWriteFail(jsonOut, err.Error())
			}
			if jsonOut {
				return json.NewEncoder(os.Stdout).Encode(envelope.NewSuccess(feature, map[string]any{"id": id, "status": "open"}))
			}
			fmt.Printf("Incident recorded: id=%d feature=%s kind=%s\n", id, feature, kind)
			return nil
		},
	}
	cmd.Flags().StringVar(&feature, "feature", "", "change/feature name (required)")
	cmd.Flags().StringVar(&summary, "summary", "", "incident summary (required, scrubbed)")
	cmd.Flags().StringVar(&kind, "kind", "other", "incident kind: blocker|test_failure|transport|other")
	cmd.Flags().BoolVar(&jsonOut, "json", false, "emit structured JSON")
	return cmd
}

func newIncidentsResolveCmd() *cobra.Command {
	var (
		id, engramID int
		jsonOut      bool
	)
	cmd := &cobra.Command{
		Use:   "resolve",
		Short: "Resolve an incident by id (--id required; --engram-id optional)",
		RunE: func(cmd *cobra.Command, args []string) error {
			if id <= 0 {
				return incidentsInvalidArgs("resolve: --id is required")
			}
			repo, err := incidents.NewRepository("")
			if err != nil {
				return incidentsWriteFail(jsonOut, err.Error())
			}
			defer repo.Close()
			if err := repo.Resolve(id, engramID); err != nil {
				return incidentsWriteFail(jsonOut, err.Error())
			}
			if jsonOut {
				return json.NewEncoder(os.Stdout).Encode(envelope.NewSuccess("", map[string]any{"id": id, "status": "resolved"}))
			}
			fmt.Printf("Incident resolved: id=%d\n", id)
			return nil
		},
	}
	cmd.Flags().IntVar(&id, "id", 0, "incident id (required)")
	cmd.Flags().IntVar(&engramID, "engram-id", 0, "fix Engram observation id (0 = bind fallback path)")
	cmd.Flags().BoolVar(&jsonOut, "json", false, "emit structured JSON")
	return cmd
}

func newIncidentsListCmd() *cobra.Command {
	var (
		feature string
		jsonOut bool
	)
	cmd := &cobra.Command{
		Use:   "list",
		Short: "List incidents (optional --feature filter)",
		RunE: func(cmd *cobra.Command, args []string) error {
			repo, err := incidents.NewRepository("")
			if err != nil {
				// A3 read-side fail-open: warn on stderr, exit 0 — but the
				// --json surface must still emit the envelope (empty data: an
				// unreadable store enumerates nothing), never 0-byte stdout.
				fmt.Fprintln(os.Stderr, "[warn] incidents list unavailable (fail-open):", err)
				if jsonOut {
					return json.NewEncoder(os.Stdout).Encode(envelope.NewSuccess(feature, []incidents.Incident{}))
				}
				return nil
			}
			defer repo.Close()
			list, err := repo.ListByChange(feature)
			if err != nil {
				fmt.Fprintln(os.Stderr, "[warn] incidents list failed (fail-open):", err)
				if jsonOut {
					return json.NewEncoder(os.Stdout).Encode(envelope.NewSuccess(feature, []incidents.Incident{}))
				}
				return nil
			}
			if jsonOut {
				return json.NewEncoder(os.Stdout).Encode(envelope.NewSuccess(feature, list))
			}
			if len(list) == 0 {
				fmt.Println("No incidents found.")
				return nil
			}
			for _, inc := range list {
				fmt.Printf("#%d %s %s [%s] %s\n", inc.ID, inc.ChangeName, inc.Kind, inc.Status, inc.Summary)
			}
			return nil
		},
	}
	cmd.Flags().StringVar(&feature, "feature", "", "filter by change/feature")
	cmd.Flags().BoolVar(&jsonOut, "json", false, "emit structured JSON")
	return cmd
}

// incidentsInvalidArgs surfaces a usage/argument error and exits 1.
func incidentsInvalidArgs(msg string) error {
	fmt.Fprintln(os.Stderr, msg)
	os.Exit(1)
	return nil
}

// incidentsWriteFail surfaces a D2 loud FAIL-OPEN marker for a lost incident
// write and exits 2 (a record/resolve that failed must be noticed).
func incidentsWriteFail(jsonOut bool, reason string) error {
	msg := "FAIL-OPEN: incidents write lost — " + reason
	if jsonOut {
		_ = json.NewEncoder(os.Stdout).Encode(envelope.NewFailure("", envelope.CodeWriteFailed, msg, true))
	} else {
		fmt.Fprintln(os.Stderr, msg)
	}
	os.Exit(2)
	return nil
}
