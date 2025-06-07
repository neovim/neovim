local M = {}

local ts = vim.treesitter

local query = ts.query.parse('vimdoc', [[
    (tag (word) @tagname)
]])

--- Find all helptags in a single file.
--- @param filename string helpfile with tags
--- @return { [1]: string, [2]: string, [3]: string}[] tuple of tag, file, and search command
local function extract_file_tags(filename)
  local file = assert(io.open(filename, 'r'))
  local source = file:read('*a')
  file:close()

  local tags = {}
  local tree = ts.get_string_parser(source, 'vimdoc'):parse()[1]:root()

  for _, match in query:iter_matches(tree, source) do
    for id, node in pairs(match) do
      if query.captures[id] == 'tagname' then
        local tagname = ts.get_node_text(node[1], source)
        local escaped = string.gsub(tagname, '[\\/]', '\\%0')
        local searchcmd = tagname == 'help-tags' and '1' or ('/*%s*'):format(escaped)
        table.insert(tags, { tagname, filename, searchcmd })
      end
    end
  end

  return tags
end

--- Report duplicate tags.
--- @param tags { [1]: string, [2]: string, [3]: string}[] tuple of tag, file, and search command
--- @return boolean true if there are duplicate tags
local function check_duplicate_tags(tags)
  local found = false

  local prevtag, prevfn
  for _, tag in ipairs(tags) do
    local curtag, curfn, _ = unpack(tag)

    if curtag == prevtag then
      found = true
      local other_fn = prevfn ~= curfn and (' and ' .. prevfn) or ''
      vim.api.nvim_echo({
        { ('E154: Duplicate tag "%s" in %s%s'):format(curtag, curfn, other_fn) }
      }, true, { err = true })
    end

    prevtag = curtag
    prevfn = curfn
  end

  return found
end

--- Generate a tags file for a directory and its subdirectories.
--- @param dir string
local function helptags_in_dir(dir, include_helptags_tag)
  local files = vim.fs.find(function(name, _)
    return vim.endswith(name, '.txt')
  end, { path = dir, type = 'file', limit = math.huge })

  local tags = {}
  for _, filename in ipairs(files) do
    local filetags = extract_file_tags(filename)
    vim.list_extend(tags, filetags)
  end

  if include_helptags_tag then
    table.insert(tags, { 'help-tags', 'tags', '1' })
  end

  table.sort(tags, function(a, b)
    return a[1] < b[1]
  end)

  if not check_duplicate_tags(tags) then
    local tagsfile = vim.fs.joinpath(dir, 'tags')
    local f = assert(io.open(tagsfile, 'w'))

    f:write(vim.iter(tags):map(function(fields)
      return vim.iter(fields):join('\t')
    end):join('\n'))

    f:close()
  end
end

--- Get all "doc" subdirectories in the runtimepath.
local function rtp_doc_dirs()
  return vim.iter(vim.opt.runtimepath:get()):filter(function(dir)
    return vim.fn.isdirectory(vim.fs.joinpath(dir, 'doc')) == 1
  end):totable()
end

function M.generate(dir, include_helptags_tag)
  local dirs = dir == 'ALL' and rtp_doc_dirs() or { dir }
  for _, directory in ipairs(dirs) do
    helptags_in_dir(directory, include_helptags_tag or dir == vim.env.VIMRUNTIME)
  end
end

return M
