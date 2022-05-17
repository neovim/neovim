-- Contains filetype detection functions converted to Lua from Vim's autoload/runtime/dist/ft.vim file.

-- Here are a few guidelines to follow when porting a new function:
--  * Sort the function alphabetically and omit 'ft' or 'check' from the new function name.
--  * Use ':find' instead of ':match' / ':sub' if possible.
--  * When '=~' is used to match a pattern, there are two possibilities:
--     - If the pattern only contains lowercase characters, treat the comparison as case-insensitive.
--     - Otherwise, treat it as case-sensitive.
--     (Basically, we apply 'smartcase': if upper case characters are used in the original pattern, then
--     it's likely that case does matter).
--  * When '\k', '\<' or '\>' is used in a pattern, use the 'matchregex' function.
--     Note that vim.regex is case-sensitive by default, so add the '\c' flag if only lowercase letters
--     are present in the pattern:
--     Example:
--     `if line =~ '^\s*unwind_protect\>'` => `if matchregex(line, [[\c^\s*unwind_protect\>]])`

local M = {}

---@private
local function getlines(bufnr, start_lnum, end_lnum)
  if not end_lnum then
    -- Return a single line as a string
    return vim.api.nvim_buf_get_lines(bufnr, start_lnum - 1, start_lnum, false)[1]
  end
  return vim.api.nvim_buf_get_lines(bufnr, start_lnum - 1, end_lnum, false)
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

---@private
local function nextnonblank(bufnr, start_lnum)
  for _, line in ipairs(getlines(bufnr, start_lnum, -1)) do
    if not line:find('^%s*$') then
      return line
    end
  end
  return nil
end

---@private
local matchregex = (function()
  local cache = {}
  return function(line, pattern)
    if line == nil then
      return nil
    end
    if not cache[pattern] then
      cache[pattern] = vim.regex(pattern)
    end
    return cache[pattern]:match_str(line)
  end
end)()

-- luacheck: push no unused args
-- luacheck: push ignore 122

-- This function checks for the kind of assembly that is wanted by the user, or
-- can be detected from the first five lines of the file.
function M.asm(bufnr)
  -- Make sure b:asmsyntax exists
  if not vim.b[bufnr].asmsyntax then
    vim.b[bufnr].asmsyntax = ''
  end

  if vim.b[bufnr].asmsyntax == '' then
    M.asm_syntax(bufnr)
  end

  -- If b:asmsyntax still isn't set, default to asmsyntax or GNU
  if vim.b[bufnr].asmsyntax == '' then
    if vim.g.asmsyntax and vim.g.asmsyntax ~= 0 then
      vim.b[bufnr].asmsyntax = vim.g.asmsyntax
    else
      vim.b[bufnr].asmsyntax = 'asm'
    end
  end
  vim.bo[bufnr].filetype = vim.fn.fnameescape(vim.b[bufnr].asmsyntax)
end

-- Checks the first 5 lines for a asmsyntax=foo override.
-- Only whitespace characters can be present immediately before or after this statement.
function M.asm_syntax(bufnr)
  local lines = table.concat(getlines(bufnr, 1, 5), ' '):lower()
  local match = lines:match('%sasmsyntax=([a-zA-Z0-9]+)%s')
  if match then
    vim.b['asmsyntax'] = match
  elseif findany(lines, { '%.title', '%.ident', '%.macro', '%.subtitle', '%.library' }) then
    vim.b['asmsyntax'] = 'vmasm'
  end
end

local visual_basic_content = { 'vb_name', 'begin vb%.form', 'begin vb%.mdiform', 'begin vb%.usercontrol' }

-- See frm() for Visual Basic form file detection
function M.bas(bufnr)
  if vim.g.filetype_bas then
    vim.bo[bufnr].filetype = vim.g.filetype_bas
    return
  end

  -- Most frequent FreeBASIC-specific keywords in distro files
  local fb_keywords =
    [[\c^\s*\%(extern\|var\|enum\|private\|scope\|union\|byref\|operator\|constructor\|delete\|namespace\|public\|property\|with\|destructor\|using\)\>\%(\s*[:=(]\)\@!]]
  local fb_preproc =
    [[\c^\s*\%(#\a\+\|option\s\+\%(byval\|dynamic\|escape\|\%(no\)\=gosub\|nokeyword\|private\|static\)\>\)]]

  local fb_comment = "^%s*/'"
  -- OPTION EXPLICIT, without the leading underscore, is common to many dialects
  local qb64_preproc = [[\c^\s*\%($\a\+\|option\s\+\%(_explicit\|_\=explicitarray\)\>\)]]

  for _, line in ipairs(getlines(bufnr, 1, 100)) do
    if line:find(fb_comment) or matchregex(line, fb_preproc) or matchregex(line, fb_keywords) then
      vim.bo[bufnr].filetype = 'freebasic'
      return
    elseif matchregex(line, qb64_preproc) then
      vim.bo[bufnr].filetype = 'qb64'
      return
    elseif findany(line:lower(), visual_basic_content) then
      vim.bo[bufnr].filetype = 'vb'
      return
    end
  end
  vim.bo[bufnr].filetype = 'basic'
end

function M.bindzone(bufnr, default_ft) end

function M.btm(bufnr)
  if vim.g.dosbatch_syntax_for_btm and vim.g.dosbatch_syntax_for_btm ~= 0 then
    vim.bo[bufnr].filetype = 'dosbatch'
  else
    vim.bo[bufnr].filetype = 'btm'
  end
end

-- Returns true if file content looks like RAPID
local function is_rapid(bufnr, extension)
  if extension == 'cfg' then
    local line = getlines(bufnr, 1):lower()
    return findany(line, { 'eio:cfg', 'mmc:cfg', 'moc:cfg', 'proc:cfg', 'sio:cfg', 'sys:cfg' })
  end
  local line = nextnonblank(bufnr, 1)
  if line then
    -- Called from mod, prg or sys functions
    return matchregex(line:lower(), [[\c\v^\s*%(\%{3}|module\s+\k+\s*%(\(|$))]])
  end
  return false
end

function M.cfg(bufnr)
  if vim.g.filetype_cfg then
    vim.bo[bufnr].filetype = vim.g.filetype_cfg
  elseif is_rapid(bufnr, 'cfg') then
    vim.bo[bufnr].filetype = 'rapid'
  else
    vim.bo[bufnr].filetype = 'cfg'
  end
end

-- This function checks if one of the first ten lines start with a '@'.  In
-- that case it is probably a change file.
-- If the first line starts with # or ! it's probably a ch file.
-- If a line has "main", "include", "//" or "/*" it's probably ch.
-- Otherwise CHILL is assumed.
function M.change(bufnr)
  local first_line = getlines(bufnr, 1)
  if findany(first_line, { '^#', '^!' }) then
    vim.bo[bufnr].filetype = 'ch'
    return
  end
  for _, line in ipairs(getlines(bufnr, 1, 10)) do
    if line:find('^@') then
      vim.bo[bufnr].filetype = 'change'
      return
    end
    if line:find('MODULE') then
      vim.bo[bufnr].filetype = 'chill'
      return
    elseif findany(line:lower(), { 'main%s*%(', '#%s*include', '//' }) then
      vim.bo[bufnr].filetype = 'ch'
      return
    end
  end
  vim.bo[bufnr].filetype = 'chill'
end

function M.csh(path, bufnr) end

-- Determine if a *.dat file is Kuka Robot Language
-- TODO: this one fails for some reason, so I omitted it. #18219 should be merged first.
function M.dat(bufnr)
  -- if vim.g.filetype_dat then
  --   vim.bo[bufnr].filetype = vim.g.filetype_dat
  --   return
  -- end
  -- local line = nextnonblank(bufnr, 1):lower()
  -- if findany(line, { "^%s*&%w+", "^%s*defdat" }) then
  --   vim.bo[bufnr].filetype = "krl"
  -- end
end

-- This function is called for all files under */debian/patches/*, make sure not
-- to non-dep3patch files, such as README and other text files.
function M.dep3patch(path, bufnr)
  local file_name = vim.fn.fnamemodify(path, ':t')
  if file_name == 'series' then
    return
  end

  for _, line in ipairs(getlines(bufnr, 1, 100)) do
    if
      findany(line, {
        '^Description:',
        '^Subject:',
        '^Origin:',
        '^Bug:',
        '^Forwarded:',
        '^Author:',
        '^From:',
        '^Reviewed%-by:',
        '^Acked%-by:',
        '^Last%-Updated:',
        '^Applied%-Upstream:',
      })
    then
      vim.bo[bufnr].filetype = 'dep3patch'
      return
    elseif line:find('^%-%-%-') then
      -- End of headers found. stop processing
      return
    end
  end
end

function M.dtrace(bufnr)
  local did_filetype = vim.fn.did_filetype()
  if did_filetype and did_filetype ~= 0 then
    -- Filetype was already detected
    return
  end
  for _, line in ipairs(getlines(bufnr, 1, 100)) do
    if matchregex(line, [[\c^module\>\|^import\>]]) then
      --  D files often start with a module and/or import statement.
      vim.bo[bufnr].filetype = 'd'
      return
    elseif findany(line, { '^#!%S+dtrace', '#pragma%s+D%s+option', ':%S-:%S-:' }) then
      vim.bo[bufnr].filetype = 'dtrace'
      return
    end
  end
  vim.bo[bufnr].filetype = 'd'
end

function M.e(path, bufnr)
  if vim.g.filetype_euphoria then
    vim.bo[bufnr].filetype = vim.g.filetype_euphoria
    return
  end
  -- TODO: WIP
  -- for _, line in ipairs(getlines(bufnr, 1, 100)) do
  --   if line:find("^$")
  -- end
end

-- This function checks for valid cl syntax in the first five lines.
-- Look for either an opening comment, '#', or a block start, '{'.
-- If not found, assume SGML.
function M.ent(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 5)) do
    if line:find('^%s*[#{]') then
      vim.bo[bufnr].filetype = 'cl'
      return
    elseif not line:find('^%s*$') then
      -- Not a blank line, not a comment, and not a block start,
      -- so doesn't look like valid cl code.
      break
    end
  end
  vim.bo[bufnr].filetype = 'dtd'
end

function M.euphoria(bufnr)
  if vim.g.filetype_euphoria then
    vim.bo[bufnr].filetype = vim.g.filetype_euphoria
  else
    vim.bo[bufnr].filetype = 'euphoria3'
  end
end

function M.ex(bufnr)
  if vim.g.filetype_euphoria then
    vim.bo[bufnr].filetype = vim.g.filetype_euphoria
  else
    for _, line in ipairs(getlines(bufnr, 1, 100)) do
      if matchregex(line, [[\c^--\|^ifdef\>\|^include\>]]) then
        vim.bo[bufnr].filetype = 'euphoria3'
        return
      end
    end
    vim.bo[bufnr].filetype = 'elixir'
  end
end

-- This function checks the first 15 lines for appearance of 'FoamFile'
-- and then 'object' in a following line.
-- In that case, it's probably an OpenFOAM file
function M.foam(bufnr)
  local foam_file = false
  for _, line in ipairs(getlines(bufnr, 1, 15)) do
    if line:find('^FoamFile') then
      foam_file = true
    elseif foam_file and line:find('^%s*object') then
      vim.bo[bufnr].filetype = 'foam'
      return
    end
  end
end

function M.frm(bufnr)
  if vim.g.filetype_frm then
    vim.bo[bufnr].filetype = vim.g.filetype_frm
    return
  end
  local lines = table.concat(getlines(bufnr, 1, 5)):lower()
  if findany(lines, visual_basic_content) then
    vim.bo[bufnr].filetype = 'vb'
  else
    vim.bo[bufnr].filetype = 'form'
  end
end

-- Distinguish between Forth and F#.
function M.fs(bufnr)
  -- TODO: WIP
  -- if vim.g.filetype_fs then
  --   vim.bo[bufnr].filetype = vim.g.filetype_fs
  --   return
  -- end
  -- local line = nextnonblank(bufnr, 1)
  -- if findany(line, { '^%s*.?%( ', '^%s*\\G? ', '^\\$', '^%s*: %S' }) then
  --   vim.bo[bufnr].filetype = 'forth'
  -- else
  --   vim.bo[bufnr].filetype = 'fsharp'
  -- end
end

function M.header(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 200)) do
    if findany(line:lower(), { '^@interface', '^@end', '^@class' }) then
      if vim.g.c_syntax_for_h then
        vim.bo[bufnr].filetype = 'objc'
      else
        vim.bo[bufnr].filetype = 'objcpp'
      end
      return
    end
  end
  if vim.g.c_syntax_for_h then
    vim.bo[bufnr].filetype = 'c'
  elseif vim.g.ch_syntax_for_h then
    vim.bo[bufnr].filetype = 'ch'
  else
    vim.bo[bufnr].filetype = 'cpp'
  end
end

function M.html(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 10)) do
    if matchregex(line, [[\<DTD\s\+XHTML\s]]) then
      vim.bo[bufnr].filetype = 'xhtml'
      return
    elseif matchregex(line, [[\c{%\s*\(extends\|block\|load\)\>\|{#\s\+]]) then
      vim.bo[bufnr].filetype = 'htmldjango'
      return
    end
  end
  vim.bo[bufnr].filetype = 'html'
end

function M.idl(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 50)) do
    if findany(line:lower(), { '^%s*import%s+"unknwn"%.idl', '^%s*import%s+"objidl"%.idl' }) then
      vim.bo[bufnr].filetype = 'msidl'
      return
    end
  end
  vim.bo[bufnr].filetype = 'idl'
end

function M.inc(path, bufnr) end

function M.inp(bufnr)
  if getlines(bufnr, 1):find('^%*') then
    vim.bo[bufnr].filetype = 'abaqus'
  else
    for _, line in ipairs(getlines(bufnr, 1, 500)) do
      if line:lower():find('^header surface data') then
        vim.bo[bufnr].filetype = 'trasys'
        return
      end
    end
  end
end

function M.lpc(bufnr)
  if vim.g.lpc_syntax_for_c then
    for _, line in ipairs(getlines(bufnr, 1, 12)) do
      if
        findany(line, {
          '^//',
          '^inherit',
          '^private',
          '^protected',
          '^nosave',
          '^string',
          '^object',
          '^mapping',
          '^mixed',
        })
      then
        vim.bo[bufnr].filetype = 'lpc'
        return
      end
    end
  end
  vim.bo[bufnr].filetype = 'c'
end

function M.m(bufnr)
  if vim.g.filetype_m then
    vim.bo[bufnr].filetype = vim.g.filetype_m
    return
  end

  -- Excluding end(for|function|if|switch|while) common to Murphi
  local octave_block_terminators =
    [[\<end\%(_try_catch\|classdef\|enumeration\|events\|methods\|parfor\|properties\)\>]]
  local objc_preprocessor = [[\c^\s*#\s*\%(import\|include\|define\|if\|ifn\=def\|undef\|line\|error\|pragma\)\>]]

  -- Whether we've seen a multiline comment leader
  local saw_comment = false
  for _, line in ipairs(getlines(bufnr, 1, 100)) do
    if line:find('^%s*/%*') then
      -- /* ... */ is a comment in Objective C and Murphi, so we can't conclude
      -- it's either of them yet, but track this as a hint in case we don't see
      -- anything more definitive.
      saw_comment = true
    end
    if line:find('^%s*//') or matchregex(line, [[\c^\s*@import\>]]) or matchregex(line, objc_preprocessor) then
      vim.bo[bufnr].filetype = 'objc'
      return
    end
    if
      findany(line, { '^%s*#', '^%s*%%!' })
      or matchregex(line, [[\c^\s*unwind_protect\>]])
      or matchregex(line, [[\c\%(^\|;\)\s*]] .. octave_block_terminators)
    then
      vim.bo[bufnr].filetype = 'octave'
      return
    elseif line:find('^%s*%%') then
      vim.bo[bufnr].filetype = 'matlab'
      return
    elseif line:find('^%s*%(%*') then
      vim.bo[bufnr].filetype = 'mma'
      return
    elseif matchregex(line, [[\c^\s*\(\(type\|var\)\>\|--\)]]) then
      vim.bo[bufnr].filetype = 'murphi'
      return
    end
  end

  if saw_comment then
    -- We didn't see anything definitive, but this looks like either Objective C
    -- or Murphi based on the comment leader. Assume the former as it is more
    -- common.
    vim.bo[bufnr].filetype = 'objc'
  else
    -- Default is Matlab
    vim.bo[bufnr].filetype = 'matlab'
  end
end

-- Rely on the file to start with a comment.
-- MS message text files use ';', Sendmail files use '#' or 'dnl'
function M.mc(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 20)) do
    if findany(line:lower(), { '^%s*#', '^%s*dnl' }) then
      -- Sendmail .mc file
      vim.bo[bufnr].filetype = 'm4'
      return
    elseif line:find('^%s*;') then
      vim.bo[bufnr].filetype = 'msmessages'
      return
    end
  end
  -- Default: Sendmail .mc file
  vim.bo[bufnr].filetype = 'm4'
end

function M.mm(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 20)) do
    if matchregex(line, [[\c^\s*\(#\s*\(include\|import\)\>\|@import\>\|/\*\)]]) then
      vim.bo[bufnr].filetype = 'objcpp'
      return
    end
  end
  vim.bo[bufnr].filetype = 'nroff'
end

function M.mms(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 20)) do
    if findany(line, { '^%s*%%', '^%s*//', '^%*' }) then
      vim.bo[bufnr].filetype = 'mmix'
      return
    elseif line:find('^%s*#') then
      vim.bo[bufnr].filetype = 'make'
      return
    end
  end
  vim.bo[bufnr].filetype = 'mmix'
end

-- Returns true if file content looks like LambdaProlog
local function is_lprolog(bufnr)
  -- Skip apparent comments and blank lines, what looks like
  -- LambdaProlog comment may be RAPID header
  for _, line in ipairs(getlines(bufnr, 1, -1)) do
    -- The second pattern matches a LambdaProlog comment
    if not findany(line, { '^%s*$', '^%s*%%' }) then
      -- The pattern must not catch a go.mod file
      return matchregex(line, [[\c\<module\s\+\w\+\s*\.\s*\(%\|$\)]]) ~= nil
    end
  end
end

-- Determine if *.mod is ABB RAPID, LambdaProlog, Modula-2, Modsim III or go.mod
function M.mod(path, bufnr)
  if vim.g.filetype_mod then
    vim.bo[bufnr].filetype = vim.g.filetype_mod
  elseif is_lprolog(bufnr) then
    vim.bo[bufnr].filetype = 'lprolog'
  elseif matchregex(nextnonblank(bufnr, 1), [[\%(\<MODULE\s\+\w\+\s*;\|^\s*(\*\)]]) then
    vim.bo[bufnr].filetype = 'modula2'
  elseif is_rapid(bufnr) then
    vim.bo[bufnr].filetype = 'rapid'
  elseif matchregex(path, [[\c\<go\.mod$]]) then
    vim.bo[bufnr].filetype = 'gomod'
  else
    -- Nothing recognized, assume modsim3
    vim.bo[bufnr].filetype = 'modsim3'
  end
end

-- This function checks if one of the first five lines start with a dot. In
-- that case it is probably an nroff file: 'filetype' is set and true is returned.
function M.nroff(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 5)) do
    if line:find('^%.') then
      vim.bo[bufnr].filetype = 'nroff'
      return true
    end
  end
  return false
end

-- If the file has an extension of 't' and is in a directory 't' or 'xt' then
-- it is almost certainly a Perl test file.
-- If the first line starts with '#' and contains 'perl' it's probably a Perl file.
-- (Slow test) If a file contains a 'use' statement then it is almost certainly a Perl file.
function M.perl(path, bufnr)
  local dirname = vim.fn.expand(path, '%:p:h:t')
  if vim.fn.expand(dirname, '%:e') == 't' and (dirname == 't' or dirname == 'xt') then
    vim.bo[bufnr].filetype = 'perl'
    return true
  end
  local first_line = getlines(bufnr, 1)
  if first_line:find('^#') and first_line:lower():find('perl') then
    vim.bo[bufnr].filetype = 'perl'
    return true
  end
  for _, line in ipairs(getlines(bufnr, 1, 30)) do
    if matchregex(line, [[\c^use\s\s*\k]]) then
      vim.bo[bufnr].filetype = 'perl'
      return true
    end
  end
  return false
end

function M.pl(path, bufnr) end

local pascal_comments = { '^%s*{', '^%s*%(*', '^%s*//' }
local pascal_keywords = [[\c^\s*\%(program\|unit\|library\|uses\|begin\|procedure\|function\|const\|type\|var\)\>]]

function M.pp(bufnr)
  -- TODO: WIP

  -- if vim.g.filetype_pp then
  --   vim.bo[bufnr].filetype = vim.g.filetype_pp
  --   return
  -- end
  -- local first_line = nextnonblank(bufnr, 1):lower()
  -- if findany(first_line, { pascal_comments, pascal_keywords }) then
  --   vim.bo[bufnr].filetype = "pascal"
  -- else
  --   vim.bo[bufnr].filetype = "puppet"
  -- end
end

function M.prg(bufnr)
  if vim.g.filetype_prg then
    vim.bo[bufnr].filetype = vim.g.filetype_prg
  elseif is_rapid(bufnr) then
    vim.bo[bufnr].filetype = 'rapid'
  else
    -- Nothing recognized, assume Clipper
    vim.bo[bufnr].filetype = 'clipper'
  end
end

-- This function checks for an assembly comment in the first ten lines.
-- If not found, assume Progress.
function M.progress_asm(bufnr)
  if vim.g.filetype_i then
    vim.bo[bufnr].filetype = vim.g.filetype_i
    return
  end

  for _, line in ipairs(getlines(bufnr, 1, 10)) do
    if line:find('^%s*;') or line:find('^/%*') then
      return M.asm(bufnr)
    elseif not line:find('^%s*$') or line:find('^/%*') then
      -- Not an empty line: doesn't look like valid assembly code
      -- or it looks like a Progress /* comment.
      break
    end
  end
  vim.bo[bufnr].filetype = 'progress'
end

function M.progress_cweb(bufnr)
  if vim.g.filetype_w then
    vim.bo[bufnr].filetype = vim.g.filetype_w
  else
    if getlines(bufnr, 1):lower():find('^&analyze') or getlines(bufnr, 3):lower():find('^&global%-define') then
      vim.bo[bufnr].filetype = 'progress'
    else
      vim.bo[bufnr].filetype = 'cweb'
    end
  end
end

-- This function checks for valid Pascal syntax in the first 10 lines.
-- Look for either an opening comment or a program start.
-- If not found, assume Progress.
function M.progress_pascal(bufnr)
  if vim.g.filetype_p then
    vim.bo[bufnr].filetype = vim.g.filetype_p
    return
  end
  for _, line in ipairs(getlines(bufnr, 1, 10)) do
    if findany(line, pascal_comments) or matchregex(line, pascal_keywords) then
      vim.bo[bufnr].filetype = 'pascal'
      return
    elseif not line:find('^%s*$') or line:find('^/%*') then
      -- Not an empty line: Doesn't look like valid Pascal code.
      -- Or it looks like a Progress /* comment
      break
    end
  end
  vim.bo[bufnr].filetype = 'progress'
end

function M.proto(path, bufnr) end

function M.r(bufnr)
  local lines = getlines(bufnr, 1, 50)
  -- Rebol is easy to recognize, check for that first
  if matchregex(table.concat(lines), [[\c\<rebol\>]]) then
    vim.bo[bufnr].filetype = 'rebol'
    return
  end

  for _, line in ipairs(lines) do
    -- R has # comments
    if line:find('^%s*#') then
      vim.bo[bufnr].filetype = 'r'
      return
    end
    -- Rexx has /* comments */
    if line:find('^%s*/%*') then
      vim.bo[bufnr].filetype = 'rexx'
      return
    end
  end

  -- Nothing recognized, use user default or assume R
  if vim.g.filetype_r then
    vim.bo[bufnr].filetype = vim.g.filetype_r
  else
    -- Rexx used to be the default, but R appears to be much more popular.
    vim.bo[bufnr].filetype = 'r'
  end
end

function M.redif(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 5)) do
    if line:lower():find('^template%-type:') then
      vim.bo[bufnr].filetype = 'redif'
    end
  end
end

local udev_rules_pattern = '^%s*udev_rules%s*=%s*"([%^"]+)/*".*'
function M.rules(path, bufnr)
  path = path:lower()
  if
    findany(path, {
      '/etc/udev/.*%.rules$',
      '/etc/udev/rules%.d/.*$.rules$',
      '/usr/lib/udev/.*%.rules$',
      '/usr/lib/udev/rules%.d/.*%.rules$',
      '/lib/udev/.*%.rules$',
      '/lib/udev/rules%.d/.*%.rules$',
    })
  then
    vim.bo[bufnr].filetype = 'udevrules'
  elseif path:find('^/etc/ufw/') then
    -- Better than hog
    vim.bo[bufnr].filetype = 'conf'
  elseif findany(path, { '^/etc/polkit%-1/rules%.d', '/usr/share/polkit%-1/rules%.d' }) then
    vim.bo[bufnr].filetype = 'javascript'
  else
    local ok, config_lines = pcall(vim.fn.readfile, '/etc/udev/udev.conf')
    if not ok then
      vim.bo[bufnr].filetype = 'hog'
      return
    end
    local dir = vim.fn.expand(path, ':h')
    for _, line in ipairs(config_lines) do
      local match = line:match(udev_rules_pattern)
      local udev_rules = line:gsub(udev_rules_pattern, match, 1)
      if dir == udev_rules then
        vim.bo[bufnr].filetype = 'udevrules'
        return
      end
    end
    vim.bo[bufnr].filetype = 'hog'
  end
end

-- This function checks the first 25 lines of file extension "sc" to resolve
-- detection between scala and SuperCollider
function M.sc(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 25)) do
    if
      findany(
        line,
        { '[A-Za-z0-9]*%s:%s[A-Za-z0-9]', 'var%s<', 'classvar%s<', '%^this.*', '|%w*|', '%+%s%w*%s{', '%*ar%s' }
      )
    then
      vim.bo[bufnr].filetype = 'supercollider'
      return
    end
  end
  vim.bo[bufnr].filetype = 'scala'
end

-- This function checks the first line of file extension "scd" to resolve
-- detection between scdoc and SuperCollider
function M.scd(bufnr)
  local first = '^%S+%(%d[0-9A-Za-z]*%)'
  local opt = [[%s+"[^"]*"]]
  local line = getlines(bufnr, 1)
  if findany(line, { first .. '$', first .. opt .. '$', first .. opt .. opt .. '$' }) then
    vim.bo[bufnr].filetype = 'scdoc'
  else
    vim.bo[bufnr].filetype = 'supercollider'
  end
end

function M.sh(path, bufnr) end

function M.shell(path, bufnr) end

function M.sql(bufnr)
  if vim.g.filetype_sql then
    vim.bo[bufnr].filetype = vim.g.filetype_sql
  else
    vim.bo[bufnr].filetype = 'sql'
  end
end

-- Determine if a *.src file is Kuka Robot Language
function M.src(bufnr)
  if vim.g.filetype_src then
    vim.bo[bufnr].filetype = vim.g.filetype_src
    return
  end
  local line = nextnonblank(bufnr, 1)
  if matchregex(line, [[\c\v^\s*%(\&\w+|%(global\s+)?def%(fct)?>)]]) then
    vim.bo[bufnr].filetype = 'krl'
  end
end

function M.sys(bufnr)
  if vim.g.filetype_sys then
    vim.bo[bufnr].filetype = vim.g.filetype_sys
  elseif is_rapid(bufnr) then
    vim.bo[bufnr].filetype = 'rapid'
  else
    vim.bo[bufnr].filetype = 'bat'
  end
end

function M.tex(path, bufnr) end

-- Determine if a *.tf file is TF mud client or terraform
function M.tf(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, -1)) do
    -- Assume terraform file on a non-empty line (not whitespace-only)
    -- and when the first non-whitespace character is not a ; or /
    if not line:find('^%s*$') and not line:find('^%s*[;/]') then
      vim.bo[bufnr].filetype = 'terraform'
      return
    end
  end
  vim.bo[bufnr].filetype = 'tf'
end

function M.xml(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 100)) do
    local is_docbook4 = line:find('<!DOCTYPE.*DocBook')
    line = line:lower()
    local is_docbook5 = line:find([[ xmlns="http://docbook.org/ns/docbook"]])
    if is_docbook4 or is_docbook5 then
      vim.b[bufnr].docbk_type = 'xml'
      vim.b[bufnr].docbk_ver = is_docbook4 and 4 or 5
      vim.bo[bufnr].filetype = 'docbk'
      return
    end
    if line:find([[xmlns:xbl="http://www.mozilla.org/xbl"]]) then
      vim.bo[bufnr].filetype = 'xbl'
      return
    end
  end
  vim.bo[bufnr].filetype = 'xml'
end

function M.y(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 100)) do
    if line:find('^%s*%%') then
      vim.bo[bufnr].filetype = 'yacc'
      return
    end
    if matchregex(line, [[\c^\s*\(#\|class\>\)]]) and not line:lower():find('^%s*#%s*include') then
      vim.bo[bufnr].filetype = 'racc'
      return
    end
  end
  vim.bo[bufnr].filetype = 'yacc'
end

-- luacheck: pop
-- luacheck: pop

return M
