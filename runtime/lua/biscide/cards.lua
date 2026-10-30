-- The cards: each a struct with a handle of its own, never reused (as Nvim
-- numbers its windows), held in a registry by its key (its part of a file
-- and its lane). A card is a floating window on the real file's buffer,
-- kept to its part (biscide.narrow): it shows and edits only its part, while
-- the buffer is the whole file (the language server sees it all; `:w` is
-- an ordinary write). Its window is as tall as its part (wrapped): the
-- card shows up to the rows the view allows of it, and the GUI scrolls
-- them itself, smoothly. The GUI places it. The empty card at the file lane's end is
-- on the lines a new declaration is being written in.

local narrow = require("biscide.narrow")

---@class biscide.Card
---@field handle integer
---@field key string `<rel>:<ident>:<lane>` (or "new"): the same card across edits
---@field node? integer its part's node (none: the empty card)
---@field lane biscide.Lane
---@field win integer
---@field buf integer
---@field rows integer the rows the card shows (its window has all its part's)
---@field textoff integer the columns before its text (line numbers, signs)
---@field srow integer the row (from 0) its view was last put at

---@class biscide.Cards
---@field by_key table<string, biscide.Card>
---@field next_handle integer
local Cards = {}
Cards.__index = Cards

Cards.NEW_KEY = "new"

---@return biscide.Cards
function Cards.new()
  return setmetatable({ by_key = {}, next_handle = 1 }, Cards)
end

--- A card's key: its part (file and identity) and lane.
---@param n table a graph node
---@param lane biscide.Lane
function Cards.key(n, lane)
  return ("%s:%s:%s"):format(n.rel, n.ident, lane)
end

--- The real file's buffer, loaded.
---@param path string
---@return integer
function Cards.buffer(path)
  local buf = vim.fn.bufadd(path)
  if not vim.api.nvim_buf_is_loaded(buf) then
    vim.fn.bufload(buf)
    vim.bo[buf].buflisted = true
    local ft = vim.filetype.match({ buf = buf })
    if ft and vim.bo[buf].filetype ~= ft then
      vim.bo[buf].filetype = ft
    end
  end
  return buf
end

--- A card window's options. Its gutter keeps its width (a sign appearing
--- would wrap its lines more than its height has room for), and Nvim never
--- scrolls in it by parts of a line (the GUI scrolls the card itself).
Cards.WINDOW = {
  number = true,
  relativenumber = true,
  signcolumn = "yes:1",
  statuscolumn = "",
  foldcolumn = "0",
  foldenable = false,
  wrap = true,
  linebreak = true,
  smoothscroll = false,
  scrolloff = 0,
  -- The float's own background is the editor's: the GUI paints none (the
  -- canvas shows through).
  winhighlight = "NormalFloat:Normal,FloatBorder:Normal",
}

--- A card's of what is not code (a missing declaration's): no numbers.
Cards.PLAIN = vim.tbl_extend("force", Cards.WINDOW, { number = false, relativenumber = false, signcolumn = "no" })

--- The card window options set (those that differ: setting one fires
--- OptionSet, which lays the cards out again).
local function set_options(win, options)
  -- Yours (`vim.g.biscide_card_options`) over biscide's.
  options = vim.tbl_extend("force", options or Cards.WINDOW, vim.g.biscide_card_options or {})
  for name, value in pairs(options) do
    if vim.wo[win][name] ~= value then
      vim.wo[win][name] = value
    end
  end
end

local function config(cols, rows)
  return { relative = "editor", row = 0, col = 0, width = cols, height = math.max(1, rows) }
end

--- The card of `key`: its window (made, or moved onto `buf`), kept to rows
--- `srow..erow` of it, its view at its first row when they moved; its
--- window `options` (else Cards.WINDOW).
---@return biscide.Card
function Cards:place(key, buf, srow, erow, view, lane, node, options)
  local card = self.by_key[key]
  local fresh = not (card and vim.api.nvim_win_is_valid(card.win))
  if fresh then
    local cfg = config(view.cols, erow - srow + 1)
    cfg.style = "minimal"
    cfg.zindex = 10
    card = { handle = self.next_handle, key = key, win = vim.api.nvim_open_win(buf, false, cfg) }
    self.next_handle = self.next_handle + 1
    self.by_key[key] = card
  elseif vim.api.nvim_win_get_buf(card.win) ~= buf then
    vim.api.nvim_win_set_buf(card.win, buf)
    fresh = true
  end
  local win = card.win
  card.options = options
  set_options(win, options)
  narrow.set(win, srow, erow)
  if fresh or card.srow ~= srow then
    -- The view to the part's first line; the cursor too, unless the reader
    -- is in this card (typing in it).
    local here = win == vim.api.nvim_get_current_win()
    vim.api.nvim_win_call(win, function()
      vim.fn.winrestview(here and { topline = srow + 1 } or { topline = srow + 1, lnum = srow + 1, col = 0 })
    end)
  end
  -- Wrapped, the part may take more rows than lines. The window has them
  -- all (as many as the screen has); the card shows some.
  local ok, h = pcall(vim.api.nvim_win_text_height, win, { start_row = srow, end_row = erow, start_vcol = 0 })
  local all = math.max(1, (ok and h.all) or (erow - srow + 1))
  local rows = math.min(all, view.max_rows)
  vim.api.nvim_win_set_config(win, config(view.cols, math.min(all, vim.o.lines - 2)))
  narrow.clamp_view(win)
  local info = vim.fn.getwininfo(win)[1]
  card.textoff = info and info.textoff or 0
  card.buf, card.rows, card.lane, card.node, card.srow = buf, rows, lane, node, srow
  return card
end

--- The card's window as tall as its part again (its part grew or shrank as
--- it was typed in), its view back on the part.
---@param card biscide.Card
function Cards:fit(card)
  set_options(card.win, card.options)
  local s, e = narrow.rows(card.win)
  if not s then
    return
  end
  local ok, h = pcall(vim.api.nvim_win_text_height, card.win, { start_row = s, end_row = e, start_vcol = 0 })
  local all = math.min(math.max(1, (ok and h.all) or (e - s + 1)), vim.o.lines - 2)
  if all ~= vim.api.nvim_win_get_height(card.win) then
    vim.api.nvim_win_set_height(card.win, all)
  end
  narrow.clamp_view(card.win)
end

--- The card of node `n` (a declaration or another part) in `lane`.
---@param view { max_rows: integer, cols: integer }
---@return biscide.Card
---@param free? fun(from: integer, to: integer): boolean whether no other part of its file has rows `from..to`
function Cards:place_part(n, lane, view, free)
  local key, buf = Cards.key(n, lane), Cards.buffer(n.path)
  local srow, erow = self:typing_rows(key, buf, n.srow, n.erow, free)
  -- Its file typed in since it was read: the rows its window keeps (they
  -- followed the edits), not the old ones read.
  local card = self:get(key)
  if card and require("biscide.state").stale[n.path] then
    local s, e = narrow.rows(card.win)
    srow, erow = s or srow, e or erow
  end
  return self:place(key, buf, srow, erow, view, lane, n.id)
end

--- The rows card `key` is kept to: its part's; and, in the card the cursor
--- is in, the lines from its part to the cursor's that no other part has
--- (lines being written, or code read as nothing while half typed): the
--- card keeps them, the cursor is not pushed out of it.
---@param free? fun(from: integer, to: integer): boolean
---@return integer, integer
function Cards:typing_rows(key, buf, srow, erow, free)
  local card = self.by_key[key]
  local win = vim.api.nvim_get_current_win()
  if not (card and card.win == win and vim.api.nvim_win_get_buf(win) == buf) then
    return srow, erow
  end
  local row = vim.api.nvim_win_get_cursor(win)[1] - 1
  free = free or function(from, to)
    for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, from, to + 1, false)) do
      if line:find("%S") then
        return false
      end
    end
    return true
  end
  if row > erow and free(erow + 1, row) then
    return srow, row
  elseif row < srow and free(row, srow - 1) then
    return row, erow
  end
  return srow, erow
end

--- Card `card` now the card of `key` (its declaration renamed as it was
--- typed in): the same window, kept.
---@param card biscide.Card
---@param key string
function Cards:rekey(card, key)
  if card.key == key then
    return
  end
  local other = self.by_key[key]
  if other and other ~= card then
    pcall(vim.api.nvim_win_close, other.win, true)
  end
  self.by_key[card.key] = nil
  card.key = key
  self.by_key[key] = card
end

--- The empty card, on rows `srow..erow` of the file being written in.
---@return biscide.Card
function Cards:place_new(path, srow, erow, view)
  return self:place(Cards.NEW_KEY, Cards.buffer(path), srow, erow, view, "file", nil)
end

---@param key string
---@return biscide.Card?
function Cards:get(key)
  local card = self.by_key[key]
  if card and vim.api.nvim_win_is_valid(card.win) then
    return card
  end
end

--- The card showing window `win`, if any.
---@return biscide.Card?
function Cards:of_win(win)
  for _, card in pairs(self.by_key) do
    if card.win == win then
      return card
    end
  end
end

--- Closes the cards whose keys `keep` lacks.
---@param keep table<string, boolean>
function Cards:retain(keep)
  for key, card in pairs(self.by_key) do
    if not keep[key] then
      pcall(vim.api.nvim_win_close, card.win, true)
      self.by_key[key] = nil
    end
  end
end

return Cards
