const DEBUG = false;
const statusEl = document.getElementById("status");
const setStatus = (s) => (statusEl.textContent = s);
const log = (...args) => {
  if (!DEBUG) return;
  if (logEl) {
    logEl.textContent +=
      args
        .map((a) => (typeof a === "string" ? a : JSON.stringify(a)))
        .join(" ") + "\n";
  }
  console.log(...args);
};

// UiState below is ported from (github.com/MuNeNiCK/nvim-wasm)
// but, extended with win_viewport tracking.
class UiState {
  constructor(cols, rows) {
    this.defaultWidth = Math.max(1, cols || 80);
    this.defaultHeight = Math.max(1, rows || 24);
    this.defaultGrid = 1;
    this.activeGrid = this.defaultGrid;
    this.grids = new Map();
    this.grids.set(
      this.defaultGrid,
      this.#createGrid(this.defaultWidth, this.defaultHeight),
    );
    this.cursor = { grid: this.defaultGrid, row: 0, col: 0 };
    this.mode = "-";
    this.modeIdx = 0;
    this.cursorStyleEnabled = false;
    this.modeInfo = [];
    this.cursorHlId = 0;
    this.hls = new Map();
    this.hls.set(0, { foreground: null, background: null, reverse: false });
    this.windows = new Map();
  }

  resize(gridId, width, height) {
    const grid = this.#ensureGrid(gridId);
    const w = Math.max(1, width || 0);
    const h = Math.max(1, height || 0);
    grid.width = w;
    grid.height = h;
    grid.cells = Array.from({ length: h }, () => this.#blankRow(w));
  }

  clear(gridId) {
    const grid = this.#ensureGrid(gridId);
    grid.cells = Array.from({ length: grid.height }, () =>
      this.#blankRow(grid.width),
    );
  }

  destroy(gridId) {
    this.grids.delete(gridId);
    this.windows.delete(gridId);
    if (this.activeGrid === gridId) this.activeGrid = this.defaultGrid;
  }

  line(gridId, row, colStart, cells) {
    const grid = this.#ensureGrid(gridId);
    const rowIdx = row || 0;
    if (rowIdx < 0 || rowIdx >= grid.height) return;
    const rowCells =
      grid.cells[rowIdx] || (grid.cells[rowIdx] = this.#blankRow(grid.width));
    let col = colStart || 0;
    let currentHl = 0;
    for (const cell of cells) {
      const text = cell[0];
      const hlId =
        cell.length > 1 && cell[1] !== undefined ? cell[1] : currentHl;
      currentHl = hlId;
      const repeat = cell[2] || 1;
      for (let r = 0; r < repeat && col < grid.width; r += 1) {
        rowCells[col] = { ch: text || " ", hl: hlId };
        col += 1;
      }
    }
  }

  scroll(gridId, top, bot, left, right, rows) {
    const grid = this.#ensureGrid(gridId);
    const height = bot - top;
    const width = right - left;
    const slice = [];
    for (let i = 0; i < height; i += 1) {
      const row = grid.cells[top + i] || this.#blankRow(grid.width);
      slice.push(row.slice(left, right));
    }
    if (rows > 0) {
      for (let i = 0; i < height - rows; i += 1) {
        grid.cells[top + i].splice(left, width, ...slice[i + rows]);
      }
      for (let i = height - rows; i < height; i += 1) {
        grid.cells[top + i].splice(left, width, ...this.#blankRow(width));
      }
    } else if (rows < 0) {
      for (let i = height - 1; i >= -rows; i -= 1) {
        grid.cells[top + i].splice(left, width, ...slice[i + rows]);
      }
      for (let i = 0; i < -rows; i += 1) {
        grid.cells[top + i].splice(left, width, ...this.#blankRow(width));
      }
    }
  }

  setCursor(gridId, row, col) {
    this.activeGrid = gridId;
    this.#ensureGrid(gridId);
    this.cursor = { grid: gridId, row: row || 0, col: col || 0 };
  }

  setMode(mode, modeIdx) {
    this.mode = mode || "-";
    if (Number.isInteger(modeIdx)) this.modeIdx = modeIdx;
    this.#updateCursorHl();
  }

  setModeInfo(cursorStyleEnabled, modeInfo) {
    this.cursorStyleEnabled = Boolean(cursorStyleEnabled);
    this.modeInfo = Array.isArray(modeInfo) ? modeInfo : [];
    this.#updateCursorHl();
  }

  defineHl(id, rgbAttr = {}) {
    this.hls.set(id, {
      foreground: this.#toHex(rgbAttr.foreground),
      background: this.#toHex(rgbAttr.background),
      reverse: Boolean(rgbAttr.reverse),
    });
  }

  setWindowViewport(gridId, winHandle, topline, botline) {
    this.windows.set(gridId, { winHandle, topline, botline });
  }

  snapshot() {
    const grid =
      this.grids.get(this.activeGrid) || this.grids.get(this.defaultGrid);
    if (!grid)
      return {
        cells: [[{ ch: " ", hl: 0 }]],
        cursor: { row: 0, col: 0 },
        mode: this.mode,
        hls: this.hls,
      };
    const row = Math.min(Math.max(this.cursor.row, 0), grid.height - 1);
    const col = Math.min(Math.max(this.cursor.col, 0), grid.width - 1);
    return {
      cells: grid.cells.map((r) =>
        r.map((c) => ({ ch: c?.ch ?? " ", hl: c?.hl ?? 0 })),
      ),
      cursor: { row, col },
      cursorHlId: this.cursorHlId,
      mode: this.mode,
      hls: this.hls,
    };
  }

  #ensureGrid(gridId) {
    if (!this.grids.has(gridId))
      this.grids.set(
        gridId,
        this.#createGrid(this.defaultWidth, this.defaultHeight),
      );
    return this.grids.get(gridId);
  }
  #createGrid(width, height) {
    return {
      width,
      height,
      cells: Array.from({ length: height }, () => this.#blankRow(width)),
    };
  }
  #blankRow(width) {
    return Array.from({ length: width }, () => ({ ch: " ", hl: 0 }));
  }
  #updateCursorHl() {
    if (!this.cursorStyleEnabled) {
      this.cursorHlId = 0;
      return;
    }
    const info = this.modeInfo[this.modeIdx] || null;
    this.cursorHlId = info?.attr_id ?? 0;
  }
  #toHex(value) {
    if (value === undefined || value === null) return null;
    return `#${(value >>> 0).toString(16).padStart(6, "0").slice(-6)}`;
  }
}

function handleRedrawEvents(uiState, gridEl, modeEl, events) {
  for (const ev of events) {
    const [name, ...entries] = ev;
    switch (name) {
      case "grid_resize":
        for (const [grid, w, h] of entries) uiState.resize(grid, w, h);
        break;
      case "grid_clear":
        for (const [grid] of entries) uiState.clear(grid);
        break;
      case "grid_destroy":
        for (const [grid] of entries) uiState.destroy(grid);
        break;
      case "grid_line":
        for (const [grid, row, col, cells] of entries)
          uiState.line(grid, row, col, cells);
        break;
      case "grid_scroll":
        for (const [grid, top, bot, left, right, rows] of entries)
          uiState.scroll(grid, top, bot, left, right, rows);
        break;
      case "grid_cursor_goto":
        for (const [grid, row, col] of entries)
          uiState.setCursor(grid, row, col);
        break;
      case "win_viewport":
        for (const [grid, win, topline, botline] of entries)
          uiState.setWindowViewport(grid, win, topline, botline);
        break;
      case "mode_info_set":
        for (const [enabled, modeInfo] of entries)
          uiState.setModeInfo(enabled, modeInfo);
        break;
      case "mode_change":
        for (const [mode, idx] of entries) uiState.setMode(mode, idx);
        break;
      case "hl_attr_define":
        for (const [id, rgbAttr] of entries) uiState.defineHl(id, rgbAttr);
        break;
      case "flush":
        paintGrid(uiState, gridEl, modeEl);
        break;
      default:
        break; // mouse on/off, busy start/stop, etc.
    }
  }
}

function paintGrid(uiState, gridEl, modeEl) {
  const { cells, cursor, cursorHlId, mode, hls } = uiState.snapshot();
  let html = "";
  for (let r = 0; r < cells.length; r += 1) {
    for (let c = 0; c < cells[r].length; c += 1) {
      const cell = cells[r][c];
      const isCursor = r === cursor.row && c === cursor.col;
      const hl = hls.get(isCursor ? cursorHlId : cell.hl) || {};
      let style = "";
      if (hl.reverse) {
        style = `color:${hl.background || "#050912"};background:${hl.foreground || "#dfe5f1"}`;
      } else {
        if (hl.foreground) style += `color:${hl.foreground};`;
        if (hl.background) style += `background:${hl.background};`;
      }
      const ch = escapeHtml(cell.ch || " ");
      if (isCursor) {
        html += `<span class="cursor" style="${style}">${ch}</span>`;
      } else if (style) {
        html += `<span style="${style}">${ch}</span>`;
      } else {
        html += ch;
      }
    }
    if (r < cells.length - 1) html += "\n";
  }
  gridEl.innerHTML = html || " ";
  if (modeEl) modeEl.textContent = `mode: ${mode}`;
}

function escapeHtml(ch) {
  if (ch === "&") return "&amp;";
  if (ch === "<") return "&lt;";
  if (ch === ">") return "&gt;";
  return ch;
}

function translateKey(ev) {
  const isCtrl = ev.ctrlKey || ev.metaKey;
  const isAlt = ev.altKey;
  const named = {
    Backspace: "<BS>",
    Enter: "<CR>",
    Escape: "<Esc>",
    Tab: "<Tab>",
    ArrowUp: "<Up>",
    ArrowDown: "<Down>",
    ArrowLeft: "<Left>",
    ArrowRight: "<Right>",
    Delete: "<Del>",
    Home: "<Home>",
    End: "<End>",
    PageUp: "<PageUp>",
    PageDown: "<PageDown>",
  };
  if (named[ev.key]) return named[ev.key];
  if (ev.key.length === 1) {
    let char = ev.key;
    if (char === "<") char = "<lt>";
    if (!isCtrl && !isAlt) return char;
    let mod = "";
    if (isCtrl) mod += "C-";
    if (isAlt) mod += "A-";
    return `<${mod}${char}>`;
  }
  return null;
}

function main() {
  const transport = new WorkerTransport("nvim-worker.js", {
    cols: 120,
    rows: 40,
  });
  // internal FS.write/stderr trace line the worker emits.
  transport.onStatus((text) => {
    log("[status]", text);
    if (/^(FS\.write|WRITE HOOK|\[stderr\])/.test(text)) return;
    setStatus(text);
  });

  const nvim = new RpcClient(transport);
  window.nvim = nvim; // for console debugging

  const uiState = new UiState(120, 40);
  const gridEl = document.getElementById("grid");
  const modeEl = document.getElementById("mode");

  let apiInfoPromise = null;
  function ensureHandleTypesRegistered() {
    if (!apiInfoPromise) {
      apiInfoPromise = (async () => {
        const result = await nvim.request("nvim_get_api_info", []);
        log("RESPONSE nvim_get_api_info ->", result);

        const [channelId, metadata] = result;
        log("types metadata ->", metadata.types);

        registerNvimHandleTypes(metadata.types);
        setStatus("got nvim_get_api_info response, handle types registered");

        return result;
      })();
    }
    return apiInfoPromise;
  }

  // Auto-attach + visible failure status
  transport.onReady(async () => {
    const maxAttempts = 5;
    for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
      try {
        await ensureHandleTypesRegistered();
        await nvim.request("nvim_ui_attach", [
          110,
          40,
          { rgb: true, ext_linegrid: true },
        ]);
        setStatus("UI attached");
        return;
      } catch (e) {
        console.error(`auto-attach attempt ${attempt} failed`, e);
        log("auto-attach failed ->", e && e.message ? e.message : String(e));
        if (attempt === maxAttempts) {
          setStatus("auto-attach failed after retries, see console (F12)");
        } else {
          await new Promise((r) => setTimeout(r, 300 * attempt));
        }
      }
    }
  });
  transport.onExit((code) => {
      setStatus(`Neovim exited (code ${code}). Refresh the page to start a new session.`);
      gridEl.style.opacity = "0.5";
    });
  nvim.on("redraw", (params) =>
    handleRedrawEvents(uiState, gridEl, modeEl, params),
  );

  gridEl.addEventListener("click", () => gridEl.focus());
  gridEl.addEventListener("keydown", (ev) => {
    const isPasteShortcut =
      (ev.ctrlKey && ev.shiftKey && ev.key.toLowerCase() === "v") || // Linux/Win: Ctrl+Shift+V
      (ev.metaKey && ev.key.toLowerCase() === "v");                  // macOS: Cmd+V
    if (isPasteShortcut) {
      return;
    }
    const keys = translateKey(ev);
    if (!keys) return;
    ev.preventDefault();
    nvim
      .request("nvim_input", [keys])
      .catch((e) => console.error("nvim_input failed", e));
  });
  gridEl.addEventListener("paste", (ev) => {
    ev.preventDefault();
    const text = ev.clipboardData.getData("text/plain");
    if (!text) return;
    nvim
      .request("nvim_paste", [text, true, -1])
      .catch((e) => console.error("paste nvim_input failed", e));
  });

}

if (!crossOriginIsolated) {
  setStatus(
    "NOT cross-origin isolated -- SharedArrayBuffer unavailable. Serve with COOP/COEP headers.",
  );
} else {
  main();
}
