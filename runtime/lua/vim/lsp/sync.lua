-- Note on incremental sync:
--  Per the protocol, the text range should be:
--
--  A position inside a document (see Position definition below) is expressed as
--  a zero-based line and character offset. The offsets are based on a UTF-16
--  string representation. So a string of the form a𐐀b the character offset
--  of the character a is 0, the character offset of 𐐀 is 1 and the character
--  offset of b is 3 since 𐐀 is represented using two code units in UTF-16.
--
--  To ensure that both client and server split the string into the same line
--  representation the protocol specifies the following end-of-line sequences: ‘\n’, ‘\r\n’ and ‘\r’.
--
--  Positions are line end character agnostic. So you can not specify a position that denotes \r|\n or \n| where | represents the character offset. This means *no* defining a range than ends on the same line after a terminating character
--
-- Generic warnings about byte level changes in neovim
--  Join operation (2 op): extends line 1 with the contents of line 2, delete line 2
--  lastline = 3
--  test 1    test 1 test 2    test 1 test 2
--  test 2 -> test 2        -> test 3
--  test 3    test 3
--
--  Deleting (and undoing) two middle lines (1 op)
--  test 1    test 1
--  test 2 -> test 4
--  test 3
--  test 4
--
--  Delete between asterisks (5 op)
--  test *1   test *    test *     test *    test *4    test *4*
--  test 2 -> test 2 -> test *4 -> *4     -> *4      ->
--  test 3    test 3
--  test *4   test 4


-- Notes on on_bytes
-- old line/col size will only be non-zero if you replace/delete something
local M = {}

---@private
-- Given a line, byte idx, and offset_encoding convert to the
-- utf-8, utf-16, or utf-32 index.
---@param line string the line to index into
---@param byte integer the byte idx
---@param offset_encoding string utf-8|utf-16|utf-32|nil (default: utf-8)
--@returns integer the utf idx for the given encoding
function M.byte_to_utf(line, byte, offset_encoding)
  -- convert to 0 based indexing
  byte = byte - 1

  local utf_idx
  local _
  -- Convert the byte range to utf-{8,16,32} and convert 1-based (lua) indexing to 0-based
  if offset_encoding == 'utf-16' then
    _, utf_idx = vim.str_utfindex(line, byte)
  elseif offset_encoding == 'utf-32' then
    utf_idx, _ = vim.str_utfindex(line, byte)
  else
    utf_idx = byte
  end

  -- convert to 1 based indexing
  return utf_idx + 1
end

---@private
-- Given a line, byte idx, alignment, and offset_encoding convert to the aligned
-- utf-8 index and either the utf-16, or utf-32 index.
---@param line string the line to index into
---@param byte integer the byte idx
---@param align string when dealing with multibyte characters,
--        to choose the start of the current character or the beginning of the next.
--        Used for incremental sync for start/end range respectively
---@param offset_encoding string utf-8|utf-16|utf-32|nil (default: utf-8)
---@returns table<string, int> byte_idx and char_idx of first change position
function M.align_position(line, byte, align, offset_encoding)
  local char
  -- If on the first byte, or an empty string: the trivial case
  if byte == 1 or #line == 0 then
    char = byte
    -- TODO(mjlbach): not sure about this in the multibyte case
    -- Called in the case of extending an empty line "" -> "a"
  elseif byte == #line + 1 then
    byte = byte
    -- Find the utf position of the end of the line, and add one for the new character
    char = M.byte_to_utf(line, #line, offset_encoding) + 1
  else
    -- Modifying line, find the nearest utf codepoint
    if align == 'start' then
      byte = byte + vim.str_utf_start(line, byte)
      char = M.byte_to_utf(line, byte, offset_encoding)
    elseif align == 'end' then
      local offset = vim.str_utf_end(line, byte)
      -- If the byte does not fall on the start of the character, then
      -- align to the start of the next character.
      if offset > 0 then
        char = M.byte_to_utf(line, byte, offset_encoding) + 1
        byte = byte + offset
      else
        char = M.byte_to_utf(line, byte, offset_encoding)
        byte = byte + offset
      end
    else
      assert(false, '`align` must be start or end.')
    end
    -- Extending line, find the nearest utf codepoint for the last valid character
  end
  return byte, char
end

---@private
--- Finds the first line, byte, and char index of the difference between the previous and current lines buffer normalized to the previous codepoint.
---@param prev_lines table list of lines from previous buffer
---@param start_row integer start_row from on_bytes, adjusted to 1-index
---@param start_col integer start_col from on_bytes, adjusted to 1-index
---@param offset_encoding string utf-8|utf-16|utf-32|nil (fallback to utf-8)
---@returns table<int, int> line_idx, byte_idx, and char_idx of first change position
function M.compute_start_range(prev_lines, start_row, start_col, offset_encoding)
  local prev_line = prev_lines[start_row]

  -- Convert byte to codepoint
  local byte_idx, char_idx = M.align_position(prev_line, start_col, 'start', offset_encoding)

  -- Return the start difference (shared for new and prev lines)
  return { line_idx = start_row, byte_idx = byte_idx, char_idx = char_idx }
end

---@private
--- Finds the last line and byte index of the differences between prev and current buffer.
--- Normalized to the next codepoint.
--- prev_end_range is the text range sent to the server representing the changed region.
--- curr_end_range is the text that should be collected and sent to the server.
--
---@param prev_lines table list of lines
---@param prev_end_row
---@param prev_end_col
---@param offset_encoding string
---@returns (int, int) end_line_idx and end_col_idx of range
function M.compute_prev_end_range(prev_lines, start_row, start_col, prev_end_row, prev_end_col, offset_encoding)
  -- Handle pure insertion, where there is no replacement of text
  if prev_end_row == 1 and prev_end_col == 1 then
    local curr_byte_idx, curr_char_idx = M.align_position(prev_lines[start_row], start_col, 'end', offset_encoding)
    return { line_idx = start_row, byte_idx = curr_byte_idx, char_idx = curr_char_idx }
  else
    -- add the offsets
    prev_end_row = start_row + prev_end_row - 1
    prev_end_col = start_col + prev_end_col - 1
    local curr_byte_idx, curr_char_idx = M.align_position(prev_lines[prev_end_row], prev_end_col, 'end', offset_encoding)
    return { line_idx = prev_end_row, byte_idx = curr_byte_idx, char_idx = curr_char_idx }
  end
end

---@private
--- Finds the last line and byte index of the differences between prev and current buffer.
--- Normalized to the next codepoint.
--- prev_end_range is the text range sent to the server representing the changed region.
--- curr_end_range is the text that should be collected and sent to the server.
--
---@param curr_lines table list of lines
---@param curr_end_row
---@param curr_end_col
---@param offset_encoding string
---@returns (int, int) end_line_idx and end_col_idx of range
function M.compute_curr_end_range(curr_lines, start_row, start_col, curr_end_row, curr_end_col, offset_encoding)
  -- Handle pure insertion, where there is no replacement of text
  if curr_end_row == 1 and curr_end_col == 1 then
    local curr_byte_idx, curr_char_idx = M.align_position(curr_lines[start_row], start_col, 'end', offset_encoding)
    return { line_idx = start_row, byte_idx = curr_byte_idx, char_idx = curr_char_idx }
  else
    -- add the offsets
    curr_end_row = start_row + curr_end_row - 1
    curr_end_col = start_col + curr_end_col - 1
    local curr_byte_idx, curr_char_idx = M.align_position(curr_lines[curr_end_row], curr_end_col, 'end', offset_encoding)
    return { line_idx = curr_end_row, byte_idx = curr_byte_idx, char_idx = curr_char_idx }
  end
end

---@private
--- Get the text of the range defined by start and end line/column
---@param lines table list of lines
---@param start_range table table returned by first_difference
---@param end_range table new_end_range returned by last_difference
---@returns string text extracted from defined region
function M.extract_text(lines, start_range, end_range, line_ending)
  if not lines[start_range.line_idx] then
    return ""
  end

  -- Trivial case: start and end range are the same line, directly grab changed text
  if start_range.line_idx == end_range.line_idx then
    -- string.sub is inclusive, end_range is not
    return string.sub(lines[start_range.line_idx], start_range.byte_idx, end_range.byte_idx - 1)
  else
    -- Collect the changed portion of the first changed line
    local result = { string.sub(lines[start_range.line_idx], start_range.byte_idx) }

    -- Collect the full line for intermediate lines
    for idx = start_range.line_idx + 1, end_range.line_idx - 1 do
      table.insert(result, lines[idx])
    end

    -- Collect the changed portion of the last changed line.
    if lines[end_range.line_idx] then
      table.insert(result, string.sub(lines[end_range.line_idx], 1, end_range.byte_idx - 1))
    else
      table.insert(result, "")
    end

    -- Add line ending between all lines
    return table.concat(result, line_ending)
  end
end

---@private
-- rangelength depends on the offset encoding
-- bytes for utf-8 (clangd with extenion)
-- codepoints for utf-16
-- codeunits for utf-32
-- Line endings count here as 2 chars for \r\n (dos), 1 char for \n (unix), and 1 char for \r (mac)
-- These correspond to Windows, Linux/macOS (OSX and newer), and macOS (version 9 and prior)
function M.compute_range_length(lines, start_range, end_range, offset_encoding, line_ending)
  local line_ending_length = #line_ending
  -- Single line case
  if start_range.line_idx == end_range.line_idx then
    return start_range.char_idx - end_range.char_idx
  end

  local start_line = lines[start_range.line_idx]
  local range_length
  if #start_line > 0 then
    --TODO(mjlbach): check 1 indexing
    range_length = M.byte_to_utf(start_line, #start_line, offset_encoding) - start_range.char_idx + line_ending_length
  else
    -- Length of newline character
    range_length = line_ending_length
  end

  -- The first and last range of the line idx may be partial lines
  for idx = start_range.line_idx + 1, end_range.line_idx - 1 do
    -- Length full line plus newline character
    --TODO(mjlbach): check 1 indexing
    range_length = range_length + M.byte_to_utf(lines[idx], #lines[idx], offset_encoding) + line_ending_length
  end

  local end_line = lines[end_range.line_idx]
  if end_line and #end_line > 0 then
    --TODO(mjlbach): check 1 indexing
    range_length = range_length + M.byte_to_utf(end_line, #end_line, offset_encoding) - end_range.char_idx
  end

  return range_length
end

--- Returns the range table for the difference between prev and curr lines
---@param prev_lines table list of lines
---@param curr_lines table list of lines
---@param byte_change
---@param offset_encoding string encoding requested by language server
---@returns table TextDocumentContentChangeEvent see https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#textDocumentContentChangeEvent
function M.compute_diff(prev_lines, curr_lines, byte_change, offset_encoding, line_ending)
  -- Find the start of changes between the previous and current buffer. Common between both.
  -- Sent to the server as the start of the changed range.
  -- Used to grab the changed text from the latest buffer.
  local start_range = M.compute_start_range(
    prev_lines,
    byte_change.start_row + 1,
    byte_change.start_col + 1,
    offset_encoding
  )

  -- Find the last position changed in the previous and current buffer.
  -- prev_end_range is sent to the server as as the end of the changed range.
  local prev_end_range = M.compute_prev_end_range(
    prev_lines,
    byte_change.start_row + 1,
    byte_change.start_col + 1,
    byte_change.prev_end_row + 1,
    byte_change.prev_end_col + 1,
    offset_encoding
  )

  -- curr_end_range is used to grab the changed text from the latest buffer.
  local curr_end_range = M.compute_curr_end_range(
    curr_lines,
    byte_change.start_row + 1,
    byte_change.start_col + 1,
    byte_change.curr_end_row + 1,
    byte_change.curr_end_col + 1,
    offset_encoding
  )

  print(vim.inspect({curr_lines=curr_lines, start_range=start_range, prev_end_range=prev_end_range, curr_end_range=curr_end_range}))
  -- Grab the changed text of from start_range to curr_end_range in the current buffer.
  -- The text range is "" if entire range is deleted.
  local text = M.extract_text(curr_lines, start_range, curr_end_range, line_ending)

  -- Compute the range of the replaced text. Deprecated but still required for certain language servers
  -- local range_length = M.compute_range_length(prev_lines, start_range, prev_end_range, offset_encoding, line_ending)

  -- convert to 0 based indexing
  local result = {
    range = {
      ['start'] = { line = start_range.line_idx - 1, character = start_range.char_idx - 1 },
      ['end'] = { line = prev_end_range.line_idx - 1, character = prev_end_range.char_idx - 1 },
    },
    text = text,
    -- rangeLength = range_length,
  }

  return result
end

return M
