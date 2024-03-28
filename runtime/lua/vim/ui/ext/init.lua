local M = {
  ns = vim.api.nvim_create_namespace('nvim_ext_ui'),
  augroup = vim.api.nvim_create_augroup('nvim_ext_ui', {}),
  cmdline = false, -- Whether the last written text to buf was cmdline text.
  cmdheight = 1, -- 'cmdheight' value set by user.
  cmdbuf = -1, -- Buffer handle used in cmdline/message window.
  cmdhl = nil, ---@type vim.treesitter.highlighter
  hstbuf = -1, -- Buffer handle used in :messages windowwhen it is open, nil otherwise.
  hstwin = nil, -- Window handle for :messages window when it is open, nil otherwise.
  wins = {}, -- Map of tabpages to cmdline/message window.
  tab = 0, -- Current tabpage.
}

vim.api.nvim_set_hl(M.ns, 'Normal', { link = 'MsgArea' })
vim.api.nvim_create_autocmd('OptionSet', {
  group = M.augroup,
  pattern = 'cmdheight',
  callback = function()
    M.cmdheight = vim.v.option_new
    vim.api.nvim_win_set_config(M.wins[M.tab], { height = M.cmdheight })
  end,
  desc = "Store user-set 'cmdheight' to restore when changing to show multiline message or cmdline."
})

--- Ensure the buffers have not been deleted, and the cmdline/message window
--- in the current tabpage have not been closed.
M.tab_check_wins = function()
  if not vim.api.nvim_buf_is_valid(M.cmdbuf) then
    M.cmdbuf = vim.api.nvim_create_buf(false, true)
  end
  if not vim.api.nvim_buf_is_valid(M.hstbuf) then
    M.hstbuf = vim.api.nvim_create_buf(false, true)
  end
  M.tab = vim.api.nvim_get_current_tabpage()
  if not M.wins[M.tab] then
    M.wins[M.tab] = -1
  end
  if not vim.api.nvim_win_is_valid(M.wins[M.tab]) then
    M.wins[M.tab] = vim.api.nvim_open_win(M.cmdbuf, false, {
      relative = 'editor',
      col = 0,
      row = 10000,
      width = 10000,
      height = 1,
      style = 'minimal',
      focusable = false,
      noautocmd = true,
      zindex = 300,
    })
    vim.api.nvim_win_set_hl_ns(M.wins[M.tab], M.ns)
  end
end

--- Set 'cmdheight' option value without overwriting the stored value.
---@param height integer
M.set_cmdheight = function(height)
  if vim.o.cmdheight ~= height then
    vim.opt.eventignore:append('OptionSet')
    vim.o.cmdheight = height
    vim.opt.eventignore:remove('OptionSet')
  end
end

--- Shrink or grow cmdline and :messages window height to text height.
--- Set 'cmdheight' to shrink the topframe accordingly.
---
---@param prompt boolean Whether to add 1 to height for prompt if necessary.
---@return boolean Whether a prompt should be added.
M.set_win_height = function(prompt)
  local h1 = math.max(M.cmdheight, vim.api.nvim_win_text_height(M.wins[M.tab], {}).all)
  local h2 = M.hstwin and vim.api.nvim_win_text_height(M.hstwin, {}).all or 0
  local ch = h1 + h2

  if M.hstwin then
    vim.api.nvim_win_set_config(M.hstwin, {
      relative = 'editor',
      row = vim.o.lines - ch,
      col = 0,
      height = h2,
    })
  end

  prompt = prompt and M.cmdheight < h1
  vim.api.nvim_win_set_height(M.wins[M.tab], h1 + (prompt and 1 or 0))
  M.set_cmdheight(ch + (prompt and 1 or 0))
  return prompt
end

return M
