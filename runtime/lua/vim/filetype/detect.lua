local M = {}

-- Determine if a *.tf file is TF mud client or terraform
function M.tf(_, bufnr)
  local number_of_lines = vim.api.nvim_buf_line_count(bufnr)
  for _,line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, number_of_lines, true)) do
    if not line:find("^[;/ ]") then
      return "terraform"
    end
  end

  return "tf"
end

return M
