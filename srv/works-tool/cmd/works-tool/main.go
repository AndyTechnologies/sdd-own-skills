// Package main implements the works-tool CLI — a cobra root with subcommands
// for worktree list|verify and retro lookup|persist.
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
		Short: "SDD lifecycle helper: worktree and retro",
		Long: `works-tool provides subcommands for the SDD workflow:
  worktree list|verify   — enumerate and verify worktrees
  retro lookup|persist   — store-aware retrospective persistence and lookup`,
		SilenceUsage:  true,
		SilenceErrors: true,
	}
	root.AddCommand(newWorktreeCmd())
	root.AddCommand(newRetroCmd())
	return root
}
