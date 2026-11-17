# UI tokens and tasks-here alignment

Reference: sibling `tasks-here`, `lib/ui/theme.dart`, sidebar, GrowIn and spring motion helpers. Reviewed 2026-11-08. The reference checkout was read only.

## Token ownership

- `lib/ui/theme.dart`: `Palette` for invariant colors, `Skin` for light/dark surfaces and text, `Motion` for interaction timing and physical springs, `DesktopUx` for interaction geometry.
- `lib/ui/design_tokens.dart`: `UiType` typography roles, `UiRadius` component corners, `UiSpace.sN` shared logical-pixel scale, `UiLayout` independent feature extents, syntax and tag palettes.
- Widgets consume tokens instead of declaring UI color literals, font sizes, corner radii, repeated padding and control extents. Structural zeroes, unitless opacity/leading/scale ratios, indices and data values are not pixel tokens.
- `cover_presets.dart` is the content palette for selectable cover artwork. Persisted tag/cover colors remain user data; missing tag colors fall back to the accent through `Palette.stored`.

## Alignment applied

- Preserved the matching neutral light/dark and Mica palettes, accent, compact density, no-ripple feedback, clamped desktop scrolling and existing menu keyboard navigation.
- Added the reference's floating notice, filled button and visible desktop scrollbar themes; opaque scaffold when Mica is unavailable.
- Shared text roles follow the reference's 13px body, 14px title, 12px caption and 16px editor text. Notes-specific page titles and emoji retain separate roles.
- Menus/buttons use 8px corners, sidebar rows 7px, dialogs 12px. Notes-specific content dimensions remain independent tokens.
- Modal dimming resolves through Skin.scrim; code surfaces, controls and toolbar use Skin rather than private widget palettes.
- Hover/color/opacity changes use Motion.micro (80ms) and respect reduced motion. Sidebar disclosure and code folding use physical springs. Code folding preserves presentation value/velocity on reversal and settles immediately when reduced motion is enabled. Existing GrowIn already uses the matching spatial spring (mass 1, stiffness 300, damping 25).
- Keyboard result-list selection scrolls directly into view, avoiding a timed spatial easing animation.

## Verification

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: 156 passed, 3 failed. All remaining failures are Windows file-lock errors while deleting temporary SQLite migration databases: schema 8 in `database_paging_test.dart`, schema 7 (trashed true/false) in `incremental_blocks_test.dart`. Sequential execution also reproduces these cleanup errors. Database implementation and these tests were not changed by this task.
- Focused UI suite: 36 passed (code block, sidebar DnD, quick search, page link picker, icon/cover picker, export/import dialog, database block, trash and UI/UX tests).
- Final motion/sidebar regression run: 10 passed, including newly extended mid-flight reversal and reduced-motion assertions.
- Source scan: no raw `Colors.*`, hexadecimal `Color(...)`, numeric `fontSize:` or numeric `Radius.circular(...)` outside theme/token/content-palette files. `git diff --check` passed.
- Verification logs: `build/logs/flutter-analyze-verified.log`, `build/logs/flutter-test-verified.log`, `build/logs/ui-test.log`, `build/logs/motion-test-final.log` (ignored build artifacts).

This is source and widget-test validation. No side-by-side running-window visual inspection, release build or animation performance measurement was performed; exact visual parity and frame-rate targets are not claimed.

## Page menu readability (2026-11-09)

- Page and sidebar context menus share a 340 logical-pixel width, constrained by the available viewport.
- Section headers use the 11px small role, semibold weight and the full hint color. Body labels stay at 13px; the platform font remains inherited, matching Tasks Here.
- Selected menu choices have a checkmark as well as accent text.
- Page action shortcuts use Command/Option on macOS and Ctrl/Alt elsewhere. Context menus do not advertise global shortcuts that operate on the selected page. The unregistered Copy Markdown shortcut is omitted.
- Import/export has its own localized section name; it no longer uses the backup dialog title.

## Tasks Here source parity (2026-11-09)

- Inspected the reference's `ui/theme.dart`, `common/menu.dart` and `calendar/task_context_menu.dart` read-only. Both apps already inherit the same Material 3 typography with 13px regular menu labels, 34px rows, 8px corners and 12px horizontal insets. No independent font family is introduced.
- App action icons now come from `ui/common/app_icons.dart`, using the reference's outline Cupertino family. Applied across page/sidebar menus, editor controls, database controls, search, dialogs, account and trash. Page emoji and cover content are preserved.
- Page menu icons use the shared glyph path (15px, muted at rest, text on hover, destructive tone for deletion), matching Tasks Here. This replaces private 14px icons that inherited the body color.
- Notes-specific group headers are quiet 12px regular captions in sentence case. The reference task action menu has no group headers.
- Context menus use 280px; the longer page options menu uses 320px to accommodate localized actions and Windows shortcuts. These content-driven extents intentionally differ from the reference's short 200px task menu.
- These rules supersede the earlier width and uppercase-header notes above.

## Editor typography and code (2026-11-09)

- The source comparison confirmed a Flutter Material theme in both apps, not a CSS font stack. UI typography remains inherited from Tasks Here; editor prose now uses 14px regular type (13px in small-text mode), 1.4 line height and 2px vertical paragraph padding.
- Code uses the platform monospace (Consolas / Menlo), 12px regular type and 1.4 leading. Code surfaces use Skin.codeSurface with no outer border and 16px horizontal / 12px vertical insets. Hidden actions no longer reserve an empty header strip.
- Shell aliases sh/shell/zsh normalize to Bash. Command words are highlighted; double-dash flags and URL slashes do not start Shell comments. Explicit plain text remains plain. Strings use a green syntax token in both appearances.
- Inline code uses 12px monospace and a neutral surface with red text. Paragraph code backgrounds are drawn from the real text selection boxes with 3px corners; no WidgetSpan or document-offset substitution is used. Other block types retain the standard editor text background. The paragraph adapter preserves the upstream selection, link and nested-block behavior.
- New tests cover Shell tokens and plaintext, and inline-code text offsets/editing in both themes. A Windows-font render is saved in build/logs/editor-typography-preview.png. This is widget rendering, not a live-window IME/performance audit.

## Mica code surface regression (2026-11-09)

- Code surfaces no longer read the sidebar color: Mica intentionally clears that color. Code and inline-code backgrounds use the opaque light/dark content palette, independent of native window transparency.
- Verified both themes with Mica on/off, including inline-code editing, and captured a Mica widget render. Code/folding regression suite: 15 passed.

## Database interactions (2026-11-09)

- Text/title cells open a bounded multiline editor above the grid. Text can be selected natively, including across wrapped lines. Outside click, focus loss, Tab and Ctrl/Cmd+Enter save; Escape cancels. The overlay does not consume outside taps, so another cell can open with one click. Deferred title updates are applied after an untouched editor closes; local edits retain the existing commit contract. Open editors close when their cell is disposed.
- Grid selection supports cross-cell drags and Shift-click rectangles. Ctrl/Cmd+C copies TSV with quoted newlines/tabs and escaped quotes; tag IDs resolve to labels. Ctrl/Cmd+A selects the current loaded page, Escape clears the range. Selection is reset on sorting/paging or column reorder. The existing fixed-height virtual row viewport is preserved.
- Empty-field hints no longer appear/disappear on hover. Inline fields reset horizontal text scroll on blur. URL action slots retain their geometry when hidden. Popover elevation uses existing Skin/UiRadius tokens, 13px regular body text (medium titles), and 1.4 leading. No spatial hover animation or row resizing is introduced.
- Integration tests exercise range copy inside AppFlowyEditor, Shift-click from an expanded cell, native mouse text selection, clipboard quoting, outside-save/Escape and title concurrency. Full suite: 262 passed; three known Windows SQLite cleanup failures remain. This is widget/integration validation, not a live native-window IME or frame-rate measurement.

## Unified database cell editors (2026-11-09)

- Typed text/title, numbers/durations and URLs use one shared popup style. The popup
  aligns with the full cell frame in overlay-local coordinates; explicit standard
  input density preserves 8px content insets despite the compact application theme.
- Shared editor dimensions live in UiLayout: 240px minimum, 480px for long URLs,
  420px maximum height, constrained to the available overlay. URLs wrap instead of
  hiding the start of the value through horizontal scrolling during editing.
- Font roles remain 13px body, 1.4 leading, regular values and medium titles. The
  duration clock and validation feedback stay in the same container. Grid rows keep
  their fixed 36px height while the editor grows above them.
- Scroll/resize saves and closes the editor so it cannot drift from its anchor.
  Both themes and nested overlays have geometry/caret assertions. The render at
  build/logs/cell-overlay-alignment.png uses the Windows system font for inspection.

## Database whole-range selection (2026-11-09)

- The left gutter selects whole rows; Shift extends and double-click opens the row.
  Checked outline glyphs stay visible for selected rows. Column type glyphs select
  columns, while captions retain property menus and resize handles retain their role.
- Full-column selection shades the corresponding header. All ranges use the existing
  accent rectangle; row height, cell text position and virtualization stay unchanged.
- Selection size sits beside save status in the footer, using the 12px caption role:
  rows × columns and total cells. It is localized, announced as a live region, and
  scoped to the current loaded page. It disappears while another control owns focus.
- Edge autoscroll follows pointer proximity through the existing scroll controllers;
  it introduces no hover geometry animation. Release/cancel, focus/lifecycle changes
  and scroll limits stop its frame ticker.

## Full-width page frame and centered content (2026-11-09)

- The page surface fills the available viewport. Its toolbar stays outside the
  editor's content-width constraint, with the options button 16px from the right
  edge in both width modes. The toolbar remains fixed while the document scrolls.
- Standard page content uses AppFlowy's centered 820px maximum width including
  40px side insets. Title/icon, paragraphs, subpages and backlinks share the same
  column. Full-width mode removes the content maximum while preserving its insets.
- Covers are full-bleed across the editor viewport, without the former 40px inset
  or rounded banner corners; the gradient fills the full existing 148px height.
  Header and content constraints are separate, so changing text width does not
  move or resize the cover or the top-right options control.
- Page emoji use a fixed 64px centered tile with a 32px overlap at the cover edge.
  The whole tile, including its upper half, remains hit-testable. Native emoji
  fallbacks are explicit. There is no separate Remove icon button in the header;
  removal remains available inside the picker opened by the tile.
- Change/remove cover actions use 32px icon-only controls (photo/trash), with
  localized tooltips and accessible labels. Add icon/cover placeholders retain
  their existing hover actions. Normal save status is an icon with a tooltip;
  saving uses the same compact slot. Error/conflict icons stay descriptive through
  tooltips and preserve retry/compare actions.
- Emoji picker header text now flexes so its controls fit with longer localized
  labels. It no longer overflows when opening the page icon picker.

Verification: 35 focused tests passed, including seven new page-geometry/action
checks at 320px and 1600px in both appearances. Tests cover centering, full-width
switching, full-height surface, full-bleed cover, corner actions, emoji centering,
upper-overlap click, picker removal and cover controls. Full suite: 347 passed;
the same three known Windows SQLite migration cleanup failures remain. Analyzer:
no errors, nine existing warnings/info. A real widget render with Segoe UI,
Segoe UI Emoji and the bundled Cupertino icon font was inspected at
build/logs/page-header-layout.png; this is not a live installed-window audit.
Logs: build/logs/page-layout-targeted.log, build/logs/page-layout-geometry.log,
build/logs/page-layout-all.log, build/logs/page-layout-analyze.log.

## Page switching without overlapping documents (2026-11-09)

The content card no longer wraps live pages in AnimatedSwitcher. The previous
crossfade kept both PageEditorView trees alive in a Stack while blending their
text, headers and toolbars. Switching now unmounts the outgoing document immediately;
the incoming page shows its normal loading state until ready. Same-page rebuilds
retain the keyed editor. Card styling and document save/load guards stay intact.

Six new HomeScreen integration cases inspect every transition frame in both themes
with reduced motion on/off, a delayed load completed after a newer page is selected,
and title/body changes flushed when leaving their original page. There is at most
one mounted page/header/AppFlowy editor at each inspected frame. Focused regression:
29 passed. Logs: build/logs/page-switch-targeted.log, build/logs/page-switch-all.log,
build/logs/page-switch-analyze.log.

Page-switch verification: full suite 353 passed with the same three existing Windows
SQLite migration cleanup failures. Analyzer: no errors, nine existing warnings/info.

## Cover hover controls and panel-top mode (2026-11-09)

Cover controls now fade in only while the pointer is over the cover. Outside that
region they are transparent, ignore pointer input, cannot receive focus and are
excluded from semantics; invisible buttons cannot be activated accidentally. The
new up/down action moves the cover to the top edge of a normal page's panel or
returns it below the toolbar. Its direction/tooltip describe the reverse action.

The preference is stored per page in _notes_here_page.coverToTop, defaults to false,
and shares existing backup/sync metadata without a schema migration. Other page
settings and unknown metadata are preserved. Row peeks retain their dedicated frame
and do not expose a normal-page metadata toggle.

The document moves through one AnimatedPadding; no second editor or crossfade is
introduced. Cover-control positioning uses the matching duration/curve, keeping
its screen position stable while the cover moves. Both honor reduced motion. The
fixed toolbar remains in its corner, uses the matching cover background at panel
top, and gives its light status/options icons a compact contrast surface. Its cover
background also prevents scrolling document text from showing through the toolbar.
Removing the cover restores the normal toolbar; the saved preference remains for
future covers. The centered content width and fixed icon-tile alignment are kept.

Verification: 20 focused checks passed, including four new hover/persistence/toggle
cases and narrow dark-layout/removal checks. All 11 page geometry checks pass.
Full suite: 357 passed; the same three existing Windows SQLite cleanup failures
remain. Analyzer: no errors, nine existing warnings/info. The inspected widget
render at build/logs/cover-to-top-preview.png uses Windows fonts and bundled icons.
Logs: build/logs/cover-top-targeted.log, build/logs/cover-top-geometry.log,
build/logs/cover-top-all.log and build/logs/cover-top-analyze.log.


### Database column drag (2026-11-09)

Column drag previews retain the header width, height, body font size and weight. The preview moves horizontally with its original grab offset; the source remains visible at 35% opacity without changing table geometry. A leading insertion line indicates a move to the left; a trailing line indicates a move to the right, matching repository target-index semantics. Title columns remain fixed. Typed drag payloads reject columns from other databases and unrelated string drags. Stable column keys preserve header state when columns reorder.

Validation: `database_column_drag_test.dart` covers both directions, diagonal pointer motion, source visibility, preview geometry, cleanup, title-column protection and both themes. The selection-controls and repository suites also pass (16 tests total). Analyzer reports the same nine existing issues outside this change.


### Smooth desktop wheel scrolling (2026-11-09)

Pages and database tables interpolate discrete mouse-wheel steps over 140 ms with ease-out cubic motion. Consecutive notches accumulate distance per ScrollPosition; reversing direction immediately drops the pending distance in the previous direction. Horizontal wheels and Shift+wheel preserve native axis selection. The pointer-signal resolver chooses a single innermost movable viewport, allowing vertical scrolling to pass from an exhausted table to its page. Normal drag/scrollbar/programmatic scrolling cancels the wheel animation. Trackpad signals and reduced-motion settings retain native behavior.

`SmoothWheelRegion` sits inside each viewport, before its native wheel handler. The AppFlowy page adapter wraps full-width list items, including header, footer and side margins, while retaining the original item builder, virtualized list controllers, listeners, layout and selection logic. Its list type currently requires one documented internal import from the pinned AppFlowy dependency; review this adapter when upgrading that dependency. Database rows retain stable root keys. Wheel animation keeps content hit-testable so subsequent wheel events and text selection remain reachable.

Validation: `smooth_wheel_scroll_test.dart` exercises interpolation, bursts, reversal, horizontal/Shift input, nested bounds, reduced motion, trackpad signals, programmatic interruption, disposal, and the real virtualized editor's side margins. `smooth_wheel_database_test.dart` checks both axes on an actual repository-backed table and verifies that its parent page does not also scroll.

Full regression run: 366 tests passed; the same three pre-existing Windows SQLite temporary-directory cleanup failures remain in migration tests. Analyzer: nine existing issues, no new diagnostics.


### Database column resizing (2026-11-09)

Resize widths are calculated from the header-local pointer displacement and the width captured on pointer down, rather than adding each event delta to a potentially stale widget width. The boundary follows the pointer 1:1 even when several mouse events arrive between frames or the UI is transformed. The former 600 px maximum is removed; minimum widths remain 115 px for text-like columns and 60 px for checkboxes. Release/cancel saves the last calculated visible width instead of the last rebuilt width. An unchanged drag does not write to the repository.

Validation: five regression cases cover batched movement of 300 px, growth beyond 600 px, frame-by-frame dragging under 1.5x scaling, both minimum widths, cancellation, and clicking without a change. These tests and the drag, selection-controls and real database wheel suites pass (16 tests total). Analyzer: same nine existing issues.


### Page emoji optical alignment on Windows (2026-11-09)

The 64 px page-icon tile and its cover overlap remain geometrically centered. Segoe UI Emoji's visible artwork sits below the typographic line-box center, so Windows applies a -3.5 px optical correction to the glyph only. Other platforms retain their native placement. The existing native-font preview test now measures the actual orange lightning pixels, verifying that the upper and lower white gaps differ by at most one pixel. All 17 page-layout and page-switching tests pass.


### Page block reordering (2026-11-09)

Top-level page blocks expose a six-dot grip in the existing left gutter on hover or keyboard focus. Dragging only the grip moves the complete block; the content retains its native text selection, code controls and table interactions. A compact preview uses plain text rather than another live editor. The source dims, and a two-pixel accent insertion line marks the upper/lower half of the target. Header/title and footer items remain outside the movable set. Typed drag payloads reject unrelated and cross-editor drops.

Clicking the grip opens the standard popover with the available Move above / Move below actions. Moving retains node metadata and descendants, remaps the current selection, and records one isolated editor transaction. Ctrl+Z and redo restore the order independently from adjacent typing. The editor keyboard service regains focus after moving from the menu or a drop. Existing autosave persists the new order. Read-only editors and detached/stale nodes cannot be mutated. The virtualized page adapter remains enabled for normal pages and row peeks; no extra editor instance is created.

Validation: eight new tests cover code metadata, nested list/database references, selection remapping, isolated undo/redo, no-op and stale targets, light/dark drag feedback and line placement, menu Ctrl+Z, cancelled dragging, and production autosave/reopen. The native-font preview is in `build/logs/block-reorder-preview.png`. Full suite: 379 passed, with the same three pre-existing Windows SQLite cleanup failures. Analyzer: nine existing issues, no new diagnostics.


### Compact code title panel (2026-11-09)

Code blocks use a separate, always-visible header above the code: fold chevron and editable name on the left, language/copy/actions on the right. The header uses the existing muted code-badge surface without an outer border. Copy excludes the title; Paste is available in the secondary actions popover. On narrow blocks the actions move below the title instead of overlapping it. Native IconButtons support keyboard focus.

The optional `title` node attribute follows existing page persistence, backup and sync; legacy blocks show an empty name placeholder. Editing the native title field temporarily disables document shortcuts and clears the code selection, keeping native paste/typing out of the code delta. Title edits are isolated from adjacent editor changes, and external node updates/undo synchronize the title field. Read-only mode permits copying but disables content, title, language and fold mutations.

Folding now hides the complete code body, including short snippets, leaving the header accessible. The existing spatial spring is retained with a zero-height folded body; the former 130 px preview and Show more overlay are replaced by the header chevron. Clipped folded content cannot receive pointer input or appear in semantics. Reduced-motion and mid-animation retargeting remain supported. Code text keeps its existing 12 px monospace style, highlighting and body padding.

Validation: seven new panel tests cover legacy names, geometry, native title paste, undo, clipboard contents, language/fold/move metadata retention, narrow large-text layouts in both themes, read-only state and production save/reopen. Existing code and reorder tests pass with updated folding expectations. Native-font preview: `build/logs/code-panel-preview.png`. Full suite: 386 passed; the same three existing SQLite cleanup failures remain. Analyzer has no new diagnostics.


### Code fold endpoint stability (2026-11-10)

Code-body height uses the existing critically damped `Motion.spring` instead of the elastic spatial spring. The elastic spring crossed zero and was clipped; its return swing briefly reopened the body, producing a visible terminal twitch (reproduced up to 1.98 px in a 180-line snippet). Normalized spring distance/velocity tolerances are now 1e-6 / 1e-5 so long snippets also settle without a visible endpoint snap. Retargeting retains current progress and velocity; reduced-motion behavior remains unchanged. Other application springs are unchanged.

Validation: three frame-by-frame regressions (3, 40 and 180 lines) failed before the fix and pass after it, checking monotonic closing height, last-pixel motion and settled geometry. All 19 fold/code/panel tests pass, including spring reversal and accessibility preference changes. Analyzer: same nine existing issues.


### Trash aligned to Tasks Here (2026-11-10)

Trash uses Tasks Here's 720 px content column, 40 px desktop top padding, 26 px heading and unframed 48 px rows. The former enclosing border, row separators, heading icon tile and count badge are removed. Item titles use 15 px regular text; parent page/database names appear below in 12 px muted text when available. Page/database/emoji leading icons retain their content meaning. The title and red-tinted Empty Trash pill share a row, and stack on narrow or large-text layouts.

Restore and permanent delete are neutral icon-only IconButtons, using the same Material restore/delete glyphs as the supplied Tasks Here screen. Empty Trash uses its sweep glyph and destructive pill treatment; row deletion becomes red on hover/focus. Native keyboard activation and tooltips remain available. Existing restore/delete operations and Empty Trash confirmation are retained. Empty-state and failure text are localized.

A single reactive UNION query joins parent titles for pages, database rows and databases, observes both tables, and preserves the existing set of trash entries. It avoids per-row lookups and updates subtitles when parents are renamed. No schema migration is required.

Validation: restore, database/row batch restore, empty/cancel, keyboard restore, permanent delete, live parent renaming, centered geometry and narrow large-text layouts pass. A native-font/icon preview is saved in `build/logs/trash-reference-preview.png`. Full suite: 394 tests passed; the same three existing Windows SQLite temporary-directory cleanup failures remain. Final trash-specific suite: nine passed. Analyzer: same nine existing diagnostics.
