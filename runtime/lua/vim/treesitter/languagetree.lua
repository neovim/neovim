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
local byte_range = require('vim.treesitter._byte_range')
local bit = require('bit')
local rshift = bit.rshift

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

--- @type table<TSCallbackNameOn,TSCallbackName>
local TSCallbackNames = {
  on_changedtree = 'changedtree',
  on_bytes = 'bytes',
  on_detach = 'detach',
  on_child_added = 'child_added',
  on_child_removed = 'child_removed',
}

---@nodoc
---@class (private) InjectionMatch
---Root range. Any text/syntax change inside makes the match invalid.
---Range is 0-based, end-exclusive.
---@field range Range6
---@field included Range6[]? Included ranges, relative to `range`.
---@field lang string
---@field pattern integer
---@field combined boolean

---@nodoc
---@class (private) InjectionsState
---@field injections InjectionMatch[] Sorted by begin byte.
---@field edit_ranges ByteRange[]

---@nodoc
---@class vim.treesitter.LanguageTree
---@field private _callbacks table<TSCallbackName,function[]> Callback handlers
---@field package _callbacks_rec table<TSCallbackName,function[]> Callback handlers (recursive)
---@field private _children table<string,vim.treesitter.LanguageTree> Injected languages
---@field private _injection_query vim.treesitter.Query Queries defining injected languages
---@field private _opts table Options
---@field private _parser TSParser Parser for language
---@field private _has_regions boolean
---@field private _regions table<integer, Range6[]>?
---List of regions this tree should manage and parse. If nil then regions are
---taken from _trees. This is mostly a short-lived cache for included_regions()
---@field private _lang string Language name
---@field private _parent? vim.treesitter.LanguageTree Parent LanguageTree
---@field private _source (integer|string) Buffer or string to parse
---@field private _trees table<integer, TSTree> Reference to parsed tree (one for each language).
---@field private _tree_region_valid table<integer, boolean> Whether the region bounds are up-to-date.
---@field private _injections table<integer, InjectionsState>
---@field private _incremental_injections boolean
---@field private _possible_combined_injections boolean
---Each key is the index of region, which is synced with _regions and _valid.
---@field private _valid boolean|table<integer,boolean> If the parsed tree is valid
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
---@param injection boolean?
---@return vim.treesitter.LanguageTree parser object
function LanguageTree.new(source, lang, opts, injection)
  assert(language.add(lang))
  opts = opts or {}

  if source == 0 then
    source = vim.api.nvim_get_current_buf()
  end

  local injections = opts.injections or {}

  local q = injections[lang] and query.parse(lang, injections[lang])
    or query.get(lang, 'injections')

  local all_have_injection_root = true
  local any_injection_combined = false
  if q then
    for _, pattern in pairs(q.info.patterns) do
      local has_injection_root = false
      for _, pred in ipairs(pattern) do
        if pred[1] == 'set!' and pred[2] == 'nvim.injection-root' then
          has_injection_root = true
        end
        if pred[1] == 'set!' and pred[2] == 'injection.combined' then
          any_injection_combined = true
        end
      end
      if not has_injection_root then
        all_have_injection_root = false
        break
      end
    end
  end

  local is_root = not injection

  --- @type vim.treesitter.LanguageTree
  local self = {
    _source = source,
    _lang = lang,
    _children = {},
    _trees = {},
    _injections = is_root and { { injections = {}, edit_ranges = {} } } or {},
    _tree_region_valid = is_root and { true } or {},
    _incremental_injections = all_have_injection_root,
    _possible_combined_injections = any_injection_combined,
    _opts = opts,
    _injection_query = q,
    _has_regions = false,
    _valid = false,
    _parser = vim._create_ts_parser(lang),
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
---@param f fun(): R1, R2, R2
---@return number, R1, R2, R3
local function tcall(f, ...)
  local start = vim.uv.hrtime()
  ---@diagnostic disable-next-line
  local r = { f(...) }
  --- @type number
  local duration = (vim.uv.hrtime() - start) / 1000000
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
  self._valid = false

  -- buffer was reloaded, reparse all trees
  if reload then
    for _, t in pairs(self._trees) do
      self:_do_callback('changedtree', t:included_ranges(true), t)
    end
    self._trees = {}
    -- TODO(vanaigr): should `_injections` and `_tree_region_valid`
    -- also be reset for injections?
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
function LanguageTree:lang()
  return self._lang
end

--- Returns whether this LanguageTree is valid, i.e., |LanguageTree:trees()| reflects the latest
--- state of the source. If invalid, user should call |LanguageTree:parse()|.
---@param exclude_children boolean|nil whether to ignore the validity of children (default `false`)
---@return boolean
function LanguageTree:is_valid(exclude_children)
  local valid = self._valid

  if type(valid) == 'table' then
    for i, _ in pairs(self:included_regions()) do
      if not valid[i] or not self._tree_region_valid[i] then
        return false
      end
    end
  end

  if not exclude_children then
    for index, _ in pairs(self._trees) do
      local invalid = not self._tree_region_valid[index]
        or (#self._injections[index].edit_ranges > 0)
      if invalid then
        return false
      end
    end

    for _, child in pairs(self._children) do
      if not child:is_valid(exclude_children) then
        return false
      end
    end
  end

  if type(valid) == 'boolean' then
    return valid
  end

  self._valid = true
  return true
end

--- Returns a map of language to child tree.
function LanguageTree:children()
  return self._children
end

--- Returns the source content of the language tree (bufnr or string).
function LanguageTree:source()
  return self._source
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

---@param injections InjectionMatch[]
---@param ranges Range6[]
local function injection_matches_invalidate(injections, ranges)
  local icount = #injections
  local rcount = #ranges
  if icount == 0 or rcount == 0 then
    return
  end

  local ri = 1
  ---@type integer
  local range_end = ranges[ri][6] + 1

  -- Since injection matches are sorted by begin byte, and the
  -- change ranges are sorted and don't overlap, we only need to keep
  -- track of the next possibly intersecting change range.
  for _, injection in ipairs(injections) do
    while injection.range[3] >= range_end do
      if ri >= rcount then
        return
      end
      ri = ri + 1
      range_end = ranges[ri][6] + 1
    end
    local range_beg = ranges[ri][3]

    if injection.range[6] > range_beg then
      injection.included = nil
    end
  end
end

--- @private
--- @param range boolean|Range?
--- @return Range6[] changes
--- @return integer no_regions_parsed
--- @return number total_parse_time
function LanguageTree:_parse_regions(range)
  local changes = {}
  local no_regions_parsed = 0
  local total_parse_time = 0

  if type(self._valid) ~= 'table' then
    self._valid = {}
  end

  -- If there are no ranges, set to an empty list
  -- so the included ranges in the parser are cleared.
  for i, ranges in pairs(self:included_regions()) do
    if
      self._tree_region_valid[i]
      and not self._valid[i]
      and (
        intercepts_region(ranges, range)
        or (self._trees[i] and intercepts_region(self._trees[i]:included_ranges(false), range))
      )
    then
      self._parser:set_included_ranges(ranges)
      local prev_tree = self._trees[i]
      local parse_time, tree, tree_changes =
        tcall(self._parser.parse, self._parser, prev_tree, self._source, true)

      -- Pass ranges if this is an initial parse
      local cb_changes = prev_tree and tree_changes or tree:included_ranges(true)

      self:_do_callback('changedtree', cb_changes, tree)
      self._trees[i] = tree
      vim.list_extend(changes, tree_changes)

      if prev_tree then
        local state = self._injections[i]
        for _, change in ipairs(cb_changes) do
          local bb = change[3]
          local eb = change[6] + 1
          byte_range.ranges_insert(state.edit_ranges, bb, eb)
        end
        injection_matches_invalidate(state.injections, cb_changes)
      else
        local edit_ranges = {}
        for _, change in ipairs(cb_changes) do
          table.insert(edit_ranges, { change[3], change[6] })
        end
        self._injections[i] = {
          injections = {},
          edit_ranges = edit_ranges,
        }
      end

      total_parse_time = total_parse_time + parse_time
      no_regions_parsed = no_regions_parsed + 1
      self._valid[i] = true
    end
  end

  return changes, no_regions_parsed, total_parse_time
end

--- @private
--- @param range Range | true
--- @return number
function LanguageTree:_add_injections(range)
  local seen_langs = {} ---@type table<string,boolean>

  local query_time, injections_by_lang = tcall(self._get_injections, self, range)
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

  return query_time
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
--- @return table<integer, TSTree>
function LanguageTree:parse(range)
  if self:is_valid() then
    self:_log('valid')
    return self._trees
  end

  local changes --- @type Range6[]?

  -- Collect some stats
  local no_regions_parsed = 0
  local query_time = 0
  local total_parse_time = 0

  -- At least 1 region is invalid
  if not self:is_valid(true) then
    changes, no_regions_parsed, total_parse_time = self:_parse_regions(range)
    -- Need to run injections when we parsed something
  end

  if range then
    local all_valid = true
    for index, _ in pairs(self._trees) do
      if self._tree_region_valid[index] and #self._injections[index].edit_ranges > 0 then
        all_valid = false
        break
      end
    end
    if not all_valid then
      query_time = self:_add_injections(range)
    end
  end

  self:_log({
    changes = changes and #changes > 0 and changes or nil,
    regions_parsed = no_regions_parsed,
    parse_time = total_parse_time,
    query_time = query_time,
    range = range,
  })

  for _, child in pairs(self._children) do
    child:parse(range)
  end

  return self._trees
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

  local child = LanguageTree.new(self._source, lang, self._opts, true)

  -- Inherit recursive callbacks
  for nm, cb in pairs(self._callbacks_rec) do
    vim.list_extend(child._callbacks_rec[nm], cb)
  end

  child._parent = self
  self._children[lang] = child
  self:_do_callback('child_added', self._children[lang])

  return self._children[lang]
end

--- @package
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
  if not self._valid then
    return
  end

  local was_valid = type(self._valid) ~= 'table'

  if was_valid then
    self:_log('was valid', self._valid)
    self._valid = {}
  end

  local all_valid = true

  for i, region in pairs(self:included_regions()) do
    if was_valid or self._valid[i] then
      self._valid[i] = fn(i, region)
      if not self._valid[i] then
        self:_log(function()
          return 'invalidating region', i, region_tostr(region)
        end)
      end
    end

    if not self._valid[i] then
      all_valid = false
    end
  end

  -- Compress the valid value to 'true' if there are no invalid regions
  if all_valid then
    self._valid = all_valid
  end
end

--- Sets the included regions that should be parsed by this |LanguageTree|.
---
---@private
---@param new_regions (Range6[]?)[] List of regions this tree should manage and parse.
function LanguageTree:set_included_regions(new_regions)
  self._has_regions = true

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
    self._injections = {}
    self._tree_region_valid = {}
    self:invalidate()
  else
    self:_iter_regions(function(i, region)
      return not new_regions[i] or vim.deep_equal(new_regions[i], region)
    end)
  end

  self._regions = {}
  for i, match in ipairs(new_regions) do
    if match then
      self._tree_region_valid[i] = true
      self._regions[i] = match
    end
    if not self._injections[i] then
      self._injections[i] = { injections = {}, edit_ranges = {} }
    end
  end
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

  if not self._has_regions then
    -- treesitter.c will default empty ranges to { -1, -1, -1, -1, -1, -1} (the full range)
    return { {} }
  end

  local regions = {} ---@type Range6[][]
  for i, _ in pairs(self._trees) do
    regions[i] = self._trees[i]:included_ranges(true)
  end

  self._regions = regions
  return regions
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
    ---@cast c_erow integer
    ---@cast c_ecol integer
    ---@cast c_ebyte integer
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

---False if the range was invalidated, but wasn't reparsed.
---@alias InProgressInjections table<string, { combined:  table<integer, ((Range6[]?) | false)>, separate: (Range6[] | false)[] }>

---@param t InProgressInjections
---@param match InjectionMatch
local function add_injection(t, match)
  local g1 = t[match.lang]
  if not g1 then
    g1 = { combined = {}, separate = {} }
    t[match.lang] = g1
  end

  if match.combined then
    local all_ranges = g1.combined[match.pattern]
    if all_ranges == nil then
      all_ranges = {}
      g1.combined[match.pattern] = all_ranges
    end

    if match.pattern and all_ranges then
      for _, range in ipairs(match.included) do
        range = { unpack(range) }
        Range.range6_add(range, match.range)
        table.insert(all_ranges, range)
      end
    else
      g1.combined[match.pattern] = false
    end
  else
    if match.included then
      local ranges = {}
      for _, range in ipairs(match.included) do
        range = { unpack(range) }
        Range.range6_add(range, match.range)
        table.insert(ranges, range)
      end
      table.insert(g1.separate, ranges)
    else
      table.insert(g1.separate, false)
    end
  end
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
---@return string?, boolean, Range6[], Range6?
function LanguageTree:_get_injection(match, metadata)
  local ranges = {} ---@type Range6[]
  local combined = metadata['injection.combined'] ~= nil
  local injection_lang = metadata['injection.language'] --[[@as string?]]
  local lang = metadata['injection.self'] ~= nil and self:lang()
    or metadata['injection.parent'] ~= nil and self._parent:lang()
    or (injection_lang and resolve_lang(injection_lang))
  local include_children = metadata['injection.include-children'] ~= nil

  ---@type Range6?
  local root_range

  local root_i = metadata['nvim.injection-root']
  if root_i then
    ---@cast root_i integer
    local root = match[root_i][1]
    root_range = { root:range(true) }
  end

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
        ranges = get_node_ranges(node, self._source, metadata[id], include_children)
      end
    end
  end

  return lang, combined, ranges, root_range
end

---@param state InjectionsState
---@param range Range | true
---@return ByteRange[] In ascending order.
function LanguageTree:_calc_update_ranges(state, range)
  ---@type ByteRange[]
  local update_ranges

  if not self._incremental_injections then
    if #state.edit_ranges > 0 then
      update_ranges = { { 0, 2 ^ 32 - 1 } }
      state.edit_ranges = {}
    else
      update_ranges = {}
    end
  elseif range == true or self._possible_combined_injections then
    update_ranges = state.edit_ranges
    state.edit_ranges = {}
  else
    ---@type integer
    local bb
    ---@type integer
    local eb
    if #range == 6 then
      bb = range[3]
      eb = range[6] + 1
    else
      ---@type integer
      local line_f
      ---@type integer
      local line_l
      if #range == 4 then
        line_f = range[1]
        line_l = range[3]
      else
        line_f = range[1]
        line_l = range[2]
      end

      bb = Range.line_byte(self._source, line_f)
      eb = Range.line_byte(self._source, line_l + 1)
    end

    update_ranges = byte_range.ranges_slice(state.edit_ranges, bb, eb)
  end

  return update_ranges
end

---Finds first match that begins after the given byte.
---@param matches InjectionMatch[] Sorted by range begin position.
---@param byte integer
---@return integer index
local function matches_find_begin(matches, byte)
  local count = #matches

  local bi = 1
  local ei = count + 1
  while bi < ei do
    local mi = rshift(bi + ei, 1)
    local mb = matches[bi].range[3]
    if mb > byte then
      ei = mi
    else
      bi = mi + 1
    end
  end

  return ei
end

---@param tree_i integer
---@param range Range | true
---@param result InProgressInjections
function LanguageTree:_injection_matches_update(tree_i, range, result)
  local tree = self._trees[tree_i]
  local state = self._injections[tree_i]

  local update_ranges = self:_calc_update_ranges(state, range)
  if #update_ranges == 0 then
    for _, it in ipairs(state.injections) do
      add_injection(result, it)
    end
    return
  end

  local old = state.injections
  local old_i = 1
  local old_c = #old
  if not self._incremental_injections then
    old = {}
    old_i = 1
    old_c = 0
  end

  local root_node = tree:root()

  ---@type InjectionMatch[]
  local new_injections = {}
  for _, upd_range in ipairs(update_ranges) do
    -- Preserve the ranges before current update range.
    while old_i <= old_c do
      local o = old[old_i]
      -- Note: needs to be different for 0-width ranges, but they
      -- were deleted earlier and would need to be deleted anyway.
      if o.range[6] > upd_range[1] then
        break
      end
      table.insert(new_injections, o)
      add_injection(result, o)
      old_i = old_i + 1
    end

    -- Insert valid ranges, skip invalidated ranges.
    while old_i <= old_c do
      local o = old[old_i]
      if upd_range[2] <= o.range[3] then
        break
      end
      if o.range[6] <= upd_range[1] then
        table.insert(new_injections, o)
        add_injection(result, o)
      end
      old_i = old_i + 1
    end

    local opts = { byte_begin = upd_range[1], byte_end = upd_range[2] }
    for pattern, match, metadata in
      self._injection_query:iter_matches(root_node, self._source, opts)
    do
      local lang, combined, ranges, root_range = self:_get_injection(match, metadata)
      if not lang then
        self:_log('match from injection query failed for pattern', pattern)
      elseif #ranges ~= 0 and ranges[1][3] < ranges[#ranges][6] then
        if not root_range then
          assert(not self._incremental_injections)
          local rf = ranges[1]
          local rl = ranges[#ranges]
          root_range = { rf[1], rf[2], rf[3], rl[4], rl[5], rl[6] }
        end

        for _, included_range in ipairs(ranges) do
          Range.range6_sub(included_range, root_range)
        end

        ---@type InjectionMatch
        local injection = {
          range = root_range,
          lang = lang,
          combined = combined,
          included = ranges,
          pattern = pattern,
          valid = true,
        }

        local count = #new_injections
        if count == 0 or new_injections[count].range[6] <= root_range[3] then
          table.insert(new_injections, injection)
        else
          local insert_i = matches_find_begin(new_injections, root_range[3])
          table.insert(new_injections, insert_i, injection)
        end
        add_injection(result, injection)
      end
    end
  end

  -- Preserve the remaining ranges.
  while old_i <= old_c do
    local o = old[old_i]
    table.insert(new_injections, o)
    add_injection(result, o)
    old_i = old_i + 1
  end

  state.injections = new_injections
end

--- Gets language injection regions by language.
---
--- This is where most of the injection processing occurs.
---
--- TODO: Allow for an offset predicate to tailor the injection range
---       instead of using the entire nodes range.
--- @private
--- @param range Range | true
--- @return table<string, Range6[]?>
function LanguageTree:_get_injections(range)
  if not self._injection_query then
    return {}
  end

  ---@type InProgressInjections
  local injections = {}

  for index, _ in pairs(self._trees) do
    if self._tree_region_valid[index] then
      self:_injection_matches_update(index, range, injections)
    end
  end

  ---@type table<string, Range6[]?>
  local result = {}

  -- Generate a map by lang of node lists.
  -- Each list is a set of ranges that should be parsed together.
  for lang, group in pairs(injections) do
    local res = {}

    for _, m in pairs(group.combined) do
      table.insert(res, m)
    end

    for _, m in ipairs(group.separate) do
      table.insert(res, m)
    end

    if #res > 0 then
      result[lang] = res
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

---@param injections InjectionMatch[]
---@param beg Point
---@param old_end Point
---@param new_end Point
local function injection_matches_adjust(injections, beg, old_end, new_end)
  local count = #injections

  local insert_i = 1
  local i = 1
  while i <= count do
    local it = injections[i]
    local changed = Range.range6_edit(it.range, beg, old_end, new_end)
    if changed then
      it.included = nil
    end

    -- Remove match if 0-width.
    if it.range[3] ~= it.range[6] then
      if i ~= insert_i then
        injections[insert_i] = it
      end
      insert_i = insert_i + 1
    end

    i = i + 1
  end

  while insert_i <= count do
    injections[insert_i] = nil
    insert_i = insert_i + 1
  end
end

---@param ranges ByteRange[]
---@param edit_b integer
---@param edit_e_old integer
---@param edit_e_new integer
local function edit_ranges_adjust(ranges, edit_b, edit_e_old, edit_e_new)
  ---@type integer
  local count = #ranges
  local i = byte_range.ranges_find_first_edited(ranges, edit_b, edit_e_old)

  while i <= count do
    local it = ranges[i]
    if it[1] >= edit_e_old then
      break
    end

    byte_range.edit_intersects(it, edit_b, edit_e_old, edit_e_new)
    i = i + 1
    -- Empty ranges will be removed when inserting the new edit.
  end

  local diff = edit_e_new - edit_e_old
  while i <= count do
    local it = ranges[i]
    it[1] = byte_range.clamp(it[1] + diff)
    it[2] = byte_range.clamp(it[2] + diff)
    i = i + 1
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
  local beg = { start_row, start_col, start_byte }
  local old_end = { end_row_old, end_col_old, end_byte_old }
  local new_end = { end_row_new, end_col_new, end_byte_new }

  for tree_i, tree in pairs(self._trees) do
    tree:edit(
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

    local state = self._injections[tree_i]
    injection_matches_adjust(state.injections, beg, old_end, new_end)
    edit_ranges_adjust(state.edit_ranges, start_byte, end_byte_old, end_byte_new)

    local can_affect = false

    local region = tree:included_ranges(true)
    local min = region[1][3]
    local max = region[#region][6]
    -- Do coarse check, since currently even if a change is in between
    -- included ranges of the tree, it can still affect the query results
    -- (the text of the node includes content from outside the ranges).
    if start_byte < max and end_byte_new > min then
      can_affect = true
    end

    if can_affect then
      -- Matches adjecent to the range are not included by query cursor.
      -- But if it is an edit, it could change the meaning of adjecent nodes.
      -- Must now match them again. It's safe to increse the size here.
      -- Even if this range is edited later, the latter edit will also be extended.
      byte_range.ranges_insert(
        state.edit_ranges,
        byte_range.clamp(start_byte - 1),
        byte_range.clamp(end_byte_new + 1)
      )
    end
  end

  self._regions = nil

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

  return Range.contains({
    tree_ranges[1][1],
    tree_ranges[1][2],
    tree_ranges[#tree_ranges][3],
    tree_ranges[#tree_ranges][4],
  }, range)
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
