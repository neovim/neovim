--- @defgroup lua-treesitter-languagetree
---
--- @brief A \*LanguageTree\* contains a tree of parsers: the root treesitter parser for {lang} and
--- any "injected" language parsers, which themselves may inject other languages, recursively.
--- For example a Lua buffer containing some Vimscript commands needs multiple parsers to fully
--- understand its contents.
---
--- To create a LanguageTree (parser object) for a given buffer and language, use:
---
--- <pre>lua
---     local parser = vim.treesitter.get_parser(bufnr, lang)
--- </pre>
---
--- (where `bufnr=0` means current buffer). `lang` defaults to 'filetype'.
--- Note: currently the parser is retained for the lifetime of a buffer but this may change;
--- a plugin should keep a reference to the parser object if it wants incremental updates.
---
--- Whenever you need to access the current syntax tree, parse the buffer:
---
--- <pre>lua
---     local tree = parser:parse()
--- </pre>
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

local api = vim.api
local query = require('vim.treesitter.query')
local language = require('vim.treesitter.language')
local Range = require('vim.treesitter._range')

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

---@class LanguageTree
---@field private _callbacks table<TSCallbackName,function[]> Callback handlers
---@field package _callbacks_rec table<TSCallbackName,function[]> Callback handlers (recursive)
---@field private _children table<string,LanguageTree> Injected languages
---@field private _injection_query Query Queries defining injected languages
---@field private _opts table Options
---@field private _parser TSParser Parser for language
---@field private _has_regions boolean
---@field private _regions Range6[][]?
---List of regions this tree should manage and parse. If nil then regions are
---taken from _trees. This is mostly a short-lived cache for included_regions()
---@field private _lang string Language name
---@field private _source (integer|string) Buffer or string to parse
---@field private _trees TSTree[] Reference to parsed tree (one for each language)
---@field private _valid boolean|table<integer,boolean> If the parsed tree is valid
local LanguageTree = {}

---@class LanguageTreeOpts
---@field queries table<string,string>  -- Deprecated
---@field injections table<string,string>

LanguageTree.__index = LanguageTree

--- @package
---
--- |LanguageTree| contains a tree of parsers: the root treesitter parser for {lang} and any
--- "injected" language parsers, which themselves may inject other languages, recursively.
---
---@param source (integer|string) Buffer or text string to parse
---@param lang string Root language of this tree
---@param opts (table|nil) Optional arguments:
---             - injections table Map of language to injection query strings. Overrides the
---                                built-in runtime file searching for language injections.
---@return LanguageTree parser object
function LanguageTree.new(source, lang, opts)
  language.add(lang)
  ---@type LanguageTreeOpts
  opts = opts or {}

  if source == 0 then
    source = vim.api.nvim_get_current_buf()
  end

  local injections = opts.injections or {}
  local self = setmetatable({
    _source = source,
    _lang = lang,
    _children = {},
    _trees = {},
    _opts = opts,
    _injection_query = injections[lang] and query.parse(lang, injections[lang])
      or query.get(lang, 'injections'),
    _valid = false,
    _parser = vim._create_ts_parser(lang),
    _callbacks = {},
    _callbacks_rec = {},
  }, LanguageTree)

  for _, name in pairs(TSCallbackNames) do
    self._callbacks[name] = {}
    self._callbacks_rec[name] = {}
  end

  return self
end

---@private
---Measure execution time of a function
---@generic R1, R2, R3
---@param f fun(): R1, R2, R2
---@return integer, R1, R2, R3
local function tcall(f, ...)
  local start = vim.loop.hrtime()
  ---@diagnostic disable-next-line
  local r = { f(...) }
  --- @type number
  local duration = (vim.loop.hrtime() - start) / 1000000
  return duration, unpack(r)
end

---@private
---@vararg any
function LanguageTree:_log(...)
  if vim.g.__ts_debug == nil then
    return
  end

  local args = { ... }
  if type(args[1]) == 'function' then
    args = { args[1]() }
  end

  local info = debug.getinfo(2, 'nl')
  local nregions = #self:included_regions()
  local prefix =
    string.format('%s:%d: [%s:%d] ', info.name, info.currentline, self:lang(), nregions)

  api.nvim_out_write(prefix)
  for _, x in ipairs(args) do
    if type(x) == 'string' then
      api.nvim_out_write(x)
    else
      api.nvim_out_write(vim.inspect(x, { newline = ' ', indent = '' }))
    end
    api.nvim_out_write(' ')
  end
  api.nvim_out_write('\n')
end

--- Invalidates this parser and all its children
---@param reload boolean|nil
function LanguageTree:invalidate(reload)
  self._valid = false

  -- buffer was reloaded, reparse all trees
  if reload then
    for _, t in ipairs(self._trees) do
      self:_do_callback('changedtree', t:included_ranges(true), t)
    end
    self._trees = {}
  end

  for _, child in pairs(self._children) do
    child:invalidate(reload)
  end
end

--- Returns all trees this language tree contains.
--- Does not include child languages.
function LanguageTree:trees()
  return self._trees
end

--- Gets the language of this tree node.
function LanguageTree:lang()
  return self._lang
end

--- Determines whether this tree is valid.
--- If the tree is invalid, call `parse()`.
--- This will return the updated tree.
---@param exclude_children boolean|nil
---@return boolean
function LanguageTree:is_valid(exclude_children)
  local valid = self._valid

  if type(valid) == 'table' then
    for _, v in ipairs(valid) do
      if not v then
        return false
      end
    end
  end

  if not exclude_children then
    for _, child in pairs(self._children) do
      if not child:is_valid(exclude_children) then
        return false
      end
    end
  end

  assert(type(valid) == 'boolean')

  return valid
end

--- Returns a map of language to child tree.
function LanguageTree:children()
  return self._children
end

--- Returns the source content of the language tree (bufnr or string).
function LanguageTree:source()
  return self._source
end

--- Parses all defined regions using a treesitter parser
--- for the language this tree represents.
--- This will run the injection query for this language to
--- determine if any child languages should be created.
---
---@return TSTree[]
function LanguageTree:parse()
  if self:is_valid() then
    self:_log('valid')
    return self._trees
  end

  local changes = {}

  -- Collect some stats
  local regions_parsed = 0
  local total_parse_time = 0

  --- At least 1 region is invalid
  if not self:is_valid(true) then
    -- If there are no ranges, set to an empty list
    -- so the included ranges in the parser are cleared.
    for i, ranges in ipairs(self:included_regions()) do
      if not self._valid or not self._valid[i] then
        self._parser:set_included_ranges(ranges)
        local parse_time, tree, tree_changes =
          tcall(self._parser.parse, self._parser, self._trees[i], self._source, true)

        -- Pass ranges if this is an initial parse
        local cb_changes = self._trees[i] and tree_changes or tree:included_ranges(true)

        self:_do_callback('changedtree', cb_changes, tree)
        self._trees[i] = tree
        vim.list_extend(changes, tree_changes)

        total_parse_time = total_parse_time + parse_time
        regions_parsed = regions_parsed + 1
      end
    end
  end

  local seen_langs = {} ---@type table<string,boolean>

  local query_time, injections_by_lang = tcall(self._get_injections, self)
  for lang, injection_ranges in pairs(injections_by_lang) do
    local has_lang = pcall(language.add, lang)

    -- Child language trees should just be ignored if not found, since
    -- they can depend on the text of a node. Intermediate strings
    -- would cause errors for unknown parsers.
    if has_lang then
      local child = self._children[lang]

      if not child then
        child = self:add_child(lang)
      end

      child:set_included_regions(injection_ranges)
      seen_langs[lang] = true
    end
  end

  for lang, _ in pairs(self._children) do
    if not seen_langs[lang] then
      self:remove_child(lang)
    end
  end

  self:_log({
    changes = changes,
    regions_parsed = regions_parsed,
    parse_time = total_parse_time,
    query_time = query_time,
  })

  for _, child in pairs(self._children) do
    child:parse()
  end

  self._valid = true

  return self._trees
end

--- Invokes the callback for each |LanguageTree| and its children recursively
---
---@param fn fun(tree: LanguageTree, lang: string)
---@param include_self boolean|nil Whether to include the invoking tree in the results
function LanguageTree:for_each_child(fn, include_self)
  if include_self then
    fn(self, self._lang)
  end

  for _, child in pairs(self._children) do
    child:for_each_child(fn, true)
  end
end

--- Invokes the callback for each |LanguageTree| recursively.
---
--- Note: This includes the invoking tree's child trees as well.
---
---@param fn fun(tree: TSTree, ltree: LanguageTree)
function LanguageTree:for_each_tree(fn)
  for _, tree in ipairs(self._trees) do
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
---@return LanguageTree injected
function LanguageTree:add_child(lang)
  if self._children[lang] then
    self:remove_child(lang)
  end

  local child = LanguageTree.new(self._source, lang, self._opts)

  -- Inherit recursive callbacks
  for nm, cb in pairs(self._callbacks_rec) do
    vim.list_extend(child._callbacks_rec[nm], cb)
  end

  self._children[lang] = child
  self:invalidate()
  self:_do_callback('child_added', self._children[lang])

  return self._children[lang]
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
    self:invalidate()
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

---@private
---@param region Range6[]
local function region_tostr(region)
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

  if type(self._valid) ~= 'table' then
    self._valid = {}
  end

  local all_valid = true

  for i, region in ipairs(self:included_regions()) do
    if self._valid[i] == nil then
      self._valid[i] = true
    end

    if self._valid[i] then
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
---@param new_regions Range6[][] List of regions this tree should manage and parse.
function LanguageTree:set_included_regions(new_regions)
  self._has_regions = true

  -- Transform the tables from 4 element long to 6 element long (with byte offset)
  for _, region in ipairs(new_regions) do
    for i, range in ipairs(region) do
      if type(range) == 'table' and #range == 4 then
        region[i] = Range.add_bytes(self._source, range)
      end
    end
  end

  if #self:included_regions() ~= #new_regions then
    -- TODO(lewis6991): inefficient; invalidate trees incrementally
    for _, t in ipairs(self._trees) do
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
end

---Gets the set of included regions
---@return integer[][]
function LanguageTree:included_regions()
  if self._regions then
    return self._regions
  end

  if not self._has_regions or #self._trees == 0 then
    -- treesitter.c will default empty ranges to { -1, -1, -1, -1, -1, -1}
    return { {} }
  end

  local regions = {} ---@type Range6[][]
  for i, _ in ipairs(self._trees) do
    regions[i] = self._trees[i]:included_ranges(true)
  end

  self._regions = regions
  return regions
end

---@private
---@param node TSNode
---@param source string|integer
---@param metadata TSMetadata
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
    local child = node:named_child(i)
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

---@class TSInjectionElem
---@field combined boolean
---@field regions Range6[][]

---@alias TSInjection table<string,table<integer,TSInjectionElem>>

---@private
---@param t table<integer,TSInjection>
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

---@private
--- Extract injections according to:
--- https://tree-sitter.github.io/tree-sitter/syntax-highlighting#language-injection
---@param match table<integer,TSNode>
---@param metadata TSMetadata
---@return string?, boolean, Range6[]
function LanguageTree:_get_injection(match, metadata)
  local ranges = {} ---@type Range6[]
  local combined = metadata['injection.combined'] ~= nil
  local lang = metadata['injection.language'] --[[@as string?]]
  local include_children = metadata['injection.include-children'] ~= nil

  for id, node in pairs(match) do
    local name = self._injection_query.captures[id]

    -- Lang should override any other language tag
    if name == 'injection.language' then
      lang = vim.treesitter.get_node_text(node, self._source, { metadata = metadata[id] })
    elseif name == 'injection.content' then
      ranges = get_node_ranges(node, self._source, metadata[id], include_children)
    end
  end

  return lang, combined, ranges
end

---@private
---@param match table<integer,TSNode>
---@param metadata TSMetadata
---@return string, boolean, Range6[]
function LanguageTree:_get_injection_deprecated(match, metadata)
  local lang = nil ---@type string
  local ranges = {} ---@type Range6[]
  local combined = metadata.combined ~= nil

  -- Directives can configure how injections are captured as well as actual node captures.
  -- This allows more advanced processing for determining ranges and language resolution.
  if metadata.content then
    local content = metadata.content ---@type any

    -- Allow for captured nodes to be used
    if type(content) == 'number' then
      content = { match[content]:range() }
    end

    if type(content) == 'table' and #content >= 4 then
      vim.list_extend(ranges, content)
    end
  end

  local mlang = metadata.language
  if mlang ~= nil then
    assert(type(mlang) == 'string')
    lang = mlang
  end

  -- You can specify the content and language together
  -- using a tag with the language, for example
  -- @javascript
  for id, node in pairs(match) do
    local name = self._injection_query.captures[id]

    -- Lang should override any other language tag
    if name == 'language' and not lang then
      lang = vim.treesitter.get_node_text(node, self._source, { metadata = metadata[id] })
    elseif name == 'combined' then
      combined = true
    elseif name == 'content' and #ranges == 0 then
      ranges[#ranges + 1] = vim.treesitter.get_range(node, self._source, metadata[id])
      -- Ignore any tags that start with "_"
      -- Allows for other tags to be used in matches
    elseif string.sub(name, 1, 1) ~= '_' then
      if not lang then
        lang = name
      end

      if #ranges == 0 then
        ranges[#ranges + 1] = vim.treesitter.get_range(node, self._source, metadata[id])
      end
    end
  end

  return lang, combined, ranges
end

--- Gets language injection points by language.
---
--- This is where most of the injection processing occurs.
---
--- TODO: Allow for an offset predicate to tailor the injection range
---       instead of using the entire nodes range.
---@private
---@return table<string, Range6[][]>
function LanguageTree:_get_injections()
  if not self._injection_query then
    return {}
  end

  ---@type table<integer,TSInjection>
  local injections = {}

  for tree_index, tree in ipairs(self._trees) do
    local root_node = tree:root()
    local start_line, _, end_line, _ = root_node:range()

    for pattern, match, metadata in
      self._injection_query:iter_matches(root_node, self._source, start_line, end_line + 1)
    do
      local lang, combined, ranges = self:_get_injection(match, metadata)
      if not lang then
        -- TODO(lewis6991): remove after 0.9 (#20434)
        lang, combined, ranges = self:_get_injection_deprecated(match, metadata)
      end
      add_injection(injections, tree_index, pattern, lang, combined, ranges)
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
          ---@diagnostic disable-next-line:no-unknown
          local regions = vim.tbl_map(function(e)
            return vim.tbl_flatten(e)
          end, entry.regions)
          table.insert(result[lang], regions)
        else
          for _, ranges in ipairs(entry.regions) do
            table.insert(result[lang], ranges)
          end
        end
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
  for _, tree in ipairs(self._trees) do
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

---@package
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

---@package
function LanguageTree:_on_reload()
  self:invalidate(true)
end

---@package
function LanguageTree:_on_detach(...)
  self:invalidate(true)
  self:_do_callback('detach', ...)
end

--- Registers callbacks for the |LanguageTree|.
---@param cbs table An |nvim_buf_attach()|-like table argument with the following handlers:
---           - `on_bytes` : see |nvim_buf_attach()|, but this will be called _after_ the parsers callback.
---           - `on_changedtree` : a callback that will be called every time the tree has syntactical changes.
---              It will only be passed one argument, which is a table of the ranges (as node ranges) that
---              changed.
---           - `on_child_added` : emitted when a child is added to the tree.
---           - `on_child_removed` : emitted when a child is removed from the tree.
--- @param recursive? boolean Apply callbacks recursively for all children. Any new children will
---                           also inherit the callbacks.
function LanguageTree:register_cbs(cbs, recursive)
  ---@cast cbs table<TSCallbackNameOn,function>
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

---@private
---@param tree TSTree
---@param range Range
---@return boolean
local function tree_contains(tree, range)
  return Range.contains({ tree:root():range() }, range)
end

--- Determines whether {range} is contained in the |LanguageTree|.
---
---@param range Range4 `{ start_line, start_col, end_line, end_col }`
---@return boolean
function LanguageTree:contains(range)
  for _, tree in pairs(self._trees) do
    if tree_contains(tree, range) then
      return true
    end
  end

  return false
end

--- Gets the tree that contains {range}.
---
---@param range Range4 `{ start_line, start_col, end_line, end_col }`
---@param opts table|nil Optional keyword arguments:
---             - ignore_injections boolean Ignore injected languages (default true)
---@return TSTree|nil
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

--- Gets the smallest named node that contains {range}.
---
---@param range Range4 `{ start_line, start_col, end_line, end_col }`
---@param opts table|nil Optional keyword arguments:
---             - ignore_injections boolean Ignore injected languages (default true)
---@return TSNode | nil Found node
function LanguageTree:named_node_for_range(range, opts)
  local tree = self:tree_for_range(range, opts)
  if tree then
    return tree:root():named_descendant_for_range(unpack(range))
  end
end

--- Gets the appropriate language that contains {range}.
---
---@param range Range4 `{ start_line, start_col, end_line, end_col }`
---@return LanguageTree Managing {range}
function LanguageTree:language_for_range(range)
  for _, child in pairs(self._children) do
    if child:contains(range) then
      return child:language_for_range(range)
    end
  end

  return self
end

return LanguageTree
