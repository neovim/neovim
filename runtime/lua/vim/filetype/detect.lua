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

---@private
local function iter_lines(bufnr, start_lnum, end_lnum)
  end_lnum = end_lnum or start_lnum
  return ipairs(vim.api.nvim_buf_get_lines(bufnr, start_lnum - 1, end_lnum, false))
end

function M.inp_check(_, bufnr)
  if get_lines(bufnr, 1):match("^%*") then
    vim.bo[bufnr].filetype = "abaqus"
  else
    for _, line in iter_lines(bufnr, 1, 500) do
      if line:match("header surface data") then
        vim.bo[bufnr].filetype = "trasys"
      end
    end
  end
end

function M.ex_check(_, bufnr)
  if vim.g.filetype_euphoria ~= nil then
    vim.bo[bufnr].filetype = vim.g.filetype_euphoria
  else
    for _, line in iter_lines(bufnr, 1, 100) do
    -- TODO: regex
      if line:match("") then
        vim.bo[bufnr].filetype = "euphoria3"
      else
        vim.bo[bufnr].filetype = "elixir"
      end
    end
  end
end

function M.euphoria_check(_, bufnr)
  if vim.g.filetype_euphoria ~= nil then
    vim.bo[bufnr].filetype = vim.g.filetype_euphoria
  else
    vim.bo[bufnr].filetype = "euphoria3"
  end
end

-- This function checks if one of the first five lines start with a dot. In
-- that case it is probably an nroff file.
function M.nroff(_, bufnr)
  for _, line in iter_lines(bufnr, 1, 5) do
    if line:find("^%.") then
      vim.bo[bufnr].filetype = "nroff"
    end
  end
end

function M.sql(_, bufnr)
  if vim.g.filetype_sql ~= nil then
    vim.bo[bufnr].filetype = vim.g.filetype_sql
  else
    vim.bo[bufnr].filetype = "sql"
  end
end

function M.xml(_, bufnr)
  for _, line in iter_lines(bufnr, 1, 100) do
    -- TODO: the vim version uses =~ which ignores case based on the ignorecase option.
    -- How should we handle this in lua?
    local is_docbook4 = line:find("<!DOCTYPE.*DocBook")
    local is_docbook5 = line:find(' xmlns="http://docbook%.org/ns/docbook"')
    if is_docbook4 or is_docbook5 then
      vim.b[bufnr].docbk_type = "xml"
      if is_docbook4 then
        vim.b[bufnr].docbk_ver = 4
      else
        vim.b[bufnr].docbk_ver = 5
      end
      vim.bo[bufnr].filetype = "docbk"
      return
    end
    if line:find('xmlns:xbl="http://www%.mozilla%.org/xbl"') then
      vim.bo[bufnr].filetype = "xbl"
      return
    end
  end
  vim.bo[bufnr].filetype = "xml"
end

function M.redif(_, bufnr)
  for _, line in iter_lines(bufnr, 1, 5) do
    -- TODO: maybe this is too expensive because a new string is created, any thoughts?
    -- However, it seems much more readable too me than "^[tT][eE]..."
    if line:lower():find("^template%-type:") then
      vim.bo[bufnr].filetype = "redif"
    end
  end
end

-- This function checks the first 15 lines for appearance of 'FoamFile'
-- and then 'object' in a following line.
-- In that case, it's probably an OpenFOAM file
function M.foam(_, bufnr)
  local foam_file = false
  for _, line in iter_lines(bufnr, 1, 15) do
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
  for _, line in iter_lines(bufnr, 1, -1) do
    -- TODO: regex
    if not line:find("^%s*[;/]") then
      vim.bo[bufnr].filetype = "terraform"
    else
      vim.bo[bufnr].filetype = "tf"
    end
  end
end

return M
