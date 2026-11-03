-- Notes on incremental sync:
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
--  Positions are line end character agnostic. So you can not specify a position that
--  denotes \r|\n or \n| where | represents the character offset. This means *no* defining
--  a range than ends on the same line after a terminating character
--
-- Generic warnings about byte level changes in neovim. Many apparently "single"
-- operations in on_lines callbacks are actually multiple operations.
--
--  Join operation (2 operations):
--  * extends line 1 with the contents of line 2
--  * deletes line 2
--
--  test 1    test 1 test 2    test 1 test 2
--  test 2 -> test 2        -> test 3
--  test 3    test 3
--
--  Deleting (and undoing) two middle lines (1 operation):
--
--  test 1    test 1
--  test 2 -> test 4
--  test 3
--  test 4
--
--  Deleting partial lines (5 operations) deleting between asterisks below:
--
--  test *1   test *    test *     test *    test *4    test *4*
--  test 2 -> test 2 -> test *4 -> *4     -> *4      ->
--  test 3    test 3
--  test *4   test 4

local M = {}

-- local string.byte, unclear if this is necessary for JIT compilation
local str_byte = string.byte
local min = math.min
local str_utfindex = vim.str_utfindex
local str_byteindex = vim.str_byteindex

---@class vim.lsp.sync.Range Represents a position (not a range) in the document
---@field line_idx integer 1-indexed line index
---@field byte_idx integer 1-indexed byte index, for indexing into Lua string
---@field char_idx integer 1-indexed char index, for sending to LSP server

--- Get the text of the range defined by start and end line/column
---@param lines table list of lines
---@param start_range vim.lsp.sync.Range table returned by first_difference
---@param end_range vim.lsp.sync.Range new_end_range returned by last_difference
---@param line_ending string
---@return string text extracted from defined region
local function extract_text(lines, start_range, end_range, line_ending)
  if not lines[start_range.line_idx] then
    return ''
  end
  -- Trivial case: start and end range are the same line, directly grab changed text
  if start_range.line_idx == end_range.line_idx then
    -- string.sub is inclusive, end_range is not
    return string.sub(lines[start_range.line_idx], start_range.byte_idx, end_range.byte_idx - 1)
  else
    -- Handle deletion case
    -- Collect the changed portion of the first changed line
    local result = { string.sub(lines[start_range.line_idx], start_range.byte_idx) }

    -- Collect the full line for intermediate lines
    for idx = start_range.line_idx + 1, end_range.line_idx - 1 do
      table.insert(result, lines[idx])
    end

    if lines[end_range.line_idx] then
      -- Collect the changed portion of the last changed line.
      table.insert(result, string.sub(lines[end_range.line_idx], 1, end_range.byte_idx - 1))
    else
      table.insert(result, '')
    end

    -- Add line ending between all lines
    return table.concat(result, line_ending)
  end
end

-- rangelength depends on the position encoding
-- bytes for utf-8 (clangd with extension)
-- codepoints for utf-16
-- codeunits for utf-32
-- Line endings count here as 2 chars for \r\n (dos), 1 char for \n (unix), and 1 char for \r (mac)
-- These correspond to Windows, Linux/macOS (OSX and newer), and macOS (version 9 and prior)
---@param lines string[]
---@param start_range vim.lsp.sync.Range
---@param end_range vim.lsp.sync.Range
---@param position_encoding 'utf-8'|'utf-16'|'utf-32'
---@param line_ending string
---@return integer
local function compute_range_length(lines, start_range, end_range, position_encoding, line_ending)
  local line_ending_length = #line_ending
  -- Single line case
  if start_range.line_idx == end_range.line_idx then
    return end_range.char_idx - start_range.char_idx
  end

  local start_line = lines[start_range.line_idx]
  local range_length --- @type integer
  if start_line and #start_line > 0 then
    range_length = str_utfindex(start_line, position_encoding)
      - start_range.char_idx
      + 1
      + line_ending_length
  else
    -- Length of newline character
    range_length = line_ending_length
  end

  -- The first and last range of the line idx may be partial lines
  for idx = start_range.line_idx + 1, end_range.line_idx - 1 do
    -- Length full line plus newline character
    if #lines[idx] > 0 then
      range_length = range_length
        + str_utfindex(assert(lines[idx]), position_encoding)
        + #line_ending
    else
      range_length = range_length + line_ending_length
    end
  end

  local end_line = lines[end_range.line_idx]
  if end_line and #end_line > 0 then
    range_length = range_length + end_range.char_idx - 1
  end

  return range_length
end

--- Returns the range table for the difference between prev and curr lines
---@param prev_lines table list of lines
---@param curr_lines table list of lines
---@param firstline integer 0-indexed line to begin search for first difference
---@param lastline integer 0-indexed line to begin search in old_lines for last difference
---@param new_lastline integer 0-indexed line to begin search in new_lines for last difference
---@param position_encoding 'utf-8'|'utf-16'|'utf-32' encoding requested by language server
---@param line_ending string
---@param prev_eol boolean whether the previous buffer text ended with a line ending
---@param curr_eol boolean whether the current buffer text ends with a line ending
---@return lsp.TextDocumentContentChangeEvent : see https://microsoft.github.io/language-server-protocol/specification/#textDocumentContentChangeEvent
function M.compute_diff(
  prev_lines,
  curr_lines,
  firstline,
  lastline,
  new_lastline,
  position_encoding,
  line_ending,
  prev_eol,
  curr_eol
)
  if prev_eol ~= curr_eol then
    return {
      text = table.concat(curr_lines, line_ending) .. (curr_eol and line_ending or ''),
    }
  end

  -- A special case for the following `firstline == new_lastline` case where lines are deleted.
  -- Even if the buffer has become empty, nvim behaves as if it has an empty line with eol.
  if #curr_lines == 1 and curr_lines[1] == '' then
    new_lastline = 1
  end

  -- The range [firstline, lastline) is half-open: prev_lines[firstline + 1] may differ from
  -- curr_lines[firstline + 1], but with the adjustment above, prev_lines[lastline + 1] is
  -- equal to curr_lines[new_lastline + 1]. It's possible that both are nil.

  -- The start of changes between the previous and current buffer. Common between both.
  -- Sent to the server as the start of the changed range.
  -- Used to grab the changed text from the latest buffer.
  local start_range = {
    line_idx = firstline + 1,
    byte_idx = 1,
    char_idx = 1,
  }

  -- When we delete the last line from a buffer without 'eol' set, we want to emit the change
  -- that deletes the eol character of the line before that line instead of after.
  -- For simplicity, we just also compare the line before. This shouldn't matter unless the line
  -- before is very long.
  if start_range.line_idx > 1 then
    start_range.line_idx = start_range.line_idx - 1
  end

  -- The last position changed in the previous and current buffer.
  -- prev_end_range is sent to the server as the end of the changed range.
  -- curr_end_range is used to grab the changed text from the latest buffer.
  local prev_end_range = {
    line_idx = lastline + 1,
    byte_idx = 1,
    char_idx = 1,
  }
  local curr_end_range = {
    line_idx = new_lastline + 1,
    byte_idx = 1,
    char_idx = 1,
  }

  -- Simultaneously shrink prev_end_range and curr_end_range as much as possible while they're still
  -- after start_range.
  -- Note that throughout the shrinking procedure, the replacement range remains valid.
  -- Start with comparing whole lines.
  while
    prev_end_range.line_idx > start_range.line_idx
    and curr_end_range.line_idx > start_range.line_idx
    and assert(prev_lines[prev_end_range.line_idx - 1])
      == assert(curr_lines[curr_end_range.line_idx - 1])
  do
    prev_end_range.line_idx = prev_end_range.line_idx - 1
    curr_end_range.line_idx = curr_end_range.line_idx - 1
  end

  -- Now shrink by character.
  if
    prev_end_range.line_idx > start_range.line_idx
    and curr_end_range.line_idx > start_range.line_idx
  then
    -- First, shrink the common newline character.
    prev_end_range.line_idx = prev_end_range.line_idx - 1
    curr_end_range.line_idx = curr_end_range.line_idx - 1
    local prev_line = assert(prev_lines[prev_end_range.line_idx])
    local curr_line = assert(curr_lines[curr_end_range.line_idx])
    prev_end_range.byte_idx = #prev_line + 1
    curr_end_range.byte_idx = #curr_line + 1

    -- Then, shrink the characters byte by byte.
    while
      prev_end_range.byte_idx > 1
      and curr_end_range.byte_idx > 1
      and str_byte(prev_line, prev_end_range.byte_idx - 1)
        == str_byte(curr_line, curr_end_range.byte_idx - 1)
    do
      prev_end_range.byte_idx = prev_end_range.byte_idx - 1
      curr_end_range.byte_idx = curr_end_range.byte_idx - 1
    end

    -- Recompute char index and round byte index upwards to the end of a UTF-8 sequence.
    prev_end_range.char_idx = str_utfindex(
      prev_line,
      position_encoding,
      prev_end_range.byte_idx - 1
    ) + 1
    curr_end_range.char_idx = str_utfindex(
      curr_line,
      position_encoding,
      curr_end_range.byte_idx - 1
    ) + 1
    prev_end_range.byte_idx = str_byteindex(
      prev_line,
      position_encoding,
      prev_end_range.char_idx - 1
    ) + 1
    curr_end_range.byte_idx = str_byteindex(
      curr_line,
      position_encoding,
      curr_end_range.char_idx - 1
    ) + 1
  end

  -- Do the same procedure, but go forward from start instead.
  while
    prev_end_range.line_idx > start_range.line_idx
    and curr_end_range.line_idx > start_range.line_idx
    and assert(prev_lines[start_range.line_idx]) == assert(curr_lines[start_range.line_idx])
  do
    start_range.line_idx = start_range.line_idx + 1
  end

  -- Now, if both ranges are nonempty, shrink by character.
  if
    (
      start_range.line_idx ~= prev_end_range.line_idx
      or start_range.byte_idx ~= prev_end_range.byte_idx
    )
    and (
      start_range.line_idx ~= curr_end_range.line_idx
      or start_range.byte_idx ~= curr_end_range.byte_idx
    )
  then
    local prev_line = assert(prev_lines[start_range.line_idx])
    local curr_line = assert(curr_lines[start_range.line_idx])

    local max_shrink_bytes = min(#prev_line, #curr_line)
    if start_range.line_idx == prev_end_range.line_idx then
      max_shrink_bytes = min(max_shrink_bytes, prev_end_range.byte_idx - 1)
    end
    if start_range.line_idx == curr_end_range.line_idx then
      max_shrink_bytes = min(max_shrink_bytes, curr_end_range.byte_idx - 1)
    end

    for idx = 1, max_shrink_bytes + 1 do
      start_range.byte_idx = idx
      if str_byte(prev_line, idx) ~= str_byte(curr_line, idx) then
        break
      end
    end

    -- Recompute char index and round byte index downwards to the start of a UTF-8 sequence.
    if start_range.byte_idx <= #prev_line then
      start_range.byte_idx = start_range.byte_idx
        + vim.str_utf_start(prev_line, start_range.byte_idx)
    end
    start_range.char_idx = str_utfindex(prev_line, position_encoding, start_range.byte_idx - 1) + 1
  end

  -- Grab the changed text from start_range to curr_end_range in the current buffer (in the
  -- curr_lines variable).
  -- The text range is "" if entire range is deleted.
  local text = extract_text(curr_lines, start_range, curr_end_range, line_ending)

  -- Compute the range of the replaced text. Deprecated but still required for certain language servers
  local range_length =
    compute_range_length(prev_lines, start_range, prev_end_range, position_encoding, line_ending)

  -- convert to 0 based indexing
  local result = {
    range = {
      ['start'] = { line = start_range.line_idx - 1, character = start_range.char_idx - 1 },
      ['end'] = { line = prev_end_range.line_idx - 1, character = prev_end_range.char_idx - 1 },
    },
    text = text,
    rangeLength = range_length,
  }

  return result
end

return M
