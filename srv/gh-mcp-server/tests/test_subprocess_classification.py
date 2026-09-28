"""Classification of subprocess failures (executor + safety net).

The executor used to raise ONE type (``SubprocessError``) for three unrelated
situations — a command that exceeded its deadline, a binary that does not exist
(ENOENT), and a real OS-level failure. The safety net mapped that single type to
``network_error``, so all three were reported as a network problem: a slow link
told the caller to debug the network, and a missing ``gh`` was worse than merely
unhelpful, because it sent the caller to look in exactly the wrong place.

One type for three failures is what makes the classification impossible
downstream, so the executor now raises three and the safety net answers three
different ``error.type`` values. These tests pin the mapping, not the plumbing.
"""

from __future__ import annotations

import asyncio
import subprocess
from typing import Any

import pytest

from src.executor import (
    DEFAULT_TIMEOUT_S,
    TIMEOUT_ENV_VAR,
    SubprocessBinaryMissing,
    SubprocessError,
    SubprocessRunner,
    SubprocessTimeout,
    default_timeout_s,
)


class _RaisingSubprocess:
    """Stand-in for subprocess.run that raises whatever the test asked for."""

    def __init__(self, exc: BaseException) -> None:
        self.exc = exc
        self.calls: list[list[str]] = []

    def __call__(self, argv, **kwargs: Any) -> subprocess.CompletedProcess:
        self.calls.append(argv)
        raise self.exc


# ---------------------------------------------------------------------------
# executor: the three exceptions are actually distinct
# ---------------------------------------------------------------------------


def test_timeout_raises_subprocess_timeout(monkeypatch) -> None:
    """A command that blew its deadline must not look like an OS failure."""
    fake = _RaisingSubprocess(subprocess.TimeoutExpired(cmd=["gh", "x"], timeout=30))
    monkeypatch.setattr("src.executor.subprocess.run", fake)
    with pytest.raises(SubprocessTimeout) as excinfo:
        SubprocessRunner().run(["gh", "x"])
    assert "timed out" in str(excinfo.value)


def test_missing_binary_raises_subprocess_binary_missing(monkeypatch) -> None:
    """ENOENT is not a network failure, and the hint has to name the binary."""
    fake = _RaisingSubprocess(FileNotFoundError(2, "No such file or directory"))
    monkeypatch.setattr("src.executor.subprocess.run", fake)
    with pytest.raises(SubprocessBinaryMissing) as excinfo:
        SubprocessRunner().run(["gh", "auth", "status"])
    assert excinfo.value.binary == "gh"


def test_generic_oserror_raises_subprocess_error(monkeypatch) -> None:
    """Any other OSError stays on the base type (the network_error arm)."""
    fake = _RaisingSubprocess(PermissionError(13, "Permission denied"))
    monkeypatch.setattr("src.executor.subprocess.run", fake)
    with pytest.raises(SubprocessError) as excinfo:
        SubprocessRunner().run(["git", "status"])
    assert not isinstance(excinfo.value, (SubprocessTimeout, SubprocessBinaryMissing))


def test_specific_types_subclass_the_base() -> None:
    """``gh_auth`` and ``worktree_state`` catch the base; it has to keep working."""
    assert issubclass(SubprocessTimeout, SubprocessError)
    assert issubclass(SubprocessBinaryMissing, SubprocessError)


# ---------------------------------------------------------------------------
# timeout budget: configurable, with the 30 s default preserved
# ---------------------------------------------------------------------------


def test_default_timeout_is_preserved_when_env_absent(monkeypatch) -> None:
    """The 30 s default is NOT changed on a hunch: the only cold sample is ~11 s."""
    monkeypatch.delenv(TIMEOUT_ENV_VAR, raising=False)
    assert default_timeout_s() == DEFAULT_TIMEOUT_S == 30.0


def test_timeout_is_configurable_by_env(monkeypatch) -> None:
    monkeypatch.setenv(TIMEOUT_ENV_VAR, "90")
    assert default_timeout_s() == 90.0


@pytest.mark.parametrize("raw", ["", "  ", "abc", "0", "-5"])
def test_invalid_env_keeps_the_default(monkeypatch, raw: str) -> None:
    """A misconfigured env var must not leave commands without a deadline."""
    monkeypatch.setenv(TIMEOUT_ENV_VAR, raw)
    assert default_timeout_s() == DEFAULT_TIMEOUT_S


def test_env_default_reaches_subprocess_run(monkeypatch) -> None:
    """The resolved default is what actually reaches the subprocess call."""
    seen: dict[str, Any] = {}

    def fake_run(argv, **kwargs: Any) -> subprocess.CompletedProcess:
        seen.update(kwargs)
        return subprocess.CompletedProcess(argv, 0, stdout="", stderr="")

    monkeypatch.setenv(TIMEOUT_ENV_VAR, "77")
    monkeypatch.setattr("src.executor.subprocess.run", fake_run)
    SubprocessRunner().run(["git", "status"])
    assert seen["timeout"] == 77.0


def test_per_call_override_wins_over_env(monkeypatch) -> None:
    """``gh_get_run_logs`` (120 s) and codegraph init (60 s) keep working."""
    seen: dict[str, Any] = {}

    def fake_run(argv, **kwargs: Any) -> subprocess.CompletedProcess:
        seen.update(kwargs)
        return subprocess.CompletedProcess(argv, 0, stdout="", stderr="")

    monkeypatch.setenv(TIMEOUT_ENV_VAR, "77")
    monkeypatch.setattr("src.executor.subprocess.run", fake_run)
    SubprocessRunner().run(["gh", "run", "view", "--log"], timeout_s=120)
    assert seen["timeout"] == 120.0


# ---------------------------------------------------------------------------
# server boundary: the error.type the caller actually sees
# ---------------------------------------------------------------------------


def _envelope_from(exc: BaseException, name: str) -> dict[str, Any]:
    """Run one exception through the real safety net and return the envelope."""
    from src.server import _safety_net_tool

    async def raiser() -> None:
        raise exc

    raiser.__name__ = name
    wrapped = _safety_net_tool()(raiser)
    return asyncio.run(wrapped())


def test_server_boundary_maps_timeout_to_timeout() -> None:
    envelope = _envelope_from(SubprocessTimeout("Command timed out after 30s: gh x"), "probe_timeout")
    assert envelope["ok"] is False
    assert envelope["error"]["type"] == "timeout"
    assert "GH_GIT_MCP_TIMEOUT_S" in (envelope["error"]["hint"] or "")


def test_server_boundary_maps_missing_binary_to_not_found_with_hint() -> None:
    envelope = _envelope_from(
        SubprocessBinaryMissing("Binary not found: gh", binary="gh"), "probe_missing"
    )
    assert envelope["ok"] is False
    assert envelope["error"]["type"] == "not_found"
    assert "gh" in (envelope["error"]["hint"] or "")


def test_server_boundary_maps_generic_oserror_to_network_error() -> None:
    envelope = _envelope_from(SubprocessError("OS error running git: EACCES"), "probe_os")
    assert envelope["ok"] is False
    assert envelope["error"]["type"] == "network_error"


def test_server_boundary_still_net_unexpected_exceptions() -> None:
    """The transport net is unchanged: unexpected → invalid_parameter."""

    async def boom() -> None:
        raise ValueError("algo que nadie espero")

    from src.server import _safety_net_tool

    wrapped = _safety_net_tool()(boom)
    envelope = asyncio.run(wrapped())
    assert envelope["error"]["type"] == "invalid_parameter"


def test_the_three_failures_are_no_longer_indistinguishable() -> None:
    """The regression this whole change exists for: three errors, one type."""
    types = {
        _envelope_from(SubprocessTimeout("t"), "probe_distinct_a")["error"]["type"],
        _envelope_from(SubprocessBinaryMissing("b", binary="gh"), "probe_distinct_b")["error"]["type"],
        _envelope_from(SubprocessError("o"), "probe_distinct_c")["error"]["type"],
    }
    assert types == {"timeout", "not_found", "network_error"}
