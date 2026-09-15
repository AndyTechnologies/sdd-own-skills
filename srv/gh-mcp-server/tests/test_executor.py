"""RED tests for the subprocess executor env hygiene (executor.SubprocessRunner).

Regression for the gh >= 2.100 contract: the ``--nocolor`` flag was removed from
gh, so the runner must NOT inject it into any argv (it broke every remote tool
with ``unknown flag: --nocolor`` → RC=1 → the auth gate misreported
``auth_required``). Color suppression now ships via the standard ``NO_COLOR=1``
env var instead. The runner never sets ``GH_TOKEN`` / ``GITHUB_TOKEN``.
"""

from __future__ import annotations

import subprocess
from typing import Any

from src.executor import SubprocessRunner


class _RecordingSubprocess:
    """Stand-in for subprocess.run capturing argv/env (default: rc=0)."""

    def __init__(self) -> None:
        self.calls: list[tuple[list[str], dict[str, str]]] = []

    def __call__(self, argv, **kwargs: Any) -> subprocess.CompletedProcess:
        self.calls.append((argv, kwargs.get("env", {})))
        return subprocess.CompletedProcess(argv, 0, stdout="", stderr="")

    def install(self, monkeypatch: Any) -> None:
        monkeypatch.setattr("src.executor.subprocess.run", self)


def test_no_nocolor_flag_injected(monkeypatch) -> None:
    """The removed ``--nocolor`` flag must never appear in any argv."""
    rec = _RecordingSubprocess()
    rec.install(monkeypatch)
    runner = SubprocessRunner()
    runner.run(["gh", "auth", "status", "--json", "hosts"])
    runner.run(["git", "status", "--porcelain"])
    assert all("--nocolor" not in argv for argv, _env in rec.calls)
    assert rec.calls[0][0] == ["gh", "auth", "status", "--json", "hosts"]


def test_no_color_env_var_present(monkeypatch) -> None:
    """Color suppression ships via NO_COLOR=1, never via GH_TOKEN injection."""
    rec = _RecordingSubprocess()
    rec.install(monkeypatch)
    runner = SubprocessRunner()
    runner.run(["gh", "auth", "status", "--json", "hosts"])
    _argv, env = rec.calls[0]
    assert env.get("NO_COLOR") == "1"
    assert env.get("GH_PROMPT_DISABLED") == "1"
    assert env.get("GIT_TERMINAL_PROMPT") == "0"
    assert "GH_TOKEN" not in env
    assert "GITHUB_TOKEN" not in env