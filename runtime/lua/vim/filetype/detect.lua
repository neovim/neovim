-- Contains filetype detection functions for use in filetype.lua that are either:
--  * used more than once or
--  * complex (e.g. check more than one line or use conditionals).
-- Simple one-line checks, such as a check for a string in the first line are better inlined in filetype.lua.

-- A few guidelines to follow when porting a new function:
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

local getlines = vim.filetype.getlines
local findany = vim.filetype.findany
local nextnonblank = vim.filetype.nextnonblank
local matchregex = vim.filetype.matchregex

-- luacheck: push no unused args
-- luacheck: push ignore 122

-- This function checks for the kind of assembly that is wanted by the user, or
-- can be detected from the first five lines of the file.
function M.asm(bufnr)
  local syntax = vim.b[bufnr].asmsyntax
  if not syntax or syntax == '' then
    syntax = M.asm_syntax(bufnr)
  end

  -- If b:asmsyntax still isn't set, default to asmsyntax or GNU
  if not syntax or syntax == '' then
    if vim.g.asmsyntax and vim.g.asmsyntax ~= 0 then
      syntax = vim.g.asmsyntax
    else
      syntax = 'asm'
    end
  end
  return syntax, function(b)
    vim.b[b].asmsyntax = syntax
  end
end

-- Active Server Pages (with Perl or Visual Basic Script)
function M.asp(bufnr)
  if vim.g.filetype_asp then
    return vim.g.filetype_asp
  elseif table.concat(getlines(bufnr, 1, 3)):lower():find('perlscript') then
    return 'aspperl'
  else
    return 'aspvbs'
  end
end

-- Checks the first 5 lines for a asmsyntax=foo override.
-- Only whitespace characters can be present immediately before or after this statement.
function M.asm_syntax(bufnr)
  local lines = table.concat(getlines(bufnr, 1, 5), ' '):lower()
  local match = lines:match('%sasmsyntax=([a-zA-Z0-9]+)%s')
  if match then
    return match
  elseif findany(lines, { '%.title', '%.ident', '%.macro', '%.subtitle', '%.library' }) then
    return 'vmasm'
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
    [[\c^\s*\%(#\s*\a\+\|option\s\+\%(byval\|dynamic\|escape\|\%(no\)\=gosub\|nokeyword\|private\|static\)\>\|\%(''\|rem\)\s*\$lang\>\|def\%(byte\|longint\|short\|ubyte\|uint\|ulongint\|ushort\)\>\)]]

  local fb_comment = "^%s*/'"
  -- OPTION EXPLICIT, without the leading underscore, is common to many dialects
  local qb64_preproc = [[\c^\s*\%($\a\+\|option\s\+\%(_explicit\|_\=explicitarray\)\>\)]]

  for _, line in ipairs(getlines(bufnr, 1, 100)) do
    if findany(line:lower(), visual_basic_content) then
      return 'vb'
    elseif line:find(fb_comment) or matchregex(line, fb_preproc) or matchregex(line, fb_keywords) then
      return 'freebasic'
    elseif matchregex(line, qb64_preproc) then
      return 'qb64'
    end
  end
  return 'basic'
end

function M.bindzone(bufnr, default)
  local lines = table.concat(getlines(bufnr, 1, 4))
  if findany(lines, { '^; <<>> DiG [0-9%.]+.* <<>>', '%$ORIGIN', '%$TTL', 'IN%s+SOA' }) then
    return 'bindzone'
  end
  return default
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

function M.changelog(bufnr)
  local line = getlines(bufnr, 1):lower()
  if line:find('; urgency=') then
    return 'debchangelog'
  end
  return 'changelog'
end

function M.class(bufnr)
  -- Check if not a Java class (starts with '\xca\xfe\xba\xbe')
  if not getlines(bufnr, 1):find('^\202\254\186\190') then
    return 'stata'
  end
end

function M.cls(bufnr)
  if vim.g.filetype_cls then
    return vim.g.filetype_cls
  end
  local line = getlines(bufnr, 1)
  if line:find('^%%') then
    return 'tex'
  elseif line:find('^#') and line:lower():find('rexx') then
    return 'rexx'
  elseif line == 'VERSION 1.0 CLASS' then
    return 'vb'
  else
    return 'st'
  end
end

-- Debian Control
function M.control(bufnr)
  if getlines(bufnr, 1):find('^Source:') then
    return 'debcontrol'
  end
end

-- Debian Copyright
function M.copyright(bufnr)
  if getlines(bufnr, 1):find('^Format:') then
    return 'debcopyright'
  end
end

function M.csh(path, bufnr)
  if vim.fn.did_filetype() ~= 0 then
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

function M.dat(path, bufnr)
  -- Innovation data processing
  if findany(path:lower(), { '^upstream%.dat$', '^upstream%..*%.dat$', '^.*%.upstream%.dat$' }) then
    return 'upstreamdat'
  end
  if vim.g.filetype_dat then
    return vim.g.filetype_dat
  end
  -- Determine if a *.dat file is Kuka Robot Language
  local line = nextnonblank(bufnr, 1)
  if matchregex(line, [[\c\v^\s*%(\&\w+|defdat>)]]) then
    return 'krl'
  end
end

function M.decl(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 3)) do
    if line:lower():find('^<!sgml') then
      return 'sgmldecl'
    end
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
  if vim.fn.did_filetype() ~= 0 then
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

function M.edn(bufnr)
  local line = getlines(bufnr, 1)
  if matchregex(line, [[\c^\s*(\s*edif\>]]) then
    return 'edif'
  else
    return 'clojure'
  end
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

function M.fvwm(path)
  if vim.fn.fnamemodify(path, ':e') == 'm4' then
    return 'fvwm2m4'
  end
  return 'fvwm', function(bufnr)
    vim.b[bufnr].fvwm_version = 2
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

function M.git(bufnr)
  local line = getlines(bufnr, 1)
  if line:find('^' .. string.rep('%x', 40) .. '+ ') or line:sub(1, 5) == 'ref: ' then
    return 'git'
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

-- Virata Config Script File or Drupal module
function M.hw(bufnr)
  if getlines(bufnr, 1):lower():find('<%?php') then
    return 'php'
  end
  return 'virata'
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
    local syntax = M.asm_syntax(bufnr)
    if not syntax or syntax == '' then
      return 'pov'
    end
    return syntax, function(b)
      vim.b[b].asmsyntax = syntax
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

function M.install(path, bufnr)
  if getlines(bufnr, 1):lower():find('<%?php') then
    return 'php'
  end
  return M.sh(path, bufnr, 'bash')
end

-- Innovation Data Processing
-- (refactor of filetype.vim since the patterns are case-insensitive)
function M.log(path)
  path = path:lower()
  if findany(path, { 'upstream%.log', 'upstream%..*%.log', '.*%.upstream%.log', 'upstream%-.*%.log' }) then
    return 'upstreamlog'
  elseif findany(path, { 'upstreaminstall%.log', 'upstreaminstall%..*%.log', '.*%.upstreaminstall%.log' }) then
    return 'upstreaminstalllog'
  elseif findany(path, { 'usserver%.log', 'usserver%..*%.log', '.*%.usserver%.log' }) then
    return 'usserverlog'
  elseif findany(path, { 'usw2kagt%.log', 'usws2kagt%..*%.log', '.*%.usws2kagt%.log' }) then
    return 'usw2kagtlog'
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

function M.m4(path)
  path = path:lower()
  if not path:find('html%.m4$') and not path:find('fvwm2rc') then
    return 'm4'
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

function M.me(path)
  local filename = vim.fn.fnamemodify(path, ':t'):lower()
  if filename ~= 'read.me' and filename ~= 'click.me' then
    return 'nroff'
  end
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

function M.news(bufnr)
  if getlines(bufnr, 1):lower():find('; urgency=') then
    return 'debchangelog'
  end
end

-- This function checks if one of the first five lines start with a dot. In
-- that case it is probably an nroff file.
function M.nroff(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 5)) do
    if line:find('^%.') then
      return 'nroff'
    end
  end
end

function M.patch(bufnr)
  local firstline = getlines(bufnr, 1)
  if string.find(firstline, '^From ' .. string.rep('%x', 40) .. '+ Mon Sep 17 00:00:00 2001$') then
    return 'gitsendemail'
  else
    return 'diff'
  end
end

-- If the file has an extension of 't' and is in a directory 't' or 'xt' then
-- it is almost certainly a Perl test file.
-- If the first line starts with '#' and contains 'perl' it's probably a Perl file.
-- (Slow test) If a file contains a 'use' statement then it is almost certainly a Perl file.
function M.perl(path, bufnr)
  local dirname = vim.fn.expand(path, '%:p:h:t')
  if vim.fn.expand(dirname, '%:e') == 't' and (dirname == 't' or dirname == 'xt') then
    return 'perl'
  end
  local first_line = getlines(bufnr, 1)
  if first_line:find('^#') and first_line:lower():find('perl') then
    return 'perl'
  end
  for _, line in ipairs(getlines(bufnr, 1, 30)) do
    if matchregex(line, [[\c^use\s\s*\k]]) then
      return 'perl'
    end
  end
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

function M.pm(bufnr)
  local line = getlines(bufnr, 1)
  if line:find('XPM2') then
    return 'xpm2'
  elseif line:find('XPM') then
    return 'xpm'
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

function M.printcap(ptcap_type)
  if vim.fn.did_filetype() == 0 then
    return 'ptcap', function(bufnr)
      vim.b[bufnr].ptcap_type = ptcap_type
    end
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

-- Software Distributor Product Specification File (POSIX 1387.2-1995)
function M.psf(bufnr)
  local line = getlines(bufnr, 1):lower()
  if
    findany(
      line,
      { '^%s*distribution%s*$', '^%s*installed_software%s*$', '^%s*root%s*$', '^%s*bundle%s*$', '^%s*product%s*$' }
    )
  then
    return 'psf'
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

function M.reg(bufnr)
  local line = getlines(bufnr, 1):lower()
  if line:find('^regedit[0-9]*%s*$') or line:find('^windows registry editor version %d*%.%d*%s*$') then
    return 'registry'
  end
end

-- Diva (with Skill) or InstallShield
function M.rul(bufnr)
  if table.concat(getlines(bufnr, 1, 6)):lower():find('installshield') then
    return 'ishd'
  end
  return 'diva'
end

local udev_rules_pattern = '^%s*udev_rules%s*=%s*"([%^"]+)/*".*'
function M.rules(path)
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
      if match then
        local udev_rules = line:gsub(udev_rules_pattern, match, 1)
        if dir == udev_rules then
          return 'udevrules'
        end
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

function M.sgml(bufnr)
  local lines = table.concat(getlines(bufnr, 1, 5))
  if lines:find('linuxdoc') then
    return 'smgllnx'
  elseif lines:find('<!DOCTYPE.*DocBook') then
    return 'docbk', function(b)
      vim.b[b].docbk_type = 'sgml'
      vim.b[b].docbk_ver = 4
    end
  else
    return 'sgml'
  end
end

function M.sh(path, bufnr, name)
  if vim.fn.did_filetype() ~= 0 or path:find(vim.g.ft_ignore_pat) then
    -- Filetype was already detected or detection should be skipped
    return
  end

  local on_detect

  name = name or getlines(bufnr, 1)
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
    on_detect = function(b)
      vim.b[b].is_kornshell = 1
      vim.b[b].is_bash = nil
      vim.b[b].is_sh = nil
    end
  elseif vim.g.bash_is_sh or matchregex(name, [[\<bash\>]]) or matchregex(name, [[\<bash2\>]]) then
    on_detect = function(b)
      vim.b[b].is_bash = 1
      vim.b[b].is_kornshell = nil
      vim.b[b].is_sh = nil
    end
  elseif matchregex(name, [[\<sh\>]]) then
    on_detect = function(b)
      vim.b[b].is_sh = 1
      vim.b[b].is_kornshell = nil
      vim.b[b].is_bash = nil
    end
  end
  return M.shell(path, bufnr, 'sh'), on_detect
end

-- For shell-like file types, check for an "exec" command hidden in a comment, as used for Tcl.
-- Also called from scripts.vim, thus can't be local to this script. [TODO]
function M.shell(path, bufnr, name)
  if vim.fn.did_filetype() ~= 0 or matchregex(path, vim.g.ft_ignore_pat) then
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

-- SMIL or SNMP MIB file
function M.smi(bufnr)
  local line = getlines(bufnr, 1)
  if matchregex(line, [[\c\<smil\>]]) then
    return 'smil'
  else
    return 'mib'
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

function M.ttl(bufnr)
  local line = getlines(bufnr, 1):lower()
  if line:find('^@?prefix') or line:find('^@?base') then
    return 'turtle'
  end
  return 'teraterm'
end

function M.txt(bufnr)
  -- helpfiles match *.txt, but should have a modeline as last line
  if not getlines(bufnr, -1):find('vim:.*ft=help') then
    return 'text'
  end
end

-- WEB (*.web is also used for Winbatch: Guess, based on expecting "%" comment
-- lines in a WEB file).
function M.web(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 5)) do
    if line:find('^%%') then
      return 'web'
    end
  end
  return 'winbatch'
end

-- XFree86 config
function M.xfree86()
  return 'xf86conf',
    function(bufnr)
      local line = getlines(bufnr, 1)
      if matchregex(line, [[\<XConfigurator\>]]) then
        vim.b[bufnr].xf86conf_xfree86_version = 3
      end
    end
end

function M.xml(bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 100)) do
    local is_docbook4 = line:find('<!DOCTYPE.*DocBook')
    line = line:lower()
    local is_docbook5 = line:find([[ xmlns="http://docbook.org/ns/docbook"]])
    if is_docbook4 or is_docbook5 then
      return 'docbk',
        function(b)
          vim.b[b].docbk_type = 'xml'
          vim.b[b].docbk_ver = is_docbook4 and 4 or 5
        end
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
