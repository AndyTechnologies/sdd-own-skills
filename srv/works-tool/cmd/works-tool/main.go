// Package main implements the works-tool CLI — a cobra root with subcommands
// for worktree list|verify, retro lookup|persist, and incidents
// record|resolve|list.
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
		Use:   "works-tool",
		Short: "ODD lifecycle helper: worktree, retro, and incidents",
		Long: `works-tool provides subcommands for the ODD workflow:
  worktree list|verify     — enumerate and verify worktrees
  retro lookup|persist     — retro ledger: Engram primary + task-doc appendix secondary
  incidents record|resolve — track and resolve orchestrator-observed failures
  incidents list           — list incidents (optional --feature filter)`,
		SilenceUsage:  true,
		SilenceErrors: true,
	}
	root.AddCommand(newWorktreeCmd())
	root.AddCommand(newRetroCmd())
	root.AddCommand(newIncidentsCmd())
	return root
}
