local M = {}

local ts = vim.treesitter
local async = vim._async
local query = ts.query.parse('vimdoc', '(tag (word) @tagname)')

--- @alias Tag { [1]: string, [2]: string, [3]: string}[] tuple of tag, file, and search command

---Read file in libuv callback-style
---@param path string
---@param cb fun(string?, string?): string?, string?
local function uv_read(path, cb)
  local fd = assert(vim.uv.fs_open(path, 'r', 438))
  local stat = assert(vim.uv.fs_fstat(fd))
  vim.uv.fs_read(fd, stat.size, 0, function(err, data)
    vim.uv.fs_close(fd)
    cb(data, err)
  end)
end

--- Extract all tag definitions from a help file.
--- @async
--- @param path string Help file with tags.
--- @return Tag[] # List of tags. Empty if file is not readable.
local function extract_file_tags(path)
  local tags = {}
  local source = assert(async.await(2, uv_read, path))

  -- FIX(yochem): creates many scratch buffers, which is slow. Destroying
  -- the parser deletes the buffers, but ideally after #36306 this uses a
  -- faster string parser.
  async.await(vim.schedule)
  local parser = ts.get_string_parser(source, 'vimdoc')
  local _, tree = async.await(3, parser.parse, parser, false)
  parser:destroy()
  assert(tree)

  local filename = vim.fs.basename(path)
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

  return tags
end

--- Report duplicate tags. Assumes the tags are alphabetically sorted.
--- @param tags Tag[]
--- @return boolean # true if there are duplicate tags
local function duplicate_tags(tags)
  local found = false
  for i = 1, #tags - 1 do
    local curtag, curfn, _ = unpack(tags[i])
    local prevtag, prevfn, _ = unpack(tags[i + 1])
    if curtag == prevtag then
      found = true
      if prevfn ~= curfn then
        curfn = ('%s and %s'):format(curfn, prevfn)
      end
      vim.schedule(function()
        vim.notify(('E154: Duplicate tag "%s" in %s'):format(curtag, curfn), vim.log.levels.WARN)
      end)
    end
  end
  return found
end

--- Extract tags from helpfiles and combine in a single 'tags' file.
--- @async
--- @param helpfiles string[] list of helpfiles
--- @param outpath string path to write the 'tags' file to.
--- @param include_helptags_tag boolean true if the 'help-tags' tag should be included
local function create_tags_from_files(helpfiles, outpath, include_helptags_tag)
  local time = vim.uv.hrtime()
  local tasks = {}
  for i, file in ipairs(helpfiles) do
    tasks[i] = async.run(extract_file_tags, file)
  end

  ---@type { [1]: string?, [2]: Tag[]}[]
  local results = async.join(tasks)

  local tags = {}
  for _, res in ipairs(results) do
    vim.list_extend(tags, res[2])
  end

  if include_helptags_tag then
    table.insert(tags, { 'help-tags', 'tags', '1' })
  end

  -- sort alphabetically on tag name
  table.sort(tags, function(a, b)
    return a[1] < b[1]
  end)

  if vim.tbl_isempty(tags) or duplicate_tags(tags) then
    return
  end

  local f = assert(io.open(outpath, 'w'))
  for _, tag in ipairs(tags) do
    f:write(table.concat(tag, '\t') .. '\n')
  end
  f:close()

  time = vim.uv.hrtime() - time
  print(('Helptags written to %s in %f s'):format(outpath, time / 1e9))
end

--- Create a "tags" file for all help files in the given directory.
---
--- The directory {dir} is generally a "doc" directory that contains "*.txt"
--- helpfiles. If dir is `ALL`, create tags file for every "doc" directory in
--- runtimepath.
---
--- Function is asynchronous. To run synchronously, set `wait` to true.
--- @param dir string Directory to generate help tag file for.
--- @param include_helptags? boolean (default: false) Whether to include the "help-tags" tag.
--- @param wait? boolean (default: false) Run synchronously.
function M.generate(dir, include_helptags, wait)
  vim.validate('dir', dir, 'string')
  vim.validate('include_helptags_tag', include_helptags, 'boolean', true)
  vim.validate('wait', wait, 'boolean', true)

  local dirs = { vim.fs.normalize(dir) }
  if dir == 'ALL' then
    dirs = vim.api.nvim_get_runtime_file('doc', true)
  end

  local vimruntime = vim.fs.normalize(vim.env.VIMRUNTIME)

  local tasks = {}
  for _, directory in ipairs(dirs) do
    -- always include the help-tags tag for the $VIMRUNTIME
    include_helptags = include_helptags or directory == vimruntime

    local files = vim.fs.find(function(name, _)
      return vim.endswith(name, '.txt')
    end, { path = directory, type = 'file', limit = math.huge })

    local outpath = vim.fs.joinpath(directory, 'tags')
    local t1 = async.run(create_tags_from_files, files, outpath, include_helptags)
    table.insert(tasks, t1)

    -- handle translated help files per language
    local translated = vim.fs.find(function(name, _)
      -- "*.[a-z][a-z]x", see :help help-translated
      return name:match('%.%l%lx', -4)
    end, { path = directory, type = 'file', limit = math.huge })

    -- categorize translated files per two-letter language code
    ---@type table<string, string[]>
    local per_lang = {}
    for _, file in ipairs(translated) do
      -- "plugin.nlx" --> "nl"
      local lang = file:sub(-3, -2)
      per_lang[lang] = per_lang[lang] or {}
      table.insert(per_lang[lang], file)
    end

    for lang, langfiles in pairs(per_lang) do
      local tagsfile = vim.fs.joinpath(directory, 'tags-' .. lang)
      local t2 = async.run(create_tags_from_files, langfiles, tagsfile, include_helptags)
      table.insert(tasks, t2)
    end
  end
  if wait then
    async.run(async.join, tasks):wait()
  end
end

return M
