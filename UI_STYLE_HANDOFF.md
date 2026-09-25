# Actually Useful Turtles — UI Style Handoff

Permanent style reference. Read this before any UI change.

**Reference:** [MikaylaFischler/cc-mek-scada](https://github.com/MikaylaFischler/cc-mek-scada) —
its *graphical language* only: layout method, information density, component
consistency, interaction patterns. Not its application layout, branding,
wording or palette.

**Goal:** "Actually Useful Turtles, with the visual discipline and industrial
HMI feel of cc-mek-scada." When choosing between looking more like
cc-mek-scada and fitting the turtle system better, **fit the turtle system.**

---

## Palette — established, do not replace

These come from `classTaskGroup.lua` (`statusToColor`) and must keep their
meanings:

| Status | Color |
|---|---|
| `new` | white |
| `started`, `resumed` | green |
| `partially_started`, `partially_resumed` | yellow |
| `completed` | lightBlue |
| `cancelled` | orange |
| `error` | red |
| `deleted` | gray |

Semantic roles already in use across the project:

- **green** — positive / selection / valid / active
- **purple / magenta** — turtle, home, project identity
- **red** — destructive / error / stop
- **orange, yellow** — warning / secondary
- **cyan, lightBlue** — navigation / control
- **gray, black** — structure / background / map data

Only add a color when the palette genuinely cannot express the state. Prefer
consistency over more colors.

---

## Conventions established by the map screen

From the map-screen SCADA pass, these are house style now:

- **Plates** — a filled `colors.gray` rectangle behind a group of related
  values, with dimmed captions and white values on top. Use `Box` for the
  plate and set each `Label`'s `backgroundColor` to match.
- **Solid buttons** — filled blocks, dark glyph. Arrows use CraftOS triangle
  glyphs; close uses `×`.
- **Right-aligned numerics** so digits don't jump as values change.
- **Framed panel** for a grouped set of toggles, each lamp in the color of the
  thing it controls.
- **One source of truth for positions** — a `layout` table, so drawn cells and
  click areas cannot drift apart.
- Clicking a plate or panel must not trigger the surface underneath.

## Draw order (framework fact)

`BasicWindow:redraw()` fills the window background first, then walks children
from `objects.last` backwards. `addObject` prepends, so **children added later
draw on top**. Therefore:

- register plates and strips **before** the labels that sit on them
- anything drawn in an overridden `redraw()` *after* `BasicWindow.redraw(self)`
  paints over the children

## Visual language

- **Flat panels** over decorative boxes; use background changes to define
  sections. Avoid boxes inside boxes inside boxes. A per-row box inside a list
  panel is already one nesting level too many — prefer a status strip plus a
  divider.
- **Header strips** — full-width filled plate, title left, compact state right.
- **Hierarchy** — header, primary state, important values, secondary detail,
  controls.
- **Compact spacing** — 1-character gaps, aligned columns, no large dead areas.
- **Status indicators** — small colored cells / lamps / vertical strips beside a
  label, rather than sentences. Color carries state.
- **Vertical status strips** beside list rows, where they help scanning:

  ```
  ▌ DTX-001  MINING
  ▌ DTX-003  WAITING
  ▌ DTX-004  BLOCKED
  ```

- **Controls** feel like terminal controls: consistent dimensions, obvious
  disabled state, selection via foreground/background change rather than extra
  borders. Destructive controls stay visually distinct.
- **Borders** deliberately: one major panel, a map viewport, an important
  subsystem. Not around everything.
- **Glanceable** — standing at the monitor you should see: system healthy?
  all turtles online? anything blocked or waiting? a group running? mapping
  active? errors?
- Keep the graphical UI distinct from shell/debug output. Don't remove
  diagnostics; don't make the UI depend on them.

Avoid looking like: a mobile app, a web dashboard, Material Design, a game HUD,
or flashy sci-fi. Aim for purpose-built industrial ComputerCraft control
software.

## Map UI

The map stays visually dominant — do not bury it in chrome. Overlays use the
existing semantic colors. Temporary elements (area selection, task bounds,
focus, route previews) behave as UI state, never as permanent map data; group
outlines are keyed by group id and cleaned up on completion, cancellation and
deletion.

**Flow/process diagrams are deliberately out of scope.** The map already
represents the system spatially and the current behavior is what's wanted — do
not add flow-diagram visualisation to it.

## Component reuse

Evolve the existing `Box`, `Frame`, `Label`, `Button`, `ToggleButton`,
`ScrollBar`, `BasicWindow`, `Window`, `MapDisplay` primitives rather than
hand-designing each screen. Move toward shared primitives: panel, header,
status indicator, button, tab, sidebar item, key/value row, divider, progress
indicator, alert indicator.

Drift visual constants toward a central style table (`UI_STYLE.background`,
`.panel`, `.header`, `.text`, `.label`, `.disabled`, `.active`, `.warning`,
`.error`, `.navigation`, `.selection`) **incrementally, as screens are
touched** — never as a standalone architecture rewrite.

## Incremental redesign rule

This project is redesigned screen by screen.

1. Inspect the existing implementation first.
2. Identify the information and actions that must remain.
3. Change only the requested screen or component.
4. Preserve all current functionality.
5. Preserve existing meaningful colors.
6. Reuse the existing UI architecture.
7. Do not redesign unrelated screens.
8. Never change turtle / mining / network / task logic for a cosmetic task.
9. No giant rewrites.
10. Leave the project working after every step.

## Progress

| Screen | State |
|---|---|
| Map screen | SCADA pass done — plates, solid buttons, LAYERS panel, framed viewport |
| Groups page | SCADA pass done — header strip with counts, status strip per row, plates, key/value block |
| Turtle list | not yet |
| Turtle details | not yet |
| Storage | not yet |
| Main menu | not yet |
