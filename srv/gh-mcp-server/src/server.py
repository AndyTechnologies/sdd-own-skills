#!/usr/bin/env python3
"""FastMCP composition root — gh-git-mcp-server.

This is the **composition root**:
- Constructs ``SubprocessRunner()`` (the only adapter)
- Wraps ``mcp.tool`` with an exception safety net BEFORE registration,
  so every tool is protected (transport-level net: unexpected exceptions
  become ``invalid_parameter``; ``SubprocessError`` is re-raised because
  each handler classifies its own subprocess failures)
- Calls ``register_all(mcp, executor)`` to wire all handler families
- No token env, no import of concrete runner in handlers
- Runs via stdio (``mcp.run()``)
"""

from __future__ import annotations

import functools
import logging
import sys
from typing import Any, Callable

from fastmcp import FastMCP

from src.executor import SubprocessRunner, SubprocessError
from src.envelope import err

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("gh-git-mcp-server")

mcp = FastMCP("gh-git-mcp")

# Keep the fastmcp tool decorator before wrapping it
_original_tool: Callable[..., Any] = mcp.tool


def _safety_net_tool(*args: Any, **kwargs: Any) -> Any:
    """Decorator wrapper that adds an exception safety net to each tool.

    ``SubprocessError`` (timeout / missing binary) is classified as a typed
    ``network_error`` envelope so subprocess failures never escape the payload
    contract. Unexpected exceptions are caught at the transport boundary and
    returned as ``invalid_parameter``.
    """

    def decorator(fn: Any) -> Any:
        @functools.wraps(fn)
        async def safe_fn(*a: Any, **kw: Any) -> dict[str, Any]:
            try:
                return await fn(*a, **kw)
            except SubprocessError as exc:
                logger.error("Subprocess failure in %s: %s", fn.__name__, exc)
                return dict(err("network_error", str(exc)))
            except Exception as exc:  # noqa: BLE001 - transport net
                logger.error("Unexpected error in %s: %s", fn.__name__, exc)
                return dict(err("invalid_parameter", f"Unexpected error: {exc}"))

        return _original_tool(*args, **kwargs)(safe_fn)

    return decorator


mcp.tool = _safety_net_tool  # type: ignore[assignment,method-assign]

# Register all tools via the handler families (wrapped by the safety net)
from src.tool_handlers import register_all  # noqa: E402

_executor = SubprocessRunner()
register_all(mcp, _executor)

# Restore the original decorator so any late registration is unwrapped-clean
mcp.tool = _original_tool  # type: ignore[assignment,method-assign]


if __name__ == "__main__":
    try:
        mcp.run()
    except KeyboardInterrupt:
        logger.info("Server stopped")
    except Exception as exc:  # noqa: BLE001 - fatal startup error
        logger.critical("Fatal: %s", exc)
        sys.exit(1)