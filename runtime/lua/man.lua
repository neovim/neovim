local api, fn = vim.api, vim.fn

local M = {}

--- Run a system command and timeout after 10 seconds.
--- @param cmd string[]
--- @param silent boolean?
--- @param env? table<string,string|number>
--- @return string
local function system(cmd, silent, env)
  if vim.fn.executable(cmd[1]) == 0 then
    error(string.format('executable not found: "%s"', cmd[1]), 0)
  end

  local r = vim.system(cmd, { env = env, timeout = 10000 }):wait()

  if not silent then
    if r.code ~= 0 then
      local cmd_str = table.concat(cmd, ' ')
      error(string.format("command error '%s': %s", cmd_str, r.stderr))
    end
    assert(r.stdout ~= '')
  end

  return assert(r.stdout)
end

--- @enum Man.Attribute
local Attrs = {
  None = 0,
  Bold = 1,
  Underline = 2,
  Italic = 3,
}

--- @param line string
--- @param row integer
--- @param hls {attr:Man.Attribute,row:integer,start:integer,final:integer}[]
--- @return string
local function render_line(line, row, hls)
  --- @type string[]
  local chars = {}
  local prev_char = ''
  local overstrike, escape, osc8 = false, false, false

  local attr = Attrs.None
  local byte = 0 -- byte offset

  local hls_start = #hls + 1

  --- @param code integer
  local function add_attr_hl(code)
    local continue_hl = true
    if code == 0 then
      attr = Attrs.None
      continue_hl = false
    elseif code == 1 then
      attr = Attrs.Bold
    elseif code == 22 then
      attr = Attrs.Bold
      continue_hl = false
    elseif code == 3 then
      attr = Attrs.Italic
    elseif code == 23 then
      attr = Attrs.Italic
      continue_hl = false
    elseif code == 4 then
      attr = Attrs.Underline
    elseif code == 24 then
      attr = Attrs.Underline
      continue_hl = false
    else
      attr = Attrs.None
      return
    end

    if continue_hl then
      hls[#hls + 1] = { attr = attr, row = row, start = byte, final = -1 }
    else
      for _, a in pairs(attr == Attrs.None and Attrs or { attr }) do
        for i = hls_start, #hls do
          if hls[i].attr == a and hls[i].final == -1 then
            hls[i].final = byte
          end
        end
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
        if char == '_' and attr == Attrs.Italic and last_hl and last_hl.final == byte then
          -- This underscore is in the middle of an italic word
          attr = Attrs.Italic
        else
          attr = Attrs.Bold
        end
      elseif prev_char == '_' then
        -- Even though underline is strictly what this should be. <bs>_ was used by nroff to
        -- indicate italics which wasn't possible on old typewriters so underline was used. Modern
        -- terminals now support italics so lets use that now.
        -- See:
        -- - https://unix.stackexchange.com/questions/274658/purpose-of-ascii-text-with-overstriking-file-format/274795#274795
        -- - https://cmd.inp.nsk.su/old/cmd2/manuals/unix/UNIX_Unleashed/ch08.htm
        -- attr = Attrs.Underline
        attr = Attrs.Italic
      elseif prev_char == '+' and char == 'o' then
        -- bullet (overstrike text '+^Ho')
        attr = Attrs.Bold
        char = '·'
      elseif prev_char == '·' and char == 'o' then
        -- bullet (additional handling for '+^H+^Ho^Ho')
        attr = Attrs.Bold
        char = '·'
      else
        -- use plain char
        attr = Attrs.None
      end

      -- Grow the previous highlight group if possible
      if last_hl and last_hl.attr == attr and last_hl.final == byte then
        last_hl.final = byte + #char
      else
        hls[#hls + 1] = { attr = attr, row = row, start = byte, final = byte + #char }
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
      --- @type string?
      local sgr = prev_char:match('^%[([\032-\063]*)m$')
      -- Ignore escape sequences with : characters, as specified by ITU's T.416
      -- Open Document Architecture and interchange format.
      if sgr and not sgr:find(':') then
        local match --- @type string?
        while sgr and #sgr > 0 do
          -- Match against SGR parameters, which may be separated by ';'
          --- @type string?, string?
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

  return table.concat(chars, '')
end

local HlGroups = {
  [Attrs.Bold] = 'manBold',
  [Attrs.Underline] = 'manUnderline',
  [Attrs.Italic] = 'manItalic',
}

local function highlight_man_page()
  local mod = vim.bo.modifiable
  vim.bo.modifiable = true

  local lines = api.nvim_buf_get_lines(0, 0, -1, false)

  --- @type {attr:Man.Attribute,row:integer,start:integer,final:integer}[]
  local hls = {}

  for i, line in ipairs(lines) do
    lines[i] = render_line(line, i - 1, hls)
  end

  api.nvim_buf_set_lines(0, 0, -1, false, lines)

  for _, hl in ipairs(hls) do
    if hl.attr ~= Attrs.None then
      --- @diagnostic disable-next-line: deprecated
      api.nvim_buf_add_highlight(0, -1, HlGroups[hl.attr], hl.row, hl.start, hl.final)
    end
  end

  vim.bo.modifiable = mod
end

--- @param name? string
--- @param sect? string
local function get_path(name, sect)
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
  local cmd --- @type string[]
  if sect == '' then
    cmd = { 'man', '-w', name }
  else
    cmd = { 'man', '-w', sect, name }
  end

  local lines = system(cmd, true)
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
  --- @param v string
  local namematches = vim.tbl_filter(function(v)
    local tail = fn.fnamemodify(v, ':t')
    return tail:find(name, 1, true) ~= nil
  end, results) or {}
  local sectmatches = {}

  if #namematches > 0 and sect ~= '' then
    --- @param v string
    sectmatches = vim.tbl_filter(function(v)
      return fn.fnamemodify(v, ':e') == sect
    end, namematches)
  end

  return (sectmatches[1] or namematches[1] or results[1]):gsub('\n+$', '')
end

--- Attempt to extract the name and sect out of 'name(sect)'
--- otherwise just return the largest string of valid characters in ref
--- @param ref string
--- @return string? name
--- @return string? sect
--- @return string? err
local function parse_ref(ref)
  if ref == '' or ref:sub(1, 1) == '-' then
    return nil, nil, ('invalid manpage reference "%s"'):format(ref)
  end

  -- match "<name>(<sect>)"
  -- note: name can contain spaces
  local name, sect = ref:match('([^()]+)%(([^()]+)%)')
  if name then
    -- see ':Man 3X curses' on why tolower.
    -- TODO(nhooyr) Not sure if this is portable across OSs
    -- but I have not seen a single uppercase section.
    return name, sect:lower()
  end

  name = ref:match('[^()]+')
  if not name then
    return nil, nil, ('invalid manpage reference "%s"'):format(ref)
  end
  return name
end

--- Attempts to find the path to a manpage based on the passed section and name.
---
--- 1. If manpage could not be found with the given sect and name,
---    then try all the sections in b:man_default_sects.
--- 2. If it still could not be found, then we try again without a section.
--- 3. If still not found but $MANSECT is set, then we try again with $MANSECT
---    unset.
--- 4. If a path still wasn't found, return nil.
--- @param name string?
--- @param sect string?
--- @return string? path
function M._find_path(name, sect)
  if sect and sect ~= '' then
    local ret = get_path(name, sect)
    if ret then
      return ret
    end
  end

  if vim.b.man_default_sects ~= nil then
    for sec in vim.gsplit(vim.b.man_default_sects, ',', { trimempty = true }) do
      local ret = get_path(name, sec)
      if ret then
        return ret
      end
    end
  end

  -- if none of the above worked, we will try with no section
  local ret = get_path(name)
  if ret then
    return ret
  end

  -- if that still didn't work, we will check for $MANSECT and try again with it
  -- unset
  if vim.env.MANSECT then
    --- @type string
    local mansect = vim.env.MANSECT
    vim.env.MANSECT = nil
    local res = get_path(name)
    vim.env.MANSECT = mansect
    if res then
      return res
    end
  end

  -- finally, if that didn't work, there is no hope
  return nil
end

--- Extracts the name/section from the 'path/name.sect', because sometimes the
--- actual section is more specific than what we provided to `man`
--- (try `:Man 3 App::CLI`). Also on linux, name seems to be case-insensitive.
--- So for `:Man PRIntf`, we still want the name of the buffer to be 'printf'.
--- @param path string
--- @return string name
--- @return string sect
local function parse_path(path)
  local tail = fn.fnamemodify(path, ':t')
  if
    path:match('%.[glx]z$')
    or path:match('%.bz2$')
    or path:match('%.lzma$')
    or path:match('%.Z$')
  then
    tail = fn.fnamemodify(tail, ':r')
  end
  return tail:match('^(.+)%.([^.]+)$')
end

--- @return boolean
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

--- Always use -l if possible. #6683
--- @type boolean?
local localfile_arg

--- @param path string
--- @param silent boolean?
--- @return string
local function get_page(path, silent)
  -- Disable hard-wrap by using a big $MANWIDTH (max 1000 on some systems #9065).
  -- Soft-wrap: ftplugin/man.lua sets wrap/breakindent/….
  -- Hard-wrap: driven by `man`.
  local manwidth --- @type integer|string
  if (vim.g.man_hardwrap or 1) ~= 1 then
    manwidth = 999
  elseif vim.env.MANWIDTH then
    manwidth = vim.env.MANWIDTH --- @type string|integer
  else
    manwidth = api.nvim_win_get_width(0) - vim.o.wrapmargin
  end

  if localfile_arg == nil then
    local mpath = get_path('man')
    -- Check for -l support.
    localfile_arg = (mpath and system({ 'man', '-l', mpath }, true) or '') ~= ''
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

--- @param path string
--- @param psect string
local function format_candidate(path, psect)
  if vim.endswith(path, '.pdf') or vim.endswith(path, '.in') then
    -- invalid extensions
    return ''
  end
  local name, sect = parse_path(path)
  if sect == psect then
    return name
  elseif sect:match(psect .. '.+$') then -- invalid extensions
    -- We include the section if the user provided section is a prefix
    -- of the actual section.
    return ('%s(%s)'):format(name, sect)
  end
  return ''
end

--- @param name string
--- @param sect? string
--- @return string[] paths
--- @return string? err
local function get_paths(name, sect)
  -- Try several sources for getting the list man directories:
  --   1. `manpath -q`
  --   2. `man -w` (works on most systems)
  --   3. $MANPATH
  --
  -- Note we prefer `manpath -q` because `man -w`:
  -- - does not work on MacOS 14 and later.
  -- - only returns '/usr/bin/man' on MacOS 13 and earlier.
  --- @type string?
  local mandirs_raw = vim.F.npcall(system, { 'manpath', '-q' })
    or vim.F.npcall(system, { 'man', '-w' })
    or vim.env.MANPATH

  if not mandirs_raw then
    return {}, "Could not determine man directories from: 'man -w', 'manpath' or $MANPATH"
  end

  local mandirs = table.concat(vim.split(mandirs_raw, '[:\n]', { trimempty = true }), ',')

  sect = sect or ''

  --- @type string[]
  local paths = fn.globpath(mandirs, 'man[^\\/]*/' .. name .. '*.' .. sect .. '*', false, true)

  -- Prioritize the result from find_path as it obeys b:man_default_sects.
  local first = M._find_path(name, sect)
  if first then
    --- @param v string
    paths = vim.tbl_filter(function(v)
      return v ~= first
    end, paths)
    table.insert(paths, 1, first)
  end

  return paths
end

--- @param arg_lead string
--- @param cmd_line string
--- @return string? sect
--- @return string? psect
--- @return string? name
local function parse_cmdline(arg_lead, cmd_line)
  local args = vim.split(cmd_line, '%s+', { trimempty = true })
  local cmd_offset = fn.index(args, 'Man')
  if cmd_offset > 0 then
    -- Prune all arguments up to :Man itself. Otherwise modifier commands like
    -- :tab, :vertical, etc. would lead to a wrong length.
    args = vim.list_slice(args, cmd_offset + 1)
  end

  if #args > 3 then
    return
  end

  if #args == 1 then
    -- returning full completion is laggy. Require some arg_lead to complete
    -- return '', '', ''
    return
  end

  if arg_lead:match('^[^()]+%([^()]*$') then
    -- cursor (|) is at ':Man printf(|' or ':Man 1 printf(|'
    -- The later is is allowed because of ':Man pri<TAB>'.
    -- It will offer 'priclass.d(1m)' even though section is specified as 1.
    local tmp = vim.split(arg_lead, '(', { plain = true })
    local name = tmp[1]
    -- See extract_sect_and_name_ref on why :lower()
    local sect = (tmp[2] or ''):lower()
    return sect, '', name
  end

  if not args[2]:match('^[^()]+$') then
    -- cursor (|) is at ':Man 3() |' or ':Man (3|' or ':Man 3() pri|'
    -- or ':Man 3() pri |'
    return
  end

  if #args == 2 then
    --- @type string, string
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
    return sect, sect, name
  end

  if not arg_lead:match('[^()]+$') then
    -- cursor (|) is at ':Man 3 printf |' or ':Man 3 (pr)i|'
    return
  end

  -- cursor (|) is at ':Man 3 pri|'
  local name, sect = arg_lead, args[2]:lower()
  return sect, sect, name
end

--- @param arg_lead string
--- @param cmd_line string
function M.man_complete(arg_lead, cmd_line)
  local sect, psect, name = parse_cmdline(arg_lead, cmd_line)
  if not (sect and psect and name) then
    return {}
  end

  local ok, pages = pcall(get_paths, name, sect)
  if not ok then
    return nil
  end

  -- We check for duplicates in case the same manpage in different languages
  -- was found.
  local pages_fmt = {} --- @type string[]
  local pages_fmt_keys = {} --- @type table<string,true>
  for _, v in ipairs(pages) do
    local x = format_candidate(v, psect)
    local xl = x:lower() -- ignore case when searching avoiding duplicates
    if not pages_fmt_keys[xl] then
      pages_fmt[#pages_fmt + 1] = x
      pages_fmt_keys[xl] = true
    end
  end
  table.sort(pages_fmt)

  return pages_fmt
end

--- @param pattern string
--- @return {name:string,filename:string,cmd:string}[]
function M.goto_tag(pattern, _, _)
  local name, sect, err = parse_ref(pattern)
  if err then
    error(err)
  end

  local paths, err2 = get_paths(assert(name), sect)
  if err2 then
    error(err2)
  end

  --- @type table[]
  local ret = {}

  for _, path in ipairs(paths) do
    local pname, psect = parse_path(path)
    ret[#ret + 1] = {
      name = pname,
      filename = ('man://%s(%s)'):format(pname, psect),
      cmd = '1',
    }
  end

  return ret
end

--- Called when Nvim is invoked as $MANPAGER.
function M.init_pager()
  if fn.getline(1):match('^%s*$') then
    api.nvim_buf_set_lines(0, 0, 1, false, {})
  else
    vim.cmd('keepjumps 1')
  end
  highlight_man_page()
  -- Guess the ref from the heading (which is usually uppercase, so we cannot
  -- know the correct casing, cf. `man glDrawArraysInstanced`).
  --- @type string
  local ref = (fn.getline(1):match('^[^)]+%)') or ''):gsub(' ', '_')
  local _, sect, err = pcall(parse_ref, ref)
  vim.b.man_sect = err ~= nil and sect or ''

  local man_bufname = 'man://' .. fn.fnameescape(ref):lower()

  -- Raw manpage into (:Man!) overlooks `match('man://')` condition,
  -- so if the buffer already exists, create new with a non existing name.
  if vim.fn.bufexists(man_bufname) == 1 then
    local new_bufname = man_bufname
    for i = 1, 100 do
      if vim.fn.bufexists(new_bufname) == 0 then
        break
      end
      new_bufname = ('%s?new=%s'):format(man_bufname, i)
    end
    vim.cmd.file({ new_bufname, mods = { silent = true } })
  elseif not fn.bufname('%'):match('man://') then -- Avoid duplicate buffers, E95.
    vim.cmd.file({ man_bufname, mods = { silent = true } })
  end

  set_options()
end

--- Combine the name and sect into a manpage reference so that all
--- verification/extraction can be kept in a single function.
--- @param args string[]
--- @return string? ref
local function ref_from_args(args)
  if #args <= 1 then
    return args[1]
  elseif args[1]:match('^%d$') or args[1]:match('^%d%a') or args[1]:match('^%a$') then
    -- NB: Valid sections are not only digits, but also:
    --  - <digit><word> (see POSIX mans),
    --  - and even <letter> and <word> (see, for example, by tcl/tk)
    -- NB2: don't optimize to :match("^%d"), as it will match manpages like
    --    441toppm and others whose name starts with digit
    local sect = args[1]
    table.remove(args, 1)
    local name = table.concat(args, ' ')
    return ('%s(%s)'):format(name, sect)
  end

  return table.concat(args, ' ')
end

--- @param count integer
--- @param args string[]
--- @return string? err
function M.open_page(count, smods, args)
  local ref = ref_from_args(args)
  if not ref then
    ref = vim.bo.filetype == 'man' and fn.expand('<cWORD>') or fn.expand('<cword>')
    if ref == '' then
      return 'no identifier under cursor'
    end
  end

  local name, sect, err = parse_ref(ref)
  if err then
    return err
  end
  assert(name)

  if count >= 0 then
    sect = tostring(count)
  end

  -- Try both spaces and underscores, use the first that exists.
  local path = M._find_path(name, sect)
  if not path then
    --- Replace spaces in a man page name with underscores
    --- intended for PostgreSQL, which has man pages like 'CREATE_TABLE(7)';
    --- while editing SQL source code, it's nice to visually select 'CREATE TABLE'
    --- and hit 'K', which requires this transformation
    path = M._find_path(name:gsub('%s', '_'), sect)
    if not path then
      return 'no manual entry for ' .. name
    end
  end

  name, sect = parse_path(path)
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
  end
  set_options()

  vim.b.man_sect = sect
end

--- Called when a man:// buffer is opened.
--- @return string? err
function M.read_page(ref)
  local name, sect, err = parse_ref(ref)
  if err then
    return err
  end

  local path = M._find_path(name, sect)
  if not path then
    return 'no manual entry for ' .. name
  end

  local _, sect1 = parse_path(path)
  local page = get_page(path)

  vim.b.man_sect = sect1
  vim.bo.modifiable = true
  vim.bo.readonly = false
  vim.bo.swapfile = false

  api.nvim_buf_set_lines(0, 0, -1, false, vim.split(page, '\n'))

  while fn.getline(1):match('^%s*$') do
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

function M.show_toc()
  local bufnr = api.nvim_get_current_buf()
  local bufname = api.nvim_buf_get_name(bufnr)
  local info = fn.getloclist(0, { winid = 1 })
  if info ~= '' and vim.w[info.winid].qf_toc == bufname then
    vim.cmd.lopen()
    return
  end

  --- @type {bufnr:integer, lnum:integer, text:string}[]
  local toc = {}

  local lnum = 2
  local last_line = fn.line('$') - 1
  while lnum and lnum < last_line do
    local text = fn.getline(lnum)
    if text:match('^%s+[-+]%S') or text:match('^   %S') or text:match('^%S') then
      toc[#toc + 1] = {
        bufnr = bufnr,
        lnum = lnum,
        text = text:gsub('^%s+', ''):gsub('%s+$', ''),
      }
    end
    lnum = fn.nextnonblank(lnum + 1)
  end

  fn.setloclist(0, toc, ' ')
  fn.setloclist(0, {}, 'a', { title = 'Table of contents' })
  vim.cmd.lopen()
  vim.w.qf_toc = bufname
end

return M
