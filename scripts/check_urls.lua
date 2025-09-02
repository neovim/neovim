#!/usr/bin/env -S nvim -l

-- Usage:
--    ./scripts/check_urls.lua [DIR...]
-- If [DIR...] is not provided, defaults to all 'doc' directories in the RTP.

local ts = vim.treesitter

local query = ts.query.parse('vimdoc', '(url) @url')

local function read_file(path)
  local fd = assert(vim.uv.fs_open(path, 'r', tonumber('644', 8)))
  local stat = assert(vim.uv.fs_fstat(fd))
  local data = assert(vim.uv.fs_read(fd, stat.size, 0))
  assert(vim.uv.fs_close(fd))
  return data
end

---@param helpfile string
---@return string[]
local function extract_urls(helpfile)
  ---@type string[]
  local urls = {}
  local source = read_file(helpfile)
  local tree = ts.get_string_parser(source, 'vimdoc'):parse()[1]

  for id, node in query:iter_captures(tree:root(), source) do
    if query.captures[id] == 'url' then
      local url = ts.get_node_text(node, source)
      -- tree-sitter-vimdoc parses these as part of the url
      if vim.endswith(url, '.') or vim.endswith(url, ',') then
        url = url:sub(0, #url - 1)
      end
      urls[#urls + 1] = url
    end
  end

  return urls
end

local function run()
  local dirs = vim.list_slice(_G.arg, 1)
  if #dirs < 1 then
    dirs = vim.api.nvim_get_runtime_file('doc', true)
  end

  for filename, file_urls in pairs(all_urls) do
    for _, url in ipairs(file_urls) do
      -- if output is not specified, err will always be nil (seems curl-specific)
      vim.net.request(url, { retry = 1, outpath = '/dev/null' }, function(err, _)
        if err then
          vim.print(('Unreachable url in %s: %s'):format(filename, url))
        end
      end)
    end
  end
end

local function get_helpfiles()
  local dirs = vim.api.nvim_get_runtime_file('doc', true)

  local files = {}
  for _, directory in ipairs(dirs) do
    vim.list_extend(
      files,
      vim.fs.find(function(name, _)
        return vim.endswith(name, '.txt')
      end, { path = directory, type = 'file', limit = math.huge })
    )
  end

  find_urls(files)
end

get_helpfiles()
