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

local fn = vim.fn

local M = {}

local getlines = vim.filetype._getlines
local getline = vim.filetype._getline
local findany = vim.filetype._findany
local nextnonblank = vim.filetype._nextnonblank
local matchregex = vim.filetype._matchregex

-- luacheck: push no unused args
-- luacheck: push ignore 122

-- This function checks for the kind of assembly that is wanted by the user, or
-- can be detected from the first five lines of the file.
--- @type vim.filetype.mapfn
function M.asm(path, bufnr)
  local syntax = vim.b[bufnr].asmsyntax
  if not syntax or syntax == '' then
    syntax = M.asm_syntax(path, bufnr)
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

--- Active Server Pages (with Perl or Visual Basic Script)
--- @type vim.filetype.mapfn
function M.asp(_, bufnr)
  if vim.g.filetype_asp then
    return vim.g.filetype_asp
  elseif table.concat(getlines(bufnr, 1, 3)):lower():find('perlscript') then
    return 'aspperl'
  end
  return 'aspvbs'
end

-- Checks the first 5 lines for a asmsyntax=foo override.
-- Only whitespace characters can be present immediately before or after this statement.
--- @type vim.filetype.mapfn
function M.asm_syntax(_, bufnr)
  local lines = ' ' .. table.concat(getlines(bufnr, 1, 5), ' '):lower() .. ' '
  local match = lines:match('%sasmsyntax=([a-zA-Z0-9]+)%s')
  if match then
    return match
  elseif findany(lines, { '%.title', '%.ident', '%.macro', '%.subtitle', '%.library' }) then
    return 'vmasm'
  end
end

local visual_basic_content =
  [[\c^\s*\%(Attribute\s\+VB_Name\|Begin\s\+\%(VB\.\|{\%(\x\+-\)\+\x\+}\)\)]]

-- See frm() for Visual Basic form file detection
--- @type vim.filetype.mapfn
function M.bas(_, bufnr)
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
    if matchregex(line, visual_basic_content) then
      return 'vb'
    elseif
      line:find(fb_comment)
      or matchregex(line, fb_preproc)
      or matchregex(line, fb_keywords)
    then
      return 'freebasic'
    elseif matchregex(line, qb64_preproc) then
      return 'qb64'
    end
  end
  return 'basic'
end

--- @type vim.filetype.mapfn
function M.bindzone(_, bufnr)
  local lines = table.concat(getlines(bufnr, 1, 4))
  if findany(lines, { '^; <<>> DiG [0-9%.]+.* <<>>', '%$ORIGIN', '%$TTL', 'IN%s+SOA' }) then
    return 'bindzone'
  end
end

-- Returns true if file content looks like RAPID
--- @param bufnr integer
--- @param extension? string
--- @return string|boolean?
local function is_rapid(bufnr, extension)
  if extension == 'cfg' then
    local line = getline(bufnr, 1):lower()
    return findany(line, { 'eio:cfg', 'mmc:cfg', 'moc:cfg', 'proc:cfg', 'sio:cfg', 'sys:cfg' })
  end
  local line = nextnonblank(bufnr, 1)
  if line then
    -- Called from mod, prg or sys functions
    return matchregex(line:lower(), [[\c\v^\s*%(\%{3}|module\s+\k+\s*%(\(|$))]])
  end
  return false
end

--- @type vim.filetype.mapfn
function M.cfg(_, bufnr)
  if vim.g.filetype_cfg then
    return vim.g.filetype_cfg --[[@as string]]
  elseif is_rapid(bufnr, 'cfg') then
    return 'rapid'
  end
  return 'cfg'
end

--- This function checks if one of the first ten lines start with a '@'.  In
--- that case it is probably a change file.
--- If the first line starts with # or ! it's probably a ch file.
--- If a line has "main", "include", "//" or "/*" it's probably ch.
--- Otherwise CHILL is assumed.
--- @type vim.filetype.mapfn
function M.change(_, bufnr)
  local first_line = getline(bufnr, 1)
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

--- @type vim.filetype.mapfn
function M.changelog(_, bufnr)
  local line = getline(bufnr, 1):lower()
  if line:find('; urgency=') then
    return 'debchangelog'
  end
  return 'changelog'
end

--- @type vim.filetype.mapfn
function M.class(_, bufnr)
  -- Check if not a Java class (starts with '\xca\xfe\xba\xbe')
  if not getline(bufnr, 1):find('^\202\254\186\190') then
    return 'stata'
  end
end

--- @type vim.filetype.mapfn
function M.cls(_, bufnr)
  if vim.g.filetype_cls then
    return vim.g.filetype_cls
  end
  local line1 = getline(bufnr, 1)
  if matchregex(line1, [[^#!.*\<\%(rexx\|regina\)\>]]) then
    return 'rexx'
  elseif line1 == 'VERSION 1.0 CLASS' then
    return 'vb'
  end

  local nonblank1 = nextnonblank(bufnr, 1)
  if nonblank1 and nonblank1:find('^[%%\\]') then
    return 'tex'
  elseif nonblank1 and findany(nonblank1, { '^%s*/%*', '^%s*::%w' }) then
    return 'rexx'
  end
  return 'st'
end

--- @type vim.filetype.mapfn
function M.conf(path, bufnr)
  if fn.did_filetype() ~= 0 or path:find(vim.g.ft_ignore_pat) then
    return
  end
  if path:find('%.conf$') then
    return 'conf'
  end
  for _, line in ipairs(getlines(bufnr, 1, 5)) do
    if line:find('^#') then
      return 'conf'
    end
  end
end

--- Debian Control
--- @type vim.filetype.mapfn
function M.control(_, bufnr)
  if getline(bufnr, 1):find('^Source:') then
    return 'debcontrol'
  end
end

--- Debian Copyright
--- @type vim.filetype.mapfn
function M.copyright(_, bufnr)
  if getline(bufnr, 1):find('^Format:') then
    return 'debcopyright'
  end
end

--- @type vim.filetype.mapfn
function M.cpp(_, _)
  return vim.g.cynlib_syntax_for_cpp and 'cynlib' or 'cpp'
end

--- @type vim.filetype.mapfn
function M.csh(path, bufnr)
  if fn.did_filetype() ~= 0 then
    -- Filetype was already detected
    return
  end
  local contents = getlines(bufnr)
  if vim.g.filetype_csh then
    return M.shell(path, contents, vim.g.filetype_csh)
  elseif string.find(vim.o.shell, 'tcsh') then
    return M.shell(path, contents, 'tcsh')
  else
    return M.shell(path, contents, 'csh')
  end
end

--- @param path string
--- @param contents string[]
--- @return string?
local function cvs_diff(path, contents)
  for _, line in ipairs(contents) do
    if not line:find('^%? ') then
      if matchregex(line, [[^Index:\s\+\f\+$]]) then
        -- CVS diff
        return 'diff'
      elseif
        -- Locale input files: Formal Definitions of Cultural Conventions
        -- Filename must be like en_US, fr_FR@euro or en_US.UTF-8
        findany(path, {
          '%a%a_%a%a$',
          '%a%a_%a%a[%.@]',
          '%a%a_%a%ai18n$',
          '%a%a_%a%aPOSIX$',
          '%a%a_%a%atranslit_',
        })
      then
        -- Only look at the first 100 lines
        for line_nr = 1, 100 do
          if not contents[line_nr] then
            break
          elseif
            findany(contents[line_nr], {
              '^LC_IDENTIFICATION$',
              '^LC_CTYPE$',
              '^LC_COLLATE$',
              '^LC_MONETARY$',
              '^LC_NUMERIC$',
              '^LC_TIME$',
              '^LC_MESSAGES$',
              '^LC_PAPER$',
              '^LC_TELEPHONE$',
              '^LC_MEASUREMENT$',
              '^LC_NAME$',
              '^LC_ADDRESS$',
            })
          then
            return 'fdcc'
          end
        end
      end
    end
  end
end

--- @type vim.filetype.mapfn
function M.dat(path, bufnr)
  local file_name = fn.fnamemodify(path, ':t'):lower()
  -- Innovation data processing
  if findany(file_name, { '^upstream%.dat$', '^upstream%..*%.dat$', '^.*%.upstream%.dat$' }) then
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

--- @type vim.filetype.mapfn
function M.decl(_, bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 3)) do
    if line:lower():find('^<!sgml') then
      return 'sgmldecl'
    end
  end
end

-- This function is called for all files under */debian/patches/*, make sure not
-- to non-dep3patch files, such as README and other text files.
--- @type vim.filetype.mapfn
function M.dep3patch(path, bufnr)
  local file_name = fn.fnamemodify(path, ':t')
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

local function diff(contents)
  if
    contents[1]:find('^%-%-%- ') and contents[2]:find('^%+%+%+ ')
    or contents[1]:find('^%* looking for ') and contents[2]:find('^%* comparing to ')
    or contents[1]:find('^%*%*%* ') and contents[2]:find('^%-%-%- ')
    or contents[1]:find('^=== ') and ((contents[2]:find('^' .. string.rep('=', 66)) and contents[3]:find(
      '^%-%-% '
    ) and contents[4]:find('^%+%+%+')) or (contents[2]:find('^%-%-%- ') and contents[3]:find(
      '^%+%+%+ '
    )))
    or findany(contents[1], { '^=== removed', '^=== added', '^=== renamed', '^=== modified' })
  then
    return 'diff'
  end
end

local function dns_zone(contents)
  if
    findany(
      contents[1] .. contents[2] .. contents[3] .. contents[4],
      { '^; <<>> DiG [0-9%.]+.* <<>>', '%$ORIGIN', '%$TTL', 'IN%s+SOA' }
    )
  then
    return 'bindzone'
  end
  -- BAAN
  if -- Check for 1 to 80 '*' characters
    contents[1]:find('|%*' .. string.rep('%*?', 79)) and contents[2]:find('VRC ')
    or contents[2]:find('|%*' .. string.rep('%*?', 79)) and contents[3]:find('VRC ')
  then
    return 'baan'
  end
end

--- @type vim.filetype.mapfn
function M.dtrace(_, bufnr)
  if fn.did_filetype() ~= 0 then
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

--- @param bufnr integer
--- @return boolean
local function is_modula2(bufnr)
  return matchregex(nextnonblank(bufnr, 1), [[\<MODULE\s\+\w\+\s*\%(\[.*]\s*\)\=;\|^\s*(\*]])
end

--- @param bufnr integer
--- @return string, fun(b: integer)
local function modula2(bufnr)
  local dialect = vim.g.modula2_default_dialect or 'pim'
  local extension = vim.g.modula2_default_extension or ''

  -- ignore unknown dialects or badly formatted tags
  for _, line in ipairs(getlines(bufnr, 1, 200)) do
    local matched_dialect, matched_extension = line:match('%(%*!m2(%w+)%+(%w+)%*%)')
    if not matched_dialect then
      matched_dialect = line:match('%(%*!m2(%w+)%*%)')
    end
    if matched_dialect then
      if vim.tbl_contains({ 'iso', 'pim', 'r10' }, matched_dialect) then
        dialect = matched_dialect
      end
      if vim.tbl_contains({ 'gm2' }, matched_extension) then
        extension = matched_extension
      end
      break
    end
  end

  return 'modula2',
    function(b)
      vim._with({ buf = b }, function()
        fn['modula2#SetDialect'](dialect, extension)
      end)
    end
end

--- @type vim.filetype.mapfn
function M.def(_, bufnr)
  if getline(bufnr, 1):find('%%%%') then
    return 'tex'
  end
  if vim.g.filetype_def == 'modula2' or is_modula2(bufnr) then
    return modula2(bufnr)
  end

  if vim.g.filetype_def then
    return vim.g.filetype_def
  end
  return 'def'
end

--- @type vim.filetype.mapfn
function M.dsp(path, bufnr)
  if vim.g.filetype_dsp then
    return vim.g.filetype_dsp
  end

  -- Test the filename
  local file_name = fn.fnamemodify(path, ':t')
  if file_name:find('^[mM]akefile.*$') then
    return 'make'
  end

  -- Test the file contents
  for _, line in ipairs(getlines(bufnr, 1, 200)) do
    if
      findany(line, {
        -- Check for comment style
        [[#.*]],
        -- Check for common lines
        [[^.*Microsoft Developer Studio Project File.*$]],
        [[^!MESSAGE This is not a valid makefile\..+$]],
        -- Check for keywords
        [[^!(IF,ELSEIF,ENDIF).*$]],
        -- Check for common assignments
        [[^SOURCE=.*$]],
      })
    then
      return 'make'
    end
  end

  -- Otherwise, assume we have a Faust file
  return 'faust'
end

--- @type vim.filetype.mapfn
function M.e(_, bufnr)
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

--- @type vim.filetype.mapfn
function M.edn(_, bufnr)
  local line = getline(bufnr, 1)
  if matchregex(line, [[\c^\s*(\s*edif\>]]) then
    return 'edif'
  else
    return 'clojure'
  end
end

-- This function checks for valid cl syntax in the first five lines.
-- Look for either an opening comment, '#', or a block start, '{'.
-- If not found, assume SGML.
--- @type vim.filetype.mapfn
function M.ent(_, bufnr)
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

--- @type vim.filetype.mapfn
function M.euphoria(_, _)
  return vim.g.filetype_euphoria or 'euphoria3'
end

--- @type vim.filetype.mapfn
function M.ex(_, bufnr)
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

--- @param bufnr integer
--- @return boolean
local function is_forth(bufnr)
  local first_line = nextnonblank(bufnr, 1)

  -- SwiftForth block comment (line is usually filled with '-' or '=') or
  -- OPTIONAL (sometimes precedes the header comment)
  if first_line and findany(first_line:lower(), { '^%{%s', '^%{$', '^optional%s' }) then
    return true
  end

  for _, line in ipairs(getlines(bufnr, 1, 100)) do
    -- Forth comments and colon definitions
    if line:find('^[:(\\] ') then
      return true
    end
  end
  return false
end

-- Distinguish between Forth and Fortran
--- @type vim.filetype.mapfn
function M.f(_, bufnr)
  if vim.g.filetype_f then
    return vim.g.filetype_f
  end
  if is_forth(bufnr) then
    return 'forth'
  end
  return 'fortran'
end

-- This function checks the first 15 lines for appearance of 'FoamFile'
-- and then 'object' in a following line.
-- In that case, it's probably an OpenFOAM file
--- @type vim.filetype.mapfn
function M.foam(_, bufnr)
  local foam_file = false
  for _, line in ipairs(getlines(bufnr, 1, 15)) do
    if line:find('^FoamFile') then
      foam_file = true
    elseif foam_file and line:find('^%s*object') then
      return 'foam'
    end
  end
end

--- @type vim.filetype.mapfn
function M.frm(_, bufnr)
  if vim.g.filetype_frm then
    return vim.g.filetype_frm
  end
  if getline(bufnr, 1) == 'VERSION 5.00' then
    return 'vb'
  end
  for _, line in ipairs(getlines(bufnr, 1, 5)) do
    if matchregex(line, visual_basic_content) then
      return 'vb'
    end
  end
  return 'form'
end

--- @type vim.filetype.mapfn
function M.fvwm_v1(_, _)
  return 'fvwm', function(bufnr)
    vim.b[bufnr].fvwm_version = 1
  end
end

--- @type vim.filetype.mapfn
function M.fvwm_v2(path, _)
  if fn.fnamemodify(path, ':e') == 'm4' then
    return 'fvwm2m4'
  end
  return 'fvwm', function(bufnr)
    vim.b[bufnr].fvwm_version = 2
  end
end

-- Distinguish between Forth and F#
--- @type vim.filetype.mapfn
function M.fs(_, bufnr)
  if vim.g.filetype_fs then
    return vim.g.filetype_fs
  end
  if is_forth(bufnr) then
    return 'forth'
  end
  return 'fsharp'
end

--- @type vim.filetype.mapfn
function M.git(_, bufnr)
  local line = getline(bufnr, 1)
  if matchregex(line, [[^\x\{40,\}\>\|^ref: ]]) then
    return 'git'
  end
end

--- @type vim.filetype.mapfn
function M.header(_, bufnr)
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

--- Recursively search for Hare source files in a directory and any
--- subdirectories, up to a given depth.
--- @param dir string
--- @param depth number
--- @return boolean
local function is_hare_module(dir, depth)
  depth = math.max(depth, 0)
  for name, _ in vim.fs.dir(dir, { depth = depth + 1 }) do
    if name:find('%.ha$') then
      return true
    end
  end
  return false
end

--- @type vim.filetype.mapfn
function M.haredoc(path, _)
  if vim.g.filetype_haredoc then
    if is_hare_module(vim.fs.dirname(path), vim.g.haredoc_search_depth or 1) then
      return 'haredoc'
    end
  end
end

--- @type vim.filetype.mapfn
function M.html(_, bufnr)
  -- Disabled for the reasons mentioned here:
  -- https://github.com/vim/vim/pull/13594#issuecomment-1834465890
  -- local filename = fn.fnamemodify(path, ':t')
  -- if filename:find('%.component%.html$') then
  --   return 'htmlangular'
  -- end

  for _, line in ipairs(getlines(bufnr, 1, 40)) do
    if
      matchregex(
        line,
        [[@\(if\|for\|defer\|switch\)\|\*\(ngIf\|ngFor\|ngSwitch\|ngTemplateOutlet\)\|ng-template\|ng-content\|{{.*}}]]
      )
    then
      return 'htmlangular'
    elseif matchregex(line, [[\<DTD\s\+XHTML\s]]) then
      return 'xhtml'
    elseif
      matchregex(
        line,
        [[\c{%\s*\(autoescape\|block\|comment\|csrf_token\|cycle\|debug\|extends\|filter\|firstof\|for\|if\|ifchanged\|include\|load\|lorem\|now\|query_string\|regroup\|resetcycle\|spaceless\|templatetag\|url\|verbatim\|widthratio\|with\)\>\|{#\s\+]]
      )
    then
      return 'htmldjango'
    elseif findany(line, { '<extend', '<super>' }) then
      return 'superhtml'
    end
  end
  return 'html'
end

-- Virata Config Script File or Drupal module
--- @type vim.filetype.mapfn
function M.hw(_, bufnr)
  if getline(bufnr, 1):lower():find('<%?php') then
    return 'php'
  end
  return 'virata'
end

-- This function checks for an assembly comment or a SWIG keyword or verbatim
-- block in the first 50 lines.
-- If not found, assume Progress.
--- @type vim.filetype.mapfn
function M.i(path, bufnr)
  if vim.g.filetype_i then
    return vim.g.filetype_i
  end

  -- These include the leading '%' sign
  local ft_swig_keywords =
    [[^\s*%\%(addmethods\|apply\|beginfile\|clear\|constant\|define\|echo\|enddef\|endoffile\|extend\|feature\|fragment\|ignore\|import\|importfile\|include\|includefile\|inline\|insert\|keyword\|module\|name\|namewarn\|native\|newobject\|parms\|pragma\|rename\|template\|typedef\|typemap\|types\|varargs\|warn\)]]
  -- This is the start/end of a block that is copied literally to the processor file (C/C++)
  local ft_swig_verbatim_block_start = '^%s*%%{'

  for _, line in ipairs(getlines(bufnr, 1, 50)) do
    if line:find('^%s*;') or line:find('^%*') then
      return M.asm(path, bufnr)
    elseif matchregex(line, ft_swig_keywords) or line:find(ft_swig_verbatim_block_start) then
      return 'swig'
    end
  end
  return 'progress'
end

--- @type vim.filetype.mapfn
function M.idl(_, bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 50)) do
    if findany(line:lower(), { '^%s*import%s+"unknwn"%.idl', '^%s*import%s+"objidl"%.idl' }) then
      return 'msidl'
    end
  end
  return 'idl'
end

local pascal_comments = { '^%s*{', '^%s*%(%*', '^%s*//' }
local pascal_keywords =
  [[\c^\s*\%(program\|unit\|library\|uses\|begin\|procedure\|function\|const\|type\|var\)\>]]

--- @type vim.filetype.mapfn
function M.inc(path, bufnr)
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
  elseif findany(lines, { '^%s*inherit ', '^%s*require ', '^%s*%u[%w_:${}]*%s+%??[?:+]?= ' }) then
    return 'bitbake'
  else
    local syntax = M.asm_syntax(path, bufnr)
    if not syntax or syntax == '' then
      return 'pov'
    end
    return syntax, function(b)
      vim.b[b].asmsyntax = syntax
    end
  end
end

--- @type vim.filetype.mapfn
function M.inp(_, bufnr)
  if getline(bufnr, 1):find('%%%%') then
    return 'tex'
  elseif getline(bufnr, 1):find('^%*') then
    return 'abaqus'
  else
    for _, line in ipairs(getlines(bufnr, 1, 500)) do
      if line:lower():find('^header surface data') then
        return 'trasys'
      end
    end
  end
end

--- @type vim.filetype.mapfn
function M.install(path, bufnr)
  if getline(bufnr, 1):lower():find('<%?php') then
    return 'php'
  end
  return M.bash(path, bufnr)
end

--- Innovation Data Processing
--- (refactor of filetype.vim since the patterns are case-insensitive)
--- @type vim.filetype.mapfn
function M.log(path, _)
  path = path:lower()
  if
    findany(
      path,
      { 'upstream%.log', 'upstream%..*%.log', '.*%.upstream%.log', 'upstream%-.*%.log' }
    )
  then
    return 'upstreamlog'
  elseif
    findany(
      path,
      { 'upstreaminstall%.log', 'upstreaminstall%..*%.log', '.*%.upstreaminstall%.log' }
    )
  then
    return 'upstreaminstalllog'
  elseif findany(path, { 'usserver%.log', 'usserver%..*%.log', '.*%.usserver%.log' }) then
    return 'usserverlog'
  elseif findany(path, { 'usw2kagt%.log', 'usw2kagt%..*%.log', '.*%.usw2kagt%.log' }) then
    return 'usw2kagtlog'
  end
end

--- @type vim.filetype.mapfn
function M.lpc(_, bufnr)
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

--- @type vim.filetype.mapfn
function M.lsl(_, bufnr)
  if vim.g.filetype_lsl then
    return vim.g.filetype_lsl
  end

  local line = nextnonblank(bufnr, 1)
  if findany(line, { '^%s*%%', ':%s*trait%s*$' }) then
    return 'larch'
  else
    return 'lsl'
  end
end

--- @type vim.filetype.mapfn
function M.m(_, bufnr)
  if vim.g.filetype_m then
    return vim.g.filetype_m
  end

  -- Excluding end(for|function|if|switch|while) common to Murphi
  local octave_block_terminators =
    [[\<end\%(_try_catch\|classdef\|enumeration\|events\|methods\|parfor\|properties\)\>]]
  local objc_preprocessor =
    [[\c^\s*#\s*\%(import\|include\|define\|if\|ifn\=def\|undef\|line\|error\|pragma\)\>]]

  -- Whether we've seen a multiline comment leader
  local saw_comment = false
  for _, line in ipairs(getlines(bufnr, 1, 100)) do
    if line:find('^%s*/%*') then
      -- /* ... */ is a comment in Objective C and Murphi, so we can't conclude
      -- it's either of them yet, but track this as a hint in case we don't see
      -- anything more definitive.
      saw_comment = true
    end
    if
      line:find('^%s*//')
      or matchregex(line, [[\c^\s*@import\>]])
      or matchregex(line, objc_preprocessor)
    then
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

--- @param contents string[]
--- @return string?
local function m4(contents)
  for _, line in ipairs(contents) do
    if matchregex(line, [[^\s*dnl\>]]) then
      return 'm4'
    end
  end
  if vim.env.TERM == 'amiga' and findany(contents[1]:lower(), { '^;', '^%.bra' }) then
    -- AmigaDos scripts
    return 'amiga'
  end
end

--- Check if it is a Microsoft Makefile
--- @type vim.filetype.mapfn
function M.make(_, bufnr)
  vim.b.make_microsoft = nil
  for _, line in ipairs(getlines(bufnr, 1, 1000)) do
    if matchregex(line, [[\c^\s*!\s*\(ifn\=\(def\)\=\|include\|message\|error\)\>]]) then
      vim.b.make_microsoft = 1
      break
    elseif
      matchregex(line, [[^ *ifn\=\(eq\|def\)\>]])
      or findany(line, { '^ *[-s]?%s', '^ *%w+%s*[!?:+]=' })
    then
      break
    end
  end
  return 'make'
end

--- @type vim.filetype.mapfn
function M.markdown(_, _)
  return vim.g.filetype_md or 'markdown'
end

--- Rely on the file to start with a comment.
--- MS message text files use ';', Sendmail files use '#' or 'dnl'
--- @type vim.filetype.mapfn
function M.mc(_, bufnr)
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

--- @param path string
--- @return string?
function M.me(path)
  local filename = fn.fnamemodify(path, ':t'):lower()
  if filename ~= 'read.me' and filename ~= 'click.me' then
    return 'nroff'
  end
end

--- @type vim.filetype.mapfn
function M.mm(_, bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 20)) do
    if matchregex(line, [[\c^\s*\(#\s*\(include\|import\)\>\|@import\>\|/\*\)]]) then
      return 'objcpp'
    end
  end
  return 'nroff'
end

--- @type vim.filetype.mapfn
function M.mms(_, bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 20)) do
    if findany(line, { '^%s*%%', '^%s*//', '^%*' }) then
      return 'mmix'
    elseif line:find('^%s*#') then
      return 'make'
    end
  end
  return 'mmix'
end

--- Returns true if file content looks like LambdaProlog
--- @param bufnr integer
--- @return boolean
local function is_lprolog(bufnr)
  -- Skip apparent comments and blank lines, what looks like
  -- LambdaProlog comment may be RAPID header
  for _, line in ipairs(getlines(bufnr)) do
    -- The second pattern matches a LambdaProlog comment
    if not findany(line, { '^%s*$', '^%s*%%' }) then
      -- The pattern must not catch a go.mod file
      return matchregex(line, [[\c\<module\s\+\w\+\s*\.\s*\(%\|$\)]])
    end
  end
  return false
end

--- Determine if *.mod is ABB RAPID, LambdaProlog, Modula-2, Modsim III or go.mod
--- @type vim.filetype.mapfn
function M.mod(path, bufnr)
  if vim.g.filetype_mod == 'modula2' or is_modula2(bufnr) then
    return modula2(bufnr)
  end

  if vim.g.filetype_mod then
    return vim.g.filetype_mod
  elseif matchregex(path, [[\c\<go\.mod$]]) then
    return 'gomod'
  elseif is_lprolog(bufnr) then
    return 'lprolog'
  elseif is_rapid(bufnr) then
    return 'rapid'
  end
  -- Nothing recognized, assume modsim3
  return 'modsim3'
end

--- Determine if *.mod is ABB RAPID, LambdaProlog, Modula-2, Modsim III or go.mod
--- @type vim.filetype.mapfn
function M.mp(_, _)
  return 'mp', function(b)
    vim.b[b].mp_metafun = 1
  end
end

--- @type vim.filetype.mapfn
function M.news(_, bufnr)
  if getline(bufnr, 1):lower():find('; urgency=') then
    return 'debchangelog'
  end
end

--- This function checks if one of the first five lines start with a dot. In
--- that case it is probably an nroff file.
--- @type vim.filetype.mapfn
function M.nroff(_, bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 5)) do
    if line:find('^%.') then
      return 'nroff'
    end
  end
end

--- @type vim.filetype.mapfn
function M.patch(_, bufnr)
  local firstline = getline(bufnr, 1)
  if string.find(firstline, '^From ' .. string.rep('%x', 40) .. '+ Mon Sep 17 00:00:00 2001$') then
    return 'gitsendemail'
  end
  return 'diff'
end

--- If the file has an extension of 't' and is in a directory 't' or 'xt' then
--- it is almost certainly a Perl test file.
--- If the first line starts with '#' and contains 'perl' it's probably a Perl file.
--- (Slow test) If a file contains a 'use' statement then it is almost certainly a Perl file.
--- @type vim.filetype.mapfn
function M.perl(path, bufnr)
  local dir_name = vim.fs.dirname(path)
  if fn.expand(path, '%:e') == 't' and (dir_name == 't' or dir_name == 'xt') then
    return 'perl'
  end
  local first_line = getline(bufnr, 1)
  if first_line:find('^#') and first_line:lower():find('perl') then
    return 'perl'
  end
  for _, line in ipairs(getlines(bufnr, 1, 30)) do
    if matchregex(line, [[\c^use\s\s*\k]]) then
      return 'perl'
    end
  end
end

local prolog_patterns = { '^%s*:%-', '^%s*%%+%s', '^%s*%%+$', '^%s*/%*', '%.%s*$' }

--- @type vim.filetype.mapfn
function M.pl(_, bufnr)
  if vim.g.filetype_pl then
    return vim.g.filetype_pl
  end
  -- Recognize Prolog by specific text in the first non-empty line;
  -- require a blank after the '%' because Perl uses "%list" and "%translate"
  local line = nextnonblank(bufnr, 1)
  if line and matchregex(line, [[\c\<prolog\>]]) or findany(line, prolog_patterns) then
    return 'prolog'
  else
    return 'perl'
  end
end

--- @type vim.filetype.mapfn
function M.pm(_, bufnr)
  local line = getline(bufnr, 1)
  if line:find('XPM2') then
    return 'xpm2'
  elseif line:find('XPM') then
    return 'xpm'
  else
    return 'perl'
  end
end

--- @type vim.filetype.mapfn
function M.pp(_, bufnr)
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

--- @type vim.filetype.mapfn
function M.prg(_, bufnr)
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
  if fn.did_filetype() == 0 then
    return 'ptcap', function(bufnr)
      vim.b[bufnr].ptcap_type = ptcap_type
    end
  end
end

--- @type vim.filetype.mapfn
function M.progress_cweb(_, bufnr)
  if vim.g.filetype_w then
    return vim.g.filetype_w
  else
    if
      getline(bufnr, 1):lower():find('^&analyze')
      or getline(bufnr, 3):lower():find('^&global%-define')
    then
      return 'progress'
    else
      return 'cweb'
    end
  end
end

-- This function checks for valid Pascal syntax in the first 10 lines.
-- Look for either an opening comment or a program start.
-- If not found, assume Progress.
--- @type vim.filetype.mapfn
function M.progress_pascal(_, bufnr)
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

--- Distinguish between "default", Prolog and Cproto prototype file.
--- @type vim.filetype.mapfn
function M.proto(_, bufnr)
  if getline(bufnr, 2):find('/%* Generated automatically %*/') then
    return 'c'
  elseif getline(bufnr, 2):find('.;$') then
    -- Cproto files have a comment in the first line and a function prototype in
    -- the second line, it always ends in ";".  Indent files may also have
    -- comments, thus we can't match comments to see the difference.
    -- IDL files can have a single ';' in the second line, require at least one
    -- character before the ';'.
    return 'cpp'
  end
  -- Recognize Prolog by specific text in the first non-empty line;
  -- require a blank after the '%' because Perl uses "%list" and "%translate"
  local line = nextnonblank(bufnr, 1)
  if line and matchregex(line, [[\c\<prolog\>]]) or findany(line, prolog_patterns) then
    return 'prolog'
  end
end

-- Software Distributor Product Specification File (POSIX 1387.2-1995)
--- @type vim.filetype.mapfn
function M.psf(_, bufnr)
  local line = getline(bufnr, 1):lower()
  if
    findany(line, {
      '^%s*distribution%s*$',
      '^%s*installed_software%s*$',
      '^%s*root%s*$',
      '^%s*bundle%s*$',
      '^%s*product%s*$',
    })
  then
    return 'psf'
  end
end

--- @type vim.filetype.mapfn
function M.r(_, bufnr)
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
  end
  -- Rexx used to be the default, but R appears to be much more popular.
  return 'r'
end

--- @type vim.filetype.mapfn
function M.redif(_, bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 5)) do
    if line:lower():find('^template%-type:') then
      return 'redif'
    end
  end
end

--- @type vim.filetype.mapfn
function M.reg(_, bufnr)
  local line = getline(bufnr, 1):lower()
  if
    line:find('^regedit[0-9]*%s*$') or line:find('^windows registry editor version %d*%.%d*%s*$')
  then
    return 'registry'
  end
end

-- Diva (with Skill) or InstallShield
--- @type vim.filetype.mapfn
function M.rul(_, bufnr)
  if table.concat(getlines(bufnr, 1, 6)):lower():find('installshield') then
    return 'ishd'
  end
  return 'diva'
end

local udev_rules_pattern = '^%s*udev_rules%s*=%s*"([%^"]+)/*".*'
--- @type vim.filetype.mapfn
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
    local ok, config_lines = pcall(fn.readfile, '/etc/udev/udev.conf')
    --- @cast config_lines +string[]
    if not ok then
      return 'hog'
    end
    local dir = fn.expand(path, ':h')
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

-- LambdaProlog and Standard ML signature files
--- @type vim.filetype.mapfn
function M.sig(_, bufnr)
  if vim.g.filetype_sig then
    return vim.g.filetype_sig
  end

  local line = nextnonblank(bufnr, 1)

  -- LambdaProlog comment or keyword
  if findany(line, { '^%s*/%*', '^%s*%%', '^%s*sig%s+%a' }) then
    return 'lprolog'
    -- SML comment or keyword
  elseif findany(line, { '^%s*%(%*', '^%s*signature%s+%a', '^%s*structure%s+%a' }) then
    return 'sml'
  end
end

-- This function checks the first 25 lines of file extension "sc" to resolve
-- detection between scala and SuperCollider
--- @type vim.filetype.mapfn
function M.sc(_, bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 25)) do
    if
      findany(line, {
        'var%s<',
        'classvar%s<',
        '%^this.*',
        '|%w+|',
        '%+%s%w*%s{',
        '%*ar%s',
      })
    then
      return 'supercollider'
    end
  end
  return 'scala'
end

-- This function checks the first line of file extension "scd" to resolve
-- detection between scdoc and SuperCollider
--- @type vim.filetype.mapfn
function M.scd(_, bufnr)
  local first = '^%S+%(%d[0-9A-Za-z]*%)'
  local opt = [[%s+"[^"]*"]]
  local line = getline(bufnr, 1)
  if findany(line, { first .. '$', first .. opt .. '$', first .. opt .. opt .. '$' }) then
    return 'scdoc'
  end
  return 'supercollider'
end

--- @type vim.filetype.mapfn
function M.sgml(_, bufnr)
  local lines = table.concat(getlines(bufnr, 1, 5))
  if lines:find('linuxdoc') then
    return 'sgmllnx'
  elseif lines:find('<!DOCTYPE.*DocBook') then
    return 'docbk',
      function(b)
        vim.b[b].docbk_type = 'sgml'
        vim.b[b].docbk_ver = 4
      end
  else
    return 'sgml'
  end
end

--- @param path string
--- @param contents string[]
--- @param name? string
--- @return string?, fun(b: integer)?
local function sh(path, contents, name)
  -- Path may be nil, do not fail in that case
  if fn.did_filetype() ~= 0 or (path or ''):find(vim.g.ft_ignore_pat) then
    -- Filetype was already detected or detection should be skipped
    return
  end

  -- Get the name from the first line if not specified
  name = name or contents[1]
  if matchregex(name, [[\<csh\>]]) then
    -- Some .sh scripts contain #!/bin/csh.
    return M.shell(path, contents, 'csh')
    -- Some .sh scripts contain #!/bin/tcsh.
  elseif matchregex(name, [[\<tcsh\>]]) then
    return M.shell(path, contents, 'tcsh')
    -- Some .sh scripts contain #!/bin/zsh.
  elseif matchregex(name, [[\<zsh\>]]) then
    return M.shell(path, contents, 'zsh')
  end

  local on_detect --- @type fun(b: integer)?

  if matchregex(name, [[\<ksh\>]]) then
    on_detect = function(b)
      vim.b[b].is_kornshell = 1
      vim.b[b].is_bash = nil
      vim.b[b].is_sh = nil
    end
  elseif vim.g.bash_is_sh or matchregex(name, [[\<\(bash\|bash2\)\>]]) then
    on_detect = function(b)
      vim.b[b].is_bash = 1
      vim.b[b].is_kornshell = nil
      vim.b[b].is_sh = nil
    end
    -- Ubuntu links sh to dash
  elseif matchregex(name, [[\<\(sh\|dash\)\>]]) then
    on_detect = function(b)
      vim.b[b].is_sh = 1
      vim.b[b].is_kornshell = nil
      vim.b[b].is_bash = nil
    end
  end
  return M.shell(path, contents, 'sh'), on_detect
end

--- @param name? string
--- @return vim.filetype.mapfn
local function sh_with(name)
  return function(path, bufnr)
    return sh(path, getlines(bufnr), name)
  end
end

M.sh = sh_with()
M.bash = sh_with('bash')
M.ksh = sh_with('ksh')
M.tcsh = sh_with('tcsh')

--- For shell-like file types, check for an "exec" command hidden in a comment, as used for Tcl.
--- @param path string
--- @param contents string[]
--- @param name? string
--- @return string?
function M.shell(path, contents, name)
  if fn.did_filetype() ~= 0 or matchregex(path, vim.g.ft_ignore_pat) then
    -- Filetype was already detected or detection should be skipped
    return
  end

  local prev_line = ''
  for line_nr, line in ipairs(contents) do
    -- Skip the first line
    if line_nr ~= 1 then
      --- @type string
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
  end
  return name
end

-- Swift Intermediate Language or SILE
--- @type vim.filetype.mapfn
function M.sil(_, bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 100)) do
    if line:find('^%s*[\\%%]') then
      return 'sile'
    elseif line:find('^%s*%S') then
      return 'sil'
    end
  end
  -- No clue, default to "sil"
  return 'sil'
end

-- SMIL or SNMP MIB file
--- @type vim.filetype.mapfn
function M.smi(_, bufnr)
  local line = getline(bufnr, 1)
  if matchregex(line, [[\c\<smil\>]]) then
    return 'smil'
  else
    return 'mib'
  end
end

--- @type vim.filetype.mapfn
function M.sql(_, _)
  return vim.g.filetype_sql and vim.g.filetype_sql or 'sql'
end

-- Determine if a *.src file is Kuka Robot Language
--- @type vim.filetype.mapfn
function M.src(_, bufnr)
  if vim.g.filetype_src then
    return vim.g.filetype_src
  end
  local line = nextnonblank(bufnr, 1)
  if matchregex(line, [[\c\v^\s*%(\&\w+|%(global\s+)?def%(fct)?>)]]) then
    return 'krl'
  end
end

--- @type vim.filetype.mapfn
function M.sys(_, bufnr)
  if vim.g.filetype_sys then
    return vim.g.filetype_sys
  elseif is_rapid(bufnr) then
    return 'rapid'
  end
  return 'bat'
end

-- Choose context, plaintex, or tex (LaTeX) based on these rules:
-- 1. Check the first line of the file for "%&<format>".
-- 2. Check the first 1000 non-comment lines for LaTeX or ConTeXt keywords.
-- 3. Default to "plain" or to g:tex_flavor, can be set in user's vimrc.
--- @type vim.filetype.mapfn
function M.tex(path, bufnr)
  local matched, _, format = getline(bufnr, 1):find('^%%&%s*(%a+)')
  if matched then
    --- @type string
    format = format:lower():gsub('pdf', '', 1)
  elseif path:lower():find('tex/context/.*/.*%.tex') then
    return 'context'
  else
    -- Default value, may be changed later:
    format = vim.g.tex_flavor or 'plaintex'

    local lpat = [[documentclass\>\|usepackage\>\|begin{\|newcommand\>\|renewcommand\>]]
    local cpat =
      [[start\a\+\|setup\a\+\|usemodule\|enablemode\|enableregime\|setvariables\|useencoding\|usesymbols\|stelle\a\+\|verwende\a\+\|stel\a\+\|gebruik\a\+\|usa\a\+\|imposta\a\+\|regle\a\+\|utilisemodule\>]]

    for i, l in ipairs(getlines(bufnr, 1, 1000)) do
      -- Find first non-comment line
      if not l:find('^%s*%%%S') then
        -- Check the next thousand lines for a LaTeX or ConTeXt keyword.
        for _, line in ipairs(getlines(bufnr, i, i + 1000)) do
          if matchregex(line, [[\c^\s*\\\%(]] .. lpat .. [[\)]]) then
            return 'tex'
          elseif matchregex(line, [[\c^\s*\\\%(]] .. cpat .. [[\)]]) then
            return 'context'
          end
        end
      end
    end
  end -- if matched

  -- Translation from formats to file types.  TODO:  add AMSTeX, RevTex, others?
  if format == 'plain' then
    return 'plaintex'
  elseif format == 'plaintex' or format == 'context' then
    return format
  else
    -- Probably LaTeX
    return 'tex'
  end
end

-- Determine if a *.tf file is TF (TinyFugue) mud client or terraform
--- @type vim.filetype.mapfn
function M.tf(_, bufnr)
  for _, line in ipairs(getlines(bufnr)) do
    -- Assume terraform file on a non-empty line (not whitespace-only)
    -- and when the first non-whitespace character is not a ; or /
    if not line:find('^%s*$') and not line:find('^%s*[;/]') then
      return 'terraform'
    end
  end
  return 'tf'
end

--- @type vim.filetype.mapfn
function M.ttl(_, bufnr)
  local line = getline(bufnr, 1):lower()
  if line:find('^@?prefix') or line:find('^@?base') then
    return 'turtle'
  end
  return 'teraterm'
end

--- @type vim.filetype.mapfn
function M.txt(_, bufnr)
  -- helpfiles match *.txt, but should have a modeline as last line
  if not getline(bufnr, -1):find('vim:.*ft=help') then
    return 'text'
  end
end

--- @type vim.filetype.mapfn
function M.typ(_, bufnr)
  if vim.g.filetype_typ then
    return vim.g.filetype_typ
  end

  for _, line in ipairs(getlines(bufnr, 1, 200)) do
    if
      findany(line, {
        '^CASE[%s]?=[%s]?SAME$',
        '^CASE[%s]?=[%s]?LOWER$',
        '^CASE[%s]?=[%s]?UPPER$',
        '^CASE[%s]?=[%s]?OPPOSITE$',
        '^TYPE%s',
      })
    then
      return 'sql'
    end
  end

  return 'typst'
end

--- @type vim.filetype.mapfn
function M.uci(_, bufnr)
  -- Return "uci" iff the file has a config or package statement near the
  -- top of the file and all preceding lines were comments or blank.
  for _, line in ipairs(getlines(bufnr, 1, 3)) do
    -- Match a config or package statement at the start of the line.
    if
      line:find('^%s*[cp]%s+%S')
      or line:find('^%s*config%s+%S')
      or line:find('^%s*package%s+%S')
    then
      return 'uci'
    end
    -- Match a line that is either all blank or blank followed by a comment
    if not (line:find('^%s*$') or line:find('^%s*#')) then
      break
    end
  end
end

-- Determine if a .v file is Verilog, V, or Coq
--- @type vim.filetype.mapfn
function M.v(_, bufnr)
  if fn.did_filetype() ~= 0 then
    -- Filetype was already detected
    return
  end
  if vim.g.filetype_v then
    return vim.g.filetype_v
  end
  local in_comment = 0
  for _, line in ipairs(getlines(bufnr, 1, 200)) do
    if line:find('^%s*/%*') then
      in_comment = 1
    end
    if in_comment == 1 then
      if line:find('%*/') then
        in_comment = 0
      end
    elseif not line:find('^%s*//') then
      if
        line:find('%.%s*$') and not line:find('/[/*]')
        or line:find('%(%*') and not line:find('/[/*].*%(%*')
      then
        return 'coq'
      elseif findany(line, { ';%s*$', ';%s*/[/*]' }) then
        return 'verilog'
      end
    end
  end
  return 'v'
end

--- @type vim.filetype.mapfn
function M.vba(_, bufnr)
  if getline(bufnr, 1):find('^["#] Vimball Archiver') then
    return 'vim'
  end
  return 'vb'
end

-- WEB (*.web is also used for Winbatch: Guess, based on expecting "%" comment
-- lines in a WEB file).
--- @type vim.filetype.mapfn
function M.web(_, bufnr)
  for _, line in ipairs(getlines(bufnr, 1, 5)) do
    if line:find('^%%') then
      return 'web'
    end
  end
  return 'winbatch'
end

-- XFree86 config
--- @type vim.filetype.mapfn
function M.xfree86_v3(_, _)
  return 'xf86conf',
    function(bufnr)
      local line = getline(bufnr, 1)
      if matchregex(line, [[\<XConfigurator\>]]) then
        vim.b[bufnr].xf86conf_xfree86_version = 3
      end
    end
end

-- XFree86 config
--- @type vim.filetype.mapfn
function M.xfree86_v4(_, _)
  return 'xf86conf', function(b)
    vim.b[b].xf86conf_xfree86_version = 4
  end
end

--- @type vim.filetype.mapfn
function M.xml(_, bufnr)
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

--- @type vim.filetype.mapfn
function M.y(_, bufnr)
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

local patterns_hashbang = {
  ['^zsh\\>'] = { 'zsh', { vim_regex = true } },
  ['^\\(tclsh\\|wish\\|expectk\\|itclsh\\|itkwish\\)\\>'] = { 'tcl', { vim_regex = true } },
  ['^expect\\>'] = { 'expect', { vim_regex = true } },
  ['^gnuplot\\>'] = { 'gnuplot', { vim_regex = true } },
  ['make\\>'] = { 'make', { vim_regex = true } },
  ['^pike\\%(\\>\\|[0-9]\\)'] = { 'pike', { vim_regex = true } },
  lua = 'lua',
  perl = 'perl',
  php = 'php',
  python = 'python',
  ['^groovy\\>'] = { 'groovy', { vim_regex = true } },
  raku = 'raku',
  ruby = 'ruby',
  ['node\\(js\\)\\=\\>\\|js\\>'] = { 'javascript', { vim_regex = true } },
  ['rhino\\>'] = { 'javascript', { vim_regex = true } },
  -- BC calculator
  ['^bc\\>'] = { 'bc', { vim_regex = true } },
  ['sed\\>'] = { 'sed', { vim_regex = true } },
  ocaml = 'ocaml',
  -- Awk scripts; also finds "gawk"
  ['awk\\>'] = { 'awk', { vim_regex = true } },
  wml = 'wml',
  scheme = 'scheme',
  cfengine = 'cfengine',
  escript = 'erlang',
  haskell = 'haskell',
  clojure = 'clojure',
  ['scala\\>'] = { 'scala', { vim_regex = true } },
  -- Free Pascal
  ['instantfpc\\>'] = { 'pascal', { vim_regex = true } },
  ['fennel\\>'] = { 'fennel', { vim_regex = true } },
  -- MikroTik RouterOS script
  ['rsc\\>'] = { 'routeros', { vim_regex = true } },
  ['fish\\>'] = { 'fish', { vim_regex = true } },
  ['gforth\\>'] = { 'forth', { vim_regex = true } },
  ['icon\\>'] = { 'icon', { vim_regex = true } },
  guile = 'scheme',
  ['nix%-shell'] = 'nix',
  ['^crystal\\>'] = { 'crystal', { vim_regex = true } },
  ['^\\%(rexx\\|regina\\)\\>'] = { 'rexx', { vim_regex = true } },
  ['^janet\\>'] = { 'janet', { vim_regex = true } },
  ['^dart\\>'] = { 'dart', { vim_regex = true } },
  ['^execlineb\\>'] = { 'execline', { vim_regex = true } },
  ['^vim\\>'] = { 'vim', { vim_regex = true } },
}

---@private
--- File starts with "#!".
--- @param contents string[]
--- @param path string
--- @param dispatch_extension fun(name: string): string?, fun(b: integer)?
--- @return string?
--- @return fun(b: integer)?
local function match_from_hashbang(contents, path, dispatch_extension)
  local first_line = contents[1]
  -- Check for a line like "#!/usr/bin/env {options} bash".  Turn it into
  -- "#!/usr/bin/bash" to make matching easier.
  -- Recognize only a few {options} that are commonly used.
  if matchregex(first_line, [[^#!\s*\S*\<env\s]]) then
    first_line = first_line:gsub('%S+=%S+', '')
    first_line = first_line
      :gsub('%-%-ignore%-environment', '', 1)
      :gsub('%-%-split%-string', '', 1)
      :gsub('%-[iS]', '', 1)
    first_line = fn.substitute(first_line, [[\<env\s\+]], '', '')
  end

  -- Get the program name.
  -- Only accept spaces in PC style paths: "#!c:/program files/perl [args]".
  -- If the word env is used, use the first word after the space:
  -- "#!/usr/bin/env perl [path/args]"
  -- If there is no path use the first word: "#!perl [path/args]".
  -- Otherwise get the last word after a slash: "#!/usr/bin/perl [path/args]".
  local name --- @type string
  if first_line:find('^#!%s*%a:[/\\]') then
    name = fn.substitute(first_line, [[^#!.*[/\\]\(\i\+\).*]], '\\1', '')
  elseif matchregex(first_line, [[^#!.*\<env\>]]) then
    name = fn.substitute(first_line, [[^#!.*\<env\>\s\+\(\i\+\).*]], '\\1', '')
  elseif matchregex(first_line, [[^#!\s*[^/\\ ]*\>\([^/\\]\|$\)]]) then
    name = fn.substitute(first_line, [[^#!\s*\([^/\\ ]*\>\).*]], '\\1', '')
  else
    name = fn.substitute(first_line, [[^#!\s*\S*[/\\]\(\f\+\).*]], '\\1', '')
  end

  -- tcl scripts may have #!/bin/sh in the first line and "exec wish" in the
  -- third line. Suggested by Steven Atkinson.
  if contents[3] and contents[3]:find('^exec wish') then
    name = 'wish'
  end

  if matchregex(name, [[^\(bash\d*\|dash\|ksh\d*\|sh\)\>]]) then
    -- Bourne-like shell scripts: bash bash2 dash ksh ksh93 sh
    return sh(path, contents, first_line)
  elseif matchregex(name, [[^csh\>]]) then
    return M.shell(path, contents, vim.g.filetype_csh or 'csh')
  elseif matchregex(name, [[^tcsh\>]]) then
    return M.shell(path, contents, 'tcsh')
  end

  for k, v in pairs(patterns_hashbang) do
    local ft = type(v) == 'table' and v[1] or v
    local opts = type(v) == 'table' and v[2] or {}
    if opts.vim_regex and matchregex(name, k) or name:find(k) then
      return ft
    end
  end

  -- If nothing matched, check the extension table. For a hashbang like
  -- '#!/bin/env foo', this will set the filetype to 'fooscript' assuming
  -- the filetype for the 'foo' extension is 'fooscript' in the extension table.
  return dispatch_extension(name)
end

local patterns_text = {
  ['^#compdef\\>'] = { 'zsh', { vim_regex = true } },
  ['^#autoload\\>'] = { 'zsh', { vim_regex = true } },
  -- ELM Mail files
  ['^From [a-zA-Z][a-zA-Z_0-9%.=%-]*(@[^ ]*)? .* 19%d%d$'] = 'mail',
  ['^From [a-zA-Z][a-zA-Z_0-9%.=%-]*(@[^ ]*)? .* 20%d%d$'] = 'mail',
  ['^From %- .* 19%d%d$'] = 'mail',
  ['^From %- .* 20%d%d$'] = 'mail',
  -- Mason
  ['^<[%%&].*>'] = 'mason',
  -- Vim scripts (must have '" vim' as the first line to trigger this)
  ['^" *[vV]im$['] = 'vim',
  -- libcxx and libstdc++ standard library headers like ["iostream["] do not have
  -- an extension, recognize the Emacs file mode.
  ['%-%*%-.*[cC]%+%+.*%-%*%-'] = 'cpp',
  ['^\\*\\* LambdaMOO Database, Format Version \\%([1-3]\\>\\)\\@!\\d\\+ \\*\\*$'] = {
    'moo',
    { vim_regex = true },
  },
  -- Diff file:
  -- - "diff" in first line (context diff)
  -- - "Only in " in first line
  -- - "--- " in first line and "+++ " in second line (unified diff).
  -- - "*** " in first line and "--- " in second line (context diff).
  -- - "# It was generated by makepatch " in the second line (makepatch diff).
  -- - "Index: <filename>" in the first line (CVS file)
  -- - "=== ", line of "=", "---", "+++ " (SVK diff)
  -- - "=== ", "--- ", "+++ " (bzr diff, common case)
  -- - "=== (removed|added|renamed|modified)" (bzr diff, alternative)
  -- - "# HG changeset patch" in first line (Mercurial export format)
  ['^\\(diff\\>\\|Only in \\|\\d\\+\\(,\\d\\+\\)\\=[cda]\\d\\+\\>\\|# It was generated by makepatch \\|Index:\\s\\+\\f\\+\\r\\=$\\|===== \\f\\+ \\d\\+\\.\\d\\+ vs edited\\|==== //\\f\\+#\\d\\+\\|# HG changeset patch\\)'] = {
    'diff',
    { vim_regex = true },
  },
  function(contents)
    return diff(contents)
  end,
  -- PostScript Files (must have %!PS as the first line, like a2ps output)
  ['^%%![ \t]*PS'] = 'postscr',
  function(contents)
    return m4(contents)
  end,
  -- SiCAD scripts (must have procn or procd as the first line to trigger this)
  ['^ *proc[nd] *$'] = { 'sicad', { ignore_case = true } },
  ['^%*%*%*%*  Purify'] = 'purifylog',
  -- XML
  ['<%?%s*xml.*%?>'] = 'xml',
  -- XHTML (e.g.: PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN")
  ['\\<DTD\\s\\+XHTML\\s'] = 'xhtml',
  -- HTML (e.g.: <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN")
  -- Avoid "doctype html", used by slim.
  ['\\c<!DOCTYPE\\s\\+html\\>'] = { 'html', { vim_regex = true } },
  -- PDF
  ['^%%PDF%-'] = 'pdf',
  -- XXD output
  ['^%x%x%x%x%x%x%x: %x%x ?%x%x ?%x%x ?%x%x '] = 'xxd',
  -- RCS/CVS log output
  ['^RCS file:'] = { 'rcslog', { start_lnum = 1, end_lnum = 2 } },
  -- CVS commit
  ['^CVS:'] = { 'cvs', { start_lnum = 2 } },
  ['^CVS: '] = { 'cvs', { start_lnum = -1 } },
  -- Prescribe
  ['^!R!'] = 'prescribe',
  -- Send-pr
  ['^SEND%-PR:'] = 'sendpr',
  -- SNNS files
  ['^SNNS network definition file'] = 'snnsnet',
  ['^SNNS pattern definition file'] = 'snnspat',
  ['^SNNS result file'] = 'snnsres',
  ['^%%.-[Vv]irata'] = { 'virata', { start_lnum = 1, end_lnum = 5 } },
  function(lines)
    if
      -- inaccurate fast match first, then use accurate slow match
      (lines[1]:find('execve%(') and lines[1]:find('^[0-9:%. ]*execve%('))
      or lines[1]:find('^__libc_start_main')
    then
      return 'strace'
    end
  end,
  -- VSE JCL
  ['^\\* $$ JOB\\>'] = { 'vsejcl', { vim_regex = true } },
  ['^// *JOB\\>'] = { 'vsejcl', { vim_regex = true } },
  -- TAK and SINDA
  ['K & K  Associates'] = { 'takout', { start_lnum = 4 } },
  ['TAK 2000'] = { 'takout', { start_lnum = 2 } },
  ['S Y S T E M S   I M P R O V E D '] = { 'syndaout', { start_lnum = 3 } },
  ['Run Date: '] = { 'takcmp', { start_lnum = 6 } },
  ['Node    File  1'] = { 'sindacmp', { start_lnum = 9 } },
  dns_zone,
  -- Valgrind
  ['^==%d+== valgrind'] = 'valgrind',
  ['^==%d+== Using valgrind'] = { 'valgrind', { start_lnum = 3 } },
  -- Go docs
  ['PACKAGE DOCUMENTATION$'] = 'godoc',
  -- Renderman Interface Bytestream
  ['^##RenderMan'] = 'rib',
  -- Scheme scripts
  ['exec%s%+%S*scheme'] = { 'scheme', { start_lnum = 1, end_lnum = 2 } },
  -- Git output
  ['^\\(commit\\|tree\\|object\\) \\x\\{40,\\}\\>\\|^tag \\S\\+$'] = {
    'git',
    { vim_regex = true },
  },
  function(lines)
    -- Gprof (gnu profiler)
    if
      lines[1] == 'Flat profile:'
      and lines[2] == ''
      and lines[3]:find('^Each sample counts as .* seconds%.$')
    then
      return 'gprof'
    end
  end,
  -- Erlang terms
  -- (See also: http://www.gnu.org/software/emacs/manual/html_node/emacs/Choosing-Modes.html#Choosing-Modes)
  ['%-%*%-.*erlang.*%-%*%-'] = { 'erlang', { ignore_case = true } },
  -- YAML
  ['^%%YAML'] = 'yaml',
  -- MikroTik RouterOS script
  ['^#.*by RouterOS'] = 'routeros',
  -- Sed scripts
  -- #ncomment is allowed but most likely a false positive so require a space before any trailing comment text
  ['^#n%s'] = 'sed',
  ['^#n$'] = 'sed',
}

---@private
--- File does not start with "#!".
--- @param contents string[]
--- @param path string
--- @return string?
--- @return fun(b: integer)?
local function match_from_text(contents, path)
  if contents[1]:find('^:$') then
    -- Bourne-like shell scripts: sh ksh bash bash2
    return sh(path, contents)
  elseif
    matchregex(
      '\n' .. table.concat(contents, '\n'),
      [[\n\s*emulate\s\+\%(-[LR]\s\+\)\=[ckz]\=sh\>]]
    )
  then
    -- Z shell scripts
    return 'zsh'
  end

  for k, v in pairs(patterns_text) do
    if type(v) == 'string' then
      -- Check the first line only
      if contents[1]:find(k) then
        return v
      end
    elseif type(v) == 'function' then
      -- If filetype detection fails, continue with the next pattern
      local ok, ft = pcall(v, contents)
      if ok and ft then
        return ft
      end
    else
      local opts = type(v) == 'table' and v[2] or {}
      if opts.start_lnum and opts.end_lnum then
        assert(
          not opts.ignore_case,
          'ignore_case=true is ignored when start_lnum is also present, needs refactor'
        )
        for i = opts.start_lnum, opts.end_lnum do
          if not contents[i] then
            break
          elseif contents[i]:find(k) then
            return v[1]
          end
        end
      else
        local line_nr = opts.start_lnum == -1 and #contents or opts.start_lnum or 1
        if contents[line_nr] then
          local line = opts.ignore_case and contents[line_nr]:lower() or contents[line_nr]
          if opts.vim_regex and matchregex(line, k) or line:find(k) then
            return v[1]
          end
        end
      end
    end
  end
  return cvs_diff(path, contents)
end

--- @param contents string[]
--- @param path string
--- @param dispatch_extension fun(name: string): string?, fun(b: integer)?
--- @return string?
--- @return fun(b: integer)?
function M.match_contents(contents, path, dispatch_extension)
  local first_line = contents[1]
  if first_line:find('^#!') then
    return match_from_hashbang(contents, path, dispatch_extension)
  else
    return match_from_text(contents, path)
  end
end

return M
