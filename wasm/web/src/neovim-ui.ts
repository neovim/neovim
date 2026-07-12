// wasm/web/src/neovim-ui.ts - the headless screen model for a Neovim instance.
//
//   * Screen - a HEADLESS model of the ext_linegrid screen: it decodes `redraw`
//     batches into a 2-D character grid + cursor + highlight table. No DOM.
//     Deliberately separable so it can be driven and asserted without a
//     browser; renderers (neovim-ui-pre.ts's <pre> DOM renderer today) paint
//     from it.
//
//   * keyToNvim - KeyboardEvent -> nvim_input notation ('<CR>', '<C-x>', ...).
//
// We attach with ext_linegrid and model grid 1 as a monospace cell grid: the
// Screen decodes the highlight stream (default_colors_set, hl_attr_define,
// and the per-cell hl ids in grid_line). The command line and messages are
// drawn by Neovim into the bottom rows of that same grid (we don't request
// ext_cmdline/ext_messages), so `:w`, `:q`, etc. are visible.
//
// This module is the TypeScript SOURCE OF TRUTH; the build emits a UMD
// `neovim-ui.js` (globalThis.NeovimUI / require()) and a `neovim-ui.d.ts`.

// The subset of a neovim.js instance the renderer uses.
export interface UIInstance {
  request(method: string, params?: any[]): Promise<any>;
  notify(method: string, params?: any[]): void;
  input(keys: string): void;
  onNotification(method: string, fn: (params: any) => void): () => void;
}

// A highlight attribute definition (the rgb_attrs dict from hl_attr_define).
export interface HlAttrs {
  foreground?: number;
  background?: number;
  special?: number;
  reverse?: boolean;
  bold?: boolean;
  italic?: boolean;
  underline?: boolean;
  underdouble?: boolean;
  underdotted?: boolean;
  underdashed?: boolean;
  undercurl?: boolean;
  strikethrough?: boolean;
  [k: string]: any;
}


// ---- Screen: headless grid model + redraw decode ------------------------
export class Screen {
  cols: number;
  rows: number;
  cursor: { row: number; col: number };
  grid: string[][];
  // Per-cell highlight id, in lockstep with `grid`. 0 = the default highlight.
  hlGrid: number[][];
  // Highlight attribute definitions, keyed by id (from hl_attr_define). Each
  // value is the rgb_attrs dict (foreground/background/special as 24-bit ints
  // when present, plus boolean style flags). id 0 is always the default.
  hlAttrs: Record<number, HlAttrs>;
  // Default colours from default_colors_set (24-bit ints, or null for "use the
  // terminal default", which we leave to the embedder's base colours).
  defaultFg: number | null;
  defaultBg: number | null;
  defaultSp: number | null;
  onFlush: (() => void) | null;

  constructor(cols?: number, rows?: number) {
    this.cols = cols || 80;
    this.rows = rows || 24;
    this.cursor = { row: 0, col: 0 };
    this.grid = Screen._makeGrid(this.cols, this.rows, ' ');
    this.hlGrid = Screen._makeGrid(this.cols, this.rows, 0);
    this.hlAttrs = { 0: {} };
    this.defaultFg = null;
    this.defaultBg = null;
    this.defaultSp = null;
    this.onFlush = null;   // called (no args) on each `flush` event
  }

  static _makeGrid<T>(c: number, r: number, fill: T): T[][] {
    const g: T[][] = new Array(r);
    for (let y = 0; y < r; y++) {
      g[y] = new Array(c);
      for (let x = 0; x < c; x++) { g[y][x] = fill; }
    }
    return g;
  }

  // Normalise a colour from the redraw stream: a 24-bit int is kept; the -1
  // sentinel ("use the default terminal colour") and a missing value become null.
  static _color(v: any): number | null {
    return (typeof v === 'number' && v >= 0) ? v : null;
  }

  _clear(): void {
    for (let y = 0; y < this.rows; y++) {
      for (let x = 0; x < this.cols; x++) { this.grid[y][x] = ' '; this.hlGrid[y][x] = 0; }
    }
  }

  // Apply one redraw notification's params (an array of [event, args...] batches).
  handleRedraw(batches: any[]): void {
    for (let i = 0; i < batches.length; i++) {
      const batch = batches[i];
      const name = batch[0];
      for (let j = 1; j < batch.length; j++) { this._event(name, batch[j]); }
    }
  }

  _event(name: string, a: any): void {
    switch (name) {
    case 'grid_resize':                       // [grid, width, height]
      this.cols = a[1]; this.rows = a[2];
      this.grid = Screen._makeGrid(this.cols, this.rows, ' ');
      this.hlGrid = Screen._makeGrid(this.cols, this.rows, 0);
      break;
    case 'grid_clear':
      this._clear(); break;
    case 'grid_cursor_goto':                   // [grid, row, col]
      this.cursor.row = a[1]; this.cursor.col = a[2]; break;
    case 'default_colors_set':                 // [rgb_fg, rgb_bg, rgb_sp, cterm_fg, cterm_bg]
      this.defaultFg = Screen._color(a[0]);
      this.defaultBg = Screen._color(a[1]);
      this.defaultSp = Screen._color(a[2]);
      break;
    case 'hl_attr_define':                      // [id, rgb_attrs, cterm_attrs, info]
      // Store the rgb_attrs dict directly (we attach with rgb:true, so the
      // cterm_attrs are irrelevant). Missing colours fall back to the defaults
      // at render time.
      this.hlAttrs[a[0]] = a[1] || {};
      break;
    case 'grid_line': {                        // [grid, row, col_start, cells, wrap]
      const row = a[1]; let col = a[2]; const cells = a[3];
      const line = this.grid[row], hlLine = this.hlGrid[row];
      if (!line) { break; }
      // hl_id is sticky WITHIN this grid_line: a cell that omits it reuses the
      // previous cell's id. Each grid_line starts from 0 (the default).
      let hl = 0;
      for (let i = 0; i < cells.length; i++) {
        const cell = cells[i];
        const text = cell[0];
        if (cell.length >= 2) { hl = cell[1]; }
        const repeat = cell.length >= 3 ? cell[2] : 1;
        for (let k = 0; k < repeat; k++) {
          if (col < this.cols) { line[col] = text; hlLine[col] = hl; col++; }
        }
      }
      break;
    }
    case 'grid_scroll': {                       // [grid, top, bot, left, right, rows, cols]
      const top = a[1], bot = a[2], left = a[3], right = a[4], dr = a[5];
      if (dr > 0) {
        for (let y = top; y < bot - dr; y++) {
          for (let x = left; x < right; x++) {
            this.grid[y][x] = this.grid[y + dr][x];
            this.hlGrid[y][x] = this.hlGrid[y + dr][x];
          }
        }
      } else if (dr < 0) {
        for (let y2 = bot - 1; y2 >= top - dr; y2--) {
          for (let x2 = left; x2 < right; x2++) {
            this.grid[y2][x2] = this.grid[y2 + dr][x2];
            this.hlGrid[y2][x2] = this.hlGrid[y2 + dr][x2];
          }
        }
      }
      break;
    }
    case 'flush':
      if (this.onFlush) { this.onFlush(); }
      break;
    default:
      break;   // ignore mode/msg/etc. events
    }
  }

  // The whole screen as text (rows joined by '\n').
  text(): string {
    return this.grid.map(function (line) { return line.join(''); }).join('\n');
  }

  // The resolved highlight id at a cell (0 = default), for headless assertions.
  hlIdAt(row: number, col: number): number {
    const line = this.hlGrid[row];
    return line ? (line[col] || 0) : 0;
  }

  // The resolved rgb_attrs dict at a cell (the hl_attr_define entry, or {} for
  // an unknown/default id). For headless assertions.
  attrAt(row: number, col: number): HlAttrs {
    return this.hlAttrs[this.hlIdAt(row, col)] || {};
  }
}

// ---- keyboard -----------------------------------------------------------
const SPECIAL: Record<string, string> = {
  'Enter': 'CR', 'Backspace': 'BS', 'Tab': 'Tab', 'Escape': 'Esc',
  'ArrowUp': 'Up', 'ArrowDown': 'Down', 'ArrowLeft': 'Left', 'ArrowRight': 'Right',
  'Delete': 'Del', 'Home': 'Home', 'End': 'End', 'PageUp': 'PageUp',
  'PageDown': 'PageDown', 'Insert': 'Insert',
};
export function keyToNvim(e: KeyboardEvent): string | null {
  const k = e.key;
  if (k === 'Shift' || k === 'Control' || k === 'Alt' || k === 'Meta' ||
      k === 'CapsLock' || k === 'Dead' || k === 'Unidentified') { return null; }
  const c = e.ctrlKey, alt = e.altKey || e.metaKey;
  if (k === ' ') {
    if (!c && !alt) { return ' '; }
    return '<' + (c ? 'C-' : '') + (alt ? 'A-' : '') + 'Space>';
  }
  let base: string | null = null, special = false;
  if (Object.prototype.hasOwnProperty.call(SPECIAL, k)) { base = SPECIAL[k]; special = true; }
  else if (/^F([1-9]|1[0-2])$/.test(k)) { base = k; special = true; }
  else if (k.length === 1) { base = k; }
  else { return null; }

  let mods = '';
  if (c) { mods += 'C-'; }
  if (alt) { mods += 'A-'; }
  if (e.shiftKey && special) { mods += 'S-'; }

  if (!mods && !special) { return base === '<' ? '<lt>' : base; }
  const inner = base === '<' ? 'lt' : base;
  return '<' + mods + inner + '>';
}
