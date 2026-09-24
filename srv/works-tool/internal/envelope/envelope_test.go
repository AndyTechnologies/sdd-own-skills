package envelope

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestNewSuccessShape(t *testing.T) {
	raw, err := json.Marshal(NewSuccess("works-tool-rewire", []string{"a"}))
	if err != nil {
		t.Fatal(err)
	}
	got := string(raw)
	if !strings.Contains(got, `"ok":true`) {
		t.Fatalf("expected ok true, got %s", got)
	}
	if !strings.Contains(got, `"feature":"works-tool-rewire"`) {
		t.Fatalf("expected feature field, got %s", got)
	}
	if !strings.Contains(got, `"data":["a"]`) {
		t.Fatalf("expected data payload, got %s", got)
	}
	if strings.Contains(got, `"error"`) {
		t.Fatalf("success must not carry an error, got %s", got)
	}
}

func TestNewSuccessOmitsEmptyFeature(t *testing.T) {
	raw, err := json.Marshal(NewSuccess("", []int{}))
	if err != nil {
		t.Fatal(err)
	}
	got := string(raw)
	if strings.Contains(got, "feature") {
		t.Fatalf("empty feature must be omitted, got %s", got)
	}
	// Clean empty surfaces are honest results, never errors.
	if strings.Contains(got, `"error"`) {
		t.Fatalf("empty data must not be an error, got %s", got)
	}
	if !strings.Contains(got, `"data":[]`) {
		t.Fatalf("expected honest empty data slice, got %s", got)
	}
}

func TestNewFailureShape(t *testing.T) {
	raw, err := json.Marshal(NewFailure("f", "write_failed", "cannot write", true))
	if err != nil {
		t.Fatal(err)
	}
	got := string(raw)
	if !strings.Contains(got, `"ok":false`) {
		t.Fatalf("expected ok false, got %s", got)
	}
	if !strings.Contains(got, `"fail_open":true`) {
		t.Fatalf("expected fail_open true, got %s", got)
	}
	if !strings.Contains(got, `"code":"write_failed"`) {
		t.Fatalf("expected code, got %s", got)
	}
	if !strings.Contains(got, `"message":"cannot write"`) {
		t.Fatalf("expected message, got %s", got)
	}
	if strings.Contains(got, `"data"`) {
		t.Fatalf("failure must not carry data, got %s", got)
	}
}

func TestNewFailureOmitsFailOpenWhenFalse(t *testing.T) {
	raw, err := json.Marshal(NewFailure("", "signal_failed", "nope", false))
	if err != nil {
		t.Fatal(err)
	}
	got := string(raw)
	if strings.Contains(got, "fail_open") {
		t.Fatalf("fail_open false must be omitted, got %s", got)
	}
}

func TestExitCodeMapping(t *testing.T) {
	cases := []struct {
		err  *Error
		want int
	}{
		{nil, 0},
		{&Error{Code: "x", Message: "m", FailOpen: false}, 1},
		{&Error{Code: "x", Message: "m", FailOpen: true}, 2},
	}
	for _, c := range cases {
		if got := ExitCode(c.err); got != c.want {
			t.Errorf("ExitCode(%+v) = %d, want %d", c.err, got, c.want)
		}
	}
}
