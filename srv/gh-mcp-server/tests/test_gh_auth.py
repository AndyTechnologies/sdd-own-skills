"""RED tests for the auth gate (gh_auth.require_auth).

Covers the gh >= 2.98 contract: ``gh auth status --exit-code`` was removed, so
the gate probes ``gh auth status --json hosts`` and treats the ``active`` field
as the authoritative signal. A host list with at least one active host passes;
everything else fails closed with an ``auth_required`` envelope. Also covers
pathological inputs (invalid JSON, subprocess failure, missing gh CLI).

FakeExecutor mocks the subprocess boundary; gh_auth is exercised directly.
"""

from __future__ import annotations

import json

import pytest

from src.envelope import Envelope
from src.executor import ProcResult, SubprocessError
from src.gh_auth import require_auth

ACTIVE_HOSTS = json.dumps({"hosts": {"github.com": [{"active": True}]}})
INACTIVE_HOSTS = json.dumps({"hosts": {"github.com": [{"active": False}]}})
NO_HOSTS = json.dumps({"hosts": {}})


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


class FakeExecutor:
    """Recorded argv -> ProcResult mapping (default: fail)."""

    def __init__(self, mapping: dict[tuple[str, ...], ProcResult] | None = None) -> None:
        self.mapping = mapping or {}
        self.calls: list[tuple[tuple[str, ...], str | None]] = []

    def run(self, argv, *, cwd=None, text=True, timeout_s=30.0) -> ProcResult:  # noqa: ARG002
        key = tuple(argv)
        self.calls.append((key, cwd))
        if key not in self.mapping:
            return ProcResult(1, "", f"unmocked: {' '.join(argv)}")
        return self.mapping[key]


class RaisingExecutor:
    """Executor whose run() always raises SubprocessError (timeout/OSError)."""

    def run(self, argv, *, cwd=None, text=True, timeout_s=30.0) -> ProcResult:  # noqa: ARG002
        raise SubprocessError(f"boom: {' '.join(argv)}")


def ok(executor, *, hosts: str) -> Envelope | None:
    return require_auth(executor)


def auth_required(executor) -> Envelope:
    env = require_auth(executor)
    assert env is not None, "expected auth_required envelope"
    assert env["ok"] is False
    assert env["error"] is not None
    assert env["error"]["type"] == "auth_required"
    return env


AUTH_ARGV = ("gh", "auth", "status", "--json", "hosts")


# ---------------------------------------------------------------------------
# Happy path — at least one active host
# ---------------------------------------------------------------------------


def test_active_host_passes() -> None:
    """One active host -> gate passes (None)."""
    executor = FakeExecutor({AUTH_ARGV: ProcResult(0, ACTIVE_HOSTS, "")})
    assert require_auth(executor) is None
    assert list(executor.calls) == [(AUTH_ARGV, None)]


def test_multiple_hosts_with_one_active_passes() -> None:
    """Multi-host output with one active among inactives -> passes."""
    hosts = json.dumps(
        {"hosts": {"github.com": [{"active": False}], "enterprise.example": [{"active": True}]}}
    )
    executor = FakeExecutor({AUTH_ARGV: ProcResult(0, hosts, "")})
    assert require_auth(executor) is None


# ---------------------------------------------------------------------------
# Fail closed — auth_required envelopes
# ---------------------------------------------------------------------------


def test_inactive_host_fails_closed() -> None:
    """Hosts present but none active -> auth_required."""
    executor = FakeExecutor({AUTH_ARGV: ProcResult(0, INACTIVE_HOSTS, "")})
    env = auth_required(executor)
    assert env["error"]["message"] == "gh is not authenticated. Run `gh auth login` first."
    assert env["error"]["hint"] == "gh auth login"


def test_no_hosts_fails_closed() -> None:
    """Empty hosts dict -> auth_required."""
    executor = FakeExecutor({AUTH_ARGV: ProcResult(0, NO_HOSTS, "")})
    auth_required(executor)


def test_non_zero_exit_fails_closed() -> None:
    """gh returns non-zero -> auth_required (compat path)."""
    executor = FakeExecutor({AUTH_ARGV: ProcResult(1, "", "not logged in")})
    auth_required(executor)


def test_invalid_json_fails_closed() -> None:
    """rc=0 but stdout is not JSON -> auth_required with specific message."""
    executor = FakeExecutor({AUTH_ARGV: ProcResult(0, "not-json", "")})
    env = auth_required(executor)
    assert env["error"]["message"] == "gh auth status returned invalid JSON."


def test_subprocess_error_fails_closed() -> None:
    """Executor raises SubprocessError -> auth_required (never bubbles)."""
    env = auth_required(RaisingExecutor())
    assert "gh auth status failed" in env["error"]["message"]


def test_missing_gh_cli_fails_closed(monkeypatch: pytest.MonkeyPatch) -> None:
    """gh binary absent -> auth_required without invoking the executor."""
    monkeypatch.setattr("shutil.which", lambda name: None)
    env = auth_required(FakeExecutor())
    assert env["error"]["message"] == "gh CLI is not installed."
    assert env["error"]["hint"] == "install gh CLI"


# ---------------------------------------------------------------------------
# Contract — always the same argv shape
# ---------------------------------------------------------------------------


def test_always_probes_json_hosts() -> None:
    """The gate only ever calls the modern probe (never --exit-code)."""
    executor = FakeExecutor({AUTH_ARGV: ProcResult(0, ACTIVE_HOSTS, "")})
    require_auth(executor)
    assert list(executor.calls) == [(AUTH_ARGV, None)]