"""Subprocess executor — the ONLY module that calls ``subprocess.run()``.

Provides:
- ``ProcResult`` (NamedTuple) — returncode + captured stdout/stderr
- ``ExecutorProto`` (Protocol) — port for DI / mock-swap
- ``SubprocessRunner`` — concrete adapter with prompt-disable env hygiene
- ``SubprocessError`` — raised on a generic OSError (e.g. EACCES, resource limits)
- ``SubprocessTimeout`` — raised when the command exceeds its timeout
- ``SubprocessBinaryMissing`` — raised when the binary does not exist (ENOENT)

Why three types: a timeout, a missing binary and a real OS failure are three
different things that need three different answers. Collapsing them into one
type makes the classification impossible downstream — a missing ``gh`` reported
as "network error" sends the caller to debug the network instead of installing
the CLI. ``SubprocessTimeout`` and ``SubprocessBinaryMissing`` both subclass
``SubprocessError``, so existing handlers that catch the base keep working.
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
    """Raised when subprocess.run fails with an OSError other than ENOENT.

    This is the base type: catching it still catches a timeout or a missing
    binary, which is what pre-existing callers expect.
    """


class SubprocessTimeout(SubprocessError):
    """Raised when the command exceeded its timeout and was killed."""


class SubprocessBinaryMissing(SubprocessError):
    """Raised when the binary to run does not exist (ENOENT).

    Carries ``binary`` so the caller can name the missing executable in the hint
    instead of surfacing a bare errno.
    """

    def __init__(self, message: str, *, binary: str = "") -> None:
        super().__init__(message)
        self.binary = binary


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
        timeout_s: float | None = None,
    ) -> ProcResult:
        """Run *argv* with prompt-disable env.

        Returns ``(returncode, stdout, stderr)``.
        Raises ``SubprocessTimeout`` on timeout, ``SubprocessBinaryMissing`` when
        *argv[0]* does not exist, ``SubprocessError`` on any other OSError.
        Never reads or sets a token.
        """
        ...


# ---------------------------------------------------------------------------
# Timeout budget
# ---------------------------------------------------------------------------

# El default NO se cambia a ciegas: la unica evidencia en frio disponible es una
# muestra de ~11 s, insuficiente para justificar otro numero. Se preserva 30 s y se
# hace configurable por entorno. Los overrides por tool ya existian y siguen
# funcionando (gh_get_run_logs 120 s, codegraph init 60 s).
DEFAULT_TIMEOUT_S = 30.0
TIMEOUT_ENV_VAR = "GH_GIT_MCP_TIMEOUT_S"


def default_timeout_s() -> float:
    """El timeout por defecto, overridable por ``GH_GIT_MCP_TIMEOUT_S``.

    Se lee en cada llamada (no al importar) para que un test pueda cambiar el
    entorno. Un valor invalido o no positivo NO cambia el default: una variable
    de entorno mal puesta no debe dejar los comandos sin limite de tiempo.
    """
    import os

    raw = os.environ.get(TIMEOUT_ENV_VAR)
    if raw is None or raw.strip() == "":
        return DEFAULT_TIMEOUT_S
    try:
        value = float(raw)
    except ValueError:
        return DEFAULT_TIMEOUT_S
    return value if value > 0 else DEFAULT_TIMEOUT_S


# ---------------------------------------------------------------------------
# Concrete adapter
# ---------------------------------------------------------------------------

class SubprocessRunner:
    """Facade over ``subprocess.run`` — the ONLY place subprocess is called.

    Env hygiene applied to every call:
    - ``GH_PROMPT_DISABLED=1`` + ``NO_COLOR=1`` (gh never prompts over stdio, no ANSI)
    - ``GIT_TERMINAL_PROMPT=0`` (git never prompts for credentials)
    - Inherited env otherwise — the server never sets ``GH_TOKEN`` / ``GITHUB_TOKEN``
    - Hard timeout (``GH_GIT_MCP_TIMEOUT_S``, default 30 s; callers may override
      per call, as ``gh_get_run_logs`` does with 120 s)
    """

    _PROMPT_DISABLE_ENV: dict[str, str] = {
        "GH_PROMPT_DISABLED": "1",
        "GIT_TERMINAL_PROMPT": "0",
        "NO_COLOR": "1",
    }

    def run(
        self,
        argv: list[str],
        *,
        cwd: str | None = None,
        text: bool = True,
        timeout_s: float | None = None,
    ) -> ProcResult:
        import os

        merged_env = {**os.environ, **self._PROMPT_DISABLE_ENV}
        timeout = default_timeout_s() if timeout_s is None else timeout_s
        binary = argv[0] if argv else ""

        try:
            result = subprocess.run(
                argv,
                cwd=cwd,
                text=text,
                capture_output=True,
                timeout=timeout,
                env=merged_env,
            )
            return ProcResult(
                returncode=result.returncode,
                stdout=result.stdout or "",
                stderr=result.stderr or "",
            )
        except subprocess.TimeoutExpired as exc:
            raise SubprocessTimeout(
                f"Command timed out after {timeout}s: {' '.join(argv)}"
            ) from exc
        except FileNotFoundError as exc:
            # ENOENT: el binario no existe. No es un problema de red.
            raise SubprocessBinaryMissing(
                f"Binary not found: {binary}", binary=binary
            ) from exc
        except OSError as exc:
            raise SubprocessError(
                f"OS error running {' '.join(argv)}: {exc}"
            ) from exc
