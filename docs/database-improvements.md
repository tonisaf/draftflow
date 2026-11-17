# Database improvement steps

Work is delivered in small, independently verified changes. Preserve existing
editing, synchronization and bounded row virtualization throughout.

## 1. Data correctness

- [x] 1.1 Full-selection summaries: reuse row filters/search, aggregate across pages,
  preserve duration and checkbox semantics, update on writes, explain scope.
- [x] 1.2 Reliable saves: pending/saved/error states, retry without losing input,
  acknowledge successful writes before marking the local value committed.
- [x] 1.3 External updates: defer incoming values while any typed cell is edited;
  apply deferred values when closing untouched; preserve local drafts on conflict.
- [x] 1.4 Numeric validation: invalid/ambiguous input, finite values, explicit
  distinction between numbers, durations and unsupported formulas.

## 2. Table control

- [x] 2.1 Arrow keys, Shift+arrows, Tab/Shift+Tab and Enter/F2 with reliable focus.
- [x] 2.2 Typed rectangular TSV paste, validation and atomic undo.
- [x] 2.3 Selection autoscroll, whole-row/column selection and selection dimensions.

## 3. Large-table reading

- [x] Keep expanded cell editors anchored on scroll/resize or close predictably.
- [ ] Sticky headers/title column and automatic column sizing.
- [ ] Optional text wrapping/density with correct variable-height virtualization.

## 4. Views and polish

- [ ] Persist named views: filters, sorting, visible columns and column widths.
- [ ] Clearly distinguish active cells, ranges, editing and validation states.
- [ ] Consistent keyboard/accessibility semantics, reduced motion and undo feedback.

## Step 1.1 implementation

The SQL summary subscription shares the filtered row query and excludes pagination
and sorting. It groups only columns with active calculations. Weighted statistics
run through a top-level compute callback without capturing a database connection.
The grid still loads one bounded page and mounts only visible rows.

Tests cover 70 rows across pages, weighted durations and booleans, search/filter
scope, trash, empty selections and updates originating from another page. Loading
and query errors are displayed instead of silently showing a page subtotal.

Verification for step 1.1: full suite 265 passed; the three pre-existing Windows
SQLite temporary-file cleanup failures remain. Analyzer: no errors, 10 existing
warnings/info. Logs: build/logs/full-summary-all-verified.log and
build/logs/full-summary-analyze-verified.log.

## Step 1.2 implementation

All grid property types and row-card properties use a repository-scoped save session.
Writes are serialized per cell; successful acknowledgement is separate from the
latest submitted value. Failed writes retain their draft, red cell outline and
localized retry status. The session survives paging, virtualization and reopening
within the same repository session; it is not an on-disk recovery journal.

Recovery exposes selectable draft text, retry and explicit discard of failed edits.
Discard restores the current database projection. Clean unmounted entries are
released; failed/pending entries remain available. Account switches await pending
writes and are blocked while failed drafts remain, until retry or explicit discard.

Verification: 275 passed, three pre-existing Windows SQLite cleanup failures.
Analyzer: no errors, 10 existing warnings/info. Additional tests cover delayed writes,
rapid edits, older failures, exact value types, snapshot isolation, retry, remount,
copyable recovery/discard and account switching. Logs: build/logs/cell-save-step12-all.log
and build/logs/cell-save-step12-analyze.log.

## Step 1.3 implementation

Cell edit sessions freeze the acknowledged baseline while allowing streams to
record incoming values. Untouched editors apply the incoming value after closing;
local text/caret state is preserved during editing. This covers text/title overlays,
numeric and URL editors, date pickers and tag pickers.

A database transaction compares only the targeted cell against its baseline before
writing, preserving independent edits to other columns. Unseen changes become a
conflict with the original baseline, remote value and local draft retained. Normal
retry cannot overwrite conflicts. The user explicitly chooses the remote value or
their draft; the latter is compared against the version actually reviewed. A new
change during review keeps the dialog open and requires another review. Tag labels,
checkbox states and numeric formats are shown instead of internal storage values.

Conflicts survive virtualization/session navigation and block account switching until
resolved. Missing rows/columns become failed drafts rather than resurrected data.

Verification: 285 passed; the three existing Windows SQLite cleanup failures remain.
Analyzer: no errors, 10 existing warnings/info. Tests cover unseen updates, atomic
comparison, independent column edits, titles, cursor stability, untouched/edited
text/title/number/URL fields, tag presentation and repeated changes during review.
Logs: build/logs/cell-conflict-step13-all.log and build/logs/cell-conflict-analyze-verified.log.

Next delivery: step 1.4 (numeric and duration validation, finite values and formulas).

## Step 1.4 implementation

Interactive numeric edits share a strict parser across the cell editor, save session,
transactional write guard and summary calculations. Decimal comma/point and spaced
thousands are supported without guessing mixed separators; percent keeps its existing
stored magnitude. Duration syntax consumes the entire input, supports a leading sign,
fractions, English/Russian units, milliseconds and M:S / H:M:S / D:H:M:S notation.
NaN, infinity, malformed values, unsupported formulas and unsafe duration magnitudes
remain visible as invalid drafts and never reach the interactive database writer.

Validation uses a fixed-width tooltip icon while typing and a red value/outline after
editing, without changing row height. Recovery exposes the raw draft and explanation;
correction or explicit discard clears the error. Invalid drafts block account switching
alongside failed/conflicting edits. Drafts survive table remounts in this session,
not application restarts. Import/legacy values are preserved and invalid numeric values
are excluded from numeric summaries. Column formats invalidate summary subscriptions.

The duration picker validates every field, preserves negative/fractional values, uses
localized labels and stays open on invalid input instead of silently substituting zero.
Large numbers use scientific notation when integer conversion would overflow; numeric
summary overflow displays an explanation rather than an infinite result.

Verification: 54 targeted tests passed; full suite 295 passed with the same three
pre-existing Windows SQLite temporary-file cleanup failures. Analyzer: no errors,
nine existing warnings/info. Logs: build/logs/validation-targeted.log,
build/logs/validation-all.log and build/logs/validation-analyze.log.

Next: stage 2, keyboard navigation and focus (arrows, Shift+arrows, Tab/Shift+Tab,
Enter/F2), followed by typed rectangular paste and atomic undo.

## Step 2.1 implementation

The grid is one keyboard traversal stop. Arrow keys move the active cell within the
loaded page; Shift+arrows extends the existing rectangular selection, retaining TSV
copy. Tab/Shift+Tab traverse cells in row order and leave the table at page boundaries.
Empty tables are skipped. Keyboard movement reveals the destination vertically and
horizontally without mounting the whole page. Focused cells use the existing accent
outline; navigation does not animate or change text geometry.

Enter/F2 opens the existing cell editor. Text editors keep native cursor movement,
selection and multiline Enter. Tab/Shift+Tab save and move, Ctrl/Cmd+Enter saves and
returns to the grid, and Escape cancels the current unsubmitted text. Numeric/URL
editors commit on Tab or Enter and cancel unsubmitted input on Escape; previously
submitted invalid drafts remain available for correction. Checkbox cells toggle with
Enter/F2 or Space. Date/tag pickers reuse their existing controls and keyboard focus.
Clicking an external focus target after editing text does not restore the old opener.

Only mounted cells register editor callbacks. Filtering/reordering clears obsolete
coordinates; paging keeps its existing explicit controls. Clipboard output includes
visible session drafts while waiting for a repository update, including invalid input;
copying a range does not allocate entries for unmounted cells.

Verification: 48 targeted tests passed, including AppFlowy integration, native text
selection, forward/reverse traversal and exits, draft preservation, checkbox/date/tag
activation, empty/filter states and lazy-row/horizontal reveal. Full suite: 303 passed;
the same three pre-existing Windows SQLite cleanup failures remain. Analyzer: no errors,
nine existing warnings/info. Logs: build/logs/keyboard-targeted.log,
build/logs/keyboard-all.log, build/logs/keyboard-analyze.log.

Next: typed rectangular TSV paste with validation and atomic undo.

## Step 2.2 implementation

Ctrl/Cmd+V pastes a typed TSV rectangle from the upper-left cell of the selection.
One clipboard value fills the selected rectangle. A multi-cell clipboard must match
an existing multi-cell selection, or expand from one active cell. Quoted multiline
fields, tabs, doubled quotes, CRLF and trailing empty cells roundtrip correctly.
The destination must fit in the current loaded table page; rows/columns are never
silently added or truncated. Limits are 2,000 cells and 2 million clipboard characters.

Text/title content remains literal. Numeric/duration parsing shares step 1.4 rules;
checkboxes accept TRUE/FALSE, 1/0 and English/Russian yes/no. Dates require valid
YYYY-MM-DD within the date picker's 1970–2100 range. URL values are normalized to
HTTP/HTTPS/mailto. Tags resolve existing unambiguous labels without creating new
options; multi-tags accept comma-separated names or a JSON list. Copy uses a JSON
list when tag names contain commas so these values roundtrip without ambiguity.

All target values are validated before writing. A single local transaction compares
expected cell values and column type/options, then applies row patches and titles.
Late failures roll back every row, Unicode search projections and sync outbox changes.
Existing unsaved target drafts block the operation, even if the copied value matches
a draft. Later typed edits queue behind the batch and use its acknowledged values;
account/workspace flush waits for the batch. Native paste/undo inside text editors
remains local to that editor. Clipboard reads are canceled if navigation moves away
before the clipboard returns.

After success the full pasted rectangle is highlighted. The notification offers
Undo paste; Ctrl/Cmd+Z undoes the entire range, Ctrl/Cmd+Shift+Z or Ctrl+Y redoes it.
A fresh paste clears redo. History retains up to 20 range operations per database in
the repository session and survives grid remounts, not application restarts. Undo
checks all touched cells before restoring them and refuses to overwrite newer edits;
unrelated columns are preserved. Previously stored legacy values can be restored.
Errors identify the destination row/column and explain validation without partial
writes. Range progress uses an indicator; feedback is localized in Russian/English.

Verification: 51 targeted tests passed, including an AppFlowy editor integration,
clipboard/selection/shortcut behavior, type conversion, unknown/ambiguous tags,
late transaction rollback with sync outbox, undo conflicts and queued typed writes.
Full suite: 323 passed with the same three pre-existing Windows SQLite temporary-file
cleanup failures. Analyzer: no errors, nine existing warnings/info. Logs:
build/logs/paste-targeted.log, build/logs/paste-all.log, build/logs/paste-analyze.log.

Next: selection autoscroll, whole-row/column selection and selection dimensions.

## Cell editor alignment correction

Title/text, numeric/duration and URL editing now share the same expanded surface.
The anchor comes from the complete DataCell frame, not the centered internal input.
Coordinates are converted into the actual destination overlay, including nested
Navigators. The previous -8px offsets and artificial extra width were removed.
Input density is explicitly standard inside the popup so the shared 8px padding is
not reduced by the app's compact controls. Tests verify that the first text caret
stays within one logical pixel of the idle title position in both appearances.

URL editors expand to 480 logical pixels when space permits and wrap long values.
Other editors use at least 240px. All sizes are constrained to the overlay viewport.
Duration editing keeps live validation, select-all on entry and its clock picker;
Enter submits numeric/URL edits, while text/title retain multiline Enter. Tab,
Shift+Tab, Ctrl/Cmd+Enter, Escape, native selection, conflict sessions and range
clipboard behavior keep their previous contracts. Underlying row geometry stays fixed.

Scrolling either ancestor axis or resizing the window saves and closes the popup,
removing stale floating editors. Internal popup scrolling remains available for long
content. Pointer dismissals preserve the destination focus.

Verification: 55 existing focused checks and 8 geometry/lifecycle checks passed.
Full suite: 332 passed; the same three known Windows SQLite cleanup failures remain.
Analyzer: no errors, nine existing warnings/info. Geometry tests cover full-cell
alignment, caret position, narrow windows, nested overlay coordinates, long URL wrap,
validation and scroll/resize close behavior. A further keyboard test verifies focus
return after applying the duration picker. A Windows Segoe UI widget render was
inspected at build/logs/cell-overlay-alignment.png. This is widget rendering, not a
live installed-window or IME audit. Logs: build/logs/cell-overlay-targeted.log,
build/logs/cell-overlay-geometry.log, build/logs/cell-overlay-all.log,
build/logs/cell-overlay-analyze.log.

## Step 2.3 implementation

Dragging a range near the visible grid's top/bottom or left/right edges scrolls the
corresponding row/horizontal viewport, including while the pointer stays stationary.
The visible rectangle intersects ancestor scroll viewports so horizontal clipping
and partially visible grids use the correct edge. A frame ticker advances directly,
with edge-distance speed and clamped elapsed time. Pointer coordinates are resolved
again after scrolling, keeping the rectangle aligned with variable-width columns.
Same-cell native text drags remain owned by the input. Row-gutter drags scroll only
vertically. No extra pages are fetched or added to the mounted row set.

The ticker stops on pointer up/cancel, loss of the primary button, focus/lifecycle
loss, dataset/controller changes, disposal and scroll limits. The selection anchor
survives ordinary scroll; filtering/paging/reordering clears obsolete coordinates.
Selection controller updates are coalesced and do not write to the repository.

Click or drag the left gutter to select complete rows; Shift-click extends from the
original row. Double-click still opens the row peek/page. The gutter has a separate
semantic select action and page-open long-press action. Column type glyphs select
complete columns; Shift-click another glyph extends the column range. Header text
still opens its property menu, whose Select column action is also available. Resize
handles and reorder drags retain their existing behavior. The top-left table button
and Ctrl/Cmd+A select all cells on the current loaded page.

Shift+Space selects the active row; Ctrl+Space selects the active column. Shift+Up/
Down extends/shrinks full-row selection, Shift+Left/Right full-column selection.
Ordinary arrows return to a single cell while preserving the active row/column.
Copy/paste and range undo reuse the same rectangular bounds and typed validation.
The footer announces rows × columns and total selected cells in Russian/English,
with a tooltip explicitly describing current-page scope. Focus loss/Escape hides
it; detaching the grid clears its controller safely.

Verification: 41 focused tests passed, including 8 new control tests for stationary
edge scrolling, reverse scrolling, bounds/cancel/filter/disposal, row/column Shift
selection, dimensions, clipboard output, page opening, header resizing and focus
cleanup. AppFlowy integration also selects a column and copies it through the grid.
Full suite: 340 passed; the same three existing Windows SQLite migration cleanup
failures remain. Analyzer: no errors, nine existing warnings/info. Logs:
build/logs/selection-targeted.log, build/logs/selection-controls.log,
build/logs/selection-all.log, build/logs/selection-analyze.log.

Next: sticky headers/title column and automatic column sizing.
