#!/usr/bin/env -S nvim -l

-- Finds unreachable URLs in help files.
--
-- Usage:
--    $ ./scripts/check_urls.lua [DIR...]
--
-- [DIR...] defaults to all 'doc' directories in the runtimepath.

local ts = vim.treesitter

local query = ts.query.parse('vimdoc', '(url) @url')

---Read and return full content of given file path.
---@param path string
---@return string
local function read_file(path)
  local fd = assert(vim.uv.fs_open(path, 'r', tonumber('644', 8)))
  local stat = assert(vim.uv.fs_fstat(fd))
  local data = assert(vim.uv.fs_read(fd, stat.size, 0))
  assert(vim.uv.fs_close(fd))
  return data
end

---Extract URLs from a vimdoc file using the vimdoc TS parser.
---@param helpfile string Path to help file
---@return string[] # list of URLs found in the document
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

  ---@type string[]
  local help_files = {}
  for _, dir in ipairs(dirs) do
    vim.list_extend(
      help_files,
      vim.fs.find(function(name, _)
        return vim.endswith(name, '.txt')
      end, { path = dir, type = 'file', limit = math.huge })
    )
  end

  ---@type table<string, string[]>
  local all_urls = {}
  local requests = 0
  for _, file in ipairs(help_files) do
    local urls = extract_urls(file)
    requests = requests + #urls
    all_urls[file] = urls
  end

  for file, file_urls in pairs(all_urls) do
    for _, url in ipairs(file_urls) do
      vim.net.request(url, { retry = 3 }, function(err, _)
        if err then
          vim.print(('Unreachable url %s in %s'):format(url, file))
        end
        requests = requests - 1
        if requests <= 0 then
          vim.uv.stop()
        end
      end)
    end
  end

  -- wait for all pending async requests to finish (by calling vim.uv.stop())
  vim.uv.run()
end

run()
