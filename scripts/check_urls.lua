local ts = vim.treesitter
local async = require('vim._async')

local query = ts.query.parse('vimdoc', '(url) @url')

local function curl(url, cb)
  local cmd = {
    'curl',
    '--silent',
    '-L',
    '--max-time',
    '5',
    '--fail',
    '--output',
    '/dev/null',
    url,
  }
  vim.system(cmd, cb)
end
local request = async.wrap(2, curl)

local function read_file_uv_sync(path)
  local fd = assert(vim.uv.fs_open(path, 'r', tonumber('644', 8)))
  local stat = assert(vim.uv.fs_fstat(fd))
  local data = assert(vim.uv.fs_read(fd, stat.size, 0))
  assert(vim.uv.fs_close(fd))
  return data
end

local function extract_urls(helpfile)
  local urls = {}
  local source = read_file_uv_sync(helpfile)
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
  async.join(vim
    .iter(files)
    :map(function(file)
      return async.run(function()
        local urls = extract_urls(file)
        all_urls[file] = urls
      end)
    end)
    :totable())

  local tasks = {}
  for filename, file_urls in pairs(all_urls) do
    for _, url in ipairs(file_urls) do
      tasks[#tasks + 1] = async.run(function()
        local result = request(url)
        if result.code ~= 0 then
          print(('%s in %s (%d)'):format(url, filename, result.code))
        end
      end)
    end
  end
  async.join(tasks)
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

  async
    .run(function()
      find_urls(files)
    end)
    :wait()
end

get_helpfiles()
