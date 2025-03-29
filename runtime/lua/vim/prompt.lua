M = {}

local original_prompt = ""
---@param multiline boolean Indicates whether the buffer is in multiline mode or not
function M.add_line(multiline)
  if original_prompt == "" then
    original_prompt = vim.fn.prompt_getprompt(vim.fn.bufnr(''))
  end
  local num_lines = vim.api.nvim_buf_line_count(0)
  if multiline then
    vim.fn.prompt_setprompt(vim.fn.bufnr(''), '...')
  else
    vim.fn.prompt_setprompt(vim.fn.bufnr(''), original_prompt)
  end

  vim.api.nvim_buf_set_lines(0, num_lines + 1, num_lines + 1, false, { "" })
end

local last_line = 0 --- @type integer
function M.prompt_send()
  local lnum = vim.fn.getcurpos()[2] - 1 ---@type integer
  vim.print(vim.api.nvim_buf_get_lines(0, last_line, lnum + 1, false))
  M.add_line(false)
  last_line = lnum + 1
end

return M

