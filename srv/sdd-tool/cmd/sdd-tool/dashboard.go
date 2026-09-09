package main

import (
	"encoding/json"
	"fmt"
	"os"

	"sdd-tool/internal/dashboard"
	"sdd-tool/internal/scanner"

	"github.com/spf13/cobra"
)

func newDashboardCmd() *cobra.Command {
	var jsonOut bool
	cmd := &cobra.Command{
		Use:   "dashboard",
		Short: "On-demand Bubbletea TUI dashboard",
		RunE: func(cmd *cobra.Command, args []string) error {
			sc := scanner.New("")
			if jsonOut {
				snap, err := sc.Snapshot()
				if err != nil {
					fmt.Fprintf(os.Stderr, "FAIL-OPEN: scanner parse failed: %v\n", err)
					os.Exit(1)
				}
				return json.NewEncoder(os.Stdout).Encode(snap)
			}
			return dashboard.Run(sc)
		},
	}
	cmd.Flags().BoolVar(&jsonOut, "json", false, "emit scanner-passthrough JSON (no TUI)")
	return cmd
}
