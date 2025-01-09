-- use treesitter over syntax (for highlighted code blocks)
vim.treesitter.start()

-- Add custom highlights for list in `:h highlight-groups`.
local bufname = vim.fs.normalize(vim.api.nvim_buf_get_name(0))
if vim.endswith(bufname, '/doc/syntax.txt') then
  require('vim.vimhelp').highlight_groups({
    { start = [[\*group-name\*]], stop = '^======', match = '^(%w+)\t' },
    { start = [[\*highlight-groups\*]], stop = '^======', match = '^(%w+)\t' },
  })
elseif vim.endswith(bufname, '/doc/treesitter.txt') then
  require('vim.vimhelp').highlight_groups({
    {
      start = [[\*treesitter-highlight-groups\*]],
      stop = [[\*treesitter-highlight-spell\*]],
      match = '^@[%w%p]+',
    },
  })
elseif vim.endswith(bufname, '/doc/diagnostic.txt') then
  require('vim.vimhelp').highlight_groups({
    { start = [[\*diagnostic-highlights\*]], stop = '^======', match = '^(%w+)' },
  })
elseif vim.endswith(bufname, '/doc/lsp.txt') then
  require('vim.vimhelp').highlight_groups({
    { start = [[\*lsp-highlight\*]], stop = '^------', match = '^(%w+)' },
    { start = [[\*lsp-semantic-highlight\*]], stop = '^======', match = '^@[%w%p]+' },
  })
end

vim.keymap.set('n', 'gO', function()
  require('vim.vimhelp').show_toc()
end, { buffer = 0, silent = true })

-- Add "runnables" for Lua/Vimscript code examples.
---@type table<integer, { lang: string, code: string }>
local code_blocks = {}
local tree = vim.treesitter.get_parser():parse()[1]
local query = vim.treesitter.query.parse(
  'vimdoc',
  [[
  (codeblock
    (language) @_lang
    .
    (code) @code
    (#any-of? @_lang "lua" "vim")
    (#set! @code lang @_lang))
]]
)
local run_message_ns = vim.api.nvim_create_namespace('vimdoc/run_message')

vim.api.nvim_buf_clear_namespace(0, run_message_ns, 0, -1)
for _, match, metadata in query:iter_matches(tree:root(), 0, 0, -1) do
  for id, nodes in pairs(match) do
    local name = query.captures[id]
    local node = nodes[1]
    local start, _, end_ = node:parent():range() --[[@as integer]]

    if name == 'code' then
      vim.api.nvim_buf_set_extmark(0, run_message_ns, start, 0, {
        virt_text = { { 'Run with `yxx`', 'LspCodeLens' } },
      })
      local code = vim.treesitter.get_node_text(node, 0)
      local lang_node = match[metadata[id].lang][1] --[[@as TSNode]]
      local lang = vim.treesitter.get_node_text(lang_node, 0)
      for i = start + 1, end_ do
        code_blocks[i] = { lang = lang, code = code }
      end
    end
  end
end

vim.keymap.set('n', 'yxx', function()
  local pos = vim.api.nvim_win_get_cursor(0)[1]
  local code_block = code_blocks[pos]
  if not code_block then
    vim.print('No code block found')
  elseif code_block.lang == 'lua' then
    vim.cmd.lua(code_block.code)
  elseif code_block.lang == 'vim' then
    vim.cmd(code_block.code)
  end
end, { buffer = true })

vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '')
  .. '\n exe "nunmap <buffer> gO" | exe "nunmap <buffer> yxx"'
vim.b.undo_ftplugin = vim.b.undo_ftplugin .. ' | call v:lua.vim.treesitter.stop()'
