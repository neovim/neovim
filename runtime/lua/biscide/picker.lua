-- A picker: a source of items, a prompt the query is typed in, the items
-- the query matches (fuzzy, best first, |matchfuzzypos()|), the selected
-- one previewed; <CR> picks it. The GUI draws it (`vim._gui_send("picker",
-- …)`): the list from the items sent, the prompt and the preview as the
-- Nvim windows they are. Its pickers are biscide.pickers; vim.ui.select is
-- one (biscide.ui).
--
-- The prompt is a buffer's one line, typed in insert mode: Nvim's keys and
-- the configuration's insert maps work in it. Its own keys: <CR> picks,
-- <Esc> closes, <C-n> <C-p> <Down> <Up> <Tab> <S-Tab> <C-j> <C-k> move,
-- <PageDown> <PageUp> move a page, <C-f> <C-b> scroll the preview.

local M = {}

---@class biscide.PickerItemView
---@field text string what shows, and what the query matches
---@field detail? string what more shows (dimmed): a path, a line
---@field kind? string the badge: "func", "file:go", "error", …

---@class biscide.PickerPreview
---@field path? string a file, shown from its line `lnum` (from 1)
---@field lnum? integer
---@field col? integer from 0
---@field end_col? integer from 0: what is lit on the line
---@field lines? string[] else these lines
---@field ft? string their filetype

---@class biscide.PickerSpec
---@field title string
---@field items? any[]|fun(emit: fun(items: any[]), done: fun()): fun()? the items, or a source that gives them as it finds them (it may return its stop)
---@field live? fun(query: string, emit: fun(items: any[]), done: fun()): fun()? a source that finds the query itself (grep): run again as it is typed
---@field format fun(item: any): biscide.PickerItemView
---@field preview? fun(item: any): biscide.PickerPreview?
---@field confirm fun(item: any, index: integer)
---@field cancel? fun()
---@field query? string the query it opens with
---@field empty? string what it says when nothing matches

--- The most items the GUI is sent.
local SHOWN = 300
local DEBOUNCE_LIVE = 120

local ns = vim.api.nvim_create_namespace("biscide_picker")

---@class biscide.PickerState
local P = {
  spec = nil, ---@type biscide.PickerSpec?
  items = {}, ---@type any[]
  views = {}, ---@type biscide.PickerItemView[]
  matches = {}, ---@type { i: integer, pos: integer[] }[]
  sel = 1,
  query = "",
  busy = false,
  stop = nil, ---@type fun()?
  generation = 0,
  prompt = { buf = nil, win = nil },
  preview = { win = nil, bufs = {}, title = "" },
  from_win = nil, ---@type integer?
  last = nil, ---@type { spec: biscide.PickerSpec, query: string }?
}
M.state = P

local function size()
  local v = require("biscide.state").view.picker or {}
  return v.cols or 70, v.preview_cols or 80, v.preview_rows or 30
end

local function valid(win)
  return win and vim.api.nvim_win_is_valid(win)
end

-- ---- What the GUI is told ----

local function notify()
  local items = {}
  for k = 1, math.min(SHOWN, #P.matches) do
    local m = P.matches[k]
    local v = P.views[m.i]
    items[k] = { text = v.text, detail = v.detail or vim.NIL, kind = v.kind or vim.NIL, pos = m.pos }
  end
  require("biscide.view").send("picker", {
    open = P.spec ~= nil,
    title = P.spec and P.spec.title or vim.NIL,
    prompt_win = valid(P.prompt.win) and P.prompt.win or vim.NIL,
    preview_win = valid(P.preview.win) and P.preview.win or vim.NIL,
    preview_title = P.preview.title,
    items = items,
    selected = math.min(P.sel, #items),
    count = #P.matches,
    total = #P.items,
    busy = P.busy,
    empty = P.spec and P.spec.empty or vim.NIL,
  })
end

-- ---- The preview ----

--- A buffer with file `path`'s text: its own when loaded (the text being
--- edited), else a scratch one lit by its language's parser (no filetype:
--- no plugin, no language server, for a look).
local function preview_buf(path)
  local own = vim.fn.bufnr(path)
  if own ~= -1 and vim.api.nvim_buf_is_loaded(own) then
    return own
  end
  local buf = P.preview.bufs[path]
  if buf and vim.api.nvim_buf_is_valid(buf) then
    return buf
  end
  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  local ok, lines = pcall(vim.fn.readfile, path, "", 5000)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, ok and lines or { "(cannot read " .. path .. ")" })
  vim.bo[buf].modifiable = false
  local ft = vim.filetype.match({ filename = path })
  local lang = ft and vim.treesitter.language.get_lang(ft)
  if lang then
    pcall(vim.treesitter.start, buf, lang)
  end
  P.preview.bufs[path] = buf
  return buf
end

local function lines_buf(lines, ft)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  local lang = ft and vim.treesitter.language.get_lang(ft)
  if lang then
    pcall(vim.treesitter.start, buf, lang)
  end
  return buf
end

local function close_preview()
  if valid(P.preview.win) then
    pcall(vim.api.nvim_win_close, P.preview.win, true)
  end
  P.preview.win = nil
  P.preview.title = ""
end

--- The selected item previewed (its file at its line), if it says how.
local function show_preview()
  local m = P.matches[P.sel]
  local pv = m and P.spec.preview and P.spec.preview(P.items[m.i])
  if not pv then
    return close_preview()
  end
  local buf = pv.path and preview_buf(pv.path) or lines_buf(pv.lines or {}, pv.ft)
  local _, cols, rows = size()
  local cfg = { relative = "editor", row = 0, col = 0, width = cols, height = rows, zindex = 60 }
  if valid(P.preview.win) then
    vim.api.nvim_win_set_buf(P.preview.win, buf)
    vim.api.nvim_win_set_config(P.preview.win, cfg)
  else
    cfg.style = "minimal"
    cfg.focusable = false
    cfg.noautocmd = true
    P.preview.win = vim.api.nvim_open_win(buf, false, cfg)
    -- What is lit is lit in the preview only (its buffer may be a card's).
    if vim.api.nvim__ns_set then
      pcall(vim.api.nvim__ns_set, ns, { wins = { P.preview.win } })
    end
  end
  local win = P.preview.win
  vim.w[win].biscide_ui = true
  vim.wo[win].wrap = false
  vim.wo[win].number = true
  vim.wo[win].cursorline = true
  vim.wo[win].foldenable = false
  vim.wo[win].scrolloff = 0
  local count = vim.api.nvim_buf_line_count(buf)
  local lnum = math.max(1, math.min(pv.lnum or 1, count))
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  if pv.col and pv.end_col and pv.end_col > pv.col then
    pcall(vim.api.nvim_buf_set_extmark, buf, ns, lnum - 1, pv.col, { end_col = pv.end_col, hl_group = "Search" })
  end
  vim.api.nvim_win_call(win, function()
    vim.api.nvim_win_set_cursor(win, { lnum, pv.col or 0 })
    -- The line a third down the window (the file's first lines at its top).
    vim.fn.winrestview({ topline = math.max(1, lnum - math.floor(rows / 3)) })
  end)
  local where = pv.path and vim.fn.fnamemodify(pv.path, ":~:.") or ""
  P.preview.title = pv.path and (pv.lnum and (where .. ":" .. lnum) or where) or ""
end

-- ---- Matching ----

--- The items the query matches, best first (all, in order, for none).
local function refilter()
  local q = vim.trim(P.query)
  local matches = {}
  if q == "" or P.spec.live then
    for i = 1, #P.items do
      matches[i] = { i = i, pos = {} }
    end
    if P.spec.live and q ~= "" then
      -- What the source matched: the query's places in the text, lit.
      local lq = q:lower()
      for _, m in ipairs(matches) do
        local text = P.views[m.i].text:lower()
        local s, e = text:find(lq, 1, true)
        if s then
          local before = vim.str_utfindex(text, "utf-32", s - 1)
          local len = vim.str_utfindex(text:sub(s, e), "utf-32")
          for k = 0, len - 1 do
            m.pos[#m.pos + 1] = before + k
          end
        end
      end
    end
  else
    local list = {}
    for i, v in ipairs(P.views) do
      list[i] = { text = v.text, i = i }
    end
    local hits = vim.fn.matchfuzzypos(list, q, { key = "text" })
    for k, hit in ipairs(hits[1]) do
      matches[k] = { i = hit.i, pos = hits[2][k] }
    end
  end
  P.matches = matches
  P.sel = math.max(1, math.min(P.sel, #matches))
  show_preview()
  notify()
end

local refilter_pending = false
--- `refilter`, once, after what runs now (items come in many batches).
local function refilter_soon()
  if refilter_pending then
    return
  end
  refilter_pending = true
  vim.schedule(function()
    refilter_pending = false
    if P.spec then
      refilter()
    end
  end)
end

-- ---- The source ----

local function stop_source()
  if P.stop then
    pcall(P.stop)
  end
  P.stop = nil
  P.busy = false
end

--- Items found: kept, with how they show.
local function add(items, generation)
  if generation ~= P.generation or not P.spec then
    return
  end
  for _, it in ipairs(items) do
    P.items[#P.items + 1] = it
    P.views[#P.views + 1] = P.spec.format(it)
  end
  refilter_soon()
end

--- The source run (again): its items replace the ones there were.
local function run_source()
  stop_source()
  P.generation = P.generation + 1
  local generation = P.generation
  P.items, P.views, P.matches = {}, {}, {}
  local spec = P.spec
  local src = spec.live and function(emit, done)
    return spec.live(P.query, emit, done)
  end or spec.items
  if type(src) == "table" then
    add(src, generation)
    return
  end
  if spec.live and vim.trim(P.query) == "" then
    return refilter_soon()
  end
  P.busy = true
  local function emit(items)
    vim.schedule(function()
      add(items, generation)
    end)
  end
  local function done()
    vim.schedule(function()
      if generation == P.generation then
        P.busy = false
        P.stop = nil
        refilter_soon()
      end
    end)
  end
  P.stop = src(emit, done)
  notify()
end

-- ---- The prompt ----

local function query_of()
  return vim.api.nvim_buf_get_lines(P.prompt.buf, 0, 1, false)[1] or ""
end

local live_timer = nil
local function on_query()
  local q = query_of()
  if q == P.query then
    return
  end
  P.query = q
  P.sel = 1
  if P.spec.live then
    if live_timer then
      live_timer:stop()
    end
    live_timer = vim.defer_fn(function()
      live_timer = nil
      if P.spec and P.spec.live then
        run_source()
      end
    end, DEBOUNCE_LIVE)
  else
    refilter()
  end
end

--- The selection moved by `by` (kept on the list).
function M.move(by)
  if #P.matches == 0 then
    return
  end
  P.sel = math.max(1, math.min(math.min(#P.matches, SHOWN), P.sel + by))
  show_preview()
  notify()
end

--- Item `k` (of the list shown, from 1) selected.
function M.select(k)
  if not P.spec then
    return
  end
  P.sel = math.max(1, math.min(k, #P.matches))
  show_preview()
  notify()
  if valid(P.prompt.win) then
    vim.api.nvim_set_current_win(P.prompt.win)
  end
end

--- The preview scrolled by `by` lines.
function M.scroll_preview(by)
  if not valid(P.preview.win) then
    return
  end
  vim.api.nvim_win_call(P.preview.win, function()
    local key = by > 0 and "\5" or "\25"
    vim.cmd(("normal! %d%s"):format(math.abs(by), key))
  end)
end

local function make_prompt()
  if P.prompt.buf and vim.api.nvim_buf_is_valid(P.prompt.buf) then
    return P.prompt.buf
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "biscide://picker")
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].filetype = "biscide_picker"
  -- No completion, no pairs in the query (the plugins that would read
  -- these): the picker's keys are its own.
  vim.b[buf].completion = false
  vim.b[buf].cmp_enabled = false
  vim.b[buf].minipairs_disable = true
  vim.b[buf].autopairs_disable = true
  P.prompt.buf = buf
  local function map(modes, lhs, fn)
    vim.keymap.set(modes, lhs, fn, { buffer = buf, nowait = true, desc = "biscide picker" })
  end
  local both = { "i", "n" }
  map(both, "<CR>", function()
    M.confirm()
  end)
  map("i", "<Esc>", M.close)
  map("n", "<Esc>", M.close)
  map("n", "q", M.close)
  map(both, "<C-c>", M.close)
  for _, k in ipairs({ "<C-n>", "<Down>", "<C-j>", "<Tab>" }) do
    map(both, k, function()
      M.move(1)
    end)
  end
  for _, k in ipairs({ "<C-p>", "<Up>", "<C-k>", "<S-Tab>" }) do
    map(both, k, function()
      M.move(-1)
    end)
  end
  map(both, "<PageDown>", function()
    M.move(10)
  end)
  map(both, "<PageUp>", function()
    M.move(-10)
  end)
  map(both, "<C-f>", function()
    M.scroll_preview(8)
  end)
  map(both, "<C-b>", function()
    M.scroll_preview(-8)
  end)
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, { buffer = buf, callback = on_query })
  return buf
end

-- ---- Opening, picking, closing ----

--- Closes the picker; `picked`: an item was picked (no cancel).
local function finish(picked)
  local spec = P.spec
  if not spec then
    return
  end
  stop_source()
  P.last = { spec = spec, query = P.query }
  P.spec = nil
  if valid(P.prompt.win) then
    pcall(vim.api.nvim_win_close, P.prompt.win, true)
  end
  P.prompt.win = nil
  close_preview()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  end
  for _, buf in pairs(P.preview.bufs) do
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
  P.preview.bufs = {}
  vim.cmd.stopinsert()
  if valid(P.from_win) then
    vim.api.nvim_set_current_win(P.from_win)
  end
  notify()
  if not picked and spec.cancel then
    spec.cancel()
  end
end

function M.close()
  finish(false)
end

--- Picks the selected item (else item `k`, from 1).
function M.confirm(k)
  if not P.spec then
    return
  end
  if k then
    P.sel = k
  end
  -- Keys typed ahead come before TextChangedI: the list as typed.
  if query_of() ~= P.query then
    on_query()
  end
  local m = P.matches[P.sel]
  local spec = P.spec
  if not m then
    return
  end
  local item, index = P.items[m.i], m.i
  finish(true)
  vim.schedule(function()
    spec.confirm(item, index)
  end)
end

--- Opens a picker (another one open is closed).
---@param spec biscide.PickerSpec
function M.open(spec)
  if P.spec then
    finish(false)
  end
  local cur = vim.api.nvim_get_current_win()
  P.from_win = vim.w[cur].biscide_ui and P.from_win or cur
  P.spec = spec
  P.query = spec.query or ""
  P.sel = 1
  local buf = make_prompt()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { P.query })
  local cols = size()
  P.prompt.win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = 0,
    col = 0,
    width = cols,
    height = 1,
    style = "minimal",
    zindex = 70,
  })
  vim.w[P.prompt.win].biscide_ui = true
  vim.wo[P.prompt.win].wrap = false
  vim.cmd.startinsert({ bang = true })
  run_source()
  refilter()
end

--- The last picker again, with its query.
function M.resume()
  if not P.last then
    return require("biscide.view").notice("No picker yet.")
  end
  local spec = vim.tbl_extend("force", P.last.spec, { query = P.last.query })
  M.open(spec)
end

--- The windows sized to the GUI's picker (biscide.view's `view`).
function M.resize()
  if not P.spec then
    return
  end
  local cols, pcols, prows = size()
  if valid(P.prompt.win) then
    vim.api.nvim_win_set_config(P.prompt.win, { relative = "editor", row = 0, col = 0, width = cols, height = 1 })
  end
  if valid(P.preview.win) then
    vim.api.nvim_win_set_config(P.preview.win, { relative = "editor", row = 0, col = 0, width = pcols, height = prows })
  end
end

return M
