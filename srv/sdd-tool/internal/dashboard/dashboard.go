// Package dashboard provides an on-demand Bubbletea TUI.
// Refresh only on 'r' keypress (explicit re-parse); no polling.
// --json emits scanner-passthrough; no TUI launched.
package dashboard

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/bubbles/table"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"sdd-tool/internal/scanner"
)

var (
	titleStyle = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("170"))
	helpStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color("241"))
	detailStyle = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).Padding(0, 1)
)

type model struct {
	scanner *scanner.Scanner
	snap    *scanner.Status
	table   table.Model
	sel     int
	ready   bool
}

type refreshMsg struct {
	snap *scanner.Status
	err  error
}

func initialModel(sc *scanner.Scanner) model {
	snap, err := sc.Snapshot()
	m := model{scanner: sc, snap: snap}
	if err != nil {
		return m
	}
	columns := []table.Column{
		{Title: "Name", Width: 20},
		{Title: "Status", Width: 15},
		{Title: "Next", Width: 20},
		{Title: "Blocked", Width: 30},
	}
	rows := make([]table.Row, 0, len(snap.Changes))
	for _, ch := range snap.Changes {
		blocked := strings.Join(ch.BlockedReasons, ", ")
		if blocked == "" {
			blocked = "-"
		}
		rows = append(rows, table.Row{ch.Name, ch.Status, ch.NextRecommended, blocked})
	}
	t := table.New(
		table.WithColumns(columns),
		table.WithRows(rows),
		table.WithFocused(true),
	)
	m.table = t
	m.ready = true
	return m
}

func (m model) Init() tea.Cmd {
	return nil
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			return m, tea.Quit
		case "r":
			// Re-parse once per keypress
			return m, func() tea.Msg {
				sc := scanner.New("")
				snap, err := sc.Snapshot()
				if err != nil {
					return refreshMsg{err: err}
				}
				return refreshMsg{snap: snap}
			}
		case "up", "k":
			if m.sel > 0 {
				m.sel--
				m.table.SetCursor(m.sel)
			}
		case "down", "j":
			if m.sel < len(m.snap.Changes)-1 {
				m.sel++
				m.table.SetCursor(m.sel)
			}
		}
	case refreshMsg:
		if msg.err == nil && msg.snap != nil {
			m.snap = msg.snap
			// Rebuild table
			rows := make([]table.Row, 0, len(msg.snap.Changes))
			for _, ch := range msg.snap.Changes {
				blocked := strings.Join(ch.BlockedReasons, ", ")
				if blocked == "" {
					blocked = "-"
				}
				rows = append(rows, table.Row{ch.Name, ch.Status, ch.NextRecommended, blocked})
			}
			m.table.SetRows(rows)
		}
	}
	var cmd tea.Cmd
	m.table, cmd = m.table.Update(msg)
	return m, cmd
}

func (m model) View() string {
	if !m.ready {
		return "Loading..."
	}
	var b strings.Builder
	b.WriteString(titleStyle.Render("SDD Dashboard"))
	b.WriteString("\n\n")
	b.WriteString(m.table.View())
	b.WriteString("\n\n")
	// Detail pane
	if m.sel >= 0 && m.sel < len(m.snap.Changes) {
		ch := m.snap.Changes[m.sel]
		var d strings.Builder
		fmt.Fprintf(&d, "Change: %s\n", ch.Name)
		fmt.Fprintf(&d, "Status: %s\n", ch.Status)
		fmt.Fprintf(&d, "Next:   %s\n", ch.NextRecommended)
		if len(ch.BlockedReasons) > 0 {
			fmt.Fprintf(&d, "Blocked: %s\n", strings.Join(ch.BlockedReasons, ", "))
		}
		if len(ch.ArtifactPaths) > 0 {
			fmt.Fprintf(&d, "Artifacts: %s\n", strings.Join(ch.ArtifactPaths, ", "))
		}
		b.WriteString(detailStyle.Render(d.String()))
	}
	b.WriteString("\n")
	b.WriteString(helpStyle.Render("↑↓: navigate  Enter: select  r: refresh (re-parse once)  q: quit"))
	b.WriteString("\n")
	return b.String()
}

// Run launches the Bubbletea dashboard.
// The scanner snapshot is process-lifetime; 'r' re-parses once per keypress.
func Run(sc *scanner.Scanner) error {
	p := tea.NewProgram(initialModel(sc), tea.WithAltScreen())
	_, err := p.Run()
	return err
}
