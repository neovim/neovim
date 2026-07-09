if vim.g.loaded_matchit ~= nil then
  return
end

local function enable_mappings()
  vim.keymap.set('n', '<Plug>(MatchitNormalForward)', [[:<C-U>lua require('nvim.matchit').jump(true, 'n')<CR>]], { silent = true })
  vim.keymap.set('n', '<Plug>(MatchitNormalBackward)', [[:<C-U>lua require('nvim.matchit').jump(false, 'n')<CR>]], { silent = true })
  vim.keymap.set('x', '<Plug>(MatchitVisualForward)', [[:<C-U>lua require('nvim.matchit').jump(true, 'v')<CR>]], { silent = true })
  vim.keymap.set('x', '<Plug>(MatchitVisualBackward)', [[:<C-U>lua require('nvim.matchit').jump(false, 'v')<CR>]], { silent = true })
  vim.keymap.set('o', '<Plug>(MatchitOperationForward)', [[:<C-U>lua require('nvim.matchit').jump(true, 'o')<CR>]], { silent = true })
  vim.keymap.set('o', '<Plug>(MatchitOperationBackward)', [[:<C-U>lua require('nvim.matchit').jump(false, 'o')<CR>]], { silent = true })
  vim.keymap.set(
    'n',
    '<Plug>(MatchitNormalMultiBackward)',
    [[:<C-U>lua require('nvim.matchit').multi_match('bW', 'n')<CR>]],
    { silent = true }
  )
  vim.keymap.set(
    'n',
    '<Plug>(MatchitNormalMultiForward)',
    [[:<C-U>lua require('nvim.matchit').multi_match('W', 'n')<CR>]],
    { silent = true }
  )
  vim.keymap.set(
    'x',
    '<Plug>(MatchitVisualMultiBackward)',
    [[:<C-U>lua require('nvim.matchit').multi_match('bW', 'n')<CR>m'gv``]],
    { silent = true }
  )
  vim.keymap.set(
    'x',
    '<Plug>(MatchitVisualMultiForward)',
    [[:<C-U>lua require('nvim.matchit').multi_match('W', 'n')<CR>m'gv``]],
    { silent = true }
  )
  vim.keymap.set(
    'o',
    '<Plug>(MatchitOperationMultiBackward)',
    [[:<C-U>lua require('nvim.matchit').multi_match('bW', 'o')<CR>]],
    { silent = true }
  )
  vim.keymap.set(
    'o',
    '<Plug>(MatchitOperationMultiForward)',
    [[:<C-U>lua require('nvim.matchit').multi_match('W', 'o')<CR>]],
    { silent = true }
  )
  vim.keymap.set(
    'x',
    '<Plug>(MatchitVisualTextObject)',
    '<Plug>(MatchitVisualMultiBackward)o<Plug>(MatchitVisualMultiForward)',
    { silent = true, remap = true }
  )
  if vim.g.no_plugin_maps == nil then
    vim.keymap.set('n', '%', '<Plug>(MatchitNormalForward)', { silent = true, remap = true })
    vim.keymap.set('n', 'g%', '<Plug>(MatchitNormalBackward)', { silent = true, remap = true })
    vim.keymap.set('x', '%', '<Plug>(MatchitVisualForward)', { silent = true, remap = true })
    vim.keymap.set('x', 'g%', '<Plug>(MatchitVisualBackward)', { silent = true, remap = true })
    vim.keymap.set('o', '%', '<Plug>(MatchitOperationForward)', { silent = true, remap = true })
    vim.keymap.set('o', 'g%', '<Plug>(MatchitOperationBackward)', { silent = true, remap = true })
    vim.keymap.set('n', '[%', '<Plug>(MatchitNormalMultiBackward)', { silent = true, remap = true })
    vim.keymap.set('n', ']%', '<Plug>(MatchitNormalMultiForward)', { silent = true, remap = true })
    vim.keymap.set('x', '[%', '<Plug>(MatchitVisualMultiBackward)', { silent = true, remap = true })
    vim.keymap.set('x', ']%', '<Plug>(MatchitVisualMultiForward)', { silent = true, remap = true })
    vim.keymap.set('o', '[%', '<Plug>(MatchitOperationMultiBackward)', { silent = true, remap = true })
    vim.keymap.set('o', ']%', '<Plug>(MatchitOperationMultiForward)', { silent = true, remap = true })
    vim.keymap.set('x', 'a%', '<Plug>(MatchitVisualTextObject)', { silent = true, remap = true })
  end
end

local function disable()
  for _, mode in ipairs({ 'n', 'x', 'o' }) do
    pcall(vim.keymap.del, mode, '%')
    pcall(vim.keymap.del, mode, 'g%')
    pcall(vim.keymap.del, mode, '[%')
    pcall(vim.keymap.del, mode, ']%')
  end
  pcall(vim.keymap.del, 'x', 'a%')
end

vim.g.loaded_matchit = 1
enable_mappings()
vim.api.nvim_create_user_command('MatchDisable', disable, { force = true })
vim.api.nvim_create_user_command('MatchEnable', enable_mappings, { force = true })
