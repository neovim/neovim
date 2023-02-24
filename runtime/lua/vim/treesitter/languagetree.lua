local a = vim.api
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

---@class LanguageTree
---@field private _callbacks table<TSCallbackName,function[]> Callback handlers
---@field private _children table<string,LanguageTree> Injected languages
---@field private _injection_query Query Queries defining injected languages
---@field private _opts table Options
---@field private _parser TSParser Parser for language
---@field private _regions Range6[][] List of regions this tree should manage and parse
---@field private _lang string Language name
---@field private _source (integer|string) Buffer or string to parse
---@field private _trees TSTree[] Reference to parsed tree (one for each language)
---@field private _valid boolean|table<integer,boolean> If the parsed tree is valid
--- TODO(lewis6991): combine _regions, _valid and _trees
---@field private _is_child boolean
local LanguageTree = {}

---@class LanguageTreeOpts
---@field queries table<string,string>  -- Deprecated
---@field injections table<string,string>

LanguageTree.__index = LanguageTree

--- A |LanguageTree| holds the treesitter parser for a given language {lang} used
--- to parse a buffer. As the buffer may contain injected languages, the LanguageTree
--- needs to store parsers for these child languages as well (which in turn may contain
--- child languages themselves, hence the name).
---
---@param source (integer|string) Buffer or a string of text to parse
---@param lang string Root language this tree represents
---@param opts (table|nil) Optional keyword arguments:
---             - injections table Mapping language to injection query strings.
---                                This is useful for overriding the built-in
---                                runtime file searching for the injection language
---                                query per language.
---@return LanguageTree parser object
function LanguageTree.new(source, lang, opts)
  language.add(lang)
  ---@type LanguageTreeOpts
  opts = opts or {}

  if opts.queries then
    a.nvim_err_writeln("'queries' is no longer supported. Use 'injections' now")
    opts.injections = opts.queries
  end

  local injections = opts.injections or {}
  local self = setmetatable({
    _source = source,
    _lang = lang,
    _children = {},
    _regions = {},
    _trees = {},
    _opts = opts,
    _injection_query = injections[lang] and query.parse_query(lang, injections[lang])
      or query.get_query(lang, 'injections'),
    _valid = false,
    _parser = vim._create_ts_parser(lang),
    _callbacks = {
      changedtree = {},
      bytes = {},
      detach = {},
      child_added = {},
      child_removed = {},
    },
  }, LanguageTree)

  return self
end

--- Invalidates this parser and all its children
---@param reload boolean|nil
function LanguageTree:invalidate(reload)
  self._valid = false

  -- buffer was reloaded, reparse all trees
  if reload then
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
function LanguageTree:is_valid()
  local valid = self._valid

  if type(valid) == 'table' then
    for _, v in ipairs(valid) do
      if not v then
        return false
      end
    end
    return true
  end

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

---@private
---This is only exposed so it can be wrapped for profiling
---@param old_tree TSTree
---@return TSTree, integer[]
function LanguageTree:_parse_tree(old_tree)
  local tree, tree_changes = self._parser:parse(old_tree, self._source)
  self:_do_callback('changedtree', tree_changes, tree)
  return tree, tree_changes
end

--- Parses all defined regions using a treesitter parser
--- for the language this tree represents.
--- This will run the injection query for this language to
--- determine if any child languages should be created.
---
---@return TSTree[]
---@return table|nil Change list
function LanguageTree:parse()
  if self:is_valid() then
    return self._trees
  end

  local changes = {}

  -- If there are no ranges, set to an empty list
  -- so the included ranges in the parser are cleared.
  if #self._regions > 0 then
    for i, ranges in ipairs(self._regions) do
      if not self._valid or not self._valid[i] then
        self._parser:set_included_ranges(ranges)
        local tree, tree_changes = self:_parse_tree(self._trees[i])
        self._trees[i] = tree
        vim.list_extend(changes, tree_changes)
      end
    end
  else
    local tree, tree_changes = self:_parse_tree(self._trees[1])
    self._trees = { tree }
    changes = tree_changes
  end

  local injections_by_lang = self:_get_injections()
  local seen_langs = {} ---@type table<string,boolean>

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

      local _, child_changes = child:parse()

      -- Propagate any child changes so they are included in the
      -- the change list for the callback.
      if child_changes then
        vim.list_extend(changes, child_changes)
      end

      seen_langs[lang] = true
    end
  end

  for lang, _ in pairs(self._children) do
    if not seen_langs[lang] then
      self:remove_child(lang)
    end
  end

  self._valid = true

  return self._trees, changes
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

  self._children[lang] = LanguageTree.new(self._source, lang, self._opts)
  self._children[lang]._is_child = true

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
---@param regions Range4[][] List of regions this tree should manage and parse.
function LanguageTree:set_included_regions(regions)
  -- Transform the tables from 4 element long to 6 element long (with byte offset)
  for _, region in ipairs(regions) do
    for i, range in ipairs(region) do
      if type(range) == 'table' and #range == 4 then
        region[i] = Range.add_bytes(self._source, range)
      end
    end
  end

  if #self._regions ~= #regions then
    self._trees = {}
    self:invalidate()
  elseif self._valid ~= false then
    if self._valid == true then
      self._valid = {}
      for i = 1, #regions do
        self._valid[i] = true
      end
    end

    for i = 1, #regions do
      if not vim.deep_equal(self._regions[i], regions[i]) then
        self._valid[i] = false
      end

      if not self._valid[i] then
        self._trees[i] = nil
      end
    end
  end

  self._regions = regions
end

--- Gets the set of included regions
function LanguageTree:included_regions()
  return self._regions
end

---@private
---@param node TSNode
---@param id integer
---@param metadata TSMetadata
---@return Range4
local function get_range_from_metadata(node, id, metadata)
  if metadata[id] and metadata[id].range then
    return metadata[id].range --[[@as Range4]]
  end
  return { node:range() }
end

--- Gets language injection points by language.
---
--- This is where most of the injection processing occurs.
---
--- TODO: Allow for an offset predicate to tailor the injection range
---       instead of using the entire nodes range.
---@private
---@return table<string, integer[][]>
function LanguageTree:_get_injections()
  if not self._injection_query then
    return {}
  end

  ---@type table<integer,table<string,table<integer,table>>>
  local injections = {}

  for tree_index, tree in ipairs(self._trees) do
    local root_node = tree:root()
    local start_line, _, end_line, _ = root_node:range()

    for pattern, match, metadata in
      self._injection_query:iter_matches(root_node, self._source, start_line, end_line + 1)
    do
      local lang = nil ---@type string
      local ranges = {} ---@type Range4[]
      local combined = metadata.combined ---@type boolean

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

      if metadata.language then
        lang = metadata.language ---@type string
      end

      -- You can specify the content and language together
      -- using a tag with the language, for example
      -- @javascript
      for id, node in pairs(match) do
        local name = self._injection_query.captures[id]

        -- Lang should override any other language tag
        if name == 'language' and not lang then
          ---@diagnostic disable-next-line
          lang = query.get_node_text(node, self._source, { metadata = metadata[id] })
        elseif name == 'combined' then
          combined = true
        elseif name == 'content' and #ranges == 0 then
          table.insert(ranges, get_range_from_metadata(node, id, metadata))
          -- Ignore any tags that start with "_"
          -- Allows for other tags to be used in matches
        elseif string.sub(name, 1, 1) ~= '_' then
          if not lang then
            lang = name
          end

          if #ranges == 0 then
            table.insert(ranges, get_range_from_metadata(node, id, metadata))
          end
        end
      end

      assert(type(lang) == 'string')

      -- Each tree index should be isolated from the other nodes.
      if not injections[tree_index] then
        injections[tree_index] = {}
      end

      if not injections[tree_index][lang] then
        injections[tree_index][lang] = {}
      end

      -- Key this by pattern. If combined is set to true all captures of this pattern
      -- will be parsed by treesitter as the same "source".
      -- If combined is false, each "region" will be parsed as a single source.
      if not injections[tree_index][lang][pattern] then
        injections[tree_index][lang][pattern] = { combined = combined, regions = {} }
      end

      table.insert(injections[tree_index][lang][pattern].regions, ranges)
    end
  end

  ---@type table<string,Range4[][]>
  local result = {}

  -- Generate a map by lang of node lists.
  -- Each list is a set of ranges that should be parsed together.
  for _, lang_map in ipairs(injections) do
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
          ---@diagnostic disable-next-line:no-unknown
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
end

---@private
---@param regions Range6[][]
---@param old_range Range6
---@param new_range Range6
---@return table<integer,boolean> region indices to invalidate
local function update_regions(regions, old_range, new_range)
  ---@type table<integer,boolean>
  local valid = {}

  for i, ranges in ipairs(regions or {}) do
    valid[i] = true
    for j, r in ipairs(ranges) do
      if Range.intercepts(r, old_range) then
        valid[i] = false
        break
      end

      -- Range after change. Adjust
      if Range.cmp_pos.gt(r[1], r[2], old_range[4], old_range[5]) then
        local byte_offset = new_range[6] - old_range[6]
        local row_offset = new_range[4] - old_range[4]

        -- Update the range to avoid invalidation in set_included_regions()
        -- which will compare the regions against the parsed injection regions
        ranges[j] = {
          r[1] + row_offset,
          r[2],
          r[3] + byte_offset,
          r[4] + row_offset,
          r[5],
          r[6] + byte_offset,
        }
      end
    end
  end

  return valid
end

---@private
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

  local old_range = {
    start_row,
    start_col,
    start_byte,
    start_row + old_row,
    old_end_col,
    start_byte + old_byte,
  }

  local new_range = {
    start_row,
    start_col,
    start_byte,
    start_row + new_row,
    new_end_col,
    start_byte + new_byte,
  }

  if #self._regions == 0 then
    self._valid = false
  else
    self._valid = update_regions(self._regions, old_range, new_range)
  end

  for _, child in pairs(self._children) do
    child:_on_bytes(
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

  -- Edit trees together BEFORE emitting a bytes callback.
  for _, tree in ipairs(self._trees) do
    tree:edit(
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
  end

  if not self._is_child then
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
end

---@private
function LanguageTree:_on_reload()
  self:invalidate(true)
end

---@private
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
function LanguageTree:register_cbs(cbs)
  ---@cast cbs table<TSCallbackNameOn,function>
  if not cbs then
    return
  end

  if cbs.on_changedtree then
    table.insert(self._callbacks.changedtree, cbs.on_changedtree)
  end

  if cbs.on_bytes then
    table.insert(self._callbacks.bytes, cbs.on_bytes)
  end

  if cbs.on_detach then
    table.insert(self._callbacks.detach, cbs.on_detach)
  end

  if cbs.on_child_added then
    table.insert(self._callbacks.child_added, cbs.on_child_added)
  end

  if cbs.on_child_removed then
    table.insert(self._callbacks.child_removed, cbs.on_child_removed)
  end
end

---@private
---@param tree TSTree
---@param range Range4
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
