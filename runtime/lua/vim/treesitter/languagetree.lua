local a = vim.api
local query = require'vim.treesitter.query'
local language = require'vim.treesitter.language'

local LanguageTree = {}
LanguageTree.__index = LanguageTree

--- Represents a single treesitter parser for a language.
--- The language can contain child languages with in its range,
--- hence the tree.
---
---@param source Can be a bufnr or a string of text to parse
---@param lang The language this tree represents
---@param opts Options table
---@param opts.injections A table of language to injection query strings.
---                      This is useful for overriding the built-in runtime file
---                      searching for the injection language query per language.
function LanguageTree.new(source, lang, opts)
  language.require_language(lang)
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
    _injection_query = injections[lang]
      and query.parse_query(lang, injections[lang])
      or query.get_query(lang, "injections"),
    _valid = false,
    _parser = vim._create_ts_parser(lang),
    _callbacks = {
      changedtree = {},
      bytes = {},
      detach = {},
      child_added = {},
      child_removed = {}
    },
  }, LanguageTree)


  return self
end

--- Invalidates this parser and all its children
function LanguageTree:invalidate(reload)
  self._valid = false

  -- buffer was reloaded, reparse all trees
  if reload then
    self._trees = {}
  end

  for _, child in ipairs(self._children) do
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
--- If the tree is invalid, `parse()` must be called
--- to get the an updated tree.
function LanguageTree:is_valid()
  return self._valid
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
function LanguageTree:parse()
  if self._valid then
    return self._trees
  end

  local parser = self._parser
  local changes = {}

  local old_trees = self._trees
  self._trees = {}

  -- If there are no ranges, set to an empty list
  -- so the included ranges in the parser are cleared.
  if self._regions and #self._regions > 0 then
    for i, ranges in ipairs(self._regions) do
      local old_tree = old_trees[i]
      parser:set_included_ranges(ranges)

      local tree, tree_changes = parser:parse(old_tree, self._source)
      self:_do_callback('changedtree', tree_changes, tree)

      table.insert(self._trees, tree)
      vim.list_extend(changes, tree_changes)
    end
  else
    local tree, tree_changes = parser:parse(old_trees[1], self._source)
    self:_do_callback('changedtree', tree_changes, tree)

    table.insert(self._trees, tree)
    vim.list_extend(changes, tree_changes)
  end

  local injections_by_lang = self:_get_injections()
  local seen_langs = {}

  for lang, injection_ranges in pairs(injections_by_lang) do
    local has_lang = language.require_language(lang, nil, true)

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

--- Invokes the callback for each LanguageTree and it's children recursively
---
---@param fn The function to invoke. This is invoked with arguments (tree: LanguageTree, lang: string)
---@param include_self Whether to include the invoking tree in the results.
function LanguageTree:for_each_child(fn, include_self)
  if include_self then
    fn(self, self._lang)
  end

  for _, child in pairs(self._children) do
    child:for_each_child(fn, true)
  end
end

--- Invokes the callback for each treesitter trees recursively.
---
--- Note, this includes the invoking language tree's trees as well.
---
---@param fn The callback to invoke. The callback is invoked with arguments
---         (tree: TSTree, languageTree: LanguageTree)
function LanguageTree:for_each_tree(fn)
  for _, tree in ipairs(self._trees) do
    fn(tree, self)
  end

  for _, child in pairs(self._children) do
    child:for_each_tree(fn)
  end
end

--- Adds a child language to this tree.
---
--- If the language already exists as a child, it will first be removed.
---
---@param lang The language to add.
function LanguageTree:add_child(lang)
  if self._children[lang] then
    self:remove_child(lang)
  end

  self._children[lang] = LanguageTree.new(self._source, lang, self._opts)

  self:invalidate()
  self:_do_callback('child_added', self._children[lang])

  return self._children[lang]
end

--- Removes a child language from this tree.
---
---@param lang The language to remove.
function LanguageTree:remove_child(lang)
  local child = self._children[lang]

  if child then
    self._children[lang] = nil
    child:destroy()
    self:invalidate()
    self:_do_callback('child_removed', child)
  end
end

--- Destroys this language tree and all its children.
---
--- Any cleanup logic should be performed here.
--- Note, this DOES NOT remove this tree from a parent.
--- `remove_child` must be called on the parent to remove it.
function LanguageTree:destroy()
  -- Cleanup here
  for _, child in ipairs(self._children) do
    child:destroy()
  end
end

--- Sets the included regions that should be parsed by this parser.
--- A region is a set of nodes and/or ranges that will be parsed in the same context.
---
--- For example, `{ { node1 }, { node2} }` is two separate regions.
--- This will be parsed by the parser in two different contexts... thus resulting
--- in two separate trees.
---
--- `{ { node1, node2 } }` is a single region consisting of two nodes.
--- This will be parsed by the parser in a single context... thus resulting
--- in a single tree.
---
--- This allows for embedded languages to be parsed together across different
--- nodes, which is useful for templating languages like ERB and EJS.
---
--- Note, this call invalidates the tree and requires it to be parsed again.
---
---@param regions A list of regions this tree should manage and parse.
function LanguageTree:set_included_regions(regions)
  -- TODO(vigoux): I don't think string parsers are useful for now
  if type(self._source) == "number" then
    -- Transform the tables from 4 element long to 6 element long (with byte offset)
    for _, region in ipairs(regions) do
      for i, range in ipairs(region) do
        if type(range) == "table" and #range == 4 then
          local start_row, start_col, end_row, end_col = unpack(range)
          -- Easy case, this is a buffer parser
          -- TODO(vigoux): proper byte computation here, and account for EOL ?
          local start_byte = a.nvim_buf_get_offset(self._source, start_row) + start_col
          local end_byte = a.nvim_buf_get_offset(self._source, end_row) + end_col

          region[i] = { start_row, start_col, start_byte, end_row, end_col, end_byte }
        end
      end
    end
  end

  self._regions = regions
  -- Trees are no longer valid now that we have changed regions.
  -- TODO(vigoux,steelsojka): Look into doing this smarter so we can use some of the
  --                          old trees for incremental parsing. Currently, this only
  --                          effects injected languages.
  self._trees = {}
  self:invalidate()
end

--- Gets the set of included regions
function LanguageTree:included_regions()
  return self._regions
end

--- Gets language injection points by language.
---
--- This is where most of the injection processing occurs.
---
--- TODO: Allow for an offset predicate to tailor the injection range
---       instead of using the entire nodes range.
---@private
function LanguageTree:_get_injections()
  if not self._injection_query then return {} end

  local injections = {}

  for tree_index, tree in ipairs(self._trees) do
    local root_node = tree:root()
    local start_line, _, end_line, _ = root_node:range()

    for pattern, match, metadata in self._injection_query:iter_matches(root_node, self._source, start_line, end_line+1) do
      local lang = nil
      local ranges = {}
      local combined = metadata.combined

      -- Directives can configure how injections are captured as well as actual node captures.
      -- This allows more advanced processing for determining ranges and language resolution.
      if metadata.content then
        local content = metadata.content

        -- Allow for captured nodes to be used
        if type(content) == "number" then
          content = {match[content]}
        end

        if content then
          vim.list_extend(ranges, content)
        end
      end

      if metadata.language then
        lang = metadata.language
      end

      -- You can specify the content and language together
      -- using a tag with the language, for example
      -- @javascript
      for id, node in pairs(match) do
        local name = self._injection_query.captures[id]

        -- Lang should override any other language tag
        if name == "language" and not lang then
          lang = query.get_node_text(node, self._source)
        elseif name == "combined" then
          combined = true
        elseif name == "content" and #ranges == 0 then
          table.insert(ranges, node)
        -- Ignore any tags that start with "_"
        -- Allows for other tags to be used in matches
        elseif string.sub(name, 1, 1) ~= "_" then
          if not lang then
            lang = name
          end

          if #ranges == 0 then
            table.insert(ranges, node)
          end
        end
      end

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
          table.insert(result[lang], vim.tbl_flatten(entry.regions))
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
function LanguageTree:_do_callback(cb_name, ...)
  for _, cb in ipairs(self._callbacks[cb_name]) do
    cb(...)
  end
end

---@private
function LanguageTree:_on_bytes(bufnr, changed_tick,
                          start_row, start_col, start_byte,
                          old_row, old_col, old_byte,
                          new_row, new_col, new_byte)
  self:invalidate()

  local old_end_col = old_col + ((old_row == 0) and start_col or 0)
  local new_end_col = new_col + ((new_row == 0) and start_col or 0)

  -- Edit all trees recursively, together BEFORE emitting a bytes callback.
  -- In most cases this callback should only be called from the root tree.
  self:for_each_tree(function(tree)
    tree:edit(start_byte,start_byte+old_byte,start_byte+new_byte,
      start_row, start_col,
      start_row+old_row, old_end_col,
      start_row+new_row, new_end_col)
  end)

  self:_do_callback('bytes', bufnr, changed_tick,
      start_row, start_col, start_byte,
      old_row, old_col, old_byte,
      new_row, new_col, new_byte)
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

--- Registers callbacks for the parser
---@param cbs An `nvim_buf_attach`-like table argument with the following keys :
---  `on_bytes` : see `nvim_buf_attach`, but this will be called _after_ the parsers callback.
---  `on_changedtree` : a callback that will be called every time the tree has syntactical changes.
---      it will only be passed one argument, that is a table of the ranges (as node ranges) that
---      changed.
---  `on_child_added` : emitted when a child is added to the tree.
---  `on_child_removed` : emitted when a child is removed from the tree.
function LanguageTree:register_cbs(cbs)
  if not cbs then return end

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
local function tree_contains(tree, range)
  local start_row, start_col, end_row, end_col = tree:root():range()
  local start_fits = start_row < range[1] or (start_row == range[1] and start_col <= range[2])
  local end_fits = end_row > range[3] or (end_row == range[3] and end_col >= range[4])

  if start_fits and end_fits then
    return true
  end

  return false
end

--- Determines wether @param range is contained in this language tree
---
--- This goes down the tree to recursively check childs.
---
---@param range A range, that is a `{ start_line, start_col, end_line, end_col }` table.
function LanguageTree:contains(range)
  for _, tree in pairs(self._trees) do
    if tree_contains(tree, range) then
      return true
    end
  end

  return false
end

--- Gets the appropriate language that contains @param range
---
---@param range A text range, see |LanguageTree:contains|
function LanguageTree:language_for_range(range)
  for _, child in pairs(self._children) do
    if child:contains(range) then
      return child:language_for_range(range)
    end
  end

  return self
end

return LanguageTree
