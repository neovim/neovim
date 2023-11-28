-- Neovim syntax file
-- Language:    Tree-sitter inspector
-- Last Change: 2023 Nov 28

-- Quit when a syntax file was already loaded
if vim.b.current_syntax then
  return
end

vim.cmd([[
syn match tsInspectorComment /;.*$/
syn region tsInspectorAnonymous start=/"/ end=/"/

hi def link tsInspectorComment   Comment
hi def link tsInspectorAnonymous String
]])

vim.b.current_syntax = 'tsinspector'
