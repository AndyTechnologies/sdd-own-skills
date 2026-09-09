package main

import (
	"encoding/json"
	"fmt"
	"os"

	"sdd-tool/internal/retro"

	"github.com/spf13/cobra"
)

func newRetroCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "retro",
		Short: "Store-aware retrospective persistence and lookup",
	}
	cmd.AddCommand(newRetroLookupCmd())
	cmd.AddCommand(newRetroPersistCmd())
	return cmd
}

func newRetroLookupCmd() *cobra.Command {
	var (
		jsonOut       bool
		changeName    string
		mode          string
		verifyDomain  bool
	)
	cmd := &cobra.Command{
		Use:   "lookup",
		Short: "Lookup retrospectives (store-first, cross-store fallback, dedupe)",
		RunE: func(cmd *cobra.Command, args []string) error {
			if mode == "" {
				mode = "both"
			}
			s, err := retro.NewStore(mode)
			if err != nil {
				fmt.Fprintf(os.Stderr, "FAIL-OPEN: retro store init failed: %v\n", err)
				return nil
			}
			precis, err := s.Lookup(changeName, verifyDomain)
			if err != nil {
				fmt.Fprintf(os.Stderr, "[warn] retro lookup failed (fail-open): %v\n", err)
				return nil
			}
			if jsonOut {
				return json.NewEncoder(os.Stdout).Encode(precis)
			}
			if precis.Count == 0 {
				fmt.Println("No retrospectives found.")
				return nil
			}
			fmt.Println(precis.Text())
			return nil
		},
	}
	cmd.Flags().BoolVar(&jsonOut, "json", false, "emit structured JSON")
	cmd.Flags().StringVar(&changeName, "change", "", "filter by change name")
	cmd.Flags().StringVar(&mode, "mode", "both", "store mode: both|openspec|engram|none")
	cmd.Flags().BoolVar(&verifyDomain, "verify-domain", false, "extract only verification gaps and incidents")
	return cmd
}

func newRetroPersistCmd() *cobra.Command {
	var (
		changeName string
		mode       string
		phase      string
		body       string
		bodyFile   string
	)
	cmd := &cobra.Command{
		Use:   "persist",
		Short: "Persist a retrospective (openspec file pre-archive + engram observation)",
		RunE: func(cmd *cobra.Command, args []string) error {
			if changeName == "" {
				return fmt.Errorf("--change is required")
			}
			if phase == "" {
				phase = "verify"
			}
			if mode == "" {
				mode = "both"
			}
			s, err := retro.NewStore(mode)
			if err != nil {
				// D2: write failure → loud FAIL-OPEN marker
				fmt.Fprintf(os.Stderr, "FAIL-OPEN: retro persist lost write — store init failed: %v\n", err)
				os.Exit(1)
			}
			if err := s.Persist(changeName, phase, body, bodyFile); err != nil {
				fmt.Fprintf(os.Stderr, "FAIL-OPEN: retro persist lost write to %s store: %v\n", mode, err)
				os.Exit(1)
			}
			fmt.Printf("Retrospective persisted for %s (mode: %s)\n", changeName, mode)
			return nil
		},
	}
	cmd.Flags().StringVar(&changeName, "change", "", "change name (required)")
	cmd.Flags().StringVar(&mode, "mode", "both", "store mode: both|openspec|engram|none")
	cmd.Flags().StringVar(&phase, "phase", "verify", "phase name")
	cmd.Flags().StringVar(&body, "body", "", "retro body text")
	cmd.Flags().StringVar(&bodyFile, "body-file", "", "path to retro body file")
	return cmd
}
