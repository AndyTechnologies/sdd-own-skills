"""Tool handler families — register_all wires every family into the MCP server."""

from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from fastmcp import FastMCP

    from src.executor import ExecutorProto


def register_all(server: FastMCP, executor: ExecutorProto) -> None:
    """Wire every handler family (5) into *server* with shared *executor*."""
    from .remote_read import register as register_remote_read
    from .remote_mutation import register as register_remote_mutation
    from .local_read import register as register_local_read
    from .local_mutation import register as register_local_mutation
    from .worktree_mutation import register as register_worktree_mutation

    register_remote_read(server, executor)
    register_remote_mutation(server, executor)
    register_local_read(server, executor)
    register_local_mutation(server, executor)
    register_worktree_mutation(server, executor)