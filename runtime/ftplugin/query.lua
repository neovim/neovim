-- Neovim filetype plugin file
-- Language:	Tree-sitter query
-- Last Change:	2022 Apr 25

if vim.b.did_ftplugin == 1 then
  return
end

-- Do not set vim.b.did_ftplugin = 1 to allow loading of ftplugin/lisp.vim

-- use treesitter over syntax
vim.treesitter.start()

-- set omnifunc
vim.bo.omnifunc = 'v:lua.vim.treesitter.query.omnifunc'

-- query linter
local buf = vim.api.nvim_get_current_buf()
local query_lint_on = vim.g.query_lint_on or { 'BufEnter', 'BufWrite' }

if not vim.b.disable_query_linter and #query_lint_on > 0 then
  vim.api.nvim_create_autocmd(query_lint_on, {
    group = vim.api.nvim_create_augroup('querylint', { clear = false }),
    buffer = buf,
    callback = function()
      vim.treesitter.query.lint(buf)
    end,
    desc = 'Query linter',
  })
end

-- it's a lisp!
vim.cmd([[ runtime! ftplugin/lisp.vim ]])
