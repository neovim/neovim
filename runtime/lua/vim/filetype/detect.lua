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

function M.asm(_, bufnr)

end

function M.asm_syntax(_, bufnr)

end

function M.bas(_, bufnr)

end

function M.bindzone(_, bufnr)

end

function M.btm(_, bufnr)
  if vim.g.dosbatch_syntax_for_btm and vim.g.dosbatch_syntax_for_btm ~= 0 then
    vim.bo[bufnr].filetype = "dosbatch"
  else
    vim.bo[bufnr].filetype = "btm"
  end
end

function M.cfg(path, bufnr)
  if vim.g.filetype_cfg then
    vim.bo[bufnr].filetype = vim.g.filetype_cfg
  elseif M.is_rapid(path, bufnr) then
    vim.bo[bufnr].filetype = "rapid"
  else
    vim.bo[bufnr].filetype = "cfg"
  end
end

function M.change(_, bufnr)

end

function M.csh(_, bufnr)

end

function M.dat(_, bufnr)

end

function M.dep3patch(_, bufnr)

end

function M.dtrace(_, bufnr)

end

function M.e(_, bufnr)

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
    -- TODO: in the Vim regex, \> is used to match the end of the word, can this be omitted?
      if line:find("^%-%-") or line:find("^ifdef") or line:find("^include")  then
        vim.bo[bufnr].filetype = "euphoria3"
        return
      end
    end
  end
  vim.bo[bufnr].filetype = "elixir"
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

function M.frm(_, bufnr)
  if vim.g.filetype_frm then
    vim.bo[bufnr].filetype = vim.g.filetype_frm
  else
    for _, line in iter_lines(bufnr, 1, 5) do
      -- Always ignore case
      line = line:lower()
      if line:find("vb_name") or line:find("begin vb%.form") or line:find("begin vb%.mdiform") or line:find("begin vb%.usercontrol") then
        vim.bo[bufnr].filetype = "vb"
      else
        vim.bo[bufnr].filetype = "form"
      end
    end
  end
end

function M.fs(_, bufnr)

end

function M.header(_, bufnr)
  for _, line in iter_lines(bufnr, 1, 200) do
    if line:find("^@interface") or line:find("^@end") or line:find("^@class") then
      if vim.g.c_syntax_for_h then
        vim.bo[bufnr].filetype = "objc"
      else
        vim.bo[bufnr].filetype = "objcpp"
      end
      return
    end
  end
  if vim.g.c_syntax_for_h then
      vim.bo[bufnr].filetype = "c"
  elseif vim.g.ch_syntax_for_h then
      vim.bo[bufnr].filetype = "ch"
  else
      vim.bo[bufnr].filetype = "cpp"
  end
end

function M.idl(_, bufnr)
  for _, line in iter_lines(bufnr, 1, 50) do
    -- Always ignore case
    line = line:lower()
    if line:find('^%s*import%s+"unknwn"%.idl') or line:find('^%s*import%s+"objidl"%.idl') then
      vim.bo[bufnr].filetype = "msidl"
      return
    end
  end
  vim.bo[bufnr].filetype = "idl"
end

function M.inc(_, bufnr)

end

function M.inp(_, bufnr)
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

function M.is_rapid(_, bufnr)

end

function M.lpc(_, bufnr)

end

function M.lprolog(_, bufnr)

end

function M.m(_, bufnr)

end

-- Rely on the file to start with a comment.
-- MS message text files use ';', Sendmail files use '#' or 'dnl'
function M.mc(_, bufnr)
  for _, line in iter_lines(bufnr, 1, 20) do
    if line:find("^%s*#") or line:find("^%s*[dD][nN][lL]") then
      -- Sendmail .mc file
      vim.bo[bufnr].filetype = "m4"
      return
    elseif line:find("^%s*;") then
      vim.bo[bufnr].filetype = "msmessages"
      return
    end
  end
  -- Default: Sendmail .mc file
  vim.bo[bufnr].filetype = "m4"
end

function M.mm(_, bufnr)

end

function M.mms(_, bufnr)
  for _, line in iter_lines(bufnr, 1, 20) do
    if line:find("^%s*%%") or line:find("^%s*//") or line:find("^%*") then
      vim.bo[bufnr].filetype = "mmix"
      return
    elseif line:find("^%s*#") then
      vim.bo[bufnr].filetype = "make"
      return
    end
  end
  vim.bo[bufnr].filetype = "mmix"
end

function M.mod(_, bufnr)

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

function M.perl(_, bufnr)

end

function M.pl(_, bufnr)

end

function M.pp(_, bufnr)

end

function M.prg(_, bufnr)

end

function M.progress_asm(_, bufnr)

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

function M.progress_pascal(_, bufnr)

end

function M.proto(_, bufnr)

end

function M.r(_, bufnr)
  local lines = iter_lines(bufnr, 1, 50)
  for _, line in lines do
    -- TODO: \< / \> which match the beginning / end of a word
    -- Rebol is easy to recognize, check for that first
    if line:find("[rR][eE][bB][oO][lL]") then
      vim.bo[bufnr].filetype = "rebol"
      return
    end
  end

  for _, line in lines do
    -- R has # comments
    if line:find("^%s*#") then
      vim.bo[bufnr].filetype = "r"
      return
    end
    -- Rexx has /* comments */
    if line:find("^%s*/%*") then
      vim.bo[bufnr].filetype = "rexx"
      return
    end
  end

  -- Nothing recognized, use user default or assume R
  if vim.g.filetype_r then
    vim.bo[bufnr].filetype = vim.g.filetype_r
  else
    -- Rexx used to be the default, but R appears to be much more popular.
    vim.bo[bufnr].filetype = "r"
  end
end

function M.redif(_, bufnr)
  for _, line in iter_lines(bufnr, 1, 5) do
    -- TODO: maybe this is too expensive because a new string is created, any thoughts?
    -- However, it seems much more readable to me than "^[tT][eE]..."
    if line:lower():find("^template%-type:") then
      vim.bo[bufnr].filetype = "redif"
    end
  end
end

function M.rules(_, bufnr)

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

function M.sh(_, bufnr)

end

function M.shell(_, bufnr)

end

function M.sql(_, bufnr)
  if vim.g.filetype_sql then
    vim.bo[bufnr].filetype = vim.g.filetype_sql
  else
    vim.bo[bufnr].filetype = "sql"
  end
end

function M.src(_, bufnr)

end

function M.sys(_, bufnr)

end

function M.tex(_, bufnr)

end

-- Determine if a *.tf file is TF mud client or terraform
function M.tf(_, bufnr)
  for _, line in iter_lines(bufnr, 1, -1) do
    -- No terraform file on an empty line (whitespace only), or when the first
    -- non-whitespace character is a ; or /
    if not line:find("^%s*[;/]?") then
      vim.bo[bufnr].filetype = "terraform"
    end
  end
  vim.bo[bufnr].filetype = "tf"
end

function M.xml(_, bufnr)
  for _, line in iter_lines(bufnr, 1, 100) do
    line = line:lower()
    local is_docbook4 = line:find("<!doctype.*docbook")
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
