local M = {}

local news_path = vim.fs.normalize('$VIMRUNTIME/doc/news.txt')
local cache_path = vim.fs.normalize(vim.fn.stdpath('state') .. '/news.txt')

-- create empty cache file or attempts to write/diff with it will fail later
if not vim.uv.fs_stat(cache_path) then
  local fh = assert(io.open(cache_path, 'w+'),
    string.format('Could not create file at %s: ', cache_path))
  fh:write('')
  fh:flush()
  fh:close()
end

--- @private
--- Schedule the caching of news.txt file contents using an autocommand.
--- We don't want to cache immediately when this is called, because then
--- there would be no more diff to view if user calls `:News` manually.
local function _schedule_caching_of_news()
  local augroup = vim.api.nvim_create_augroup('news_cache', {})

  vim.api.nvim_create_autocmd('VimLeave', {
    desc = 'Cache contents of runtime news.txt file.',
    group = augroup,
    nested = true,
    callback = function()
      local cache_file = assert(io.open(cache_path, 'w+'))
      local news_file = assert(io.open(news_path, 'r'))

      local news = news_file:read('*a')
      news_file:close()

      cache_file:write(news)
      cache_file:flush()
      cache_file:close()
    end
  })
end

--- @private
--- @return boolean
local function _hashes_match()
  local cache_file = assert(io.open(cache_path, 'r'))
  local news_file = assert(io.open(news_path, 'r'))

  local news = news_file:read('*a')
  local news_hash = vim.fn.sha256(news)
  news_file:close()

  local cache = cache_file:read('*a')
  local cache_hash = vim.fn.sha256(cache)
  cache_file:close()

  return news_hash == cache_hash
end

---@private
---Return true if the contents of news.txt should be cached.
---@return boolean
local function _should_cache_news()
  local current_version = vim.version()

  if vim.version.lt(vim.g.NVIM_VERSION, current_version) then
    vim.g.NVIM_VERSION = current_version
    return true
  elseif vim.version.eq(vim.g.NVIM_VERSION, current_version) then
    -- news file contents may have, and does, change even when versions match
    if _hashes_match() then
      return false
    else
      return true
    end
  end

  -- odd situations like cache vim.version() > current vim.version()
  return false
end

function M.check_for_news_changes()
  if not vim.g.NVIM_VERSION then
    vim.g.NVIM_VERSION = vim.version()
    _schedule_caching_of_news()
  else
    if _should_cache_news() then
      vim.notify_once('News.txt updated - run `:News` to view diff', vim.log.levels.INFO, {})
      _schedule_caching_of_news()
    end
  end
end

return M
