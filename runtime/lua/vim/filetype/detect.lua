local M = {}

---@private
local function getlines(bufnr, start_lnum, end_lnum, opts)
  if not end_lnum then
    -- Return a single line as a string
    return vim.api.nvim_buf_get_lines(bufnr, start_lnum - 1, start_lnum, false)[1]
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_lnum - 1, end_lnum, false)
  opts = opts or {}
  return opts.concat and (table.concat(lines) or "") or lines
end

---@private
local function findany(s, patterns)
  for _, v in ipairs(patterns) do
    if s:find(v) then
      return true
    end
  end
  return false
end

-- luacheck: push no unused args
-- luacheck: push ignore 122

function M.asm(path, bufnr) end

function M.asm_syntax(path, bufnr) end

function M.bas(path, bufnr) end

function M.bindzone(path, bufnr) end

function M.btm(bufnr)
  if vim.g.dosbatch_syntax_for_btm and vim.g.dosbatch_syntax_for_btm ~= 0 then
    vim.bo[bufnr].filetype = "dosbatch"
  else
    vim.bo[bufnr].filetype = "btm"
  end
end

-- Returns true if file content looks like RAPID
local function is_rapid(bufnr, extension)
  if extension == "cfg" then
    local line = getlines(bufnr, 1):lower()
    return findany(line, { "eio:cfg", "mmc:cfg", "moc:cfg", "proc:cfg", "sio:cfg", "sys:cfg" })
  end
  local first = "^%s*module%s+%S+%s*"
  -- Called from mod, prg or sys functions
  for _, line in ipairs(getlines(bufnr, 1, -1)) do
    if not line:find("^%s*$") then
      return findany(line:lower(), { "^%s*%%%%%%", first .. "(", first .. "$" })
    end
  end
  -- Only found blank lines
  return false
end

function M.cfg(bufnr)
  if vim.g.filetype_cfg then
    vim.bo[bufnr].filetype = vim.g.filetype_cfg
  elseif is_rapid(bufnr, "cfg") then
    vim.bo[bufnr].filetype = "rapid"
  else
    vim.bo[bufnr].filetype = "cfg"
  end
end

function M.change(path, bufnr) end

function M.csh(path, bufnr) end

function M.dat(path, bufnr) end

function M.dep3patch(path, bufnr) end

function M.dtrace(path, bufnr) end

function M.e(path, bufnr) end

-- This function checks for valid cl syntax in the first five lines.
-- Look for either an opening comment, '#', or a block start, '{'.
-- If not found, assume SGML.
function M.ent(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 5)) do
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

function M.euphoria(bufnr)
  if vim.g.filetype_euphoria then
    vim.bo[bufnr].filetype = vim.g.filetype_euphoria
  else
    vim.bo[bufnr].filetype = "euphoria3"
  end
end

function M.ex(bufnr)
  if vim.g.filetype_euphoria then
    vim.bo[bufnr].filetype = vim.g.filetype_euphoria
  else
    for _, line in ipairs(getlines(bufnr, 1, 100)) do
      -- TODO: in the Vim regex, \> is used to match the end of the word, can this be omitted?
      if findany(line, { "^%-%-", "^ifdef", "^include" }) then
        vim.bo[bufnr].filetype = "euphoria3"
        return
      end
    end
    vim.bo[bufnr].filetype = "elixir"
  end
end

-- This function checks the first 15 lines for appearance of 'FoamFile'
-- and then 'object' in a following line.
-- In that case, it's probably an OpenFOAM file
function M.foam(bufnr)
  local foam_file = false
  for _, line in ipairs(getlines(bufnr, 1, 15)) do
    if line:find("^FoamFile") then
      foam_file = true
    elseif foam_file and line:find("^%s*object") then
      vim.bo[bufnr].filetype = "foam"
      return
    end
  end
end

function M.frm(bufnr)
  if vim.g.filetype_frm then
    vim.bo[bufnr].filetype = vim.g.filetype_frm
  else
    -- Always ignore case
    local lines = getlines(bufnr, 1, 5, { concat = true }):lower()
    if findany(lines, { "vb_name", "begin vb%.form", "begin vb%.mdiform" }) then
      vim.bo[bufnr].filetype = "vb"
    else
      vim.bo[bufnr].filetype = "form"
    end
  end
end

function M.fs(path, bufnr) end

function M.header(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 200)) do
    if findany(line, { "^@interface", "^@end", "^@class" }) then
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

function M.idl(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 50)) do
    -- Always ignore case
    line = line:lower()
    if findany(line, { '^%s*import%s+"unknwn"%.idl', '^%s*import%s+"objidl"%.idl' }) then
      vim.bo[bufnr].filetype = "msidl"
      return
    end
  end
  vim.bo[bufnr].filetype = "idl"
end

function M.inc(path, bufnr) end

function M.inp(bufnr)
  if getlines(bufnr, 1):find("^%*") then
    vim.bo[bufnr].filetype = "abaqus"
  else
    for _, line in ipairs(getlines(bufnr, 1, 500)) do
      if line:lower():find("^header surface data") then
        vim.bo[bufnr].filetype = "trasys"
        return
      end
    end
  end
end

function M.lpc(path, bufnr) end

function M.lprolog(path, bufnr) end

function M.m(path, bufnr) end

-- Rely on the file to start with a comment.
-- MS message text files use ';', Sendmail files use '#' or 'dnl'
function M.mc(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 20)) do
    if findany(line:lower(), { "^%s*#", "^%s*dnl" }) then
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

function M.mm(path, bufnr) end

function M.mms(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 20)) do
    if findany(line, { "^%s*%%", "^%s*//", "^%*" }) then
      vim.bo[bufnr].filetype = "mmix"
      return
    elseif line:find("^%s*#") then
      vim.bo[bufnr].filetype = "make"
      return
    end
  end
  vim.bo[bufnr].filetype = "mmix"
end

function M.mod(path, bufnr) end

-- This function checks if one of the first five lines start with a dot. In
-- that case it is probably an nroff file: 'filetype' is set and 1 is returned.
function M.nroff(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 5)) do
    if line:find("^%.") then
      vim.bo[bufnr].filetype = "nroff"
      return 1
    end
  end
  return 0
end

function M.perl(path, bufnr) end

function M.pl(path, bufnr) end

function M.pp(path, bufnr) end

function M.prg(path, bufnr) end

function M.progress_asm(path, bufnr) end

function M.progress_cweb(bufnr)
  if vim.g.filetype_w then
    vim.bo[bufnr].filetype = vim.g.filetype_w
  else
    if getlines(bufnr, 1):find("^&ANALYZE") or getlines(bufnr, 3):find("^&GLOBAL%-DEFINE") then
      vim.bo[bufnr].filetype = "progress"
    else
      vim.bo[bufnr].filetype = "cweb"
    end
  end
end

function M.progress_pascal(path, bufnr) end

function M.proto(path, bufnr) end

function M.r(bufnr)
  local lines = getlines(bufnr, 1, 50)
  -- TODO: \< / \> which match the beginning / end of a word
  -- Rebol is easy to recognize, check for that first
  if table.concat(lines):lower():find("rebol") then
    vim.bo[bufnr].filetype = "rebol"
    return
  end

  for _, line in ipairs(lines) do
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

function M.redif(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 5)) do
    if line:lower():find("^template%-type:") then
      vim.bo[bufnr].filetype = "redif"
    end
  end
end

function M.rules(path, bufnr) end

-- This function checks the first 25 lines of file extension "sc" to resolve
-- detection between scala and SuperCollider
function M.sc(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 25)) do
    if findany(line, { "[A-Za-z0-9]*%s:%s[A-Za-z0-9]", "var%s<", "classvar%s<", "%^this.*", "|%w*|", "%+%s%w*%s{", "%*ar%s" }) then
      vim.bo[bufnr].filetype = "supercollider"
      return
    end
  end
  vim.bo[bufnr].filetype = "scala"
end

-- This function checks the first line of file extension "scd" to resolve
-- detection between scdoc and SuperCollider
function M.scd(bufnr)
  local first = "^%S+%(%d[0-9A-Za-z]*%)"
  local opt = [[%s+"[^"]*"]]
  local line = getlines(bufnr, 1)
  if findany(line, { first .. "$", first .. opt .. "$", first .. opt .. opt .. "$" }) then
    vim.bo[bufnr].filetype = "scdoc"
  else
    vim.bo[bufnr].filetype = "supercollider"
  end
end

function M.sh(path, bufnr) end

function M.shell(path, bufnr) end

function M.sql(bufnr)
  if vim.g.filetype_sql then
    vim.bo[bufnr].filetype = vim.g.filetype_sql
  else
    vim.bo[bufnr].filetype = "sql"
  end
end

function M.src(path, bufnr) end

function M.sys(path, bufnr) end

function M.tex(path, bufnr) end

-- Determine if a *.tf file is TF mud client or terraform
function M.tf(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, -1)) do
    -- Assume terraform file on a non-empty line (not whitespace-only)
    -- and when the first non-whitespace character is not a ; or /
    if not line:find("^%s*$") and not line:find("^%s*[;/]") then
      vim.bo[bufnr].filetype = "terraform"
      return
    end
  end
  vim.bo[bufnr].filetype = "tf"
end

function M.xml(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 100)) do
    line = line:lower()
    local is_docbook4 = line:find("<!doctype.*docbook")
    local is_docbook5 = line:find([[ xmlns="http://docbook.org/ns/docbook"]])
    if is_docbook4 or is_docbook5 then
      vim.b[bufnr].docbk_type = "xml"
      vim.b[bufnr].docbk_ver = is_docbook4 and 4 or 5
      vim.bo[bufnr].filetype = "docbk"
      return
    end
    if line:find([[xmlns:xbl="http://www.mozilla.org/xbl"]]) then
      vim.bo[bufnr].filetype = "xbl"
      return
    end
  end
  vim.bo[bufnr].filetype = "xml"
end

function M.y(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 100)) do
    if line:find("^%s*%%") then
      vim.bo[bufnr].filetype = "yacc"
      return
    end
    -- TODO: in the Vim regex, \> is used to match the end of the word after "class",
    -- can this be omitted?
    if findany(line, { "^%s*#", "^%class", "^%s*#%s*include" }) then
      vim.bo[bufnr].filetype = "racc"
    end
  end
  vim.bo[bufnr].filetype = "yacc"
end

-- luacheck: pop
-- luacheck: pop

return M
