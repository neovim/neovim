local api, fn = vim.api, vim.fn

local FIND_ARG = '-w'
local localfile_arg = true -- Always use -l if possible. #6683

---@type table[]
local buf_hls = {}

local M = {}

local function man_error(msg)
  M.errormsg = 'man.lua: ' .. vim.inspect(msg)
  error(M.errormsg)
end

-- Run a system command and timeout after 30 seconds.
---@param cmd string[]
---@param silent boolean?
---@param env? table<string,string|number>
---@return string
local function system(cmd, silent, env)
  local r = vim.system(cmd, { env = env, timeout = 10000 }):wait()

  if r.code ~= 0 and not silent then
    local cmd_str = table.concat(cmd, ' ')
    man_error(string.format("command error '%s': %s", cmd_str, r.stderr))
  end

  return assert(r.stdout)
end

---@param line string
---@param linenr integer
local function highlight_line(line, linenr)
  ---@type string[]
  local chars = {}
  local prev_char = ''
  local overstrike, escape, osc8 = false, false, false

  ---@type table<integer,{attr:integer,start:integer,final:integer}>
  local hls = {} -- Store highlight groups as { attr, start, final }

  local NONE, BOLD, UNDERLINE, ITALIC = 0, 1, 2, 3
  local hl_groups = { [BOLD] = 'manBold', [UNDERLINE] = 'manUnderline', [ITALIC] = 'manItalic' }
  local attr = NONE
  local byte = 0 -- byte offset

  local function end_attr_hl(attr_)
    for i, hl in ipairs(hls) do
      if hl.attr == attr_ and hl.final == -1 then
        hl.final = byte
        hls[i] = hl
      end
    end
  end

  local function add_attr_hl(code)
    local continue_hl = true
    if code == 0 then
      attr = NONE
      continue_hl = false
    elseif code == 1 then
      attr = BOLD
    elseif code == 22 then
      attr = BOLD
      continue_hl = false
    elseif code == 3 then
      attr = ITALIC
    elseif code == 23 then
      attr = ITALIC
      continue_hl = false
    elseif code == 4 then
      attr = UNDERLINE
    elseif code == 24 then
      attr = UNDERLINE
      continue_hl = false
    else
      attr = NONE
      return
    end

    if continue_hl then
      hls[#hls + 1] = { attr = attr, start = byte, final = -1 }
    else
      if attr == NONE then
        for a, _ in pairs(hl_groups) do
          end_attr_hl(a)
        end
      else
        end_attr_hl(attr)
      end
    end
  end

  -- Break input into UTF8 code points. ASCII code points (from 0x00 to 0x7f)
  -- can be represented in one byte. Any code point above that is represented by
  -- a leading byte (0xc0 and above) and continuation bytes (0x80 to 0xbf, or
  -- decimal 128 to 191).
  for char in line:gmatch('[^\128-\191][\128-\191]*') do
    if overstrike then
      local last_hl = hls[#hls]
      if char == prev_char then
        if char == '_' and attr == ITALIC and last_hl and last_hl.final == byte then
          -- This underscore is in the middle of an italic word
          attr = ITALIC
        else
          attr = BOLD
        end
      elseif prev_char == '_' then
        -- Even though underline is strictly what this should be. <bs>_ was used by nroff to
        -- indicate italics which wasn't possible on old typewriters so underline was used. Modern
        -- terminals now support italics so lets use that now.
        -- See:
        -- - https://unix.stackexchange.com/questions/274658/purpose-of-ascii-text-with-overstriking-file-format/274795#274795
        -- - https://cmd.inp.nsk.su/old/cmd2/manuals/unix/UNIX_Unleashed/ch08.htm
        -- attr = UNDERLINE
        attr = ITALIC
      elseif prev_char == '+' and char == 'o' then
        -- bullet (overstrike text '+^Ho')
        attr = BOLD
        char = '·'
      elseif prev_char == '·' and char == 'o' then
        -- bullet (additional handling for '+^H+^Ho^Ho')
        attr = BOLD
        char = '·'
      else
        -- use plain char
        attr = NONE
      end

      -- Grow the previous highlight group if possible
      if last_hl and last_hl.attr == attr and last_hl.final == byte then
        last_hl.final = byte + #char
      else
        hls[#hls + 1] = { attr = attr, start = byte, final = byte + #char }
      end

      overstrike = false
      prev_char = ''
      byte = byte + #char
      chars[#chars + 1] = char
    elseif osc8 then
      -- eat characters until String Terminator or bell
      if (prev_char == '\027' and char == '\\') or char == '\a' then
        osc8 = false
      end
      prev_char = char
    elseif escape then
      -- Use prev_char to store the escape sequence
      prev_char = prev_char .. char
      -- We only want to match against SGR sequences, which consist of ESC
      -- followed by '[', then a series of parameter and intermediate bytes in
      -- the range 0x20 - 0x3f, then 'm'. (See ECMA-48, sections 5.4 & 8.3.117)
      ---@type string?
      local sgr = prev_char:match('^%[([\032-\063]*)m$')
      -- Ignore escape sequences with : characters, as specified by ITU's T.416
      -- Open Document Architecture and interchange format.
      if sgr and not string.find(sgr, ':') then
        local match ---@type string?
        while sgr and #sgr > 0 do
          -- Match against SGR parameters, which may be separated by ';'
          match, sgr = sgr:match('^(%d*);?(.*)')
          add_attr_hl(match + 0) -- coerce to number
        end
        escape = false
      elseif prev_char == ']8;' then
        osc8 = true
        escape = false
      elseif not prev_char:match('^[][][\032-\063]*$') then
        -- Stop looking if this isn't a partial CSI or OSC sequence
        escape = false
      end
    elseif char == '\027' then
      escape = true
      prev_char = ''
    elseif char == '\b' then
      overstrike = true
      prev_char = chars[#chars]
      byte = byte - #prev_char
      chars[#chars] = nil
    else
      byte = byte + #char
      chars[#chars + 1] = char
    end
  end

  for _, hl in ipairs(hls) do
    if hl.attr ~= NONE then
      buf_hls[#buf_hls + 1] = {
        0,
        -1,
        hl_groups[hl.attr],
        linenr - 1,
        hl.start,
        hl.final,
      }
    end
  end

  return table.concat(chars, '')
end

local function highlight_man_page()
  local mod = vim.bo.modifiable
  vim.bo.modifiable = true

  local lines = api.nvim_buf_get_lines(0, 0, -1, false)
  for i, line in ipairs(lines) do
    lines[i] = highlight_line(line, i)
  end
  api.nvim_buf_set_lines(0, 0, -1, false, lines)

  for _, args in ipairs(buf_hls) do
    api.nvim_buf_add_highlight(unpack(args))
  end
  buf_hls = {}

  vim.bo.modifiable = mod
end

-- replace spaces in a man page name with underscores
-- intended for PostgreSQL, which has man pages like 'CREATE_TABLE(7)';
-- while editing SQL source code, it's nice to visually select 'CREATE TABLE'
-- and hit 'K', which requires this transformation
---@param str string
---@return string
local function spaces_to_underscores(str)
  local res = str:gsub('%s', '_')
  return res
end

---@param sect string|nil
---@param name string|nil
---@param silent boolean
local function get_path(sect, name, silent)
  name = name or ''
  sect = sect or ''
  -- Some man implementations (OpenBSD) return all available paths from the
  -- search command. Previously, this function would simply select the first one.
  --
  -- However, some searches will report matches that are incorrect:
  -- man -w strlen may return string.3 followed by strlen.3, and therefore
  -- selecting the first would get us the wrong page. Thus, we must find the
  -- first matching one.
  --
  -- There's yet another special case here. Consider the following:
  -- If you run man -w strlen and string.3 comes up first, this is a problem. We
  -- should search for a matching named one in the results list.
  -- However, if you search for man -w clock_gettime, you will *only* get
  -- clock_getres.2, which is the right page. Searching the results for
  -- clock_gettime will no longer work. In this case, we should just use the
  -- first one that was found in the correct section.
  --
  -- Finally, we can avoid relying on -S or -s here since they are very
  -- inconsistently supported. Instead, call -w with a section and a name.
  local cmd ---@type string[]
  if sect == '' then
    cmd = { 'man', FIND_ARG, name }
  else
    cmd = { 'man', FIND_ARG, sect, name }
  end

  local lines = system(cmd, silent)
  local results = vim.split(lines, '\n', { trimempty = true })

  if #results == 0 then
    return
  end

  -- `man -w /some/path` will return `/some/path` for any existent file, which
  -- stops us from actually determining if a path has a corresponding man file.
  -- Since `:Man /some/path/to/man/file` isn't supported anyway, we should just
  -- error out here if we detect this is the case.
  if sect == '' and #results == 1 and results[1] == name then
    return
  end

  -- find any that match the specified name
  ---@param v string
  local namematches = vim.tbl_filter(function(v)
    local tail = fn.fnamemodify(v, ':t')
    return string.find(tail, name, 1, true)
  end, results) or {}
  local sectmatches = {}

  if #namematches > 0 and sect ~= '' then
    ---@param v string
    sectmatches = vim.tbl_filter(function(v)
      return fn.fnamemodify(v, ':e') == sect
    end, namematches)
  end

  return fn.substitute(sectmatches[1] or namematches[1] or results[1], [[\n\+$]], '', '')
end

---@param text string
---@param pat_or_re string
local function matchstr(text, pat_or_re)
  local re = type(pat_or_re) == 'string' and vim.regex(pat_or_re) or pat_or_re

  ---@type integer, integer
  local s, e = re:match_str(text)

  if s == nil then
    return
  end

  return text:sub(vim.str_utfindex(text, s) + 1, vim.str_utfindex(text, e))
end

-- attempt to extract the name and sect out of 'name(sect)'
-- otherwise just return the largest string of valid characters in ref
---@param ref string
---@return string, string
local function extract_sect_and_name_ref(ref)
  ref = ref or ''
  if ref:sub(1, 1) == '-' then -- try ':Man -pandoc' with this disabled.
    man_error("manpage name cannot start with '-'")
  end
  local ref1 = ref:match('[^()]+%([^()]+%)')
  if not ref1 then
    local name = ref:match('[^()]+')
    if not name then
      man_error('manpage reference cannot contain only parentheses: ' .. ref)
    end
    return '', name
  end
  local parts = vim.split(ref1, '(', { plain = true })
  -- see ':Man 3X curses' on why tolower.
  -- TODO(nhooyr) Not sure if this is portable across OSs
  -- but I have not seen a single uppercase section.
  local sect = vim.split(parts[2] or '', ')', { plain = true })[1]:lower()
  local name = parts[1]
  return sect, name
end

-- find_path attempts to find the path to a manpage
-- based on the passed section and name.
--
-- 1. If manpage could not be found with the given sect and name,
--    then try all the sections in b:man_default_sects.
-- 2. If it still could not be found, then we try again without a section.
-- 3. If still not found but $MANSECT is set, then we try again with $MANSECT
--    unset.
-- 4. If a path still wasn't found, return nil.
---@param sect string?
---@param name string
function M.find_path(sect, name)
  if sect and sect ~= '' then
    local ret = get_path(sect, name, true)
    if ret then
      return ret
    end
  end

  if vim.b.man_default_sects ~= nil then
    local sects = vim.split(vim.b.man_default_sects, ',', { plain = true, trimempty = true })
    for _, sec in ipairs(sects) do
      local ret = get_path(sec, name, true)
      if ret then
        return ret
      end
    end
  end

  -- if none of the above worked, we will try with no section
  local res_empty_sect = get_path('', name, true)
  if res_empty_sect then
    return res_empty_sect
  end

  -- if that still didn't work, we will check for $MANSECT and try again with it
  -- unset
  if vim.env.MANSECT then
    local mansect = vim.env.MANSECT
    vim.env.MANSECT = nil
    local res = get_path('', name, true)
    vim.env.MANSECT = mansect
    if res then
      return res
    end
  end

  -- finally, if that didn't work, there is no hope
  return nil
end

local EXT_RE = vim.regex([[\.\%([glx]z\|bz2\|lzma\|Z\)$]])

-- Extracts the name/section from the 'path/name.sect', because sometimes the actual section is
-- more specific than what we provided to `man` (try `:Man 3 App::CLI`).
-- Also on linux, name seems to be case-insensitive. So for `:Man PRIntf`, we
-- still want the name of the buffer to be 'printf'.
---@param path string
---@return string, string
local function extract_sect_and_name_path(path)
  local tail = fn.fnamemodify(path, ':t')
  if EXT_RE:match_str(path) then -- valid extensions
    tail = fn.fnamemodify(tail, ':r')
  end
  local name, sect = tail:match('^(.+)%.([^.]+)$')
  return sect, name
end

---@return boolean
local function find_man()
  if vim.bo.filetype == 'man' then
    return true
  end

  local win = 1
  while win <= fn.winnr('$') do
    local buf = fn.winbufnr(win)
    if vim.bo[buf].filetype == 'man' then
      vim.cmd(win .. 'wincmd w')
      return true
    end
    win = win + 1
  end
  return false
end

local function set_options()
  vim.bo.swapfile = false
  vim.bo.buftype = 'nofile'
  vim.bo.bufhidden = 'unload'
  vim.bo.modified = false
  vim.bo.readonly = true
  vim.bo.modifiable = false
  vim.bo.filetype = 'man'
end

---@param path string
---@param silent boolean?
---@return string
local function get_page(path, silent)
  -- Disable hard-wrap by using a big $MANWIDTH (max 1000 on some systems #9065).
  -- Soft-wrap: ftplugin/man.lua sets wrap/breakindent/….
  -- Hard-wrap: driven by `man`.
  local manwidth ---@type integer|string
  if (vim.g.man_hardwrap or 1) ~= 1 then
    manwidth = 999
  elseif vim.env.MANWIDTH then
    manwidth = vim.env.MANWIDTH
  else
    manwidth = api.nvim_win_get_width(0) - vim.o.wrapmargin
  end

  local cmd = localfile_arg and { 'man', '-l', path } or { 'man', path }

  -- Force MANPAGER=cat to ensure Vim is not recursively invoked (by man-db).
  -- http://comments.gmane.org/gmane.editors.vim.devel/29085
  -- Set MAN_KEEP_FORMATTING so Debian man doesn't discard backspaces.
  return system(cmd, silent, {
    MANPAGER = 'cat',
    MANWIDTH = manwidth,
    MAN_KEEP_FORMATTING = 1,
  })
end

---@param lnum integer
---@return string
local function getline(lnum)
  ---@diagnostic disable-next-line
  return fn.getline(lnum)
end

---@param page string
local function put_page(page)
  vim.bo.modifiable = true
  vim.bo.readonly = false
  vim.bo.swapfile = false

  api.nvim_buf_set_lines(0, 0, -1, false, vim.split(page, '\n'))

  while getline(1):match('^%s*$') do
    api.nvim_buf_set_lines(0, 0, 1, false, {})
  end
  -- XXX: nroff justifies text by filling it with whitespace.  That interacts
  -- badly with our use of $MANWIDTH=999.  Hack around this by using a fixed
  -- size for those whitespace regions.
  -- Use try/catch to avoid setting v:errmsg.
  vim.cmd([[
    try
      keeppatterns keepjumps %s/\s\{199,}/\=repeat(' ', 10)/g
    catch
    endtry
  ]])
  vim.cmd('1') -- Move cursor to first line
  highlight_man_page()
  set_options()
end

local function format_candidate(path, psect)
  if matchstr(path, [[\.\%(pdf\|in\)$]]) then -- invalid extensions
    return ''
  end
  local sect, name = extract_sect_and_name_path(path)
  if sect == psect then
    return name
  elseif sect and name and matchstr(sect, psect .. '.\\+$') then -- invalid extensions
    -- We include the section if the user provided section is a prefix
    -- of the actual section.
    return ('%s(%s)'):format(name, sect)
  end
  return ''
end

---@generic T
---@param list T[]
---@param elem T
---@return T[]
local function move_elem_to_head(list, elem)
  ---@diagnostic disable-next-line:no-unknown
  local list1 = vim.tbl_filter(function(v)
    return v ~= elem
  end, list)
  return { elem, unpack(list1) }
end

---@param sect string
---@param name string
---@return string[]
local function get_paths(sect, name)
  -- Try several sources for getting the list man directories:
  --   1. `man -w` (works on most systems)
  --   2. `manpath`
  --   3. $MANPATH
  local mandirs_raw = vim.F.npcall(system, { 'man', FIND_ARG })
    or vim.F.npcall(system, { 'manpath', '-q' })
    or vim.env.MANPATH

  if not mandirs_raw then
    man_error("Could not determine man directories from: 'man -w', 'manpath' or $MANPATH")
  end

  local mandirs = table.concat(vim.split(mandirs_raw, '[:\n]', { trimempty = true }), ',')
  ---@type string[]
  local paths = fn.globpath(mandirs, 'man[^\\/]*/' .. name .. '*.' .. sect .. '*', false, true)

  -- Prioritize the result from find_path as it obeys b:man_default_sects.
  local first = M.find_path(sect, name)
  if first then
    paths = move_elem_to_head(paths, first)
  end

  return paths
end

---@param sect string
---@param psect string
---@param name string
---@return string[]
local function complete(sect, psect, name)
  local pages = get_paths(sect, name)
  -- We remove duplicates in case the same manpage in different languages was found.
  return fn.uniq(fn.sort(vim.tbl_map(function(v)
    return format_candidate(v, psect)
  end, pages) or {}, 'i'))
end

-- see extract_sect_and_name_ref on why tolower(sect)
---@param arg_lead string
---@param cmd_line string
function M.man_complete(arg_lead, cmd_line, _)
  local args = vim.split(cmd_line, '%s+', { trimempty = true })
  local cmd_offset = fn.index(args, 'Man')
  if cmd_offset > 0 then
    -- Prune all arguments up to :Man itself. Otherwise modifier commands like
    -- :tab, :vertical, etc. would lead to a wrong length.
    args = vim.list_slice(args, cmd_offset + 1)
  end

  if #args > 3 then
    return {}
  end

  if #args == 1 then
    -- returning full completion is laggy. Require some arg_lead to complete
    -- return complete('', '', '')
    return {}
  end

  if arg_lead:match('^[^()]+%([^()]*$') then
    -- cursor (|) is at ':Man printf(|' or ':Man 1 printf(|'
    -- The later is is allowed because of ':Man pri<TAB>'.
    -- It will offer 'priclass.d(1m)' even though section is specified as 1.
    local tmp = vim.split(arg_lead, '(', { plain = true })
    local name = tmp[1]
    local sect = (tmp[2] or ''):lower()
    return complete(sect, '', name)
  end

  if not args[2]:match('^[^()]+$') then
    -- cursor (|) is at ':Man 3() |' or ':Man (3|' or ':Man 3() pri|'
    -- or ':Man 3() pri |'
    return {}
  end

  if #args == 2 then
    ---@type string, string
    local name, sect
    if arg_lead == '' then
      -- cursor (|) is at ':Man 1 |'
      name = ''
      sect = args[1]:lower()
    else
      -- cursor (|) is at ':Man pri|'
      if arg_lead:match('/') then
        -- if the name is a path, complete files
        -- TODO(nhooyr) why does this complete the last one automatically
        return fn.glob(arg_lead .. '*', false, true)
      end
      name = arg_lead
      sect = ''
    end
    return complete(sect, sect, name)
  end

  if not arg_lead:match('[^()]+$') then
    -- cursor (|) is at ':Man 3 printf |' or ':Man 3 (pr)i|'
    return {}
  end

  -- cursor (|) is at ':Man 3 pri|'
  local name = arg_lead
  local sect = args[2]:lower()
  return complete(sect, sect, name)
end

---@param pattern string
---@return {name:string,filename:string,cmd:string}[]
function M.goto_tag(pattern, _, _)
  local sect, name = extract_sect_and_name_ref(pattern)

  local paths = get_paths(sect, name)
  ---@type {name:string,title:string}[]
  local structured = {}

  for _, path in ipairs(paths) do
    sect, name = extract_sect_and_name_path(path)
    if sect and name then
      structured[#structured + 1] = {
        name = name,
        title = name .. '(' .. sect .. ')',
      }
    end
  end

  ---@param entry {name:string,title:string}
  return vim.tbl_map(function(entry)
    return {
      name = entry.name,
      filename = 'man://' .. entry.title,
      cmd = '1',
    }
  end, structured)
end

-- Called when Nvim is invoked as $MANPAGER.
function M.init_pager()
  if getline(1):match('^%s*$') then
    api.nvim_buf_set_lines(0, 0, 1, false, {})
  else
    vim.cmd('keepjumps 1')
  end
  highlight_man_page()
  -- Guess the ref from the heading (which is usually uppercase, so we cannot
  -- know the correct casing, cf. `man glDrawArraysInstanced`).
  local ref = fn.substitute(matchstr(getline(1), [[^[^)]\+)]]) or '', ' ', '_', 'g')
  local ok, res = pcall(extract_sect_and_name_ref, ref)
  vim.b.man_sect = ok and res or ''

  if not fn.bufname('%'):match('man://') then -- Avoid duplicate buffers, E95.
    vim.cmd.file({ 'man://' .. fn.fnameescape(ref):lower(), mods = { silent = true } })
  end

  set_options()
end

---@param count integer
---@param args string[]
function M.open_page(count, smods, args)
  local ref ---@type string
  if #args == 0 then
    ref = vim.bo.filetype == 'man' and fn.expand('<cWORD>') or fn.expand('<cword>')
    if ref == '' then
      man_error('no identifier under cursor')
    end
  elseif #args == 1 then
    ref = args[1]
  else
    -- Combine the name and sect into a manpage reference so that all
    -- verification/extraction can be kept in a single function.
    if args[1]:match('^%d$') or args[1]:match('^%d%a') or args[1]:match('^%a$') then
      -- NB: Valid sections are not only digits, but also:
      --  - <digit><word> (see POSIX mans),
      --  - and even <letter> and <word> (see, for example, by tcl/tk)
      -- NB2: don't optimize to :match("^%d"), as it will match manpages like
      --    441toppm and others whose name starts with digit
      local sect = args[1]
      table.remove(args, 1)
      local name = table.concat(args, ' ')
      ref = ('%s(%s)'):format(name, sect)
    else
      ref = table.concat(args, ' ')
    end
  end

  local sect, name = extract_sect_and_name_ref(ref)
  if count >= 0 then
    sect = tostring(count)
  end

  -- Try both spaces and underscores, use the first that exists.
  local path = M.find_path(sect, name)
  if path == nil then
    path = M.find_path(sect, spaces_to_underscores(name))
    if path == nil then
      man_error('no manual entry for ' .. name)
    end
  end

  sect, name = extract_sect_and_name_path(path)
  local buf = api.nvim_get_current_buf()
  local save_tfu = vim.bo[buf].tagfunc
  vim.bo[buf].tagfunc = "v:lua.require'man'.goto_tag"

  local target = ('%s(%s)'):format(name, sect)

  local ok, ret = pcall(function()
    smods.silent = true
    smods.keepalt = true
    if smods.hide or (smods.tab == -1 and find_man()) then
      vim.cmd.tag({ target, mods = smods })
    else
      vim.cmd.stag({ target, mods = smods })
    end
  end)

  if api.nvim_buf_is_valid(buf) then
    vim.bo[buf].tagfunc = save_tfu
  end

  if not ok then
    error(ret)
  else
    set_options()
  end

  vim.b.man_sect = sect
end

-- Called when a man:// buffer is opened.
function M.read_page(ref)
  local sect, name = extract_sect_and_name_ref(ref)
  local path = M.find_path(sect, name)
  if path == nil then
    man_error('no manual entry for ' .. name)
  end
  sect = extract_sect_and_name_path(path)
  local page = get_page(path)
  vim.b.man_sect = sect
  put_page(page)
end

function M.show_toc()
  local bufnr = api.nvim_get_current_buf()
  local bufname = api.nvim_buf_get_name(bufnr)
  local info = fn.getloclist(0, { winid = 1 })
  if info ~= '' and vim.w[info.winid].qf_toc == bufname then
    vim.cmd.lopen()
    return
  end

  ---@type {bufnr:integer, lnum:integer, text:string}[]
  local toc = {}

  local lnum = 2
  local last_line = fn.line('$') - 1
  local section_title_re = vim.regex([[^\%( \{3\}\)\=\S.*$]])
  local flag_title_re = vim.regex([[^\s\+\%(+\|-\)\S\+]])
  while lnum and lnum < last_line do
    local text = getline(lnum)
    if section_title_re:match_str(text) then
      -- if text is a section title
      toc[#toc + 1] = {
        bufnr = bufnr,
        lnum = lnum,
        text = text,
      }
    elseif flag_title_re:match_str(text) then
      -- if text is a flag title. we strip whitespaces and prepend two
      -- spaces to have a consistent format in the loclist.
      toc[#toc + 1] = {
        bufnr = bufnr,
        lnum = lnum,
        text = '  ' .. fn.substitute(text, [[^\s*\(.\{-}\)\s*$]], [[\1]], ''),
      }
    end
    lnum = fn.nextnonblank(lnum + 1)
  end

  fn.setloclist(0, toc, ' ')
  fn.setloclist(0, {}, 'a', { title = 'Man TOC' })
  vim.cmd.lopen()
  vim.w.qf_toc = bufname
end

local function init()
  local path = get_path('', 'man', true)
  local page ---@type string?
  if path ~= nil then
    -- Check for -l support.
    page = get_page(path, true)
  end

  if page == '' or page == nil then
    localfile_arg = false
  end
end

init()

return M
