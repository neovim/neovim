local M = {}

local ts = vim.treesitter
local async = vim._async
local query = ts.query.parse('vimdoc', '(tag (word) @tagname)')

local function read_file_uv(path, callback)
  vim.uv.fs_open(path, 'r', 438, function(err_open, fd)
    if err_open then return callback(nil, err_open) end

    vim.uv.fs_fstat(fd, function(err_stat, stat)
      if err_stat then
        vim.uv.fs_close(fd)
        return callback(nil, err_stat)
      end

      vim.uv.fs_read(fd, stat.size, 0, function(err_read, data)
        vim.uv.fs_close(fd)
        if err_read then
          return callback(nil, err_read)
        end
        callback(data, nil)
      end)
    end)
  end)
end

local async_read = async.wrap(2, read_file_uv)


--- @alias TagLocation { [1]: string, [2]: string, [3]: string}[] tuple of tag, file, and search command

--- Find all helptags in a single file.
---
--- @param filename string helpfile with tags
--- @return TagLocation[] # empty if file is not readable
local function extract_file_tags(filename)
  local source, err = async_read(filename)
  if source == nil or err then
    vim.schedule(function()
      vim.notify(('E153: Unable to open %s for reading'):format(filename), vim.log.levels.ERROR)
    end)
    return {}
  end
  local fn = vim.fs.basename(filename)

  local tags = {}
  local tree = ts.get_string_parser(source, 'vimdoc'):parse()[1]:root()

  for _, match in query:iter_matches(tree, source) do
    for id, node in pairs(match) do
      if query.captures[id] == 'tagname' then
        local tagname = ts.get_node_text(node[1], source)
        local escaped = tagname:gsub('[\\/]', '\\%0')
        local searchcmd = '/*' .. escaped .. '*'
        table.insert(tags, { tagname, fn, searchcmd })
      end
    end
  end

  return tags
end

--- Report duplicate tags.
---
--- @param tags TagLocation[]
--- @return boolean # true if there are duplicate tags
local function duplicate_tags(tags)
  local found = false
  local prevtag, prevfn
  for _, tag in ipairs(tags) do
    local curtag, curfn, _ = unpack(tag)
    if curtag == prevtag then
      found = true
      local other_fn = prevfn ~= curfn and (' and ' .. prevfn) or ''
      vim.schedule(function()
        vim.notify(
          ('E154: Duplicate tag "%s" in %s%s'):format(curtag, curfn, other_fn),
          vim.log.levels.WARN
        )
      end)
    end
    prevtag = curtag
    prevfn = curfn
  end
  return found
end

--- Extract tags from a list of helpfiles.
---
--- @param helpfiles string[] list of helpfiles
--- @param tagsfile string the filename of the 'tags' file
--- @param include_helptags_tag boolean true if the 'tags' tag should be included
local function create_tags_from_files(helpfiles, tagsfile, include_helptags_tag)
  local tasks = {}
  for i, file in ipairs(helpfiles) do
    tasks[i] = async.run(extract_file_tags, file)
  end

  ---@type TagLocation[]
  local results = async.join(tasks)

  local tags = {}
  for _, res in ipairs(results) do
    vim.list_extend(tags, res[2])
  end

  if include_helptags_tag then
    table.insert(tags, { 'help-tags', 'tags', '1' })
  end

  table.sort(tags, function(a, b)
    return a[1] < b[1]
  end)

  if vim.tbl_isempty(tags) or not duplicate_tags(tags) then
    return
  end

  local f, err = io.open(tagsfile, 'w')
  if f == nil or err then
    vim.notify(('E152: Cannot open %s for writing'):format(tagsfile), vim.log.levels.ERROR)
    return
  end

  local lines = vim.iter(tags):map(function(v)
    return table.concat(v, '\t')
  end):join('\n')

  f:write(lines, '\n')
  f:close()
end

--- Generate a tags file for all help files in given directory and its subdirectories.
---
--- @param dir string Directory to generate help tag file for.
--- @param include_helptags_tag boolean? (default: false) Whether to include the "help-tags" tag.
function M.generate(dir, include_helptags_tag)
  vim.validate('dir', dir, 'string')
  vim.validate('include_helptags_tag', include_helptags_tag, { 'boolean', 'nil' })
  dir = vim.fs.normalize(dir)

  -- including the tags tag can either be forced or is done for the VIMRUNTIME
  local vimruntime = vim.fs.normalize(vim.env.VIMRUNTIME)
  include_helptags_tag = include_helptags_tag or dir == vimruntime

  local dirs = dir == 'ALL' and vim.api.nvim_get_runtime_file('doc', true) or { dir }

  for _, directory in ipairs(dirs) do
    local files = vim.fs.find(function(name, _)
      return vim.endswith(name, '.txt')
    end, { path = directory, type = 'file', limit = math.huge })

    async.run(function()
      create_tags_from_files(files, vim.fs.joinpath(directory, 'tags'), include_helptags_tag)
    end):wait()

    local translated = vim.fs.find(function(name, _)
      -- files ending in `.??x` where `?` is any character a-z
      return name:match('%.%l%lx', -4)
    end, { path = directory, type = 'file', limit = math.huge })

    -- categorize translated files per two-letter language code
    local per_lang = vim.iter(translated):fold({}, function(acc, v)
      local lang = v:sub(-3, -2)
      acc[lang] = acc[lang] or {}
      table.insert(acc[lang], v)
      return acc
    end)

    for lang, langfiles in pairs(per_lang) do
      local tagsfile = vim.fs.joinpath(directory, 'tags-' .. lang)
      async.run(function()
        create_tags_from_files(langfiles, tagsfile, include_helptags_tag)
      end):wait()
    end
  end
end

return M
