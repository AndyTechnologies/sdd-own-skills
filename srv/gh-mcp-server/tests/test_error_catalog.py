"""El catalogo de ``error.type`` es un contrato, y un contrato se verifica.

El catalogo decia ser un "closed set" en el docstring de ``envelope.py`` y en el
spec, pero nadie lo verificaba. La auditoria lo pago caro: ``push_failed`` se
emitia de verdad y no estaba en la lista, y ``active_agents`` estaba en la lista
y no lo emitia nadie. El pin que cubria esto (T26) hacia ``grep -q "$et"`` sobre
el archivo entero: pasa si el nombre aparece en un comentario, y no detecta un
tipo de mas.

Estos tests cierran las dos direcciones:

- **emitido ⊆ catalogo**: lo garantiza ``err()`` rejecting unknown types, asi que
  un literal desconocido ya no puede viajar en un envelope. Este test lo afirma
  sobre el codigo real, incluida la excepcion que el propio ``err()`` lanza.
- **catalogo ⊆ emitido**: una entrada que nadie emite es un contrato muerto — el
  caller branching on it espera algo que nunca llega.

La derivacion de "que tipos se emiten" es un scan AST de verdad, no un grep: un
``err("tipo")`` partido en varias lineas tiene que contar igual, y un
``err("tipo")`` comentado NO tiene que contar. Un regex sobre el texto del
archivo cuenta las dos cosas mal, y esa es la razon de que la primera version de
este archivo fallara su propio test.
"""

from __future__ import annotations

import ast
import re
from pathlib import Path

import pytest

from src.envelope import ERROR_TYPES, UnknownErrorType, err

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
SPEC = ROOT.parents[1] / "openspec" / "specs" / "gh-git-mcp-server" / "spec.md"


def _err_calls(root: Path) -> list[tuple[Path, ast.Call]]:
    """Cada llamada a ``err(...)`` bajo *root*, con su archivo y su nodo."""
    calls: list[tuple[Path, ast.Call]] = []
    for path in sorted(root.rglob("*.py")):
        tree = ast.parse(path.read_text(), filename=str(path))
        for node in ast.walk(tree):
            if (
                isinstance(node, ast.Call)
                and isinstance(node.func, ast.Name)
                and node.func.id == "err"
            ):
                calls.append((path, node))
    return calls


def _emitted_types(root: Path | None = None) -> set[str]:
    """Tipos pasados como LITERAL a ``err(...)``.

    AST de verdad, no texto: asi un ``err("x")`` partido en varias lineas cuenta
    igual, y uno comentado no cuenta. Con un regex sobre el texto pasaban los dos
    casos, que era exactamente el defecto que este test queria cazar.
    """
    found: set[str] = set()
    for _path, call in _err_calls(root or SRC):
        if call.args and isinstance(call.args[0], ast.Constant) and isinstance(
            call.args[0].value, str
        ):
            found.add(call.args[0].value)
    return found


def _dynamic_err_calls() -> list[str]:
    """Call sites que pasan algo que NO es un literal — invisibles al scan."""
    dynamic: list[str] = []
    for path, call in _err_calls(SRC):
        if path.name == "envelope.py":
            continue  # la definicion de err() misma
        if not call.args:
            dynamic.append(f"{path}: err() sin argumentos")
            continue
        first = call.args[0]
        if not (isinstance(first, ast.Constant) and isinstance(first.value, str)):
            dynamic.append(f"{path}:{first.lineno}: err(<{type(first).__name__}>)")
    return dynamic


def _spec_types() -> set[str]:
    r"""La lista cerrada que declara el spec.

    La lista ocupa varias lineas y la lista la define su FORMA, no un terminador:
    son las lineas consecutivas que arrancan con un backtick (continuacion). Dos
    intentos de regex fallaron en esto y por el mismo motivo — ``$`` con ``re.M``
    corta en la primera linea, y ``(.*?)\n\s*\n`` se comia la linea del bullet
    siguiente e incluia ``confirm_required`` como si fuera un tipo. Parsear por
    lineas no depende de adivinar donde termina la lista.
    """
    lines = SPEC.read_text().split("\n")
    types: set[str] = set()
    collecting = False
    for line in lines:
        if "AND `error.type` covers:" in line:
            collecting = True
            types.update(re.findall(r"`([a-z_]+)`", line.split("covers:", 1)[1]))
            continue
        if collecting:
            # Continuacion: indent + backtick. Cualquier otra cosa cierra la lista.
            if re.match(r"^\s+`[a-z_]+`", line):
                types.update(re.findall(r"`([a-z_]+)`", line))
            else:
                break
    assert types, "el spec ya no declara la lista cerrada de error.type"
    return types


# ---------------------------------------------------------------------------
# err() valida
# ---------------------------------------------------------------------------


def test_err_rejects_type_outside_the_catalog() -> None:
    """Un ``error.type`` desconocido es un bug de programacion, no un dato.

    Los call sites pasan literales, nunca variables: un tipo desconocido en
    runtime solo puede ser un typo. Por eso ``err`` levanta en vez de normalizar
    en silencio — un envelope con ``type: "auth_requried"`` es indistinguible de
    uno valido para quien lo consume.
    """
    with pytest.raises(UnknownErrorType) as excinfo:
        err("auth_requried", "typo deliberado")
    assert excinfo.value.error_type == "auth_requried"


def test_err_accepts_every_catalog_type() -> None:
    """Ningun tipo del catalogo puede ser rechazado por la propia validacion."""
    for error_type in ERROR_TYPES:
        envelope = err(error_type, "mensaje")
        assert envelope["error"]["type"] == error_type


def test_error_types_is_a_tuple_not_a_string() -> None:
    """Un catalogo como string seria ``"auth_required" in ERROR_TYPES`` -> True
    para cualquier substring. Un set o tupla no tiene ese defecto."""
    assert not isinstance(ERROR_TYPES, str)
    assert len(set(ERROR_TYPES)) == len(ERROR_TYPES), "tipos duplicados en el catalogo"


# ---------------------------------------------------------------------------
# emitido ⊆ catalogo
# ---------------------------------------------------------------------------


def test_every_emitted_type_is_in_the_catalog() -> None:
    """El caso que el pin anterior no podia ver: un tipo emitido y no documentado."""
    emitted = _emitted_types()
    assert emitted, "el scan AST no encontro ningun err(...) — el scan esta roto"
    undeclared = emitted - set(ERROR_TYPES)
    assert not undeclared, (
        f"error.type emitidos que no estan en ERROR_TYPES: {sorted(undeclared)}"
    )


def test_emitted_types_ignore_commented_out_calls(tmp_path: Path) -> None:
    """Un ``err("x")`` comentado no es un tipo emitido.

    Es lo que el pin anterior hacia mal: ``grep -q "$et"`` sobre el archivo
    entero pasaba si el nombre estaba escrito en un comentario. Con AST el
    comentario desaparece antes de que haya algo que contar.
    """
    (tmp_path / "mod.py").write_text(
        'from src.envelope import err\n'
        'err("auth_required", "real")\n'
        '# err("comentado", "no cuenta")\n'
        '"""docstring con err("en_prosa", "tampoco cuenta")"""\n'
    )
    assert _emitted_types(tmp_path) == {"auth_required"}


def test_disabled_code_is_still_counted_and_that_is_known(tmp_path: Path) -> None:
    """Limite explicito del scan: codigo muerto SI cuenta, y es a proposito.

    Un ``if False: err("x")`` es una llamada valida para el AST, asi que el scan
    la ve. La primera version de este test afirmaba lo contrario y fallo — bien:
    un test que espera algo imposible se adapta al codigo en vez de medirlo.

    Que se cuente no daña: un tipo exageradamente contado solo hace que el
    catalogo exija un tipo que quizas no se emite, y eso es visible y barato de
    arreglar. Lo que NO se perdona es lo contrario —un tipo emitido fuera del
    catalogo—, y ese lo cubre ``err()`` elevando.
    """
    (tmp_path / "mod.py").write_text(
        'from src.envelope import err\n'
        'if False:\n'
        '    err("codigo_muerto", "se cuenta igual")\n'
    )
    assert _emitted_types(tmp_path) == {"codigo_muerto"}


def test_emitted_types_count_multiline_calls(tmp_path: Path) -> None:
    """Y en cambio un ``err(...)`` partido en lineas SI cuenta.

    El safety net de ``server.py`` los tiene asi, y un grep que exigiera el
    literal en una sola linea los perderia en silencio.
    """
    (tmp_path / "mod.py").write_text(
        'from src.envelope import err\n'
        'x = err(\n'
        '    "timeout",\n'
        '    "mensaje",\n'
        ')\n'
    )
    assert _emitted_types(tmp_path) == {"timeout"}


def test_every_err_call_site_passes_a_literal() -> None:
    """Completitud del scan: ningun ``err()`` recibe una variable.

    Un scan AST solo ve literales. Si alguien escribiera ``err(code, msg)``, ese
    tipo viajaria en el envelope sin estar en el catalogo y el scan no lo
    detectaria — el catalogo volveria a estar abierto, pero en silencio. Hoy no
    hay ningun call site dinamico; este test lo mantiene asi y, si aparece uno,
    dice exactamente donde.
    """
    dynamic = _dynamic_err_calls()
    assert not dynamic, (
        "err() recibe algo que no es un literal; el scan del catalogo no puede "
        f"verlo: {dynamic}"
    )


# ---------------------------------------------------------------------------
# catalogo ⊆ emitido (contratos muertos)
# ---------------------------------------------------------------------------


def test_catalog_has_no_dead_entries() -> None:
    """Un tipo documentado que nadie emite es una promesa que el caller no cumple.

    Asi se detecto ``active_agents``: estaba en el catalogo desde el change de
    worktrees, y el reporte de verificacion de aquel change preparations "32/32
    PASS" con un caso ``live-pid -> active_agents`` que el codigo no tenia.
    """
    dead = set(ERROR_TYPES) - _emitted_types()
    assert not dead, (
        f"error.type en el catalogo que ningun handler emite: {sorted(dead)}"
    )


# ---------------------------------------------------------------------------
# catalogo == spec
# ---------------------------------------------------------------------------


def test_spec_and_code_agree_on_the_catalog() -> None:
    """Docstring, codigo y spec: una sola verdad.

    El docstring ya no lista los tipos a mano (eso duplicaba la lista y permitia
    que divergieran en silencio); el catalogo vive en ``ERROR_TYPES`` y el doc
    apunta ahi. Lo que queda por verificar es que el spec no se quede atras.
    """
    assert _spec_types() == set(ERROR_TYPES), (
        "el spec y ERROR_TYPES no coinciden; el spec va atras o se adelanta"
    )
