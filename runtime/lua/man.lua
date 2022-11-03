local api, fn = vim.api, vim.fn

local find_arg = '-w'
local localfile_arg = true -- Always use -l if possible. #6683
local buf_hls = {}

local M = {}

local function man_error(msg)
  M.errormsg = 'man.lua: ' .. vim.inspect(msg)
  error(M.errormsg)
end

-- Run a system command and timeout after 30 seconds.
local function man_system(cmd, silent)
  local stdout_data = {}
  local stderr_data = {}
  local stdout = vim.loop.new_pipe(false)
  local stderr = vim.loop.new_pipe(false)

  local done = false
  local exit_code

  local handle
  handle = vim.loop.spawn(cmd[1], {
    args = vim.list_slice(cmd, 2),
    stdio = { nil, stdout, stderr },
  }, function(code)
    exit_code = code
    stdout:close()
    stderr:close()
    handle:close()
    done = true
  end)

  if handle then
    stdout:read_start(function(_, data)
      stdout_data[#stdout_data + 1] = data
    end)
    stderr:read_start(function(_, data)
      stderr_data[#stderr_data + 1] = data
    end)
  else
    stdout:close()
    stderr:close()
    if not silent then
      man_error(string.format('command error: %s', table.concat(cmd)))
    end
  end

  vim.wait(30000, function()
    return done
  end)

  if not done then
    if handle then
      handle:close()
      stdout:close()
      stderr:close()
    end
    man_error(string.format('command timed out: %s', table.concat(cmd, ' ')))
  end

  if exit_code ~= 0 and not silent then
    man_error(
      string.format("command error '%s': %s", table.concat(cmd, ' '), table.concat(stderr_data))
    )
  end

  return table.concat(stdout_data)
end

local function highlight_line(line, linenr)
  local chars = {}
  local prev_char = ''
  local overstrike, escape = false, false
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
        if char == '_' and attr == UNDERLINE and last_hl and last_hl.final == byte then
          -- This underscore is in the middle of an underlined word
          attr = UNDERLINE
        else
          attr = BOLD
        end
      elseif prev_char == '_' then
        -- char is underlined
        attr = UNDERLINE
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
    elseif escape then
      -- Use prev_char to store the escape sequence
      prev_char = prev_char .. char
      -- We only want to match against SGR sequences, which consist of ESC
      -- followed by '[', then a series of parameter and intermediate bytes in
      -- the range 0x20 - 0x3f, then 'm'. (See ECMA-48, sections 5.4 & 8.3.117)
      local sgr = prev_char:match('^%[([\032-\063]*)m$')
      -- Ignore escape sequences with : characters, as specified by ITU's T.416
      -- Open Document Architecture and interchange format.
      if sgr and not string.find(sgr, ':') then
        local match
        while sgr and #sgr > 0 do
          -- Match against SGR parameters, which may be separated by ';'
          match, sgr = sgr:match('^(%d*);?(.*)')
          add_attr_hl(match + 0) -- coerce to number
        end
        escape = false
      elseif not prev_char:match('^%[[\032-\063]*$') then
        -- Stop looking if this isn't a partial CSI sequence
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
local function spaces_to_underscores(str)
  local res = str:gsub('%s', '_')
  return res
end

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
  -- clock_getres.2, which is the right page. Searching the resuls for
  -- clock_gettime will no longer work. In this case, we should just use the
  -- first one that was found in the correct section.
  --
  -- Finally, we can avoid relying on -S or -s here since they are very
  -- inconsistently supported. Instead, call -w with a section and a name.
  local cmd
  if sect == '' then
    cmd = { 'man', find_arg, name }
  else
    cmd = { 'man', find_arg, sect, name }
  end

  local lines = man_system(cmd, silent)
  if lines == nil then
    return nil
  end

  local results = vim.split(lines, '\n', { trimempty = true })

  if #results == 0 then
    return
  end

  -- find any that match the specified name
  local namematches = vim.tbl_filter(function(v)
    return fn.fnamemodify(v, ':t'):match(name)
  end, results) or {}
  local sectmatches = {}

  if #namematches > 0 and sect ~= '' then
    sectmatches = vim.tbl_filter(function(v)
      return fn.fnamemodify(v, ':e') == sect
    end, namematches)
  end

  return fn.substitute(sectmatches[1] or namematches[1] or results[1], [[\n\+$]], '', '')
end

local function matchstr(text, pat_or_re)
  local re = type(pat_or_re) == 'string' and vim.regex(pat_or_re) or pat_or_re

  local s, e = re:match_str(text)

  if s == nil then
    return
  end

  return text:sub(vim.str_utfindex(text, s) + 1, vim.str_utfindex(text, e))
end

-- attempt to extract the name and sect out of 'name(sect)'
-- otherwise just return the largest string of valid characters in ref
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
    return '', spaces_to_underscores(name)
  end
  local parts = vim.split(ref1, '(', { plain = true })
  -- see ':Man 3X curses' on why tolower.
  -- TODO(nhooyr) Not sure if this is portable across OSs
  -- but I have not seen a single uppercase section.
  local sect = vim.split(parts[2] or '', ')', { plain = true })[1]:lower()
  local name = spaces_to_underscores(parts[1])
  return sect, name
end

-- verify_exists attempts to find the path to a manpage
-- based on the passed section and name.
--
-- 1. If manpage could not be found with the given sect and name,
--    then try all the sections in b:man_default_sects.
-- 2. If it still could not be found, then we try again without a section.
-- 3. If still not found but $MANSECT is set, then we try again with $MANSECT
--    unset.
local function verify_exists(sect, name)
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
  man_error('no manual entry for ' .. name)
end

local EXT_RE = vim.regex([[\.\%([glx]z\|bz2\|lzma\|Z\)$]])

-- Extracts the name/section from the 'path/name.sect', because sometimes the actual section is
-- more specific than what we provided to `man` (try `:Man 3 App::CLI`).
-- Also on linux, name seems to be case-insensitive. So for `:Man PRIntf`, we
-- still want the name of the buffer to be 'printf'.
local function extract_sect_and_name_path(path)
  local tail = fn.fnamemodify(path, ':t')
  if EXT_RE:match_str(path) then -- valid extensions
    tail = fn.fnamemodify(tail, ':r')
  end
  local name, sect = tail:match('^(.+)%.([^.]+)$')
  return sect, name
end

local function find_man()
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

local function set_options(pager)
  vim.bo.swapfile = false
  vim.bo.buftype = 'nofile'
  vim.bo.bufhidden = 'hide'
  vim.bo.modified = false
  vim.bo.readonly = true
  vim.bo.modifiable = false
  vim.b.pager = pager
  vim.bo.filetype = 'man'
end

local function get_page(path, silent)
  -- Disable hard-wrap by using a big $MANWIDTH (max 1000 on some systems #9065).
  -- Soft-wrap: ftplugin/man.lua sets wrap/breakindent/….
  -- Hard-wrap: driven by `man`.
  local manwidth
  if (vim.g.man_hardwrap or 1) ~= 1 then
    manwidth = 999
  elseif vim.env.MANWIDTH then
    manwidth = vim.env.MANWIDTH
  else
    manwidth = api.nvim_win_get_width(0)
  end
  -- Force MANPAGER=cat to ensure Vim is not recursively invoked (by man-db).
  -- http://comments.gmane.org/gmane.editors.vim.devel/29085
  -- Set MAN_KEEP_FORMATTING so Debian man doesn't discard backspaces.
  local cmd = { 'env', 'MANPAGER=cat', 'MANWIDTH=' .. manwidth, 'MAN_KEEP_FORMATTING=1', 'man' }
  if localfile_arg then
    cmd[#cmd + 1] = '-l'
  end
  cmd[#cmd + 1] = path
  return man_system(cmd, silent)
end

local function put_page(page)
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
  vim.cmd([[silent! keeppatterns keepjumps %s/\s\{199,}/\=repeat(' ', 10)/g]])
  vim.cmd('1') -- Move cursor to first line
  highlight_man_page()
  set_options(false)
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

local function get_paths(sect, name, do_fallback)
  -- callers must try-catch this, as some `man` implementations don't support `s:find_arg`
  local ok, ret = pcall(function()
    local mandirs =
      table.concat(vim.split(man_system({ 'man', find_arg }), '[:\n]', { trimempty = true }), ',')
    local paths = fn.globpath(mandirs, 'man?/' .. name .. '*.' .. sect .. '*', false, true)
    pcall(function()
      -- Prioritize the result from verify_exists as it obeys b:man_default_sects.
      local first = verify_exists(sect, name)
      paths = vim.tbl_filter(function(v)
        return v ~= first
      end, paths)
      paths = { first, unpack(paths) }
    end)
    return paths
  end)

  if not ok then
    if not do_fallback then
      error(ret)
    end

    -- Fallback to a single path, with the page we're trying to find.
    ok, ret = pcall(verify_exists, sect, name)

    return { ok and ret or nil }
  end
  return ret or {}
end

local function complete(sect, psect, name)
  local pages = get_paths(sect, name, false)
  -- We remove duplicates in case the same manpage in different languages was found.
  return fn.uniq(fn.sort(vim.tbl_map(function(v)
    return format_candidate(v, psect)
  end, pages) or {}, 'i'))
end

-- see extract_sect_and_name_ref on why tolower(sect)
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

function M.goto_tag(pattern, _, _)
  local sect, name = extract_sect_and_name_ref(pattern)

  local paths = get_paths(sect, name, true)
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

  if vim.o.cscopetag then
    -- return only a single entry so we work well with :cstag (#11675)
    structured = { structured[1] }
  end

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
  if fn.getline(1):match('^%s*$') then
    api.nvim_buf_set_lines(0, 0, 1, false, {})
  else
    vim.cmd('keepjumps 1')
  end
  highlight_man_page()
  -- Guess the ref from the heading (which is usually uppercase, so we cannot
  -- know the correct casing, cf. `man glDrawArraysInstanced`).
  local ref = fn.substitute(matchstr(fn.getline(1), [[^[^)]\+)]]) or '', ' ', '_', 'g')
  local ok, res = pcall(extract_sect_and_name_ref, ref)
  vim.b.man_sect = ok and res or ''

  if not fn.bufname('%'):match('man://') then -- Avoid duplicate buffers, E95.
    vim.cmd.file({ 'man://' .. fn.fnameescape(ref):lower(), mods = { silent = true } })
  end

  set_options(true)
end

function M.open_page(count, smods, args)
  if #args > 2 then
    man_error('too many arguments')
  end

  local ref
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
    -- If args[2] is a reference as well, that is fine because it is the only
    -- reference that will match.
    ref = ('%s(%s)'):format(args[2], args[1])
  end

  local sect, name = extract_sect_and_name_ref(ref)
  if count >= 0 then
    sect = tostring(count)
  end

  local path = verify_exists(sect, name)
  sect, name = extract_sect_and_name_path(path)

  local buf = fn.bufnr()
  local save_tfu = vim.bo[buf].tagfunc
  vim.bo[buf].tagfunc = "v:lua.require'man'.goto_tag"

  local target = ('%s(%s)'):format(name, sect)

  local ok, ret = pcall(function()
    if smods.tab == -1 and find_man() then
      vim.cmd.tag({ target, mods = { silent = true, keepalt = true } })
    else
      smods.silent = true
      smods.keepalt = true
      vim.cmd.stag({ target, mods = smods })
    end
  end)

  vim.bo[buf].tagfunc = save_tfu

  if not ok then
    error(ret)
  else
    set_options(false)
  end

  vim.b.man_sect = sect
end

-- Called when a man:// buffer is opened.
function M.read_page(ref)
  local sect, name = extract_sect_and_name_ref(ref)
  local path = verify_exists(sect, name)
  sect = extract_sect_and_name_path(path)
  local page = get_page(path)
  vim.b.man_sect = sect
  put_page(page)
end

function M.show_toc()
  local bufname = fn.bufname('%')
  local info = fn.getloclist(0, { winid = 1 })
  if info ~= '' and vim.w[info.winid].qf_toc == bufname then
    vim.cmd.lopen()
    return
  end

  local toc = {}
  local lnum = 2
  local last_line = fn.line('$') - 1
  local section_title_re = vim.regex([[^\%( \{3\}\)\=\S.*$]])
  local flag_title_re = vim.regex([[^\s\+\%(+\|-\)\S\+]])
  while lnum and lnum < last_line do
    local text = fn.getline(lnum)
    if section_title_re:match_str(text) then
      -- if text is a section title
      toc[#toc + 1] = {
        bufnr = fn.bufnr('%'),
        lnum = lnum,
        text = text,
      }
    elseif flag_title_re:match_str(text) then
      -- if text is a flag title. we strip whitespaces and prepend two
      -- spaces to have a consistent format in the loclist.
      toc[#toc + 1] = {
        bufnr = fn.bufnr('%'),
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
  local page
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
