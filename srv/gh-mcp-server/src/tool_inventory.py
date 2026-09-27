"""Superficie de tools del servidor MCP: inventario y derivacion desde el source.

Por que existe esto: el spec afirmaba la superficie como un conteo suelto
("26 tools in 5 families"). Un conteo no puede detectar drift — no dice QUE
tools son, asi que no puede avisar si una desaparecio ni si aparecio otra, y
las 21 que nunca se nombraban eran indistinguibles de las que si.

La regla que reemplaza al conteo es la IGUALDAD DE CONJUNTO en ambas
direcciones, entre las dos caras de la misma ecuacion:

  - el source: los decoradores ``@server.tool()`` registrados bajo
    ``src/tool_handlers/`` (derivado con ``ast``, no con grep: es preciso e
    inmune al formato, y el precedente T26 hardcodea nombres a mano, que es
    justamente lo que no servia);
  - la declaracion: ``tools.json``, la fuente unica legible por maquina.

Un inventario que no describe exactamente lo que el codigo registra no vale
nada; por eso los dos se comparan y ambos lados tienen que coincidir.

Por que es un modulo y no logica dentro del check: lo consumen DOS —
el guard RED de ``tests/run_red_checks.sh`` y ``tests/test_tool_inventory.py``.
Un guard que deriva de una forma y el test de otra vuelve a tener dos verdades
que pueden divergir, que es el mismo defecto que este modulo viene a matar.
"""

from __future__ import annotations

import ast
import json
import re
from pathlib import Path

INVENTORY_FILENAME = "tools.json"
HANDLERS_PACKAGE = "tool_handlers"

# Familias: la clave de cada familia es el stem del modulo que la registra, asi
# que el source y el inventario comparten vocabulario por construccion y no por
# convencion. El orden es el de registro de register_all().
EXPECTED_FAMILY_ORDER = (
    "remote_read",
    "remote_mutation",
    "local_read",
    "local_mutation",
    "worktree_mutation",
)

# El total no se escribe en tools.json a mano: se deriva de la lista. Este es el
# unico lugar donde el numero vive, y el unico lugar donde puede quedar viejo.
EXPECTED_TOTAL = 29

# Seccion del spec que debe enumerar la superficie. Va desde el heading del
# requirement hasta el proximo requirement, para no matchear texto de otra parte.
SPEC_REQUIREMENT_HEADING = "### Requirement: Tool surface completeness"
SPEC_REQUIREMENT_RE = re.compile(
    r"^###\s+Requirement:.*$", re.MULTILINE
)


def server_root() -> Path:
    """Raiz del servidor MCP (el directorio que contiene tools.json)."""
    return Path(__file__).resolve().parent.parent


def _is_tool_decorator(node: ast.expr) -> bool:
    """True si el decorador es una llamada ``X.tool(...)`` o el atributo ``X.tool``.

    Cubre las dos formas que se ven en el codigo (``@server.tool()`` y
    ``@server.tool``), para no depender de si el autor puso parentesis.
    """
    target = node.func if isinstance(node, ast.Call) else node
    return isinstance(target, ast.Attribute) and target.attr == "tool"


def derive_from_source(handlers_dir: Path) -> dict[str, list[str]]:
    """Familia -> lista ordenada de tools registradas en el source.

    Familia = stem del modulo (remote_read, local_mutation, ...). Solo considera
    funciones decoradas con ``@server.tool()``; cualquier otra funcion del
    modulo es helper y no es parte de la superficie.
    """
    families: dict[str, list[str]] = {}
    for module in sorted(Path(handlers_dir).glob("*.py")):
        if module.name == "__init__.py":
            continue
        names = [
            node.name
            for node in ast.walk(ast.parse(module.read_text(encoding="utf-8")))
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
            and any(_is_tool_decorator(d) for d in node.decorator_list)
        ]
        if names:
            families[module.stem] = names
    return families


def load_declared(inventory_path: Path) -> dict[str, list[str]]:
    """Familia -> lista declarada en tools.json."""
    raw = json.loads(Path(inventory_path).read_text(encoding="utf-8"))
    return {family: list(tools) for family, tools in raw["families"].items()}


def total(families: dict[str, list[str]]) -> int:
    """Total de tools derivado de las listas (nunca de un numero escrito a mano)."""
    return sum(len(tools) for tools in families.values())


def _names_by_family(families: dict[str, list[str]]) -> dict[str, str]:
    """Tool -> familia, invertida. Detecta duplicados en el propio inventario."""
    mapping: dict[str, str] = {}
    for family, tools in families.items():
        for name in tools:
            mapping.setdefault(name, family)
    return mapping


def check_equality(
    derived: dict[str, list[str]], declared: dict[str, list[str]]
) -> list[str]:
    """Igualdad de conjunto en AMBAS direcciones, mas la familia de cada tool.

    Reporta los NOMBRES, no la cantidad: "faltan 2 tools" es tan inaccionable
    como el conteo que este check reemplaza.
    """
    problems: list[str] = []
    derived_by_name = _names_by_family(derived)
    declared_by_name = _names_by_family(declared)

    for name in sorted(set(derived_by_name) - set(declared_by_name)):
        problems.append(
            f"en el source pero ausente de {INVENTORY_FILENAME}: {name} "
            f"({derived_by_name[name]})"
        )
    for name in sorted(set(declared_by_name) - set(derived_by_name)):
        problems.append(
            f"declarado en {INVENTORY_FILENAME} pero no registrado en el source: {name}"
        )
    for name in sorted(set(derived_by_name) & set(declared_by_name)):
        if derived_by_name[name] != declared_by_name[name]:
            problems.append(
                f"familia incorrecta para {name}: source={derived_by_name[name]} "
                f"vs inventario={declared_by_name[name]}"
            )
    for family in sorted(set(derived) ^ set(declared)):
        problems.append(
            f"familia presente en un lado y no en el otro: {family} "
            f"(source={'si' if family in derived else 'no'}, "
            f"inventario={'si' if family in declared else 'no'})"
        )
    for family, tools in sorted(declared.items()):
        duplicates = sorted({n for n in tools if tools.count(n) > 1})
        if duplicates:
            problems.append(
                f"tools duplicadas en {INVENTORY_FILENAME} dentro de {family}: "
                f"{', '.join(duplicates)}"
            )
    return problems


def check_total(declared: dict[str, list[str]]) -> list[str]:
    """El total derivado de la lista tiene que ser el esperado."""
    derived_total = total(declared)
    if derived_total != EXPECTED_TOTAL:
        return [
            f"total derivado de la lista = {derived_total}, esperado {EXPECTED_TOTAL} "
            f"({', '.join(f'{f}={len(t)}' for f, t in sorted(declared.items()))})"
        ]
    return []


def check_family_order(declared: dict[str, list[str]]) -> list[str]:
    """El inventario debe cubrir las familias en el orden en que se registran."""
    problems: list[str] = []
    for family in EXPECTED_FAMILY_ORDER:
        if family not in declared:
            problems.append(f"familia esperada ausente en el inventario: {family}")
    for family in sorted(set(declared) - set(EXPECTED_FAMILY_ORDER)):
        problems.append(f"familia no prevista en el inventario: {family}")
    return problems


def spec_requirement_text(spec_path: Path) -> str:
    """El bloque del requirement de superficie, sin el resto del spec."""
    text = Path(spec_path).read_text(encoding="utf-8")
    start = text.find(SPEC_REQUIREMENT_HEADING)
    if start == -1:
        return ""
    rest = text[start + len(SPEC_REQUIREMENT_HEADING) :]
    next_heading = SPEC_REQUIREMENT_RE.search(rest)
    return rest[: next_heading.start()] if next_heading else rest


def check_spec_enumeration(declared: dict[str, list[str]], spec_path: Path) -> list[str]:
    """Cada tool del inventario tiene que estar NOMBRADA en el requirement.

    Es el eslabon que cierra la cadena: si el spec vuelve a afirmar un conteo,
    esta comprobacion lo detecta porque los nombres no estan.
    """
    text = spec_requirement_text(spec_path)
    if not text:
        return [
            f"el spec no tiene el requirement '{SPEC_REQUIREMENT_HEADING}' "
            f"({spec_path})"
        ]
    problems = [
        f"el spec no nombra la tool {name} en '{SPEC_REQUIREMENT_HEADING}'"
        for family, tools in sorted(declared.items())
        for name in tools
        if not re.search(rf"(?<![\w.]){re.escape(name)}(?![\w])", text)
    ]
    return problems


def all_problems(
    inventory_path: Path | None = None, spec_path: Path | None = None
) -> list[str]:
    """Todos los problemas del inventario, en orden de severidad."""
    root = server_root()
    inventory_path = Path(inventory_path) if inventory_path else root / INVENTORY_FILENAME
    if not inventory_path.is_file():
        return [f"no existe el inventario legible por maquina: {inventory_path}"]

    declared = load_declared(inventory_path)
    derived = derive_from_source(root / "src" / HANDLERS_PACKAGE)

    problems = check_equality(derived, declared)
    problems += check_family_order(declared)
    problems += check_total(declared)
    if spec_path is not None:
        problems += check_spec_enumeration(declared, spec_path)
    return problems


def _main(argv: list[str]) -> int:
    """CLI: imprime un problema por linea y sale distinto de cero si hay alguno.

    El guard RED de tests/run_red_checks.sh consume esta salida linea por linea
    para que cada fallo diga QUE drift exacto ocurrio.
    """
    spec: Path | None = None
    args = list(argv)
    if "--spec" in args:
        index = args.index("--spec")
        spec = Path(args[index + 1])
        del args[index : index + 2]
    if args == ["--problems"]:
        problems = all_problems(spec_path=spec)
        for problem in problems:
            print(problem)
        return 1 if problems else 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    import sys

    raise SystemExit(_main(sys.argv[1:]))
