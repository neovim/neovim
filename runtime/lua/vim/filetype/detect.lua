local M = {}

---@private
local function count_lines(bufnr)
  return vim.api.nvim_buf_line_count(bufnr)
end

---@private
local function get_lines(bufnr, start_lnum, end_lnum)
  end_lnum = end_lnum or start_lnum
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_lnum - 1, end_lnum, false)
  return table.concat(lines) or ""
end

-- This function checks the first 15 lines for appearance of 'FoamFile'
-- and then 'object' in a following line.
-- In that case, it's probably an OpenFOAM file
function M.foam(_, bufnr)
  local foam_file = false
  for _, line in ipairs(get_lines(bufnr, 1, 15)) do
    if line:find("^FoamFile") then
      foam_file = true
    elseif foam_file and line:find("^%s*object") then
      vim.bo[bufnr].filetype = "foam"
      return
    end
  end
end

-- Determine if a *.tf file is TF mud client or terraform
function M.tf(_, bufnr)
  local number_of_lines = count_lines(bufnr)
  for _, line in ipairs(get_lines(bufnr, 1, number_of_lines)) do
    if not line:find("^[;/ ]") then
      vim.bo[bufnr].filetype = "terraform"
      return
    end
  end
  vim.bo[bufnr].filetype = "tf"
end

return M
