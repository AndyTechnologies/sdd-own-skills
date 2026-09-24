// Package envelope owns the uniform JSON output contract and the central
// exit-code mapping shared by every works-tool surface (worktree list|verify,
// retro persist|lookup, incidents record|resolve|list).
//
// Serialization contract (acta A3):
//
//	Success: {"ok": true,  "feature": "<name>", "data": <payload>}
//	Failure: {"ok": false, "feature": "<name>", "error": {"code", "message", "fail_open"}}
//
// `feature` is omitted when not scoped; `data` may be `[]` — clean empty
// surfaces are honest results, never errors. Exit codes are central: 0 = ok,
// 1 = hard error (fail_open false), 2 = fail-open/warn (fail_open true).
package envelope

// Error is the failure payload of the uniform envelope.
type Error struct {
	Code     string `json:"code"`
	Message  string `json:"message"`
	FailOpen bool   `json:"fail_open,omitempty"`
}

// E is the uniform JSON envelope emitted by every --json surface.
type E struct {
	OK      bool        `json:"ok"`
	Feature string      `json:"feature,omitempty"`
	Data    interface{} `json:"data,omitempty"`
	Error   *Error      `json:"error,omitempty"`
}

// Common failure codes shared across surfaces. Surfaces may define their own
// codes; these cover the cross-cutting failure classes.
const (
	CodeInvalidArgs      = "invalid_args"
	CodeWriteFailed      = "write_failed"
	CodeSignalFailed     = "signal_failed"
	CodeStoreUnavailable = "store_unavailable"
)

// NewSuccess builds an ok envelope. feature is omitted when empty; data is
// emitted as-is (nil and [] both marshal as honest empty surfaces).
func NewSuccess(feature string, data interface{}) E {
	return E{OK: true, Feature: feature, Data: data}
}

// NewFailure builds a failure envelope. failOpen marks a fail-open/warn
// outcome: the write failed loudly but the tool continues to exist.
func NewFailure(feature, code, message string, failOpen bool) E {
	return E{
		OK:      false,
		Feature: feature,
		Error: &Error{
			Code:     code,
			Message:  message,
			FailOpen: failOpen,
		},
	}
}

// ExitCode maps a failure to the central exit-code contract: nil (ok) → 0,
// hard error (fail_open false) → 1, fail-open/warn (fail_open true) → 2.
func ExitCode(err *Error) int {
	if err == nil {
		return 0
	}
	if err.FailOpen {
		return 2
	}
	return 1
}
