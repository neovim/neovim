vim.api.nvim_create_user_command('Inspect', function(cmd)
  if cmd.bang then
    vim.print(vim.inspect_pos())
  else
    vim.show_pos()
  end
end, { desc = 'Inspect highlights and extmarks at the cursor', bang = true })

vim.api.nvim_create_user_command('InspectTree', function(cmd)
  if cmd.mods ~= '' or cmd.count ~= 0 then
    local count = cmd.count ~= 0 and cmd.count or ''
    local new = cmd.mods ~= '' and 'new' or 'vnew'

    vim.treesitter.inspect_tree({
      command = ('%s %s%s'):format(cmd.mods, count, new),
    })
  else
    vim.treesitter.inspect_tree()
  end
end, { desc = 'Inspect treesitter language tree for buffer', count = true })

-- TODO: use vim.region() when it lands... #13896 #16843
local function get_visual_selection()
  local save_a = vim.fn.getreginfo('a')
  vim.cmd([[norm! "ay]])
  local selection = vim.fn.getreg('a', 1)
  vim.fn.setreg('a', save_a)
  return selection
end

local gx_desc =
  'Opens filepath or URI under cursor with the system handler (file explorer, web browser, …)'
local function do_open(uri)
  local _, err = vim.ui.open(uri)
  if err then
    vim.notify(err, vim.log.levels.ERROR)
  end
end
if vim.fn.maparg('gx', 'n') == '' then
  vim.keymap.set({ 'n' }, 'gx', function()
    do_open(vim.fn.expand('<cfile>'))
  end, { desc = gx_desc })
end
if vim.fn.maparg('gx', 'x') == '' then
  vim.keymap.set({ 'x' }, 'gx', function()
    do_open(get_visual_selection())
  end, { desc = gx_desc })
end
