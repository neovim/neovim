#!/usr/bin/env -S nvim -l

-- Finds unreachable URLs in help files.
--
-- Usage:
--    $ ./scripts/check_urls.lua [DIR...]
--
-- [DIR...] defaults to all 'doc' directories in the runtimepath.

-- these files are not checked for urls
local ignore = {
  ['credits.txt'] = true,
}

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
  local parser = ts.get_string_parser(source, 'vimdoc')
  local tree = parser:parse()[1]

  for id, node in query:iter_captures(tree:root(), source) do
    if query.captures[id] == 'url' then
      local url = ts.get_node_text(node, source)
      -- tree-sitter-vimdoc parses these as part of the url
      -- https://github.com/neovim/tree-sitter-vimdoc/issues/107
      if vim.endswith(url, '.') or vim.endswith(url, ',') then
        url = url:sub(0, #url - 1)
      end
      urls[#urls + 1] = url
    end
  end
  parser:destroy()

  return urls
end

---@param dirs string[]
local function check(dirs)
  ---@type string[]
  local help_files = {}
  for _, dir in ipairs(dirs) do
    vim.list_extend(
      help_files,
      vim.fs.find(function(name, _)
        local basename = vim.fs.basename(name)
        return vim.endswith(name, '.txt') and not ignore[basename]
      end, { path = dir, type = 'file', limit = math.huge })
    )
  end

  local total_unreachable = 0

  for _, file in ipairs(help_files) do
    local urls = extract_urls(file)
    local pending = 0
    print(('- Checking file %s (%d URLs)'):format(file, #urls))

    for _, url in ipairs(urls) do
      -- have max 30 requests pending. Prevents system running out of
      -- file handles (EMFILE error)
      while pending > 30 do
        vim.wait(1000, function()
          return pending <= 10
        end)
      end
      pending = pending + 1
      vim.net.request(url, { retry = 3 }, function(err, _)
        if err then
          print(('  - Unreachable URL: %s'):format(url))
          total_unreachable = total_unreachable --[[@type integer]] + 1
        end
        pending = pending --[[@type integer]] - 1
      end)
    end
    vim.wait(20000, function()
      return pending <= 0
    end)
    if pending > 0 then
      -- TODO(yochem): `:cancel()` tasks after #36146
      print(('Warning: timeout on '):format(file))
      total_unreachable = total_unreachable + pending --[[@type integer]]
    end
  end

  print(('\nTotal number of unreachable URLs: %d'):format(total_unreachable))
end

local dirs = vim.list_slice(_G.arg, 1)
if #dirs < 1 then
  dirs = vim.api.nvim_get_runtime_file('doc', true)
end
check(dirs)
