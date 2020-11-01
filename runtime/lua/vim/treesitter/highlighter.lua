local a = vim.api

-- support reload for quick experimentation
local TSHighlighter = rawget(vim.treesitter, 'TSHighlighter') or {}
TSHighlighter.__index = TSHighlighter

local TSHighlighterRegion = {}
TSHighlighterRegion.__index = TSHighlighterRegion

TSHighlighter.active = TSHighlighter.active or {}

local ns = a.nvim_create_namespace("treesitter/highlighter")

-- These are conventions defined by nvim-treesitter, though it
-- needs to be user extensible also.
TSHighlighter.hl_map = {
    ["error"] = "Error",

-- Miscs
    ["comment"] = "Comment",
    ["punctuation.delimiter"] = "Delimiter",
    ["punctuation.bracket"] = "Delimiter",
    ["punctuation.special"] = "Delimiter",

-- Constants
    ["constant"] = "Constant",
    ["constant.builtin"] = "Special",
    ["constant.macro"] = "Define",
    ["string"] = "String",
    ["string.regex"] = "String",
    ["string.escape"] = "SpecialChar",
    ["character"] = "Character",
    ["number"] = "Number",
    ["boolean"] = "Boolean",
    ["float"] = "Float",

-- Functions
    ["function"] = "Function",
    ["function.special"] = "Function",
    ["function.builtin"] = "Special",
    ["function.macro"] = "Macro",
    ["parameter"] = "Identifier",
    ["method"] = "Function",
    ["field"] = "Identifier",
    ["property"] = "Identifier",
    ["constructor"] = "Special",

-- Keywords
    ["conditional"] = "Conditional",
    ["repeat"] = "Repeat",
    ["label"] = "Label",
    ["operator"] = "Operator",
    ["keyword"] = "Keyword",
    ["exception"] = "Exception",

    ["type"] = "Type",
    ["type.builtin"] = "Type",
    ["structure"] = "Structure",
    ["include"] = "Include",
}

-- Represents a highlighted region.
-- A region contains a set of non-overlapping ranges.
-- These ranges will be queried and parsed together by the parser.
function TSHighlighterRegion.new(regions, root_node)
  local self = setmetatable({
    iter = nil,
    root = root_node,
    active_range = 1,
    ranges = {},
  }, TSHighlighterRegion)

  local bot_line = nil
  local top_line = nil
  local start_col = nil
  local end_cold = nil

  if regions then
    for _, region in ipairs(regions) do
      table.insert(self.ranges, {region:range()})
    end

    -- Sort to ensure they are in order from top to bottom.
    -- This keeps us from having to do the order lookup when
    -- applying the highlights.
    table.sort(self.ranges, function(a, b)
      return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2])
    end)
  else
    table.insert(self.ranges, {root_node:range()})
  end

  local head = self.ranges[1]
  local tail = self.ranges[#self.ranges]

  if head then
    top_line = head[1]
    start_col = head[2]
  end

  if tail then
    bot_line = tail[3]
    end_col = tail[4]
  end

  self.botline = bot_line
  self.topline = top_line
  self.nextrow = top_line
  self.start_col = start_col
  self.end_col = end_col

  return self
end

--- Resets a regions state.
function TSHighlighterRegion:reset()
  self.nextrow = self.topline
  self.iter = nil
  self.active_range = 1
end

function TSHighlighterRegion:range()
  return self.topline, self.start_col, self.botline, self.end_col
end

-- Determines if any of a regions ranges includes the given line.
function TSHighlighterRegion:intersects_line(line)
  for _, range in ipairs(self.ranges) do
    if line >= range[1] and line <= range[3] then
      return true
    end
  end

  return false
end

-- Determines if any range of the region is contained within the given range.
function TSHighlighterRegion:is_in_range(range)
  for _, source in ipairs(self.ranges) do
    local start_fits = range[1] > source[1] or (source[1] == range[1] and range[2] >= source[2])
    local end_fits = range[3] < source[3] or (source[3] == range[3] and range[4] <= source[4])

    if start_fits and end_fits then
      return true
    end
  end

  return false
end

-- Determines if the line is within the currently active highlighting range.
-- This is an optimization avoid looking at every range during highlighting.
function TSHighlighterRegion:is_in_active_range(line)
  local range = self.active_range and self.ranges[self.active_range] or nil

  return range and line >= range[1] and line <= range[3]
end

-- Advances the next row of the region.
-- If the the next row is outside the active range
-- we move to the next range of the region.
function TSHighlighterRegion:advance_range(nextrow)
  if self:is_in_active_range(nextrow) then
    self.nextrow = nextrow
  elseif self.active_range then
    -- Since these ranges are sorted we can just increment
    -- to move forward.
    self.active_range = self.active_range + 1

    local range = self.ranges[self.active_range]

    if range then
      self.nextrow = range[1]
    end
  end
end

function TSHighlighter.new(parser, query, opts)
  local self = setmetatable({}, TSHighlighter)

  opts = opts or {}

  self.parser = parser
  parser:register_cbs {
    on_changedtree = function(...) self:on_changedtree(...) end
  }

  self:set_query(query)
  self.edit_count = 0
  self.redraw_count = 0
  self.line_count = {}
  self.regions = {}
  self.ranges = nil
  self.id = opts.id or parser.lang

  if opts.ranges then
    self:set_ranges(opts.ranges)
  end

  self.parser:invalidate()
  self:parse()
  -- self.root = self.parser:parse():root()
  a.nvim_buf_set_option(self.buf, "syntax", "")

  -- TODO(bfredl): can has multiple highlighters per buffer????
  if not TSHighlighter.active[parser.bufnr] then
    TSHighlighter.active[parser.bufnr] = {}
  end

  TSHighlighter.active[parser.bufnr][self.id] = self

  -- Tricky: if syntax hasn't been enabled, we need to reload color scheme
  -- but use synload.vim rather than syntax.vim to not enable
  -- syntax FileType autocmds. Later on we should integrate with the
  -- `:syntax` and `set syntax=...` machinery properly.
  if vim.g.syntax_on ~= 1 then
    vim.api.nvim_command("runtime! syntax/synload.vim")
  end
  return self
end

local function is_highlight_name(capture_name)
  local firstc = string.sub(capture_name, 1, 1)
  return firstc ~= string.lower(firstc)
end

function TSHighlighter:destroy()
  if TSHighlighter.active[self.parser.bufnr] then
    TSHighlighter.active[self.parser.bufnr][self.id] = nil
  end
end

-- Parses the regions of the highlighter.
-- This uses the same parser to parse each region.
function TSHighlighter:parse()
  if not self.parser.valid then
    self.regions = {}

    if self.ranges then
      for _, range_nodes in ipairs(self.ranges) do
        self.parser:set_included_ranges(range_nodes)
        table.insert(self.regions, TSHighlighterRegion.new(range_nodes, self.parser:parse():root()))
      end
    else
      table.insert(self.regions, TSHighlighterRegion.new(nil, self.parser:parse():root()))
    end
  end

  return self.regions
end

-- Sets the ranges the parser uses to create regions.
-- Note, the parser is invalidated and `parse` on the highlighter
-- will need to be called again.
-- Calling parser directly on the parser will give unexpected results.
function TSHighlighter:set_ranges(ranges)
  self.ranges = #ranges > 0 and ranges or nil
  self.parser:invalidate()
end

function TSHighlighter:get_hl_from_capture(capture)

  local name = self.query.captures[capture]

  if is_highlight_name(name) then
    -- From "Normal.left" only keep "Normal"
    return vim.split(name, '.', true)[1]
  else
    -- Default to false to avoid recomputing
    local hl = TSHighlighter.hl_map[name]
    return hl and a.nvim_get_hl_id_by_name(hl) or 0
  end
end

function TSHighlighter:on_changedtree(changes)
  for _, ch in ipairs(changes or {}) do
    a.nvim__buf_redraw_range(self.buf, ch[1], ch[3]+1)
  end
end

function TSHighlighter:set_query(query)
  if type(query) == "string" then
    query = vim.treesitter.parse_query(self.parser.lang, query)
  end

  self.query = query

  self.hl_cache = setmetatable({}, {
    __index = function(table, capture)
      local hl = self:get_hl_from_capture(capture)
      rawset(table, capture, hl)

      return hl
    end
  })

  a.nvim__buf_redraw_range(self.parser.bufnr, 0, a.nvim_buf_line_count(self.parser.bufnr))
end

local function iter_active_tshl(buf, fn)
  for _, hl in pairs(TSHighlighter.active[buf] or {}) do
    fn(hl)
  end
end

local function on_line_impl(self, buf, line)
  if #self.regions == 0 then
    return -- parser bought the farm already
  end

  for _, region in ipairs(self.regions) do
    if region:is_in_active_range(line) then
      if region.iter == nil then
        region.iter = self.query:iter_captures(region.root,buf,line,region.botline+1)
      end
      while line >= region.nextrow do
        local capture, node = region.iter()
        if capture == nil then
          break
        end
        local start_row, start_col, end_row, end_col = node:range()
        local hl = self.hl_cache[capture]
        if hl and end_row >= line then
          a.nvim_buf_set_extmark(buf, ns, start_row, start_col,
                                 { end_line = end_row, end_col = end_col,
                                   hl_group = hl,
                                   ephemeral = true
                                  })
        end
        if start_row > line then
          region:advance_range(start_row)
        end
      end
    end
  end
end

function TSHighlighter._on_line(_, _win, buf, line, highlighter)
  -- on_line is only called when this is non-nil
  if highlighter then
    on_line_impl(highlighter, buf, line)
  else
    iter_active_tshl(buf, function(self)
      on_line_impl(self, buf, line)
    end)
  end
end

function TSHighlighter._on_buf(_, buf)
  iter_active_tshl(buf, function(self)
    if self then
      self:parse()
    end
  end)
end

function TSHighlighter._on_win(_, _win, buf, _topline, botline)
  iter_active_tshl(buf, function(self)
    if not self then
      return false
    end

    for _, region in ipairs(self.regions) do
      region:reset()
    end
    self.redraw_count = self.redraw_count + 1
    return true
  end)
  return true
end

a.nvim_set_decoration_provider(ns, {
  on_buf = TSHighlighter._on_buf;
  on_win = TSHighlighter._on_win;
  on_line = TSHighlighter._on_line;
})

return TSHighlighter
