// wasm/web/src/neovim-ui-pre.ts - the default UI renderer: a <pre> DOM grid.
//
//   * render(el, screen) turns a headless Screen (neovim-ui.ts) into styled
//     HTML spans inside a <pre> - colors, bold/italic/underline, the cursor
//     as an outlined cell. It is also handy for asserting on decoded screen
//     state without a browser (tests can inspect el.innerHTML as a string).
//   * mount_into(instance, el) wires a Screen to a neovim.js instance and a
//     <pre>: subscribes to redraw, attaches the UI (ext_linegrid), renders on
//     flush, maps keydown -> nvim_input, and auto-sizes the grid to the
//     element (ResizeObserver -> nvim_ui_try_resize).
//
// A DOM-based renderer keeps the demo dependency-free and copy-paste
// friendly; richer renderers can paint from the same headless Screen. The
// build emits a UMD `neovim-ui-pre.js` (globalThis.NeovimUIPre / require()).

import { Screen, UIInstance, keyToNvim } from './neovim-ui.js';

export interface PreMountOptions {
  font_family?: string;
  font_size?: number | string;
  cols?: number;
  rows?: number;
}

export interface PreMountHandle {
  screen: Screen;
  cols: number;
  rows: number;
  resize(c: number, r: number): Promise<any>;
  dispose(): void;
}

interface FontMetrics { fontFamily: string; fontSize: string; lineHeight: number; }

// ---- DOM rendering ------------------------------------------------------
function escapeHtml(s: string): string {
  return s.replace(/[&<>]/g, function (c) {
    return c === '&' ? '&amp;' : c === '<' ? '&lt;' : '&gt;';
  });
}
// 24-bit int -> '#rrggbb'.
function hex(n: number): string {
  const s = (n & 0xffffff).toString(16);
  return '#' + '000000'.slice(s.length) + s;
}
// Resolve an hl id to the concrete fg/bg/style we paint a span with. Returns
// null when the cell needs no per-span styling (default id 0 with no attrs);
// such cells inherit the container's base colours.
function resolveStyle(screen: Screen, id: number): string | null {
  if (!id) { return null; }
  const attrs = screen.hlAttrs[id];
  if (!attrs) { return null; }
  let fg = (typeof attrs.foreground === 'number') ? attrs.foreground : screen.defaultFg;
  let bg = (typeof attrs.background === 'number') ? attrs.background : screen.defaultBg;
  if (attrs.reverse) { const t = fg; fg = (bg === null ? screen.defaultBg : bg); bg = (t === null ? screen.defaultFg : t); }
  let css = '';
  if (fg !== null) { css += 'color:' + hex(fg) + ';'; }
  // Only paint a background when it differs from the default (reverse forces it).
  if (bg !== null && (bg !== screen.defaultBg || attrs.reverse)) { css += 'background-color:' + hex(bg) + ';'; }
  if (attrs.bold) { css += 'font-weight:bold;'; }
  if (attrs.italic) { css += 'font-style:italic;'; }
  let deco = '';
  if (attrs.underline || attrs.underdouble || attrs.underdotted || attrs.underdashed) { deco += ' underline'; }
  if (attrs.undercurl) { deco += ' underline wavy'; }
  if (attrs.strikethrough) { deco += ' line-through'; }
  if (deco) {
    css += 'text-decoration:' + deco.trim() + ';';
    const sp = (typeof attrs.special === 'number') ? attrs.special : screen.defaultSp;
    if ((attrs.undercurl || attrs.underdotted || attrs.underdashed) && sp !== null) {
      css += 'text-decoration-color:' + hex(sp) + ';';
    }
  }
  return css || null;
}
// Style for the cursor cell: a solid block (swap to the default bg/fg) so it
// stays visible over any coloured cell. Built on top of the cell's own attrs.
function cursorStyle(screen: Screen, id: number): string {
  const attrs = screen.hlAttrs[id] || {};
  let fg = (typeof attrs.foreground === 'number') ? attrs.foreground : screen.defaultFg;
  let bg = (typeof attrs.background === 'number') ? attrs.background : screen.defaultBg;
  if (attrs.reverse) { const t = fg; fg = bg; bg = t; }
  // Cursor block: paint the cell's fg as the background and the cell's bg (or
  // the default bg) as the text colour, so it reads as a solid block.
  const blockBg = (fg !== null) ? fg : screen.defaultFg;
  const blockFg = (bg !== null) ? bg : screen.defaultBg;
  let css = '';
  if (blockBg !== null) { css += 'background-color:' + hex(blockBg) + ';'; }
  if (blockFg !== null) { css += 'color:' + hex(blockFg) + ';'; }
  return css;
}
export function render(el: HTMLElement, screen: Screen): void {
  // Apply the default colours to the container so default cells need no span.
  if (screen.defaultFg !== null) { el.style.color = hex(screen.defaultFg); }
  if (screen.defaultBg !== null) { el.style.backgroundColor = hex(screen.defaultBg); }

  const out: string[] = [];
  const cur = screen.cursor;
  for (let r = 0; r < screen.rows; r++) {
    const line = screen.grid[r], hlLine = screen.hlGrid[r];
    const curCol = (r === cur.row && cur.col < screen.cols) ? cur.col : -1;
    let rowHtml = '';
    let c = 0;
    while (c < screen.cols) {
      if (c === curCol) {
        // The cursor cell is its own span (a solid block); never grouped.
        const cs = cursorStyle(screen, hlLine[c]);
        rowHtml += '<span class="cursor" style="' + cs + '">' +
                   escapeHtml(line[c] || ' ') + '</span>';
        c++;
        continue;
      }
      // Group a run of consecutive cells that share the same hl id (and don't
      // contain the cursor) into one span.
      const id = hlLine[c];
      const start = c;
      while (c < screen.cols && hlLine[c] === id && c !== curCol) { c++; }
      const text = escapeHtml(line.slice(start, c).join(''));
      const style = resolveStyle(screen, id);
      rowHtml += style ? ('<span style="' + style + '">' + text + '</span>') : text;
    }
    out.push(rowHtml);
  }
  el.innerHTML = out.join('\n');
}

function installKeyboard(el: HTMLElement, instance: UIInstance): void {
  el.setAttribute('tabindex', '0');
  el.addEventListener('keydown', function (e) {
    const keys = keyToNvim(e as KeyboardEvent);
    if (keys === null) { return; }
    e.preventDefault();
    instance.input(keys);
  });
  el.addEventListener('mousedown', function () { el.focus(); });
  el.focus();
}

// ---- font + sizing ------------------------------------------------------
// We keep the grid math stable by pinning a deterministic line-height: rows
// are an exact integer number of px so floor(contentHeight / cellH) doesn't
// wobble on sub-pixel font metrics. 1.2 is the conventional terminal ratio.
const DEFAULT_FONT_FAMILY = 'ui-monospace, "DejaVu Sans Mono", Menlo, Consolas, monospace';
const LINE_HEIGHT_RATIO = 1.2;

// Apply opts.font_family / opts.font_size to `el` (only when given, so an
// unset option leaves the page CSS alone), and pin a deterministic integer-px
// line-height. `font_size` is a number (-> px) or a string (used as-is).
// Returns the resolved { fontFamily, fontSize (css), lineHeight (px) } that the
// probe must mirror so its cell metrics match the live element.
function applyFont(el: HTMLElement, opts: PreMountOptions): FontMetrics {
  if (opts.font_family) { el.style.fontFamily = opts.font_family; }
  if (opts.font_size != null) {
    el.style.fontSize = (typeof opts.font_size === 'number')
      ? (opts.font_size + 'px') : opts.font_size;
  }
  const cs = (typeof getComputedStyle === 'function') ? getComputedStyle(el) : null;
  const fontFamily = (cs && cs.fontFamily) || el.style.fontFamily || DEFAULT_FONT_FAMILY;
  const fontSizeCss = (cs && cs.fontSize) || el.style.fontSize || '16px';
  const fontSizePx = parseFloat(fontSizeCss) || 16;
  // Pin line-height to an exact integer px so row math is stable.
  const lineHeightPx = Math.max(1, Math.round(fontSizePx * LINE_HEIGHT_RATIO));
  el.style.lineHeight = lineHeightPx + 'px';
  return { fontFamily: fontFamily, fontSize: fontSizeCss, lineHeight: lineHeightPx };
}

// Measure one monospace cell (width x height in px) for the given resolved
// font, using a hidden off-screen probe with the SAME font metrics as the live
// element. Uses getBoundingClientRect() for sub-pixel accuracy: a long run of a
// fixed glyph divided by its length gives a per-cell width that isn't skewed by
// a single glyph's rounding.
function measureCell(font: FontMetrics): { w: number; h: number } {
  const probe = document.createElement('span');
  probe.style.position = 'absolute';
  probe.style.visibility = 'hidden';
  probe.style.left = '-9999px';
  probe.style.top = '0';
  probe.style.whiteSpace = 'pre';
  probe.style.fontFamily = font.fontFamily;
  probe.style.fontSize = font.fontSize;
  probe.style.lineHeight = font.lineHeight + 'px';
  probe.style.padding = '0';
  probe.style.margin = '0';
  probe.style.border = '0';
  const N = 50;
  probe.textContent = '0'.repeat(N);
  document.body.appendChild(probe);
  const rect = probe.getBoundingClientRect();
  const cellW = rect.width / N;
  document.body.removeChild(probe);
  // Height comes from the pinned (integer) line-height, which is what the live
  // <pre> uses per row -- the probe rect height can be the same but we trust the
  // pinned value so cellH is an exact integer.
  return { w: cellW, h: font.lineHeight };
}

// `el`'s content-box size in px (clientWidth/Height already exclude border and
// scrollbar; subtract padding to get the content box).
function contentBox(el: HTMLElement): { w: number; h: number } {
  const cs = (typeof getComputedStyle === 'function') ? getComputedStyle(el) : null;
  const padL = cs ? (parseFloat(cs.paddingLeft) || 0) : 0;
  const padR = cs ? (parseFloat(cs.paddingRight) || 0) : 0;
  const padT = cs ? (parseFloat(cs.paddingTop) || 0) : 0;
  const padB = cs ? (parseFloat(cs.paddingBottom) || 0) : 0;
  return {
    w: Math.max(0, el.clientWidth - padL - padR),
    h: Math.max(0, el.clientHeight - padT - padB),
  };
}

// Derive { cols, rows } from `el`'s content box and a measured cell. Returns
// null when the element has no usable layout yet (0x0 or an unmeasurable cell),
// so the caller can fall back to the fixed defaults instead of a degenerate grid.
function deriveSize(el: HTMLElement, font: FontMetrics): { cols: number; rows: number } | null {
  const box = contentBox(el);
  const cell = measureCell(font);
  if (!(cell.w > 0) || !(cell.h > 0) || box.w <= 0 || box.h <= 0) { return null; }
  return {
    cols: Math.max(1, Math.floor(box.w / cell.w)),
    rows: Math.max(1, Math.floor(box.h / cell.h)),
  };
}

// ---- mount_into ---------------------------------------------------------
// Wire `instance` to render into the DOM element `el` (a <pre>) and forward
// its keystrokes.
export function mount_into(instance: UIInstance, el: HTMLElement, opts?: PreMountOptions): PreMountHandle {
  opts = opts || {};
  const explicit = (opts.cols != null) || (opts.rows != null);

  // Font styling + a pinned line-height so the grid math is deterministic.
  const font = applyFont(el, opts);

  let cols: number, rows: number;
  if (explicit) {
    cols = opts.cols || 80; rows = opts.rows || 24;
  } else {
    const derived = deriveSize(el, font);
    if (derived) { cols = derived.cols; rows = derived.rows; }
    else { cols = 80; rows = 24; }   // no layout yet: never attach 0x0
  }

  const screen = new Screen(cols, rows);
  screen.onFlush = function () { render(el, screen); };
  const off = instance.onNotification('redraw', function (params) { screen.handleRedraw(params); });
  installKeyboard(el, instance);
  instance.request('nvim_ui_attach', [cols, rows, { rgb: true, ext_linegrid: true }]);

  const api: PreMountHandle = {
    screen: screen,
    cols: cols,
    rows: rows,
    resize: function (c, r) {
      api.cols = c; api.rows = r;
      return instance.request('nvim_ui_try_resize', [c, r]);
    },
    dispose: function () {
      off();
      if (observer) { observer.disconnect(); observer = null; }
      if (rafId != null) { cancelRaf(rafId); rafId = null; }
    },
  };

  // ---- auto-resize: track `el` and drive try_resize on change ----------
  // Only when auto-sizing (explicit cols/rows keep a fixed grid). On each
  // observed resize we recompute cols/rows and, if they changed, ask the engine
  // to resize -- it answers with a grid_resize redraw the Screen decode already
  // handles, so we don't touch the Screen here (avoids a double-resize race).
  // Coalesce a burst of resizes (a window drag) into one try_resize per frame.
  let observer: ResizeObserver | null = null, rafId: number | null = null;
  const hasRaf = (typeof requestAnimationFrame === 'function');
  function scheduleRaf(fn: () => void): number { return hasRaf ? requestAnimationFrame(fn) : (setTimeout(fn, 16) as any); }
  function cancelRaf(id: number): void { if (hasRaf) { cancelAnimationFrame(id); } else { clearTimeout(id); } }

  if (!explicit && typeof ResizeObserver === 'function') {
    const recompute = function () {
      rafId = null;
      const derived = deriveSize(el, font);
      if (!derived) { return; }                 // 0x0 (e.g. hidden): keep last grid
      if (derived.cols === api.cols && derived.rows === api.rows) { return; }
      api.cols = derived.cols; api.rows = derived.rows;
      instance.request('nvim_ui_try_resize', [derived.cols, derived.rows]);
    };
    observer = new ResizeObserver(function () {
      if (rafId != null) { return; }            // coalesce: one try_resize per frame
      rafId = scheduleRaf(recompute);
    });
    observer.observe(el);
  }

  return api;
}
