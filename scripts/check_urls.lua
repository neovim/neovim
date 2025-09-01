local ts = vim.treesitter

local query = ts.query.parse('vimdoc', '(url) @url')

local function read(path)
  local fd = assert(vim.uv.fs_open(path, 'r', tonumber('644', 8)))
  local stat = assert(vim.uv.fs_fstat(fd))
  local data = assert(vim.uv.fs_read(fd, stat.size, 0))
  assert(vim.uv.fs_close(fd))
  return data
end

local function extract_urls(helpfile)
  local urls = {}
  local source = read(helpfile)
  local tree = ts.get_string_parser(source, 'vimdoc'):parse()[1]:root()

  for id, node in query:iter_captures(tree:root(), source) do
    if query.captures[id] == 'url' then
      local url = ts.get_node_text(node, source)
      if vim.endswith(url, '.') or vim.endswith(url, ',') then
        url = url:sub(0, #url - 1)
      end
      urls[#urls + 1] = url
    end
  end
  return urls
end

local function find_urls(files)
  local all_urls = {}
  for _, file in ipairs(files) do
    all_urls[file] = extract_urls(file)
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
