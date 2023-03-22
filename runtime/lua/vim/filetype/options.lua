local api = vim.api

local M = {}

local function get_ftplugin_runtime(filetype)
  local files = api.nvim__get_runtime({
    string.format('ftplugin/%s.vim', filetype),
    string.format('ftplugin/%s_*.vim', filetype),
    string.format('ftplugin/%s/*.vim', filetype),
    string.format('ftplugin/%s.lua', filetype),
    string.format('ftplugin/%s_*.lua', filetype),
    string.format('ftplugin/%s/*.lua', filetype),
  }, true, {}) --[[@as string[] ]]

  local r = {} ---@type string[]
  for _, f in ipairs(files) do
    -- VIMRUNTIME should be static so shouldn't need to worry about it changing
    if not vim.startswith(f, vim.env.VIMRUNTIME) then
      r[#r + 1] = f
    end
  end
  return r
end

-- Keep track of ftplugin files
local ftplugin_cache = {} ---@type table<string,table<string,integer>>

-- Keep track of total number of FileType autocmds
local ft_autocmd_num ---@type integer?

-- Keep track of filetype options
local ft_option_cache = {} ---@type table<string,table<string,any>>

--- @param path string
--- @return integer
local function hash(path)
  local mtime0 = vim.loop.fs_stat(path).mtime
  return mtime0.sec * 1000000000 + mtime0.nsec
end

--- Only update the cache on changes to the number of FileType autocmds
--- and changes to any ftplugin/ file. This isn't guaranteed to catch everything
--- but should be good enough.
--- @param filetype string
local function update_ft_option_cache(filetype)
  local new_ftautos = #api.nvim_get_autocmds({ event = 'FileType' })
  if new_ftautos ~= ft_autocmd_num then
    -- invalidate
    ft_option_cache[filetype] = nil
    ft_autocmd_num = new_ftautos
  end

  local files = get_ftplugin_runtime(filetype)

  ftplugin_cache[filetype] = ftplugin_cache[filetype] or {}

  if #files ~= #vim.tbl_keys(ftplugin_cache[filetype]) then
    -- invalidate
    ft_option_cache[filetype] = nil
    ftplugin_cache[filetype] = {}
  end

  for _, f in ipairs(files) do
    local mtime = hash(f)
    if ftplugin_cache[filetype][f] ~= mtime then
      -- invalidate
      ft_option_cache[filetype] = nil
      ftplugin_cache[filetype][f] = mtime
    end
  end
end

--- @private
--- @param filetype string Filetype
--- @param option string Option name
--- @return string|integer|boolean
function M.get_option(filetype, option)
  update_ft_option_cache(filetype)

  if not ft_option_cache[filetype] or not ft_option_cache[filetype][option] then
    ft_option_cache[filetype] = ft_option_cache[filetype] or {}
    ft_option_cache[filetype][option] = api.nvim_get_option_value(option, { filetype = filetype })
  end

  return ft_option_cache[filetype][option]
end

return M
