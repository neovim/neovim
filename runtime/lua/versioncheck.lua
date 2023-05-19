local M = {}

---@private
--- Writes runtime/doc/news.txt to stdpath('state')/news.txt
local function _write_news_to_cache()
  local cached_news = io.open(vim.fn.stdpath('state') .. '/news.txt', 'w+')
  if cached_news then
    local news = io.open(vim.fs.normalize('$VIMRUNTIME/doc/news.txt'))
    if news then
      local news_content = news:read('*a')
      cached_news:write(news_content)
      news:close()
    end
    cached_news:close()
  end
end

---@private
--- Compares size of runtime news.txt file to cached version.
--- Returns true if runtime news.txt is larger, which means there's something
--- that could be diffed.
---@return boolean whether there is something diffable
local function _can_be_diffed()
  local news_size = vim.fn.getfsize(vim.fs.normalize('$VIMRUNTIME/doc/news.txt'))
  local cache_news_size = vim.fn.getfsize(vim.fs.normalize(vim.fn.stdpath('state') .. '/news.txt'))
  return news_size > cache_news_size
end

---@private
--- Asks user if they'd like to see a diff between the cached news.txt file
--- and the current runtime news.txt.
---@return boolean whether user wants to view diff
local function _user_wants_diff()
  local result = vim.fn.confirm('Recent updates detected, view the news?', '&yes\n&no', 1)
  return result == 1
end

---@private
--- Asks the user if they'd like to see the news, and if they do, shows them
--- a diff view in a new tabpage.
local function _maybe_show_diff()
  if not _user_wants_diff() then
    return
  end

  vim.cmd.tabedit(vim.fs.normalize('$VIMRUNTIME/doc/news.txt'))
  vim.cmd.diffsplit(vim.fs.normalize(vim.fn.stdpath('state') .. '/news.txt'))
end

function M.check_for_news()
  if vim.g.NVIM_VERSION == nil then
    vim.g.NVIM_VERSION = vim.version()
    _write_news_to_cache()
  else
    -- BUG: https://github.com/neovim/neovim/issues/23687
    -- If we've reached this branch, we can assume `prerelease = true`
    -- and can workaround by extracting only what we really need to compare
    -- instead of the entire vim.version() tables
    local cached_version = {
      vim.g.NVIM_VERSION.major,
      vim.g.NVIM_VERSION.minor,
      vim.g.NVIM_VERSION.patch,
    }
    local version = vim.version()
    local current_version = {
      version.major,
      version.minor,
      version.patch,
    }
    -- cached NVIM_VERSION is less than current vim.version()
    if vim.version.cmp(cached_version, current_version) == -1 then
      vim.g.NVIM_VERSION = vim.version()
      _maybe_show_diff()
    -- cache is equal but maybe the file sizes are not
    elseif vim.version.cmp(cached_version, current_version) == 0 then
      if _can_be_diffed() then
        _maybe_show_diff()
      end
    end
  end
end

return M
