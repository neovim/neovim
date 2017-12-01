local function highlight_formatted(line, linenr)
  local chars = {}
  local prev_char = ''
  local overstrike, escape = false, false
  local hls = {} -- Store highlight groups as { attr, start, end }
  local NONE, BOLD, UNDERLINE, ITALIC = 0, 1, 2, 3
  local hl_groups = {[BOLD]="manBold", [UNDERLINE]="manUnderline", [ITALIC]="manItalic"}
  local attr = NONE
  local byte = 0 -- byte offset

  local function end_attr_hl(attr)
    for i, hl in ipairs(hls) do
      if hl[1] == attr and hl[3] == -1 then
        hl[3] = byte
        hls[i] = hl
      end
    end
  end

  local function add_attr_hl(code)
    local on = true
    if code == 0 then
      attr = NONE
      on = false
    elseif code == 1 then
      attr = BOLD
    elseif code == 21 or code == 22 then
      attr = BOLD
      on = false
    elseif code == 3 then
      attr = ITALIC
    elseif code == 23 then
      attr = ITALIC
      on = false
    elseif code == 4 then
      attr = UNDERLINE
    elseif code == 24 then
      attr = UNDERLINE
      on = false
    else
      attr = NONE
      return
    end

    if on then
      hls[#hls + 1] = {attr, byte, -1}
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

  -- Break input into UTF8 characters
  for char in line:gmatch("[^\128-\191][\128-\191]*") do
    if overstrike then
      local last_hl = hls[#hls]
      if char == prev_char then
        if char == '_' and attr == UNDERLINE and last_hl and last_hl[3] == byte then
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
        char = [[·]]
      elseif prev_char == [[·]] and char == 'o' then
        -- bullet (additional handling for '+^H+^Ho^Ho')
        attr = BOLD
        char = [[·]]
      else
        -- use plain char
        attr = NONE
      end

      -- Grow the previous highlight group if possible
      if last_hl and last_hl[1] == attr and last_hl[3] == byte then
        last_hl[3] = byte + #char
      else
        hls[#hls + 1] = {attr, byte, byte + #char}
      end

      overstrike = false
      prev_char = ''
      byte = byte + #char
      chars[#chars + 1] = char
    elseif escape then
      -- Use prev_char to store the escape sequence
      prev_char = prev_char .. char
      local sgr = prev_char:match("^%[([\020-\063]*)m$")
      if sgr then
        local match = ''
        while sgr and #sgr > 0 do
          match, sgr = sgr:match("^(%d*);?(.*)")
          add_attr_hl(match + 0) -- coerce to number
        end
        escape = false
      elseif not prev_char:match("^%[[\020-\063]*$") then
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

  for i, hl in ipairs(hls) do
    if hl[1] ~= NONE then
      vim.api.nvim_buf_add_highlight(
        0,
        -1,
        hl_groups[hl[1]],
        linenr - 1,
        hl[2],
        hl[3]
      )
    end
  end

  return table.concat(chars, '')
end

return { highlight_formatted = highlight_formatted }
