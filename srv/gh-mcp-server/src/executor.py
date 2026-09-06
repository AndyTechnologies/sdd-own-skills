"""Subprocess executor — the ONLY module that calls ``subprocess.run()``.

Provides:
- ``ProcResult`` (NamedTuple) — returncode + captured stdout/stderr
- ``ExecutorProto`` (Protocol) — port for DI / mock-swap
- ``SubprocessRunner`` — concrete adapter with prompt-disable env hygiene
- ``SubprocessError`` — raised on timeout / OSError
"""

from __future__ import annotations

import subprocess
from typing import NamedTuple, Protocol, runtime_checkable


# ---------------------------------------------------------------------------
# Result type
# ---------------------------------------------------------------------------

class ProcResult(NamedTuple):
    returncode: int
    stdout: str
    stderr: str


# ---------------------------------------------------------------------------
# Error
# ---------------------------------------------------------------------------

class SubprocessError(Exception):
    """Raised when subprocess.run fails (timeout / OSError)."""


# ---------------------------------------------------------------------------
# Protocol port (DI boundary)
# ---------------------------------------------------------------------------

@runtime_checkable
class ExecutorProto(Protocol):
    """Port for subprocess execution — anything that can ``run`` an argv."""

    def run(
        self,
        argv: list[str],
        *,
        cwd: str | None = None,
        text: bool = True,
        timeout_s: float = 30.0,
    ) -> ProcResult:
        """Run *argv* with prompt-disable env.

        Returns ``(returncode, stdout, stderr)``.
        Raises ``SubprocessError`` on timeout / OSError.
        Never reads or sets a token.
        """
        ...


# ---------------------------------------------------------------------------
# Concrete adapter
# ---------------------------------------------------------------------------

class SubprocessRunner:
    """Facade over ``subprocess.run`` — the ONLY place subprocess is called.

    Env hygiene applied to every call:
    - ``GH_PROMPT_DISABLED=1`` + ``--nocolor`` (gh never prompts over stdio)
    - ``GIT_TERMINAL_PROMPT=0`` (git never prompts for credentials)
    - Inherited env otherwise — the server never sets ``GH_TOKEN`` / ``GITHUB_TOKEN``
    - Hard timeout (default 30 s; callers may override).
    """

    _PROMPT_DISABLE_ENV: dict[str, str] = {
        "GH_PROMPT_DISABLED": "1",
        "GIT_TERMINAL_PROMPT": "0",
    }

    def run(
        self,
        argv: list[str],
        *,
        cwd: str | None = None,
        text: bool = True,
        timeout_s: float = 30.0,
    ) -> ProcResult:
        import os

        merged_env = {**os.environ, **self._PROMPT_DISABLE_ENV}

        # Ensure gh never outputs ANSI escapes
        final_argv = list(argv)
        if final_argv and final_argv[0] == "gh":
            if "--nocolor" not in final_argv:
                final_argv.insert(1, "--nocolor")

        try:
            result = subprocess.run(
                final_argv,
                cwd=cwd,
                text=text,
                capture_output=True,
                timeout=timeout_s,
                env=merged_env,
            )
            return ProcResult(
                returncode=result.returncode,
                stdout=result.stdout or "",
                stderr=result.stderr or "",
            )
        except subprocess.TimeoutExpired as exc:
            raise SubprocessError(
                f"Command timed out after {timeout_s}s: {' '.join(argv)}"
            ) from exc
        except OSError as exc:
            raise SubprocessError(
                f"OS error running {' '.join(argv)}: {exc}"
            ) from exc
