// Package main implements the sdd-tool CLI — a cobra root with subcommands
// for worktree list|verify, retro lookup|persist, dashboard, and
// bug record|resolve|list. One shared scanner (gentle-ai sdd-status --json)
// feeds listing surfaces lazily; mutating commands never invoke the scanner.
package main

import (
	"os"

	"github.com/spf13/cobra"
)

func main() {
	if err := newRootCmd().Execute(); err != nil {
		os.Exit(1)
	}
}

func newRootCmd() *cobra.Command {
	root := &cobra.Command{
		Use:   "sdd-tool",
		Short: "SDD lifecycle helper: worktree, retro, dashboard, and incidents",
		Long: `sdd-tool provides subcommands for the SDD workflow:
  worktree list|verify   — enumerate and verify worktrees
  retro lookup|persist   — store-aware retrospective persistence and lookup
  dashboard              — on-demand Bubbletea TUI
  bug record|resolve|list — incident recording with privacy scrubbing`,
		SilenceUsage:  true,
		SilenceErrors: true,
	}
	root.AddCommand(newWorktreeCmd())
	root.AddCommand(newRetroCmd())
	root.AddCommand(newDashboardCmd())
	root.AddCommand(newBugCmd())
	return root
}
