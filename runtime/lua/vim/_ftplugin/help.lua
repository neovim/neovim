local M = {}

function M.keywordprg()
  local captures = vim.treesitter.get_captures_at_pos(0, vim.fn.line('.') - 1, vim.fn.col('.'))
  if #captures == 0 then return end
  local lang = captures[#captures].lang
  if lang == 'lua' then
    local temp_isk = vim.bo.iskeyword
    vim.cmd('setl isk<')
    require('vim._ftplugin.lua').keywordprg()
    vim.bo.iskeyword = temp_isk
  else
    vim.cmd.help(vim.fn.expand('<cword>'))
  end
end

return M
