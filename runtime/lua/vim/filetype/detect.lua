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

function M.asm()

end

function M.asm_syntax()

end

function M.bas()

end

function M.bindzone()

end

function M.btm(_, bufnr)
  if vim.g.dosbatch_syntax_for_btm and vim.g.dosbatch_syntax_for_btm ~= 0 then
    vim.bo[bufnr].filetype = "dosbatch"
  else
    vim.bo[bufnr].filetype = "btm"
  end
end

function M.cfg()

end

function M.change()

end

function M.csh()

end

function M.dat()

end

function M.dep3patch()

end

function M.dtrace()

end

function M.e()

end

-- This function checks for valid cl syntax in the first five lines.
-- Look for either an opening comment, '#', or a block start, '{'.
-- If not found, assume SGML.
function M.ent(_, bufnr)
  for _, line in iter_lines(bufnr, 1, 5) do
    if line:find("^%s*[#{]") then
      vim.bo[bufnr].filetype = "cl"
      return
    elseif not line:find("^%s*$") then
      -- Not a blank line, not a comment, and not a block start,
      -- so doesn't look like valid cl code.
      break
    end
  end
  vim.bo[bufnr].filetype = "dtd"
end

function M.euphoria(_, bufnr)
  if vim.g.filetype_euphoria then
    vim.bo[bufnr].filetype = vim.g.filetype_euphoria
  else
    vim.bo[bufnr].filetype = "euphoria3"
  end
end

function M.ex(_, bufnr)
  if vim.g.filetype_euphoria then
    vim.bo[bufnr].filetype = vim.g.filetype_euphoria
  else
    for _, line in iter_lines(bufnr, 1, 100) do
    -- TODO: regex
      if line:find("") then
        vim.bo[bufnr].filetype = "euphoria3"
      else
        vim.bo[bufnr].filetype = "elixir"
      end
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

function M.frm()

end

function M.fs()

end

function M.header()

end

function M.idl()

end

function M.inc()

end

function M.inp_check(_, bufnr)
  if get_lines(bufnr, 1):find("^%*") then
    vim.bo[bufnr].filetype = "abaqus"
  else
    for _, line in iter_lines(bufnr, 1, 500) do
      if line:find("header surface data") then
        vim.bo[bufnr].filetype = "trasys"
        return
      end
    end
  end
end

function M.is_rapid()

end

function M.lpc()

end

function M.lprolog()

end

function M.m()

end

function M.mc()

end

function M.mm()

end

function M.mms()

end

function M.mod()

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

function M.perl()

end

function M.pl()

end

function M.pp()

end

function M.prg()

end

function M.progress_asm()

end

function M.progress_cweb(_, bufnr)
  if vim.g.filetype_w then
    vim.bo[bufnr].filetype = vim.g.filetype_w
  else
    if get_lines(bufnr, 1) == "&ANALYZE" or get_lines(bufnr, 3) == "&GLOBAL-DEFINE" then
      vim.bo[bufnr].filetype = "progress"
    else
      vim.bo[bufnr].filetype = "cweb"
    end
  end
end

function M.progress_pascal()

end

function M.proto()

end

function M.r()

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

function M.rules()

end

-- This function checks the first 25 lines of file extension "sc" to resolve
-- detection between scala and SuperCollider
function M.sc(_, bufnr)
  -- TODO: it still needs to be discussed if it's ok to use vim.regex in some cases
  local regex = vim.regex([[[A-Za-z0-9]*\s:\s[A-Za-z0-9]\|var\s<\|classvar\s<\|\^this.*\||\w*|\|+\s\w*\s{\|\*ar\s]])
  for _, line in iter_lines(bufnr, 1, 25) do
    if regex:match_str(line) then
      vim.bo[bufnr].filetype = "supercollider"
      return
    end
  end
  vim.bo[bufnr].filetype = "scala"
end

-- This function checks the first line of file extension "scd" to resolve
-- detection between scdoc and SuperCollider
function M.scd(_, bufnr)
  -- TODO: it still needs to be discussed if it's ok to use vim.regex in some cases
  local regex = vim.regex([[\%^\S\+(\d[0-9A-Za-z]*)\%(\s\+\"[^"]*\"\%(\s\+\"[^"]*\"\)\=\)\=$]])
  if regex:match_str(get_lines(bufnr, 1)) then
    vim.bo[bufnr].filetype = "scdoc"
  else
    vim.bo[bufnr].filetype = "supercollider"
  end
end

function M.sh()

end

function M.shell()

end

function M.sql(_, bufnr)
  if vim.g.filetype_sql then
    vim.bo[bufnr].filetype = vim.g.filetype_sql
  else
    vim.bo[bufnr].filetype = "sql"
  end
end

function M.src()

end

function M.sys()

end

function M.tex()

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

function M.xml(_, bufnr)
  for _, line in iter_lines(bufnr, 1, 100) do
    -- TODO: the vim version uses =~ which ignores case based on the ignorecase option.
    -- How should we handle this in lua?
    local is_docbook4 = line:find("<!DOCTYPE.*DocBook")
    local is_docbook5 = line:find(' xmlns="http://docbook%.org/ns/docbook"')
    if is_docbook4 or is_docbook5 then
      vim.b[bufnr].docbk_type = "xml"
      vim.b[bufnr].docbk_ver = is_docbook4 and 4 or 5
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

function M.y(_, bufnr)
  for _, line in iter_lines(bufnr, 1, 100) do
    if line:find("^%s*%%") then
      vim.bo[bufnr].filetype = "yacc"
      return
    end
    -- TODO: in the Vim regex, \> is used to match the end of the word after "class",
    -- can this be omitted?
    if line:find("^%s*#") or line:find("^%class") and not line:find("^%s*#%s*include") then
      vim.bo[bufnr].filetype = "racc"
    end
  end
  vim.bo[bufnr].filetype = "yacc"
end

return M
