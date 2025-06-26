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

local default_parse_timeout_ms = 3

---@type Range2
local entire_document_range = { 0, math.huge }

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

---@nodoc
---@class vim.treesitter.LanguageTree
---@field private _callbacks table<TSCallbackName,function[]> Callback handlers
---@field package _callbacks_rec table<TSCallbackName,function[]> Callback handlers (recursive)
---@field private _children table<string,vim.treesitter.LanguageTree> Injected languages
---@field private _injection_query vim.treesitter.Query Queries defining injected languages
---@field private _processed_injection_range Range? Range for which injections have been processed
---@field private _opts table Options
---@field private _parser TSParser Parser for language
---Table of regions for which the tree is currently running an async parse
---@field private _ranges_being_parsed table<string, boolean>
---Table of callback queues, keyed by each region for which the callbacks should be run
---@field private _cb_queues table<string, fun(err?: string, trees?: table<integer, TSTree>)[]>
---@field private _regions table<integer, Range6[]>?
---The total number of regions. Since _regions can have holes, we cannot simply read this value from #_regions.
---@field private _num_regions integer
---List of regions this tree should manage and parse. If nil then regions are
---taken from _trees. This is mostly a short-lived cache for included_regions()
---@field private _lang string Language name
---@field private _parent? vim.treesitter.LanguageTree Parent LanguageTree
---@field private _source (integer|string) Buffer or string to parse
---@field private _trees table<integer, TSTree> Reference to parsed tree (one for each language).
---Each key is the index of region, which is synced with _regions and _valid.
---@field private _valid_regions table<integer,true> Set of valid region IDs.
---@field private _num_valid_regions integer Number of valid regions
---@field private _is_entirely_valid boolean Whether the entire tree (excluding children) is valid.
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
    source = vim.api.nvim_get_current_buf()
  end

  local injections = opts.injections or {}

  --- @class vim.treesitter.LanguageTree
  local self = {
    _source = source,
    _lang = lang,
    _children = {},
    _trees = {},
    _opts = opts,
    _injection_query = injections[lang] and query.parse(lang, injections[lang])
      or query.get(lang, 'injections'),
    _processed_injection_range = nil,
    _valid_regions = {},
    _num_valid_regions = 0,
    _num_regions = 1,
    _is_entirely_valid = false,
    _parser = vim._create_ts_parser(lang),
    _ranges_being_parsed = {},
    _cb_queues = {},
    _callbacks = {},
    _callbacks_rec = {},
  }

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
  local source = self:source()
  source = type(source) == 'string' and 'text' or tostring(source)

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

---Measure execution time of a function
---@generic R1, R2, R3
---@param f fun(): R1, R2, R3
---@return number, R1, R2, R3
local function tcall(f, ...)
  local start = vim.uv.hrtime()
  ---@diagnostic disable-next-line
  local r = { f(...) }
  --- @type number
  local duration = (vim.uv.hrtime() - start) / 1000000
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
  local nregions = vim.tbl_count(self:included_regions())
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
  self._valid_regions = {}
  self._num_valid_regions = 0
  self._is_entirely_valid = false
  self._parser:reset()

  -- buffer was reloaded, reparse all trees
  if reload then
    for _, t in pairs(self._trees) do
      self:_do_callback('changedtree', t:included_ranges(true), t)
    end
    self._trees = {}
  end

  for _, child in pairs(self._children) do
    child:invalidate(reload)
  end
end

--- Returns all trees of the regions parsed by this parser.
--- Does not include child languages.
--- The result is list-like if
--- * this LanguageTree is the root, in which case the result is empty or a singleton list; or
--- * the root LanguageTree is fully parsed.
---
---@return table<integer, TSTree>
function LanguageTree:trees()
  return self._trees
end

--- Gets the language of this tree node.
--- @return string
function LanguageTree:lang()
  return self._lang
end

--- @param region Range6[]
--- @param range? boolean|Range
--- @return boolean
local function intercepts_region(region, range)
  if #region == 0 then
    return true
  end

  if range == nil then
    return false
  end

  if type(range) == 'boolean' then
    return range
  end

  for _, r in ipairs(region) do
    if Range.intercepts(r, range) then
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
  local valid_regions = self._valid_regions

  if not self._is_entirely_valid then
    if not range then
      return false
    end
    -- TODO: Efficiently search for possibly intersecting regions using a binary search
    for i, region in pairs(self:included_regions()) do
      if
        not valid_regions[i]
        and (
          intercepts_region(region, range)
          or (self._trees[i] and intercepts_region(self._trees[i]:included_ranges(false), range))
        )
      then
        return false
      end
    end
  end

  if not exclude_children then
    if
      not self._processed_injection_range
      or not Range.contains(self._processed_injection_range, range or entire_document_range)
    then
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

--- Returns the source content of the language tree (bufnr or string).
--- @return integer|string
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

  -- If there are no ranges, set to an empty list
  -- so the included ranges in the parser are cleared.
  for i, ranges in pairs(self:included_regions()) do
    if
      not self._valid_regions[i]
      and (
        intercepts_region(ranges, range)
        or (self._trees[i] and intercepts_region(self._trees[i]:included_ranges(false), range))
      )
    then
      self._parser:set_included_ranges(ranges)
      self._parser:set_timeout(thread_state.timeout and thread_state.timeout * 1000 or 0) -- ms -> micros

      local parse_time, tree, tree_changes =
        tcall(self._parser.parse, self._parser, self._trees[i], self._source, true)
      while true do
        if tree then
          break
        end
        coroutine.yield(self._trees, false)

        parse_time, tree, tree_changes =
          tcall(self._parser.parse, self._parser, self._trees[i], self._source, true)
      end

      self:_subtract_time(thread_state, parse_time)

      self:_do_callback('changedtree', tree_changes, tree)
      self._trees[i] = tree
      vim.list_extend(changes, tree_changes)

      total_parse_time = total_parse_time + parse_time
      no_regions_parsed = no_regions_parsed + 1
      self._valid_regions[i] = true
      self._num_valid_regions = self._num_valid_regions + 1

      if self._num_valid_regions == self._num_regions then
        self._is_entirely_valid = true
      end
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

    -- Child language trees should just be ignored if not found, since
    -- they can depend on the text of a node. Intermediate strings
    -- would cause errors for unknown parsers.
    if has_lang then
      local child = self._children[lang]

      if not child then
        child = self:add_child(lang)
      end

      child:set_included_regions(injection_regions)
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
  local is_buffer_parser = type(source) == 'number'
  local buf = is_buffer_parser and vim.b[source] or nil
  local ct = is_buffer_parser and buf.changedtick or nil
  local total_parse_time = 0
  local redrawtime = vim.o.redrawtime

  local thread_state = {} ---@type ParserThreadState

  ---@type fun(): table<integer, TSTree>, boolean
  local parse = coroutine.wrap(self._parse)

  local function step()
    if is_buffer_parser then
      if
        not vim.api.nvim_buf_is_valid(source --[[@as number]])
      then
        return nil
      end

      -- If buffer was changed in the middle of parsing, reset parse state
      if buf.changedtick ~= ct then
        ct = buf.changedtick
        total_parse_time = 0
        parse = coroutine.wrap(self._parse)
      end
    end

    thread_state.timeout = not vim.g._ts_force_sync_parsing and default_parse_timeout_ms or nil
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

--- Recursively parse all regions in the language tree using |treesitter-parsers|
--- for the corresponding languages and run injection queries on the parsed trees
--- to determine whether child trees should be created and parsed.
---
--- Any region with empty range (`{}`, typically only the root tree) is always parsed;
--- otherwise (typically injections) only if it intersects {range} (or if {range} is `true`).
---
--- @param range boolean|Range|nil: Parse this range in the parser's source.
---     Set to `true` to run a complete parse of the source (Note: Can be slow!)
---     Set to `false|nil` to only parse regions with empty ranges (typically
---     only the root tree without injections).
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
    coroutine.yield(self._trees, false)
  end
end

--- @private
--- @param range boolean|Range|nil
--- @param thread_state ParserThreadState
--- @return table<integer, TSTree> trees
--- @return boolean finished
function LanguageTree:_parse(range, thread_state)
  if self:is_valid(nil, type(range) == 'table' and range or nil) then
    self:_log('valid')
    return self._trees, true
  end

  local changes --- @type Range6[]?

  -- Collect some stats
  local no_regions_parsed = 0
  local query_time = 0
  local total_parse_time = 0

  -- At least 1 region is invalid
  if not self:is_valid(true, type(range) == 'table' and range or nil) then
    changes, no_regions_parsed, total_parse_time = self:_parse_regions(range, thread_state)

    -- Need to run injections when we parsed something
    if no_regions_parsed > 0 then
      self._processed_injection_range = nil
    end
  end

  if
    range
    and not (
      self._processed_injection_range
      and Range.contains(
        self._processed_injection_range,
        range ~= true and range or entire_document_range
      )
    )
  then
    local injections_by_lang = self:_get_injections(range, thread_state)
    local time = tcall(self._add_injections, self, injections_by_lang)
    self:_subtract_time(thread_state, time)
  end

  self:_log({
    changes = changes and #changes > 0 and changes or nil,
    regions_parsed = no_regions_parsed,
    parse_time = total_parse_time,
    query_time = query_time,
    range = range,
  })

  for _, child in pairs(self._children) do
    child:_parse(range, thread_state)
  end

  return self._trees, true
end

--- Invokes the callback for each |LanguageTree| recursively.
---
--- Note: This includes the invoking tree's child trees as well.
---
---@param fn fun(tree: TSTree, ltree: vim.treesitter.LanguageTree)
function LanguageTree:for_each_tree(fn)
  for _, tree in pairs(self._trees) do
    fn(tree, self)
  end

  for _, child in pairs(self._children) do
    child:for_each_tree(fn)
  end
end

--- Adds a child language to this |LanguageTree|.
---
--- If the language already exists as a child, it will first be removed.
---
---@private
---@param lang string Language to add.
---@return vim.treesitter.LanguageTree injected
function LanguageTree:add_child(lang)
  if self._children[lang] then
    self:remove_child(lang)
  end

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
  for _, child in pairs(self._children) do
    child:destroy()
  end
end

---@param region Range6[]
local function region_tostr(region)
  if #region == 0 then
    return '[]'
  end
  local srow, scol = region[1][1], region[1][2]
  local erow, ecol = region[#region][4], region[#region][5]
  return string.format('[%d:%d-%d:%d]', srow, scol, erow, ecol)
end

---@private
---Iterate through all the regions. fn returns a boolean to indicate if the
---region is valid or not.
---@param fn fun(index: integer, region: Range6[]): boolean
function LanguageTree:_iter_regions(fn)
  if vim.deep_equal(self._valid_regions, {}) then
    return
  end

  if self._is_entirely_valid then
    self:_log('was valid')
  end

  local all_valid = true

  for i, region in pairs(self:included_regions()) do
    if self._valid_regions[i] then
      -- Setting this to nil rather than false allows us to determine if all regions were parsed
      -- just by checking the length of _valid_regions.
      self._valid_regions[i] = fn(i, region) and true or nil
      if not self._valid_regions[i] then
        self._num_valid_regions = self._num_valid_regions - 1
        self:_log(function()
          return 'invalidating region', i, region_tostr(region)
        end)
      end
    end

    if not self._valid_regions[i] then
      all_valid = false
    end
  end

  self._is_entirely_valid = all_valid
end

--- Sets the included regions that should be parsed by this |LanguageTree|.
--- A region is a set of nodes and/or ranges that will be parsed in the same context.
---
--- For example, `{ { node1 }, { node2} }` contains two separate regions.
--- They will be parsed by the parser in two different contexts, thus resulting
--- in two separate trees.
---
--- On the other hand, `{ { node1, node2 } }` is a single region consisting of
--- two nodes. This will be parsed by the parser in a single context, thus resulting
--- in a single tree.
---
--- This allows for embedded languages to be parsed together across different
--- nodes, which is useful for templating languages like ERB and EJS.
---
---@private
---@param new_regions (Range4|Range6|TSNode)[][] List of regions this tree should manage and parse.
function LanguageTree:set_included_regions(new_regions)
  -- Transform the tables from 4 element long to 6 element long (with byte offset)
  for _, region in ipairs(new_regions) do
    for i, range in ipairs(region) do
      if type(range) == 'table' and #range == 4 then
        region[i] = Range.add_bytes(self._source, range --[[@as Range4]])
      elseif type(range) == 'userdata' then
        --- @diagnostic disable-next-line: missing-fields LuaLS varargs bug
        region[i] = { range:range(true) }
      end
    end
  end

  -- included_regions is not guaranteed to be list-like, but this is still sound, i.e. if
  -- new_regions is different from included_regions, then outdated regions in included_regions are
  -- invalidated. For example, if included_regions = new_regions ++ hole ++ outdated_regions, then
  -- outdated_regions is invalidated by _iter_regions in else branch.
  if #self:included_regions() ~= #new_regions then
    -- TODO(lewis6991): inefficient; invalidate trees incrementally
    for _, t in pairs(self._trees) do
      self:_do_callback('changedtree', t:included_ranges(true), t)
    end
    self._trees = {}
    self:invalidate()
  else
    self:_iter_regions(function(i, region)
      return vim.deep_equal(new_regions[i], region)
    end)
  end

  self._regions = new_regions
  self._num_regions = #new_regions
end

---Gets the set of included regions managed by this LanguageTree. This can be different from the
---regions set by injection query, because a partial |LanguageTree:parse()| drops the regions
---outside the requested range.
---Each list represents a range in the form of
---{ {start_row}, {start_col}, {start_bytes}, {end_row}, {end_col}, {end_bytes} }.
---@return table<integer, Range6[]>
function LanguageTree:included_regions()
  if self._regions then
    return self._regions
  end

  -- treesitter.c will default empty ranges to { -1, -1, -1, -1, -1, -1} (the full range)
  return { {} }
end

---@param node TSNode
---@param source string|integer
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

---@nodoc
---@class vim.treesitter.languagetree.InjectionElem
---@field combined boolean
---@field regions Range6[][]

---@alias vim.treesitter.languagetree.Injection table<string,table<integer,vim.treesitter.languagetree.InjectionElem>>

---@param t table<integer,vim.treesitter.languagetree.Injection>
---@param tree_index integer
---@param pattern integer
---@param lang string
---@param combined boolean
---@param ranges Range6[]
local function add_injection(t, tree_index, pattern, lang, combined, ranges)
  if #ranges == 0 then
    -- Make sure not to add an empty range set as this is interpreted to mean the whole buffer.
    return
  end

  -- Each tree index should be isolated from the other nodes.
  if not t[tree_index] then
    t[tree_index] = {}
  end

  if not t[tree_index][lang] then
    t[tree_index][lang] = {}
  end

  -- Key this by pattern. If combined is set to true all captures of this pattern
  -- will be parsed by treesitter as the same "source".
  -- If combined is false, each "region" will be parsed as a single source.
  if not t[tree_index][lang][pattern] then
    t[tree_index][lang][pattern] = { combined = combined, regions = {} }
  end

  table.insert(t[tree_index][lang][pattern].regions, ranges)
end

-- TODO(clason): replace by refactored `ts.has_parser` API (without side effects)
--- The result of this function is cached to prevent nvim_get_runtime_file from being
--- called too often
--- @param lang string parser name
--- @return boolean # true if parser for {lang} exists on rtp
local has_parser = vim.func._memoize(1, function(lang)
  return vim._ts_has_language(lang)
    or #vim.api.nvim_get_runtime_file('parser/' .. lang .. '.*', false) > 0
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
--- https://tree-sitter.github.io/tree-sitter/syntax-highlighting#language-injection
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

--- Can't use vim.tbl_flatten since a range is just a table.
---@param regions Range6[][]
---@return Range6[]
local function combine_regions(regions)
  local result = {} ---@type Range6[]
  for _, region in ipairs(regions) do
    for _, range in ipairs(region) do
      result[#result + 1] = range
    end
  end
  return result
end

--- Gets language injection regions by language.
---
--- This is where most of the injection processing occurs.
---
--- TODO: Allow for an offset predicate to tailor the injection range
---       instead of using the entire nodes range.
--- @private
--- @param range Range|true
--- @param thread_state ParserThreadState
--- @return table<string, Range6[][]>
function LanguageTree:_get_injections(range, thread_state)
  if not self._injection_query or #self._injection_query.captures == 0 then
    self._processed_injection_range = entire_document_range
    return {}
  end

  ---@type table<integer,vim.treesitter.languagetree.Injection>
  local injections = {}
  local start = vim.uv.hrtime()

  local full_scan = range == true or self._injection_query.has_combined_injections

  for index, tree in pairs(self._trees) do
    local root_node = tree:root()
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
        add_injection(injections, index, pattern, lang, combined, ranges)
      else
        self:_log('match from injection query failed for pattern', pattern)
      end

      -- Check the current function duration against the timeout, if it exists.
      local current_time = vim.uv.hrtime()
      self:_subtract_time(thread_state, (current_time - start) / 1000000)
      start = current_time
    end
  end

  ---@type table<string,Range6[][]>
  local result = {}

  -- Generate a map by lang of node lists.
  -- Each list is a set of ranges that should be parsed together.
  for _, lang_map in pairs(injections) do
    for lang, patterns in pairs(lang_map) do
      if not result[lang] then
        result[lang] = {}
      end

      for _, entry in pairs(patterns) do
        if entry.combined then
          table.insert(result[lang], combine_regions(entry.regions))
        else
          for _, ranges in pairs(entry.regions) do
            table.insert(result[lang], ranges)
          end
        end
      end
    end
  end

  if full_scan then
    self._processed_injection_range = entire_document_range
  else
    self._processed_injection_range = range --[[@as Range]]
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
  for i, tree in pairs(self._trees) do
    self._trees[i] = tree:edit(
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

  self._parser:reset()

  if self._regions then
    local regions = {} ---@type table<integer, Range6[]>
    for i, tree in pairs(self._trees) do
      regions[i] = tree:included_ranges(true)
    end
    self._regions = regions
  end

  local changed_range = {
    start_row,
    start_col,
    start_byte,
    end_row_old,
    end_col_old,
    end_byte_old,
  }

  -- Validate regions after editing the tree
  self:_iter_regions(function(_, region)
    if #region == 0 then
      -- empty region, use the full source
      return false
    end
    for _, r in ipairs(region) do
      if Range.intercepts(r, changed_range) then
        return false
      end
    end
    return true
  end)

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

---@nodoc
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

---@nodoc
function LanguageTree:_on_reload()
  self:invalidate(true)
end

---@nodoc
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
  for _, tree in pairs(self._trees) do
    if tree_contains(tree, range) then
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

  for _, tree in pairs(self._trees) do
    if tree_contains(tree, range) then
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
