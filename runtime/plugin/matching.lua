if vim.g.loaded_matching ~= nil or vim.g.loaded_matchparen ~= nil then
  return
end
vim.g.loaded_matching = true


local augroup = vim.api.nvim_create_augroup('nvim.matching', {})

local hl_events = {
  'CursorMoved',
  'CursorMovedI',
  'WinEnter',
  'WinScrolled',
  'TextChanged',
  'TextChangedI',
}

vim.api.nvim_create_autocmd(hl_events, {
  group = augroup,
  desc = 'Show matching highlights',
  callback = function()
    require('vim._matching').highlight()
  end
})

vim.api.nvim_create_autocmd({ 'WinLeave', 'BufLeave', 'TextChangedP' }, {
  group = augroup,
  desc = 'Hide current matching highlights',
  callback = function(args)
    -- if it exists, nvim_create_namespace returns its ID
    local ns = vim.api.nvim_create_namespace('nvim.matching')
    vim.api.nvim_buf_clear_namespace(args.buf, ns, 0, -1)
  end
})

vim.keymap.set({ 'n', 'x' }, '%', function()
  require('vim._matching').jump()
end, { desc = 'Jump to the next matching pair' })

vim.keymap.set({ 'n', 'x' }, 'g%', function()
  require('vim._matching').jump({ backward = true })
end, { desc = 'Jump to the previous matching pair' })

vim.keymap.set('o', '%', function()
  require('vim._matching').jump()
end, { desc = 'Matching group text object' })
