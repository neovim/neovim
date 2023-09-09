-- Extra functionality for displaying Vim help.

local M = {}

-- Called when editing the doc/syntax.txt file
function M.highlight_groups()
  local save_cursor = vim.fn.getcurpos()

  local start_lnum = vim.fn.search([[\*highlight-groups\*]], 'c')
  if start_lnum == 0 then
    return
  end
  local end_lnum = vim.fn.search('^======')
  if end_lnum == 0 then
    return
  end

  local ns = vim.api.nvim_create_namespace('vimhelp')
  vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)

  for lnum = start_lnum, end_lnum do
    local word = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, true)[1]:match('^(%w+)\t')
    if vim.fn.hlexists(word) ~= 0 then
      vim.api.nvim_buf_set_extmark(0, ns, lnum - 1, 0, { end_col = #word, hl_group = word })
    end
  end

  vim.fn.setpos('.', save_cursor)
end

return M
