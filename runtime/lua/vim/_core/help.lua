local M = {}

local ts = vim.treesitter
local query = ts.query.parse('vimdoc', '(tag (word) @tagname)')

--- @alias Tag { [1]: string, [2]: string, [3]: string} tuple of tag, file, and search command

---Find and report duplicate tags.
---@param tags Tag[]
---@return boolean
local function find_duplicates(tags)
  local prevtag, prevfn, has_duplicates = '', '', false

  for _, tagline in ipairs(tags) do
    local curtag, curfn, _ = unpack(tagline)
    if curtag == prevtag then
      has_duplicates = true
      local filenames = prevfn ~= curfn and (curfn .. ' and ' .. prevfn) or curfn
      local msg = ('E154: Duplicate tag "%s" in %s'):format(curtag, filenames)
      vim.api.nvim_echo({ { msg } }, false, { err = true })
    end
    prevtag = curtag
    prevfn = curfn
  end

  return has_duplicates
end

---Extract tags from {file} and add to list of tags. Modifies {tags}.
---@param tags Tag[]
---@param file string
local function extract_tags(tags, file)
  local filename = vim.fs.basename(file)
  local source = vim.fn.readblob(file)
  local parser = ts.get_string_parser(source, 'vimdoc')

  local tree = assert(parser:parse())
  local root = tree[1]:root()
  for _, match in query:iter_matches(root, source) do
    for id, node in pairs(match) do
      if query.captures[id] == 'tagname' then
        local tagname = ts.get_node_text(node[1], source)
        local escaped = tagname:gsub('[\\/]', '\\%0')
        local searchcmd = '/*' .. escaped .. '*'
        table.insert(tags, { tagname, filename, searchcmd })
      end
    end
  end
end

--- Extract tags from helpfiles and combine in a single 'tags' file.
--- @param helpfiles string[] list of helpfiles
--- @param outpath string path to write the 'tags' file to.
--- @param include_helptags_tag boolean true if the 'help-tags' tag should be included
local function gen_tagsfile(helpfiles, outpath, include_helptags_tag)
  ---@type Tag[]
  local tags = {}

  -- (1) extract tags from all files
  for _, file in ipairs(helpfiles) do
    extract_tags(tags, file)
  end

  if include_helptags_tag then
    table.insert(tags, { 'help-tags', 'tags', '1' })
  end

  if vim.tbl_isempty(tags) then
    return
  end

  -- (2) sort alphabetically on tag name
  table.sort(tags, function(a, b)
    return a[1] < b[1]
  end)

  -- (3) check duplicates
  local has_duplicates = find_duplicates(tags)

  -- (4) write tags to file
  local f = assert(io.open(outpath, 'w'))
  for _, tag in ipairs(tags) do
    f:write(table.concat(tag, '\t') .. '\n')
  end
  f:close()

  -- tags file has to be written before we can error
  if has_duplicates then
    error('duplicate tags')
  end

  -- vim.print('Helptags written to ' .. outpath)
end

--- Create a "tags" file for all help files in the given directory.
---
--- The directory {dir} is generally a "doc" directory that contains "*.txt"
--- helpfiles.
---
--- @param dir string? Path to directory with help files. If `nil` (or |vim.NIL|),
--- generate tags for every `doc` directory in the runtimepath.
--- @param include_index_tag? boolean (default: false) Whether to include the "help-tags" tag.
function M.gen_tags(dir, include_index_tag)
  if dir == vim.NIL then
    dir = nil
  end
  vim.validate('dir', dir, 'string', true)
  vim.validate('include_index_tag', include_index_tag, 'boolean', true)

  local dirs = dir and { vim.fs.normalize(dir) } or vim.api.nvim_get_runtime_file('doc', true)
  local vimruntime = vim.fs.normalize(vim.fs.joinpath(vim.env.VIMRUNTIME, 'doc'))

  for _, directory in ipairs(dirs) do
    local files = vim.fs.find(function(name, _)
      return vim.endswith(name, '.txt')
    end, { path = directory, type = 'file', limit = math.huge })

    local outpath = vim.fs.joinpath(directory, 'tags')
    gen_tagsfile(files, outpath, include_index_tag or directory == vimruntime)

    -- handle translated help files per language
    local translated = vim.fs.find(function(name, _)
      -- "*.[a-z][a-z]x", see :help help-translated
      return name:match('%.%l%lx', -4)
    end, { path = directory, type = 'file', limit = math.huge })

    -- categorize translated files per two-letter language code
    ---@type table<string, string[]>
    local per_lang = {}
    for _, file in ipairs(translated) do
      -- extract language code "nl" from filename "plugin.nlx"
      local lang = file:sub(-3, -2)
      per_lang[lang] = per_lang[lang] or {}
      table.insert(per_lang[lang], file)
    end

    for lang, langfiles in pairs(per_lang) do
      local tagsfile = vim.fs.joinpath(directory, 'tags-' .. lang)
      gen_tagsfile(langfiles, tagsfile, include_index_tag or directory == vimruntime)
    end
  end
end

return M
