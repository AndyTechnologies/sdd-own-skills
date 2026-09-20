---
name: gentle-ui
description: "Trigger: gentle-ai, Gentle-AI, diseño gentle, estilo gentle, interfaz visual, UI web, desktop, TUI, terminal, tema rose pine. Aplica los principios de diseño de Gentle-AI a UIs web, desktop y TUI."
license: MIT
metadata:
  author: andy
  version: "1.0"
---

# Gentle-AI Design System

## Cuándo usar

Siempre que generes o modifiques componentes de UI (web, desktop, TUI) para el ecosistema Gentle-AI o Gentleman Programming.

## Web UI

- **Colores**: fondo `#09090b`; tarjetas `#111113`; código `#18181c`; bordes `#ffffff12` (hover: `#ea188959`); texto `#fafafa` / `#a1a1aa` / `#52525b`; acento `#ea1889` (hover: `#ff6db0`, sutil: `#ea188926`).
- **Tipografía**: `Inter, system-ui, -apple-system, sans-serif`. Pesos: 400 cuerpo, 500 medium, 600 semibold, 700 bold, 800 extrabold. Código: `ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas`.
- **Estructura**: contenedor `max-w-6xl mx-auto px-4 sm:px-6 lg:px-8`. Navegación fija con `bg-black/80 backdrop-blur-xl border-b border-border`. `rounded-lg` (8px) para controles, `rounded-2xl` (16px) para tarjetas. Transiciones `transition-colors` en interactivos. Espaciado en múltiplos de 4px.

## TUI (terminal)

- **Tema Rose Pine**: fondo `#191724`; texto `#e0def4`; secundario `#908caa`; acento/selección `#c4a7e7`; encabezados `#ebbcba`; éxito `#9ccfd8`; error `#eb6f92`; advertencia `#f1ca93`.
- **Evitar** `#6e6a86` y `#31748f` para texto normal (contraste < 4.5:1).
- **Estructura**: cajas con bordes suaves, padding interno consistente. Encabezados en Mauve, acciones/estados activos en Lavender. Errores en Red, warnings en Yellow.

## Reglas generales

- Dark-first. Si generas modo claro, invierte la escala de grises manteniendo `#ea1889` como acento.
- Un solo acento cromático. No introduzcas colores adicionales fuera de la paleta definida.
- Jerarquía tipográfica clara: máximo 3 pesos distintos por vista.
- Bordes sutiles (`#ffffff12`), nunca líneas duras puras.
- Radios consistentes: 8px controles, 16px tarjetas.