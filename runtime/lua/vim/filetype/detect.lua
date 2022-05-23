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
  if s == nil then
    return false
  end
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

---@private
local did_filetype = function()
  return vim.fn.did_filetype() ~= 0
end

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
  return vim.fn.fnameescape(vim.b[bufnr].asmsyntax)
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
    return vim.g.filetype_bas
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
      return 'freebasic'
    elseif matchregex(line, qb64_preproc) then
      return 'qb64'
    elseif findany(line:lower(), visual_basic_content) then
      return 'vb'
    end
  end
  return 'basic'
end

function M.bindzone(bufnr, default)
  local lines = table.concat(getlines(bufnr, 1, 4))
  if findany(lines, { '^; <<>> DiG [0-9%.]+.* <<>>', '%$ORIGIN', '%$TTL', 'IN%s+SOA' }) then
    return 'bindzone'
  else
    return default
  end
end

function M.btm(bufnr)
  if vim.g.dosbatch_syntax_for_btm and vim.g.dosbatch_syntax_for_btm ~= 0 then
    return 'dosbatch'
  else
    return 'btm'
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
    return vim.g.filetype_cfg
  elseif is_rapid(bufnr, 'cfg') then
    return 'rapid'
  else
    return 'cfg'
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
    return 'ch'
  end
  for _, line in ipairs(getlines(bufnr, 1, 10)) do
    if line:find('^@') then
      return 'change'
    end
    if line:find('MODULE') then
      return 'chill'
    elseif findany(line:lower(), { 'main%s*%(', '#%s*include', '//' }) then
      return 'ch'
    end
  end
  return 'chill'
end

function M.csh(path, bufnr)
  if did_filetype() then
    -- Filetype was already detected
    return
  end
  if vim.g.filetype_csh then
    return M.shell(path, bufnr, vim.g.filetype_csh)
  elseif string.find(vim.o.shell, 'tcsh') then
    return M.shell(path, bufnr, 'tcsh')
  else
    return M.shell(path, bufnr, 'csh')
  end
end

-- Determine if a *.dat file is Kuka Robot Language
function M.dat(bufnr)
  if vim.g.filetype_dat then
    return vim.g.filetype_dat
  end
  local line = nextnonblank(bufnr, 1)
  if matchregex(line, [[\c\v^\s*%(\&\w+|defdat>)]]) then
    return 'krl'
  end
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
      return 'dep3patch'
    elseif line:find('^%-%-%-') then
      -- End of headers found. stop processing
      return
    end
  end
end

function M.dtrace(bufnr)
  if did_filetype() then
    -- Filetype was already detected
    return
  end
  for _, line in ipairs(getlines(bufnr, 1, 100)) do
    if matchregex(line, [[\c^module\>\|^import\>]]) then
      --  D files often start with a module and/or import statement.
      return 'd'
    elseif findany(line, { '^#!%S+dtrace', '#pragma%s+D%s+option', ':%S-:%S-:' }) then
      return 'dtrace'
    end
  end
  return 'd'
end

function M.e(bufnr)
  if vim.g.filetype_euphoria then
    return vim.g.filetype_euphoria
  end
  for _, line in ipairs(getlines(bufnr, 1, 100)) do
    if findany(line, { "^%s*<'%s*$", "^%s*'>%s*$" }) then
      return 'specman'
    end
  end
  return 'eiffel'
end

-- This function checks for valid cl syntax in the first five lines.
-- Look for either an opening comment, '#', or a block start, '{'.
-- If not found, assume SGML.
function M.ent(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 5)) do
    if line:find('^%s*[#{]') then
      return 'cl'
    elseif not line:find('^%s*$') then
      -- Not a blank line, not a comment, and not a block start,
      -- so doesn't look like valid cl code.
      break
    end
  end
  return 'dtd'
end

function M.euphoria(bufnr)
  if vim.g.filetype_euphoria then
    return vim.g.filetype_euphoria
  else
    return 'euphoria3'
  end
end

function M.ex(bufnr)
  if vim.g.filetype_euphoria then
    return vim.g.filetype_euphoria
  else
    for _, line in ipairs(getlines(bufnr, 1, 100)) do
      if matchregex(line, [[\c^--\|^ifdef\>\|^include\>]]) then
        return 'euphoria3'
      end
    end
    return 'elixir'
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
      return 'foam'
    end
  end
end

function M.frm(bufnr)
  if vim.g.filetype_frm then
    return vim.g.filetype_frm
  end
  local lines = table.concat(getlines(bufnr, 1, 5)):lower()
  if findany(lines, visual_basic_content) then
    return 'vb'
  else
    return 'form'
  end
end

-- Distinguish between Forth and F#.
function M.fs(bufnr)
  if vim.g.filetype_fs then
    return vim.g.filetype_fs
  end
  local line = nextnonblank(bufnr, 1)
  if findany(line, { '^%s*%.?%( ', '^%s*\\G? ', '^\\$', '^%s*: %S' }) then
    return 'forth'
  else
    return 'fsharp'
  end
end

function M.header(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 200)) do
    if findany(line:lower(), { '^@interface', '^@end', '^@class' }) then
      if vim.g.c_syntax_for_h then
        return 'objc'
      else
        return 'objcpp'
      end
    end
  end
  if vim.g.c_syntax_for_h then
    return 'c'
  elseif vim.g.ch_syntax_for_h then
    return 'ch'
  else
    return 'cpp'
  end
end

function M.html(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 10)) do
    if matchregex(line, [[\<DTD\s\+XHTML\s]]) then
      return 'xhtml'
    elseif matchregex(line, [[\c{%\s*\(extends\|block\|load\)\>\|{#\s\+]]) then
      return 'htmldjango'
    end
  end
  return 'html'
end

function M.idl(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 50)) do
    if findany(line:lower(), { '^%s*import%s+"unknwn"%.idl', '^%s*import%s+"objidl"%.idl' }) then
      return 'msidl'
    end
  end
  return 'idl'
end

local pascal_comments = { '^%s*{', '^%s*%(%*', '^%s*//' }
local pascal_keywords = [[\c^\s*\%(program\|unit\|library\|uses\|begin\|procedure\|function\|const\|type\|var\)\>]]

function M.inc(bufnr)
  if vim.g.filetype_inc then
    return vim.g.filetype_inc
  end
  local lines = table.concat(getlines(bufnr, 1, 3))
  if lines:lower():find('perlscript') then
    return 'aspperl'
  elseif lines:find('<%%') then
    return 'aspvbs'
  elseif lines:find('<%?') then
    return 'php'
    -- Pascal supports // comments but they're vary rarely used for file
    -- headers so assume POV-Ray
  elseif findany(lines, { '^%s{', '^%s%(%*' }) or matchregex(lines, pascal_keywords) then
    return 'pascal'
  else
    M.asm_syntax(bufnr)
    if vim.b[bufnr].asm_syntax then
      return vim.fn.fnameescape(vim.b[bufnr].asm_syntax)
    else
      return 'pov'
    end
  end
end

function M.inp(bufnr)
  if getlines(bufnr, 1):find('^%*') then
    return 'abaqus'
  else
    for _, line in ipairs(getlines(bufnr, 1, 500)) do
      if line:lower():find('^header surface data') then
        return 'trasys'
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
        return 'lpc'
      end
    end
  end
  return 'c'
end

function M.m(bufnr)
  if vim.g.filetype_m then
    return vim.g.filetype_m
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
      return 'objc'
    end
    if
      findany(line, { '^%s*#', '^%s*%%!' })
      or matchregex(line, [[\c^\s*unwind_protect\>]])
      or matchregex(line, [[\c\%(^\|;\)\s*]] .. octave_block_terminators)
    then
      return 'octave'
    elseif line:find('^%s*%%') then
      return 'matlab'
    elseif line:find('^%s*%(%*') then
      return 'mma'
    elseif matchregex(line, [[\c^\s*\(\(type\|var\)\>\|--\)]]) then
      return 'murphi'
    end
  end

  if saw_comment then
    -- We didn't see anything definitive, but this looks like either Objective C
    -- or Murphi based on the comment leader. Assume the former as it is more
    -- common.
    return 'objc'
  else
    -- Default is Matlab
    return 'matlab'
  end
end

-- Rely on the file to start with a comment.
-- MS message text files use ';', Sendmail files use '#' or 'dnl'
function M.mc(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 20)) do
    if findany(line:lower(), { '^%s*#', '^%s*dnl' }) then
      -- Sendmail .mc file
      return 'm4'
    elseif line:find('^%s*;') then
      return 'msmessages'
    end
  end
  -- Default: Sendmail .mc file
  return 'm4'
end

function M.mm(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 20)) do
    if matchregex(line, [[\c^\s*\(#\s*\(include\|import\)\>\|@import\>\|/\*\)]]) then
      return 'objcpp'
    end
  end
  return 'nroff'
end

function M.mms(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 20)) do
    if findany(line, { '^%s*%%', '^%s*//', '^%*' }) then
      return 'mmix'
    elseif line:find('^%s*#') then
      return 'make'
    end
  end
  return 'mmix'
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
    return vim.g.filetype_mod
  elseif is_lprolog(bufnr) then
    return 'lprolog'
  elseif matchregex(nextnonblank(bufnr, 1), [[\%(\<MODULE\s\+\w\+\s*;\|^\s*(\*\)]]) then
    return 'modula2'
  elseif is_rapid(bufnr) then
    return 'rapid'
  elseif matchregex(path, [[\c\<go\.mod$]]) then
    return 'gomod'
  else
    -- Nothing recognized, assume modsim3
    return 'modsim3'
  end
end

-- This function checks if one of the first five lines start with a dot. In
-- that case it is probably an nroff file: 'filetype' is set and true is returned.
function M.nroff(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 5)) do
    if line:find('^%.') then
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
    return true
  end
  local first_line = getlines(bufnr, 1)
  if first_line:find('^#') and first_line:lower():find('perl') then
    return true
  end
  for _, line in ipairs(getlines(bufnr, 1, 30)) do
    if matchregex(line, [[\c^use\s\s*\k]]) then
      return true
    end
  end
  return false
end

function M.pl(bufnr)
  if vim.g.filetype_pl then
    return vim.g.filetype_pl
  end
  -- Recognize Prolog by specific text in the first non-empty line;
  -- require a blank after the '%' because Perl uses "%list" and "%translate"
  local line = nextnonblank(bufnr, 1)
  if
    line and line:find(':%-')
    or matchregex(line, [[\c\<prolog\>]])
    or findany(line, { '^%s*%%+%s', '^%s*%%+$', '^%s*/%*' })
  then
    return 'prolog'
  else
    return 'perl'
  end
end

function M.pp(bufnr)
  if vim.g.filetype_pp then
    return vim.g.filetype_pp
  end
  local line = nextnonblank(bufnr, 1)
  if findany(line, pascal_comments) or matchregex(line, pascal_keywords) then
    return 'pascal'
  else
    return 'puppet'
  end
end

function M.prg(bufnr)
  if vim.g.filetype_prg then
    return vim.g.filetype_prg
  elseif is_rapid(bufnr) then
    return 'rapid'
  else
    -- Nothing recognized, assume Clipper
    return 'clipper'
  end
end

-- This function checks for an assembly comment in the first ten lines.
-- If not found, assume Progress.
function M.progress_asm(bufnr)
  if vim.g.filetype_i then
    return vim.g.filetype_i
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
  return 'progress'
end

function M.progress_cweb(bufnr)
  if vim.g.filetype_w then
    return vim.g.filetype_w
  else
    if getlines(bufnr, 1):lower():find('^&analyze') or getlines(bufnr, 3):lower():find('^&global%-define') then
      return 'progress'
    else
      return 'cweb'
    end
  end
end

-- This function checks for valid Pascal syntax in the first 10 lines.
-- Look for either an opening comment or a program start.
-- If not found, assume Progress.
function M.progress_pascal(bufnr)
  if vim.g.filetype_p then
    return vim.g.filetype_p
  end
  for _, line in ipairs(getlines(bufnr, 1, 10)) do
    if findany(line, pascal_comments) or matchregex(line, pascal_keywords) then
      return 'pascal'
    elseif not line:find('^%s*$') or line:find('^/%*') then
      -- Not an empty line: Doesn't look like valid Pascal code.
      -- Or it looks like a Progress /* comment
      break
    end
  end
  return 'progress'
end

-- Distinguish between "default" and Cproto prototype file.
function M.proto(bufnr, default)
  -- Cproto files have a comment in the first line and a function prototype in
  -- the second line, it always ends in ";".  Indent files may also have
  -- comments, thus we can't match comments to see the difference.
  -- IDL files can have a single ';' in the second line, require at least one
  -- character before the ';'.
  if getlines(bufnr, 2):find('.;$') then
    return 'cpp'
  else
    return default
  end
end

function M.r(bufnr)
  local lines = getlines(bufnr, 1, 50)
  -- Rebol is easy to recognize, check for that first
  if matchregex(table.concat(lines), [[\c\<rebol\>]]) then
    return 'rebol'
  end

  for _, line in ipairs(lines) do
    -- R has # comments
    if line:find('^%s*#') then
      return 'r'
    end
    -- Rexx has /* comments */
    if line:find('^%s*/%*') then
      return 'rexx'
    end
  end

  -- Nothing recognized, use user default or assume R
  if vim.g.filetype_r then
    return vim.g.filetype_r
  else
    -- Rexx used to be the default, but R appears to be much more popular.
    return 'r'
  end
end

function M.redif(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 5)) do
    if line:lower():find('^template%-type:') then
      return 'redif'
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
    return 'udevrules'
  elseif path:find('^/etc/ufw/') then
    -- Better than hog
    return 'conf'
  elseif findany(path, { '^/etc/polkit%-1/rules%.d', '/usr/share/polkit%-1/rules%.d' }) then
    return 'javascript'
  else
    local ok, config_lines = pcall(vim.fn.readfile, '/etc/udev/udev.conf')
    if not ok then
      return 'hog'
    end
    local dir = vim.fn.expand(path, ':h')
    for _, line in ipairs(config_lines) do
      local match = line:match(udev_rules_pattern)
      local udev_rules = line:gsub(udev_rules_pattern, match, 1)
      if dir == udev_rules then
        return 'udevrules'
      end
    end
    return 'hog'
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
      return 'supercollider'
    end
  end
  return 'scala'
end

-- This function checks the first line of file extension "scd" to resolve
-- detection between scdoc and SuperCollider
function M.scd(bufnr)
  local first = '^%S+%(%d[0-9A-Za-z]*%)'
  local opt = [[%s+"[^"]*"]]
  local line = getlines(bufnr, 1)
  if findany(line, { first .. '$', first .. opt .. '$', first .. opt .. opt .. '$' }) then
    return 'scdoc'
  else
    return 'supercollider'
  end
end

-- Also called from filetype.lua
function M.sh(path, bufnr, name)
  if did_filetype() or path:find(vim.g.ft_ignore_pat) then
    -- Filetype was already detected or detection should be skipped
    return
  end

  if matchregex(name, [[\<csh\>]]) then
    -- Some .sh scripts contain #!/bin/csh.
    return M.shell(path, bufnr, 'csh')
    -- Some .sh scripts contain #!/bin/tcsh.
  elseif matchregex(name, [[\<tcsh\>]]) then
    return M.shell(path, bufnr, 'tcsh')
    -- Some .sh scripts contain #!/bin/zsh.
  elseif matchregex(name, [[\<zsh\>]]) then
    return M.shell(path, bufnr, 'zsh')
  elseif matchregex(name, [[\<ksh\>]]) then
    vim.b[bufnr].is_kornshell = 1
    vim.b[bufnr].is_bash = nil
    vim.b[bufnr].is_sh = nil
  elseif vim.g.bash_is_sh or matchregex(name, [[\<bash\>]]) or matchregex(name, [[\<bash2\>]]) then
    vim.b[bufnr].is_bash = 1
    vim.b[bufnr].is_kornshell = nil
    vim.b[bufnr].is_sh = nil
  elseif matchregex(name, [[\<sh\>]]) then
    vim.b[bufnr].is_sh = 1
    vim.b[bufnr].is_kornshell = nil
    vim.b[bufnr].is_bash = nil
  end
  return M.shell(path, bufnr, 'sh')
end

-- For shell-like file types, check for an "exec" command hidden in a comment, as used for Tcl.
-- Also called from scripts.vim, thus can't be local to this script. [TODO]
function M.shell(path, bufnr, name)
  if did_filetype() or matchregex(path, vim.g.ft_ignore_pat) then
    -- Filetype was already detected or detection should be skipped
    return
  end
  local prev_line = ''
  for _, line in ipairs(getlines(bufnr, 2, -1)) do
    line = line:lower()
    if line:find('%s*exec%s') and not prev_line:find('^%s*#.*\\$') then
      -- Found an "exec" line after a comment with continuation
      local n = line:gsub('%s*exec%s+([^ ]*/)?', '', 1)
      if matchregex(n, [[\c\<tclsh\|\<wish]]) then
        return 'tcl'
      end
    end
    prev_line = line
  end
  return name
end

function M.sql(bufnr)
  if vim.g.filetype_sql then
    return vim.g.filetype_sql
  else
    return 'sql'
  end
end

-- Determine if a *.src file is Kuka Robot Language
function M.src(bufnr)
  if vim.g.filetype_src then
    return vim.g.filetype_src
  end
  local line = nextnonblank(bufnr, 1)
  if matchregex(line, [[\c\v^\s*%(\&\w+|%(global\s+)?def%(fct)?>)]]) then
    return 'krl'
  end
end

function M.sys(bufnr)
  if vim.g.filetype_sys then
    return vim.g.filetype_sys
  elseif is_rapid(bufnr) then
    return 'rapid'
  else
    return 'bat'
  end
end

-- Choose context, plaintex, or tex (LaTeX) based on these rules:
-- 1. Check the first line of the file for "%&<format>".
-- 2. Check the first 1000 non-comment lines for LaTeX or ConTeXt keywords.
-- 3. Default to "plain" or to g:tex_flavor, can be set in user's vimrc.
function M.tex(path, bufnr)
  local format = getlines(bufnr, 1):find('^%%&%s*(%a+)')
  if format then
    format = format:lower():gsub('pdf', '', 1)
    if format == 'tex' then
      return 'tex'
    elseif format == 'plaintex' then
      return 'plaintex'
    end
  elseif path:lower():find('tex/context/.*/.*%.tex') then
    return 'context'
  else
    local lpat = [[documentclass\>\|usepackage\>\|begin{\|newcommand\>\|renewcommand\>]]
    local cpat =
      [[start\a\+\|setup\a\+\|usemodule\|enablemode\|enableregime\|setvariables\|useencoding\|usesymbols\|stelle\a\+\|verwende\a\+\|stel\a\+\|gebruik\a\+\|usa\a\+\|imposta\a\+\|regle\a\+\|utilisemodule\>]]

    for i, l in ipairs(getlines(bufnr, 1, 1000)) do
      -- Find first non-comment line
      if not l:find('^%s*%%%S') then
        -- Check the next thousand lines for a LaTeX or ConTeXt keyword.
        for _, line in ipairs(getlines(bufnr, i + 1, i + 1000)) do
          local lpat_match, cpat_match = matchregex(line, [[\c^\s*\\\%(]] .. lpat .. [[\)\|^\s*\\\(]] .. cpat .. [[\)]])
          if lpat_match then
            return 'tex'
          elseif cpat_match then
            return 'context'
          end
        end
      end
    end
    -- TODO: add AMSTeX, RevTex, others?
    if not vim.g.tex_flavor or vim.g.tex_flavor == 'plain' then
      return 'plaintex'
    elseif vim.g.tex_flavor == 'context' then
      return 'context'
    else
      -- Probably LaTeX
      return 'tex'
    end
  end
end

-- Determine if a *.tf file is TF mud client or terraform
function M.tf(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, -1)) do
    -- Assume terraform file on a non-empty line (not whitespace-only)
    -- and when the first non-whitespace character is not a ; or /
    if not line:find('^%s*$') and not line:find('^%s*[;/]') then
      return 'terraform'
    end
  end
  return 'tf'
end

function M.xml(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 100)) do
    local is_docbook4 = line:find('<!DOCTYPE.*DocBook')
    line = line:lower()
    local is_docbook5 = line:find([[ xmlns="http://docbook.org/ns/docbook"]])
    if is_docbook4 or is_docbook5 then
      vim.b[bufnr].docbk_type = 'xml'
      vim.b[bufnr].docbk_ver = is_docbook4 and 4 or 5
      return 'docbk'
    end
    if line:find([[xmlns:xbl="http://www.mozilla.org/xbl"]]) then
      return 'xbl'
    end
  end
  return 'xml'
end

function M.y(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 100)) do
    if line:find('^%s*%%') then
      return 'yacc'
    end
    if matchregex(line, [[\c^\s*\(#\|class\>\)]]) and not line:lower():find('^%s*#%s*include') then
      return 'racc'
    end
  end
  return 'yacc'
end

-- luacheck: pop
-- luacheck: pop

return M
