local function highlight_backspaced(line, linenr)
  local chars = {}
  local prev_char = ''
  local overstrike = false
  local hls = {} -- Store highlight groups as { attr, start, end }
  local NONE, BOLD, UNDERLINE = 0, 1, 2
  local attr = NONE
  local byte = 0 -- byte offset

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
        hl[1] == BOLD and "manBold" or "manUnderline",
        linenr - 1,
        hl[2],
        hl[3]
      )
    end
  end

  return table.concat(chars, '')
end

return { highlight_backspaced = highlight_backspaced }
