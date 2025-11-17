--- @brief A [LanguageTree]() contains a tree of parsers: the root treesitter parser for {lang} and
--- any "injected" language parsers, which themselves may inject other languages, recursively.
--- For example a Lua buffer containing some Vimscript commands needs multiple parsers to fully
--- understand its contents.
---
--- To create a LanguageTree (parser object) for a given buffer and language, use:
---
--- ```lua
--- local parser = vim.treesitter.get_parser(bufnr, lang)
--- ```
---
--- (where `bufnr=0` means current buffer). `lang` defaults to 'filetype'.
--- Note: currently the parser is retained for the lifetime of a buffer but this may change;
--- a plugin should keep a reference to the parser object if it wants incremental updates.
---
--- Whenever you need to access the current syntax tree, parse the buffer:
---
--- ```lua
--- local tree = parser:parse({ start_row, end_row })
--- ```
---
--- This returns a table of immutable |treesitter-tree| objects representing the current state of
--- the buffer. When the plugin wants to access the state after a (possible) edit it must call
--- `parse()` again. If the buffer wasn't edited, the same tree will be returned again without extra
--- work. If the buffer was parsed before, incremental parsing will be done of the changed parts.
---
--- Note: To use the parser directly inside a |nvim_buf_attach()| Lua callback, you must call
--- |vim.treesitter.get_parser()| before you register your callback. But preferably parsing
--- shouldn't be done directly in the change callback anyway as they will be very frequent. Rather
--- a plugin that does any kind of analysis on a tree should use a timer to throttle too frequent
--- updates.
---

-- Debugging:
--
-- vim.g.__ts_debug levels:
--    - 1. Messages from languagetree.lua
--    - 2. Parse messages from treesitter
--    - 2. Lex messages from treesitter
--
-- Log file can be found in stdpath('log')/treesitter.log

local query = require('vim.treesitter.query')
local language = require('vim.treesitter.language')
local Range = require('vim.treesitter._range')
local api = vim.api
local hrtime = vim.uv.hrtime

-- Parse in 3ms chunks.
local default_parse_timeout_ns = 3 * 1000000

-- The largest region supported by treesitter
local max_region = { { 0, 0, 0, 4294967295, 4294967295, 4294967295 } }

---@alias TSCallbackName
---| 'changedtree'
---| 'bytes'
---| 'detach'
---| 'child_added'
---| 'child_removed'

---@alias TSCallbackNameOn
---| 'on_changedtree'
---| 'on_bytes'
---| 'on_detach'
---| 'on_child_added'
---| 'on_child_removed'

---@alias ParserThreadState { timeout: integer? }

--- @type table<TSCallbackNameOn,TSCallbackName>
local TSCallbackNames = {
  on_changedtree = 'changedtree',
  on_bytes = 'bytes',
  on_detach = 'detach',
  on_child_added = 'child_added',
  on_child_removed = 'child_removed',
}

--- Here one extmark maps to one tree. For a combined injection, this will mean multiple ranges. In
--- this case, the range of the extmark should extend from the start of the first range until the end
--- of the last range.
---
--- Note that depending on whether this region has been parsed yet, the value will either be a full
--- tree, or just a Range6 denoting the space that tree will occupy.
---
---@alias vim.treesitter.languagetree.ParseRegion { valid: boolean, value: TSTree|Range6[], root: true? }

---@nodoc
---@class vim.treesitter.LanguageTree
---@field private _callbacks table<TSCallbackName,function[]> Callback handlers
---@field package _callbacks_rec table<TSCallbackName,function[]> Callback handlers (recursive)
---@field private _children table<string,vim.treesitter.LanguageTree> Injected languages
---@field private _injection_query vim.treesitter.Query Queries defining injected languages
---@field private _opts table Options
---@field private _parser TSParser Parser for language
---Table of regions for which the tree is currently running an async parse
---@field private _ranges_being_parsed table<string, boolean>
---Table of callback queues, keyed by each region for which the callbacks should be run
---@field private _cb_queues table<string, fun(err?: string, trees?: table<integer, TSTree>)[]>
---The total number of regions. Since _regions can have holes, we cannot simply read this value from #_regions.
---@field private _ns integer The extmark namespace for this LanguageTree's injection regions.
---@field private _injection_query_ns integer The namespace for extmarks representing ranges that have been queried for injections.
---@field private _parser_regions table<integer, vim.treesitter.languagetree.ParseRegion>
---@field private _lang string Language name
---@field private _parent? vim.treesitter.LanguageTree Parent LanguageTree
---@field private _source integer Buffer to parse
---@field private _has_scratch_buf boolean Whether _source is a |scratch-buffer| for string parsing.
---@field private _logger? fun(logtype: string, msg: string)
---@field private _logfile? file*
local LanguageTree = {}

---Optional arguments:
---@class vim.treesitter.LanguageTree.new.Opts
---@inlinedoc
---@field queries? table<string,string>  -- Deprecated
---@field injections? table<string,string>

LanguageTree.__index = LanguageTree

--- @nodoc
---
--- LanguageTree contains a tree of parsers: the root treesitter parser for {lang} and any
--- "injected" language parsers, which themselves may inject other languages, recursively.
---
---@param source (integer|string) Buffer or text string to parse
---@param lang string Root language of this tree
---@param opts vim.treesitter.LanguageTree.new.Opts?
---@return vim.treesitter.LanguageTree parser object
function LanguageTree.new(source, lang, opts)
  assert(language.add(lang))
  opts = opts or {}

  if source == 0 then
    source = api.nvim_get_current_buf()
  end

  local has_scratch_buf = false

  if type(source) == 'string' then
    local new_source = api.nvim_create_buf(false, true)
    if new_source == 0 then
      error('Unable to create buffer for string parser')
    end
    vim.bo[new_source].fixeol = false
    vim.bo[new_source].eol = false
    api.nvim_buf_set_lines(new_source, 0, -1, false, vim.split(source, '\n', { plain = true }))
    source = new_source
    has_scratch_buf = true
  end

  local injections = opts.injections or {}

  --- @class vim.treesitter.LanguageTree
  local self = {
    _source = source,
    _has_scratch_buf = has_scratch_buf,
    _lang = lang,
    _children = {},
    _opts = opts,
    _injection_query = injections[lang] and query.parse(lang, injections[lang])
      or query.get(lang, 'injections'),
    _ns = api.nvim_create_namespace(''),
    _injection_query_ns = api.nvim_create_namespace(''),
    _parser_regions = {},
    _parser = vim._create_ts_parser(lang),
    _ranges_being_parsed = {},
    _cb_queues = {},
    _callbacks = {},
    _callbacks_rec = {},
  }

  -- For the root tree, insert one extmark which covers the entire buffer, and has the largest range
  -- supported by treesitter
  local id = api.nvim_buf_set_extmark(self._source, self._ns, 0, 0, {
    -- Extmarks cannot be placed outside of buffer limits, even with strict = false.
    end_line = api.nvim_buf_line_count(self._source),
    end_col = 0,
    right_gravity = false,
    end_right_gravity = true,
  })
  self._parser_regions[id] = { valid = false, value = max_region, root = true }

  setmetatable(self, LanguageTree)

  if vim.g.__ts_debug and type(vim.g.__ts_debug) == 'number' then
    self:_set_logger()
    self:_log('START')
  end

  for _, name in pairs(TSCallbackNames) do
    self._callbacks[name] = {}
    self._callbacks_rec[name] = {}
  end

  return self
end

--- @private
function LanguageTree:_set_logger()
  local source = tostring(self:source())

  local lang = self:lang()

  local logdir = vim.fn.stdpath('log') --[[@as string]]

  vim.fn.mkdir(logdir, 'p')
  local logfilename = vim.fs.joinpath(logdir, 'treesitter.log')

  local logfile, openerr = io.open(logfilename, 'a+')

  if not logfile or openerr then
    error(string.format('Could not open file (%s) for logging: %s', logfilename, openerr))
    return
  end

  self._logfile = logfile

  self._logger = function(logtype, msg)
    self._logfile:write(string.format('%s:%s:(%s) %s\n', source, lang, logtype, msg))
    self._logfile:flush()
  end

  local log_lex = vim.g.__ts_debug >= 3
  local log_parse = vim.g.__ts_debug >= 2
  self._parser:_set_logger(log_lex, log_parse, self._logger)
end

---Measure execution time of a function, in nanoseconds.
---@generic R1, R2, R3
---@param f fun(): R1, R2, R3
---@return number, R1, R2, R3
local function tcall(f, ...)
  local start = hrtime()
  ---@diagnostic disable-next-line
  local r = { f(...) }
  --- @type number
  local duration = hrtime() - start
  --- @diagnostic disable-next-line: redundant-return-value
  return duration, unpack(r)
end

---@private
---@param ... any
function LanguageTree:_log(...)
  if not self._logger then
    return
  end

  if not vim.g.__ts_debug or vim.g.__ts_debug < 1 then
    return
  end

  local args = { ... }
  if type(args[1]) == 'function' then
    args = { args[1]() }
  end

  local info = debug.getinfo(2, 'nl')
  local nregions = #api.nvim_buf_get_extmarks(self._source, self._ns, 0, -1, {})
  local prefix =
    string.format('%s:%d: (#regions=%d) ', info.name or '???', info.currentline or 0, nregions)

  local msg = { prefix }
  for _, x in ipairs(args) do
    if type(x) == 'string' then
      msg[#msg + 1] = x
    else
      msg[#msg + 1] = vim.inspect(x, { newline = ' ', indent = '' })
    end
  end
  self._logger('nvim', table.concat(msg, ' '))
end

--- Invalidates this parser and its children.
---
--- Should only be called when the tracked state of the LanguageTree is not valid against the parse
--- tree in treesitter. Doesn't clear filesystem cache. Called often, so needs to be fast.
---@param reload boolean|nil
function LanguageTree:invalidate(reload)
  self._parser:reset()

  -- buffer was reloaded, reparse all trees
  if reload then
    local marks = self:_get_marks()
    for _, mark in ipairs(marks) do
      local mark_region = self._parser_regions[mark[1]]
      mark_region.valid = false
      ---@type TSTree?
      local tree = type(mark_region.value) == 'userdata' and mark_region.value or nil
      if tree then
        local region = tree:included_ranges(true)
        self:_do_callback('changedtree', region, tree)
        mark_region.value = region
      end
    end
  end

  for _, child in pairs(self._children) do
    child:invalidate(reload)
  end
end

--- Returns the trees parsed by this |LanguageTree|. Does not include child languages.
---
---@param range Range? If present, only return trees that overlap the given range.
---@return TSTree[]
function LanguageTree:trees(range)
  ---@type TSTree[]
  local trees = {}

  for _, mark in ipairs(self:_get_marks(range)) do
    local mark_region = self._parser_regions[mark[1]]
    if type(mark_region.value) == 'userdata' then
      trees[#trees + 1] = mark_region.value
    end
  end

  return trees
end

--- Gets the language of this tree node.
--- @return string
function LanguageTree:lang()
  return self._lang
end

--- @param region Range6[]
--- @param range? boolean|Range
--- @return boolean
local function intersects_region(region, range)
  -- We don't descend into children if range is falsy, so assume any non-table range counts as an
  -- intersection (because we want to parse all regions of the current, non-injected, tree).
  if type(range) ~= 'table' then
    return true
  end

  for _, r in ipairs(region) do
    if Range.intercepts(r, range) then
      return true
    end
  end

  return false
end

---Check whether the given range is fully contained by the ranges that have been queried for
---injections.
---
---@param range Range
function LanguageTree:_has_queried_injections(range)
  ---@diagnostic disable-next-line: missing-fields
  range = { Range.unpack4(range) }

  -- The rightmost point that has been checked.
  local current_end = { range[1], range[2] }

  local marks = api.nvim_buf_get_extmarks(
    self._source,
    self._injection_query_ns,
    { range[1], range[2] },
    { range[3], range[4] },
    { overlap = true, details = true }
  )
  for _, mark in ipairs(marks) do
    if Range.cmp_pos.gt(mark[2], mark[3], current_end[1], current_end[2]) then
      return false
    end

    if Range.cmp_pos.gt(mark[4].end_row, mark[4].end_col, current_end[1], current_end[2]) then
      current_end[1] = mark[4].end_row
      current_end[2] = mark[4].end_col
    end

    if Range.cmp_pos.ge(current_end[1], current_end[2], range[3], range[4]) then
      return true
    end
  end

  return false
end

--- Returns whether this LanguageTree is valid, i.e., |LanguageTree:trees()| reflects the latest
--- state of the source. If invalid, user should call |LanguageTree:parse()|.
---@param exclude_children boolean? whether to ignore the validity of children (default `false`)
---@param range Range? range to check for validity
---@return boolean
function LanguageTree:is_valid(exclude_children, range)
  local marks = self:_get_marks(type(range) == 'table' and range or nil)
  for _, mark in ipairs(marks) do
    local region = self._parser_regions[mark[1]]
    if not region.valid then
      local ranges = region.root and max_region
        or type(region.value) == 'userdata' and region.value:included_ranges(true)
        or region.value
      if intersects_region(ranges, range) then
        return false
      end
    end
  end

  if not exclude_children then
    range = range or { 0, api.nvim_buf_line_count(self._source) }
    if not self:_has_queried_injections(range) then
      return false
    end

    for _, child in pairs(self._children) do
      if not child:is_valid(exclude_children, range) then
        return false
      end
    end
  end

  return true
end

--- Returns a map of language to child tree.
--- @return table<string,vim.treesitter.LanguageTree>
function LanguageTree:children()
  return self._children
end

--- Returns the source bufnr of the language tree.
--- @return integer
function LanguageTree:source()
  return self._source
end

--- @private
--- @param range boolean|Range?
--- @param thread_state ParserThreadState
--- @return Range6[] changes
--- @return integer no_regions_parsed
--- @return number total_parse_time
function LanguageTree:_parse_regions(range, thread_state)
  local changes = {}
  local no_regions_parsed = 0
  local total_parse_time = 0

  local marks = self:_get_marks(type(range) == 'table' and range or nil)
  for _, mark in ipairs(marks) do
    local mark_region = self._parser_regions[mark[1]]
    local region = mark_region.root and max_region
      or type(mark_region.value) == 'userdata' and mark_region.value:included_ranges(true)
      or mark_region.value
    if not mark_region.valid and intersects_region(region, range) then
      local old_tree = type(mark_region.value) == 'userdata' and mark_region.value or nil
      self._parser:set_included_ranges(region)

      local parse_time, tree, tree_changes =
        tcall(self._parser.parse, self._parser, old_tree, self._source, true, thread_state.timeout)
      while true do
        if tree then
          break
        end
        coroutine.yield(nil, false)

        parse_time, tree, tree_changes = tcall(
          self._parser.parse,
          self._parser,
          old_tree,
          self._source,
          true,
          thread_state.timeout
        )
      end

      self:_subtract_time(thread_state, parse_time)

      -- lua_ls wonkiness
      ---@cast tree -nil
      self:_do_callback('changedtree', tree_changes, tree)
      mark_region.value = tree
      vim.list_extend(changes, tree_changes)

      total_parse_time = total_parse_time + parse_time
      no_regions_parsed = no_regions_parsed + 1
      mark_region.valid = true
    end
  end

  return changes, no_regions_parsed, total_parse_time
end

--- @private
--- @param injections_by_lang table<string, Range6[][]>
function LanguageTree:_add_injections(injections_by_lang)
  local seen_langs = {} ---@type table<string,boolean>

  for lang, injection_regions in pairs(injections_by_lang) do
    local has_lang = pcall(language.add, lang)

    -- Only track a child if we have a valid parser for it.
    if has_lang then
      local child = self._children[lang] or self:add_child(lang)

      -- TODO: Incremental reparsing of child trees
      api.nvim_buf_clear_namespace(child._source, child._ns, 0, -1)
      child._parser_regions = {}

      for _, region in ipairs(injection_regions) do
        local start = region[1]
        local end_ = region[#region]
        local id = api.nvim_buf_set_extmark(child._source, child._ns, start[1], start[2], {
          end_row = end_[4],
          end_col = end_[5],
          strict = false,
        })
        child._parser_regions[id] = { valid = false, value = region }
      end

      seen_langs[lang] = true
    end
  end

  for lang, _ in pairs(self._children) do
    if not seen_langs[lang] then
      self:remove_child(lang)
    end
  end
end

--- @param range boolean|Range?
--- @return string
local function range_to_string(range)
  return type(range) == 'table' and table.concat(range, ',') or tostring(range)
end

--- @private
--- @param range boolean|Range?
--- @param callback fun(err?: string, trees?: table<integer, TSTree>)
function LanguageTree:_push_async_callback(range, callback)
  local key = range_to_string(range)
  self._cb_queues[key] = self._cb_queues[key] or {}
  local queue = self._cb_queues[key]
  queue[#queue + 1] = callback
end

--- @private
--- @param range boolean|Range?
--- @param err? string
--- @param trees? table<integer, TSTree>
function LanguageTree:_run_async_callbacks(range, err, trees)
  local key = range_to_string(range)
  for _, cb in ipairs(self._cb_queues[key]) do
    cb(err, trees)
  end
  self._ranges_being_parsed[key] = nil
  self._cb_queues[key] = nil
end

--- Run an asynchronous parse, calling {on_parse} when complete.
---
--- @private
--- @param range boolean|Range?
--- @param on_parse fun(err?: string, trees?: table<integer, TSTree>)
--- @return table<integer, TSTree>? trees the list of parsed trees, if parsing completed synchronously
function LanguageTree:_async_parse(range, on_parse)
  self:_push_async_callback(range, on_parse)

  -- If we are already running an async parse, just queue the callback.
  local range_string = range_to_string(range)
  if not self._ranges_being_parsed[range_string] then
    self._ranges_being_parsed[range_string] = true
  else
    return
  end

  local source = self._source
  local buf = vim.b[source]
  local ct = buf.changedtick
  local total_parse_time = 0
  local redrawtime = vim.o.redrawtime * 1000000

  local thread_state = {} ---@type ParserThreadState

  ---@type fun(): table<integer, TSTree>, boolean
  local parse = coroutine.wrap(self._parse)

  local function step()
    if not api.nvim_buf_is_valid(source) then
      return nil
    end

    -- If buffer was changed in the middle of parsing, reset parse state
    if buf.changedtick ~= ct then
      ct = buf.changedtick
      total_parse_time = 0
      parse = coroutine.wrap(self._parse)
    end

    thread_state.timeout = not vim.g._ts_force_sync_parsing and default_parse_timeout_ns or nil
    local parse_time, trees, finished = tcall(parse, self, range, thread_state)
    total_parse_time = total_parse_time + parse_time

    if finished then
      self:_run_async_callbacks(range, nil, trees)
      return trees
    elseif total_parse_time > redrawtime then
      self:_run_async_callbacks(range, 'TIMEOUT', nil)
      return nil
    else
      vim.schedule(step)
    end
  end

  return step()
end

--- Parse the regions in the language tree using |treesitter-parsers| for the corresponding
--- languages, and run injection queries on the parsed trees to determine whether child trees should
--- be created and parsed.
---
--- @param range boolean|Range|nil: Parse this range in the parser's source.
---     - Set to `true` to run a complete, recursive parse of the source (Note: Can be slow!).
---     - Set to a range to parse all regions (including child regions) that intersect the range.
---     - Set to `false|nil` to only parse all regions of the current language tree, skipping
---       children (injected trees).
--- @param on_parse fun(err?: string, trees?: table<integer, TSTree>)? Function invoked when parsing completes.
---     When provided and `vim.g._ts_force_sync_parsing` is not set, parsing will run
---     asynchronously. The first argument to the function is a string representing the error type,
---     in case of a failure (currently only possible for timeouts). The second argument is the list
---     of trees returned by the parse (upon success), or `nil` if the parse timed out (determined
---     by 'redrawtime').
---
---     If parsing was still able to finish synchronously (within 3ms), `parse()` returns the list
---     of trees. Otherwise, it returns `nil`.
--- @return table<integer, TSTree>?
function LanguageTree:parse(range, on_parse)
  if on_parse then
    return self:_async_parse(range, on_parse)
  end
  local trees, _ = self:_parse(range, {})
  return trees
end

---@param thread_state ParserThreadState
---@param time integer
function LanguageTree:_subtract_time(thread_state, time)
  thread_state.timeout = thread_state.timeout and math.max(thread_state.timeout - time, 0)
  if thread_state.timeout == 0 then
    coroutine.yield(nil, false)
  end
end

--- @private
--- @param range boolean|Range|nil
--- @param thread_state ParserThreadState
--- @return TSTree[] trees
--- @return boolean finished
function LanguageTree:_parse(range, thread_state)
  if self:is_valid(not range, type(range) == 'table' and range or nil) then
    self:_log('valid')
    return self:trees(type(range) == 'table' and range or nil), true
  end

  local changes --- @type Range6[]?

  -- Collect some stats
  local no_regions_parsed = 0
  local query_time = 0
  local total_parse_time = 0

  -- At least 1 region is invalid
  if not self:is_valid(true, type(range) == 'table' and range or nil) then
    changes, no_regions_parsed, total_parse_time = self:_parse_regions(range, thread_state)

    if no_regions_parsed > 0 then
      api.nvim_buf_clear_namespace(self._source, self._injection_query_ns, 0, -1)
    end
  end

  if range then
    local line_count = api.nvim_buf_line_count(self._source)
    local mark_range = type(range) == 'table' and { Range.unpack4(range) }
      or { 0, 0, line_count, 0 }
    if mark_range[3] > line_count then
      mark_range[3] = line_count
      mark_range[4] = 0
    end
    api.nvim_buf_set_extmark(self._source, self._injection_query_ns, mark_range[1], mark_range[2], {
      end_row = mark_range[3],
      end_col = mark_range[4],
    })
    local injections_by_lang = self:_get_injections(range, thread_state)
    local time = tcall(self._add_injections, self, injections_by_lang)
    self:_subtract_time(thread_state, time)
  end

  self:_log({
    changes = changes and next(changes) and changes or nil,
    regions_parsed = no_regions_parsed,
    parse_time = total_parse_time,
    query_time = query_time,
    range = range,
  })

  if range then
    for _, child in pairs(self._children) do
      child:_parse(range, thread_state)
    end
  end

  return self:trees(type(range) == 'table' and range or nil), true
end

---@param range Range?
---@return vim.api.keyset.get_extmark_item[]
function LanguageTree:_get_marks(range)
  range = range and { Range.unpack4(range) } or nil
  local start = range and { range[1], range[2] } or 0
  local end_ = range and { range[3], range[4] } or -1
  return api.nvim_buf_get_extmarks(self._source, self._ns, start, end_, { overlap = true })
end

--- Invokes the callback for each |LanguageTree| recursively.
---
--- Note: This includes the invoking tree's child trees as well.
---
---@param fn fun(tree: TSTree, ltree: vim.treesitter.LanguageTree)
function LanguageTree:for_each_tree(fn)
  local marks = self:_get_marks()
  for _, mark in ipairs(marks) do
    local tree = self._parser_regions[mark[1]].value
    if type(tree) == 'userdata' then
      fn(tree, self)
    end
  end

  for _, child in pairs(self._children) do
    child:for_each_tree(fn)
  end
end

--- Adds a child language to this |LanguageTree|.
---
---@private
---@param lang string Language to add.
---@return vim.treesitter.LanguageTree injected
function LanguageTree:add_child(lang)
  local child = LanguageTree.new(self._source, lang, self._opts)

  -- Inherit recursive callbacks
  for nm, cb in pairs(self._callbacks_rec) do
    vim.list_extend(child._callbacks_rec[nm], cb)
  end

  child._parent = self
  self._children[lang] = child
  self:_do_callback('child_added', self._children[lang])

  return self._children[lang]
end

---Returns the parent tree. `nil` for the root tree.
---@return vim.treesitter.LanguageTree?
function LanguageTree:parent()
  return self._parent
end

--- Removes a child language from this |LanguageTree|.
---
---@private
---@param lang string Language to remove.
function LanguageTree:remove_child(lang)
  local child = self._children[lang]

  if child then
    self._children[lang] = nil
    child:destroy()
    self:_do_callback('child_removed', child)
  end
end

--- Destroys this |LanguageTree| and all its children.
---
--- Any cleanup logic should be performed here.
---
--- Note: This DOES NOT remove this tree from a parent. Instead,
--- `remove_child` must be called on the parent to remove it.
function LanguageTree:destroy()
  -- Cleanup here
  if self._has_scratch_buf then
    self._has_scratch_buf = false
    api.nvim_buf_delete(self._source, {})
    -- TODO: Else, clear extmarks and _parser_regions
  end
  for _, child in pairs(self._children) do
    child:destroy()
  end
end

---Gets the set of included regions managed by this LanguageTree. This can be different from the
---regions set by injection query, because a partial |LanguageTree:parse()| drops the regions
---outside the requested range.
---Each list represents a range in the form of
---{ {start_row}, {start_col}, {start_bytes}, {end_row}, {end_col}, {end_bytes} }.
---@return table<integer, Range6[]>
function LanguageTree:included_regions()
  ---@type Range6[][]
  local regions = {}
  local num_regions = 0
  for _, mark in ipairs(self:_get_marks()) do
    local mark_region = self._parser_regions[mark[1]]
    local region = type(mark_region.value) == 'userdata' and mark_region.value:included_ranges(true)
      or mark_region.value
    num_regions = num_regions + 1
    regions[num_regions] = region
  end
  -- BREAKING: This no longer returns an empty table to represent "no ranges set"
  return regions
end

---@param node TSNode
---@param source integer
---@param metadata vim.treesitter.query.TSMetadata
---@param include_children boolean
---@return Range6[]
local function get_node_ranges(node, source, metadata, include_children)
  local range = vim.treesitter.get_range(node, source, metadata)
  local child_count = node:named_child_count()

  if include_children or child_count == 0 then
    return { range }
  end

  local ranges = {} ---@type Range6[]

  local srow, scol, sbyte, erow, ecol, ebyte = Range.unpack6(range)

  -- We are excluding children so we need to mask out their ranges
  for i = 0, child_count - 1 do
    local child = assert(node:named_child(i))
    local c_srow, c_scol, c_sbyte, c_erow, c_ecol, c_ebyte = child:range(true)
    if c_srow > srow or c_scol > scol then
      ranges[#ranges + 1] = { srow, scol, sbyte, c_srow, c_scol, c_sbyte }
    end
    srow = c_erow
    scol = c_ecol
    sbyte = c_ebyte
  end

  if erow > srow or ecol > scol then
    ranges[#ranges + 1] = Range.add_bytes(source, { srow, scol, sbyte, erow, ecol, ebyte })
  end

  return ranges
end

---Finds the intersection between two regions, assuming they are sorted in ascending order by
---starting point.
---@param region1 Range6[]
---@param region2 Range6[]
---@return Range6[]
local function clip_regions(region1, region2)
  local result = {}
  local i, j = 1, 1

  while i <= #region1 and j <= #region2 do
    local r1 = region1[i]
    local r2 = region2[j]

    local intersection = Range.intersection(r1, r2)
    if intersection then
      table.insert(result, intersection)
    end

    -- Advance the range that ends earlier
    if Range.cmp_pos.le(r1[4], r1[5], r2[4], r2[5]) then
      i = i + 1
    else
      j = j + 1
    end
  end

  return result
end

---@nodoc
---@class vim.treesitter.languagetree.InjectionElem
---@field combined boolean
---@field regions Range6[][]

---@alias vim.treesitter.languagetree.Injection table<string,table<integer,vim.treesitter.languagetree.InjectionElem>>

---@param t vim.treesitter.languagetree.Injection
---@param pattern integer
---@param lang string
---@param combined boolean
---@param ranges Range6[]
---@param parent_ranges Range6[]
---@param result table<string,Range6[][]>
local function add_injection(t, pattern, lang, combined, ranges, parent_ranges, result)
  if #ranges == 0 then
    -- Make sure not to add an empty range set as this is interpreted to mean the whole buffer.
    return
  end

  if not result[lang] then
    result[lang] = {}
  end

  if not combined then
    table.insert(result[lang], clip_regions(ranges, parent_ranges))
    return
  end

  if not t[lang] then
    t[lang] = {}
  end

  -- Key this by pattern. For combined injections, all captures of this pattern
  -- will be parsed by treesitter as the same "source".
  if not t[lang][pattern] then
    local regions = {}
    t[lang][pattern] = regions
    table.insert(result[lang], regions)
  end

  for _, range in ipairs(clip_regions(ranges, parent_ranges)) do
    table.insert(t[lang][pattern], range)
  end
end

-- TODO(clason): replace by refactored `ts.has_parser` API (without side effects)
--- The result of this function is cached to prevent nvim_get_runtime_file from being
--- called too often
--- @param lang string parser name
--- @return boolean # true if parser for {lang} exists on rtp
local has_parser = vim.func._memoize(1, function(lang)
  return vim._ts_has_language(lang)
    or #api.nvim_get_runtime_file('parser/' .. lang .. '.*', false) > 0
end)

--- Return parser name for language (if exists) or filetype (if registered and exists).
---
---@param alias string language or filetype name
---@return string? # resolved parser name
local function resolve_lang(alias)
  -- validate that `alias` is a legal language
  if not (alias and alias:match('[%w_]+') == alias) then
    return
  end

  if has_parser(alias) then
    return alias
  end

  local lang = vim.treesitter.language.get_lang(alias)
  if lang and has_parser(lang) then
    return lang
  end
end

---@private
--- Extract injections according to:
--- https://tree-sitter.github.io/tree-sitter/3-syntax-highlighting.html#language-injection
---@param match table<integer,TSNode[]>
---@param metadata vim.treesitter.query.TSMetadata
---@return string?, boolean, Range6[]
function LanguageTree:_get_injection(match, metadata)
  local ranges = {} ---@type Range6[]
  local combined = metadata['injection.combined'] ~= nil
  local injection_lang = metadata['injection.language'] --[[@as string?]]
  local lang = metadata['injection.self'] ~= nil and self:lang()
    or metadata['injection.parent'] ~= nil and self._parent:lang()
    or (injection_lang and resolve_lang(injection_lang))
  local include_children = metadata['injection.include-children'] ~= nil

  for id, nodes in pairs(match) do
    for _, node in ipairs(nodes) do
      local name = self._injection_query.captures[id]
      -- Lang should override any other language tag
      if name == 'injection.language' then
        local text = vim.treesitter.get_node_text(node, self._source, { metadata = metadata[id] })
        lang = resolve_lang(text:lower()) -- language names are always lower case
      elseif name == 'injection.filename' then
        local text = vim.treesitter.get_node_text(node, self._source, { metadata = metadata[id] })
        local ft = vim.filetype.match({ filename = text })
        lang = ft and resolve_lang(ft)
      elseif name == 'injection.content' then
        for _, range in ipairs(get_node_ranges(node, self._source, metadata[id], include_children)) do
          ranges[#ranges + 1] = range
        end
      end
    end
  end

  return lang, combined, ranges
end

--- Gets language injection regions by language.
---
--- This is where most of the injection processing occurs.
--- @private
--- @param range Range|true
--- @param thread_state ParserThreadState
--- @return table<string, Range6[][]>
function LanguageTree:_get_injections(range, thread_state)
  if not self._injection_query or #self._injection_query.captures == 0 then
    return {}
  end

  local start = hrtime()

  ---@type table<string,Range6[][]>
  local result = {}

  local full_scan = range == true or self._injection_query.has_combined_injections

  ---@type Range?
  local mark_range = not full_scan and range --[[@as Range]]
    or nil
  local marks = self:_get_marks(mark_range)

  for _, mark in ipairs(marks) do
    local tree = self._parser_regions[mark[1]].value
    if type(tree) == 'userdata' then
      ---@type vim.treesitter.languagetree.Injection
      local injections = {}
      local root_node = tree:root()
      local parent_ranges = tree:included_ranges(true)
      local start_line, end_line ---@type integer, integer
      if full_scan then
        start_line, _, end_line = root_node:range()
      else
        start_line, _, end_line = Range.unpack4(range --[[@as Range]])
      end

      for pattern, match, metadata in
        self._injection_query:iter_matches(root_node, self._source, start_line, end_line + 1)
      do
        local lang, combined, ranges = self:_get_injection(match, metadata)
        if lang then
          add_injection(injections, pattern, lang, combined, ranges, parent_ranges, result)
        else
          self:_log('match from injection query failed for pattern', pattern)
        end

        -- Check the current function duration against the timeout, if it exists.
        local current_time = hrtime()
        self:_subtract_time(thread_state, current_time - start)
        start = hrtime()
      end
    end
  end

  return result
end

---@private
---@param cb_name TSCallbackName
function LanguageTree:_do_callback(cb_name, ...)
  for _, cb in ipairs(self._callbacks[cb_name]) do
    cb(...)
  end
  for _, cb in ipairs(self._callbacks_rec[cb_name]) do
    cb(...)
  end
end

---@package
function LanguageTree:_edit(
  start_byte,
  end_byte_old,
  end_byte_new,
  start_row,
  start_col,
  end_row_old,
  end_col_old,
  end_row_new,
  end_col_new
)
  -- Edit all trees on or after this edit, so their included ranges are updated
  local changed_range = { start_row, start_col, -1, -1 }
  local marks = self:_get_marks(changed_range)
  for _, mark in ipairs(marks) do
    local mark_region = self._parser_regions[mark[1]]
    mark_region.valid = false
    if type(mark_region.value) == 'userdata' then
      mark_region.value = mark_region.value:edit(
        start_byte,
        end_byte_old,
        end_byte_new,
        start_row,
        start_col,
        end_row_old,
        end_col_old,
        end_row_new,
        end_col_new
      )
    end
  end

  self._parser:reset()

  for _, child in pairs(self._children) do
    child:_edit(
      start_byte,
      end_byte_old,
      end_byte_new,
      start_row,
      start_col,
      end_row_old,
      end_col_old,
      end_row_new,
      end_col_new
    )
  end
end

---@param bufnr integer
---@param changed_tick integer
---@param start_row integer
---@param start_col integer
---@param start_byte integer
---@param old_row integer
---@param old_col integer
---@param old_byte integer
---@param new_row integer
---@param new_col integer
---@param new_byte integer
function LanguageTree:_on_bytes(
  bufnr,
  changed_tick,
  start_row,
  start_col,
  start_byte,
  old_row,
  old_col,
  old_byte,
  new_row,
  new_col,
  new_byte
)
  local old_end_col = old_col + ((old_row == 0) and start_col or 0)
  local new_end_col = new_col + ((new_row == 0) and start_col or 0)

  self:_log(
    'on_bytes',
    bufnr,
    changed_tick,
    start_row,
    start_col,
    start_byte,
    old_row,
    old_col,
    old_byte,
    new_row,
    new_col,
    new_byte
  )

  -- Edit trees together BEFORE emitting a bytes callback.
  self:_edit(
    start_byte,
    start_byte + old_byte,
    start_byte + new_byte,
    start_row,
    start_col,
    start_row + old_row,
    old_end_col,
    start_row + new_row,
    new_end_col
  )

  self:_do_callback(
    'bytes',
    bufnr,
    changed_tick,
    start_row,
    start_col,
    start_byte,
    old_row,
    old_col,
    old_byte,
    new_row,
    new_col,
    new_byte
  )
end

function LanguageTree:_on_reload()
  self:invalidate(true)
end

function LanguageTree:_on_detach(...)
  self:invalidate(true)
  self:_do_callback('detach', ...)
  if self._logfile then
    self._logger('nvim', 'detaching')
    self._logger = nil
    self._logfile:close()
  end
end

--- Registers callbacks for the [LanguageTree].
---@param cbs table<TSCallbackNameOn,function> An [nvim_buf_attach()]-like table argument with the following handlers:
---           - `on_bytes` : see [nvim_buf_attach()].
---           - `on_changedtree` : a callback that will be called every time the tree has syntactical changes.
---              It will be passed two arguments: a table of the ranges (as node ranges) that
---              changed and the changed tree.
---           - `on_child_added` : emitted when a child is added to the tree.
---           - `on_child_removed` : emitted when a child is removed from the tree.
---           - `on_detach` : emitted when the buffer is detached, see [nvim_buf_detach_event].
---              Takes one argument, the number of the buffer.
--- @param recursive? boolean Apply callbacks recursively for all children. Any new children will
---                           also inherit the callbacks.
function LanguageTree:register_cbs(cbs, recursive)
  if not cbs then
    return
  end

  local callbacks = recursive and self._callbacks_rec or self._callbacks

  for name, cbname in pairs(TSCallbackNames) do
    if cbs[name] then
      table.insert(callbacks[cbname], cbs[name])
    end
  end

  if recursive then
    for _, child in pairs(self._children) do
      child:register_cbs(cbs, true)
    end
  end
end

---@param tree TSTree
---@param range Range
---@return boolean
local function tree_contains(tree, range)
  local tree_ranges = tree:included_ranges(false)

  for _, tree_range in ipairs(tree_ranges) do
    if Range.contains(tree_range, range) then
      return true
    end
  end

  return false
end

--- Determines whether {range} is contained in the |LanguageTree|.
---
---@param range Range4
---@return boolean
function LanguageTree:contains(range)
  local marks = self:_get_marks(range)
  for _, mark in ipairs(marks) do
    local tree = self._parser_regions[mark[1]].value
    if type(tree) == 'userdata' and tree_contains(tree, range) then
      return true
    end
  end

  return false
end

--- @class vim.treesitter.LanguageTree.tree_for_range.Opts
--- @inlinedoc
---
--- Ignore injected languages
--- (default: `true`)
--- @field ignore_injections? boolean

--- Gets the tree that contains {range}.
---
---@param range Range4
---@param opts? vim.treesitter.LanguageTree.tree_for_range.Opts
---@return TSTree?
function LanguageTree:tree_for_range(range, opts)
  opts = opts or {}
  local ignore = vim.F.if_nil(opts.ignore_injections, true)

  if not ignore then
    for _, child in pairs(self._children) do
      local tree = child:tree_for_range(range, opts)
      if tree then
        return tree
      end
    end
  end

  local marks = self:_get_marks(range)
  for _, mark in ipairs(marks) do
    local id = mark[1]
    local tree = self._parser_regions[id].value
    if type(tree) == 'userdata' and tree_contains(tree, range) then
      return tree
    end
  end

  return nil
end

--- Gets the smallest node that contains {range}.
---
---@param range Range4
---@param opts? vim.treesitter.LanguageTree.tree_for_range.Opts
---@return TSNode?
function LanguageTree:node_for_range(range, opts)
  local tree = self:tree_for_range(range, opts)
  if tree then
    return tree:root():descendant_for_range(unpack(range))
  end
end

--- Gets the smallest named node that contains {range}.
---
---@param range Range4
---@param opts? vim.treesitter.LanguageTree.tree_for_range.Opts
---@return TSNode?
function LanguageTree:named_node_for_range(range, opts)
  local tree = self:tree_for_range(range, opts)
  if tree then
    return tree:root():named_descendant_for_range(unpack(range))
  end
end

--- Gets the appropriate language that contains {range}.
---
---@param range Range4
---@return vim.treesitter.LanguageTree tree Managing {range}
function LanguageTree:language_for_range(range)
  for _, child in pairs(self._children) do
    if child:contains(range) then
      return child:language_for_range(range)
    end
  end

  return self
end

return LanguageTree
