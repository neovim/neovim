require('vim.compat')

local buf_hls = {}

local function highlight_line(line, linenr)
  local chars = {}
  local prev_char = ''
  local overstrike, escape = false, false
  local hls = {} -- Store highlight groups as { attr, start, final }
  local NONE, BOLD, UNDERLINE, ITALIC = 0, 1, 2, 3
  local hl_groups = {[BOLD]="manBold", [UNDERLINE]="manUnderline", [ITALIC]="manItalic"}
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
      hls[#hls + 1] = {attr=attr, start=byte, final=-1}
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
  for char in line:gmatch("[^\128-\191][\128-\191]*") do
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
        hls[#hls + 1] = {attr=attr, start=byte, final=byte + #char}
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
      local sgr = prev_char:match("^%[([\032-\063]*)m$")
      -- Ignore escape sequences with : characters, as specified by ITU's T.416
      -- Open Document Architecture and interchange format.
      if sgr and not string.find(sgr, ":") then
        local match
        while sgr and #sgr > 0 do
          -- Match against SGR parameters, which may be separated by ';'
          match, sgr = sgr:match("^(%d*);?(.*)")
          add_attr_hl(match + 0) -- coerce to number
        end
        escape = false
      elseif not prev_char:match("^%[[\032-\063]*$") then
        -- Stop looking if this isn't a partial CSI sequence
        escape = false
      end
    elseif char == "\027" then
      escape = true
      prev_char = ''
    elseif char == "\b" then
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
        hl.final
      }
    end
  end

  return table.concat(chars, '')
end

local function highlight_man_page()
  local mod = vim.api.nvim_buf_get_option(0, "modifiable")
  vim.api.nvim_buf_set_option(0, "modifiable", true)

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for i, line in ipairs(lines) do
    lines[i] = highlight_line(line, i)
  end
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)

  for _, args in ipairs(buf_hls) do
    vim.api.nvim_buf_add_highlight(unpack(args))
  end
  buf_hls = {}

  vim.api.nvim_buf_set_option(0, "modifiable", mod)
end

return { highlight_man_page = highlight_man_page }
