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

-- This function checks if one of the first five lines start with a dot. In
-- that case it is probably an nroff file.
function M.nroff(_, bufnr)
  if get_lines(bufnr, 1, 5):find("^%.") then
    vim.bo[bufnr].filetype = "nroff"
  end
end

function M.redif(_, bufnr)
  local lines = get_lines(bufnr, 1, 5)
  if lines:find("^[tT][eE][mM][pP][lL][aA][tT][eE]%-[tT][yY][pP][eE]:") then
    vim.bo[bufnr].filetype = "redif"
  end
end

-- This function checks the first 15 lines for appearance of 'FoamFile'
-- and then 'object' in a following line.
-- In that case, it's probably an OpenFOAM file
function M.foam(_, bufnr)
  local foam_file = false
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, 15, false)) do
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
  local lines = get_lines(bufnr, 1, count_lines(bufnr))
  if not lines:find("^[;/ ]") then
    vim.bo[bufnr].filetype = "terraform"
  else
    vim.bo[bufnr].filetype = "tf"
  end
end

return M
