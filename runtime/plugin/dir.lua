if vim.g.loaded_nvim_dir_plugin ~= nil then
  return
end
vim.g.loaded_nvim_dir_plugin = true

local api = vim.api
local nvim_on = require('vim._core.util').nvim_on

vim.keymap.set('n', '<Plug>(nvim-dir-open)', function()
  require('nvim.dir')._open_entry()
end, { silent = true, desc = 'Open directory entry' })

vim.keymap.set('n', '<Plug>(nvim-dir-up)', function()
  require('nvim.dir')._open_parent()
end, { silent = true, desc = 'Open parent directory' })

vim.keymap.set('n', '<Plug>(nvim-dir-reload)', function()
  require('nvim.dir')._reload()
end, { silent = true, desc = 'Reload directory' })

---@param buf integer
---@param path string
---@return boolean
local function should_open(buf, path)
  if path == '' then
    return false
  end
  if vim.bo[buf].buftype ~= '' and vim.b[buf].nvim_dir == nil then
    return false
  end
  if vim.bo[buf].filetype == 'netrw' or vim.b[buf].netrw_curdir ~= nil then
    return false
  end
  return vim.fn.isdirectory(path) == 1
end

api.nvim_create_augroup('FileExplorer', { clear = true })
local group = api.nvim_create_augroup('nvim.dir', { clear = true })
-- Latch on our own VimEnter, not v:vim_did_enter (set just before VimEnter
-- autocmds), so an earlier VimEnter autocmd's BufEnter can't preempt startup.
local vimentered = vim.v.vim_did_enter == 1

nvim_on('BufEnter', group, {
  pattern = '*',
  desc = 'Open local directories',
  nested = true,
}, function(ev)
  if vimentered and should_open(ev.buf, ev.file) then
    require('nvim.dir').try_open(ev.buf, ev.file)
  end
end)

nvim_on('VimEnter', group, {
  pattern = '*',
  desc = 'Open startup local directories',
  nested = true,
}, function()
  vimentered = true
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    if api.nvim_win_is_valid(win) then
      local buf = api.nvim_win_get_buf(win)
      if should_open(buf, api.nvim_buf_get_name(buf)) then
        require('nvim.dir').handle_startup_dirs()
        return
      end
    end
  end
end)
