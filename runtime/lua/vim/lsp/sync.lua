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
local str_utf_start = vim.str_utf_start
local str_utf_end = vim.str_utf_end

-- Given a line, byte idx, alignment, and offset_encoding convert to the aligned
-- utf-8 index and either the utf-16, or utf-32 index.
---@param line string the line to index into
---@param byte integer the byte idx
---@param offset_encoding string utf-8|utf-16|utf-32|nil (default: utf-8)
---@return integer byte_idx of first change position
---@return integer char_idx of first change position
local function align_end_position(line, byte, offset_encoding)
  local char --- @type integer
  -- If on the first byte, or an empty string: the trivial case
  if byte == 1 or #line == 0 then
    char = byte
    -- Called in the case of extending an empty line "" -> "a"
  elseif byte == #line + 1 then
    char = str_utfindex(line, offset_encoding) + 1
  else
    -- Modifying line, find the nearest utf codepoint
    local offset = str_utf_start(line, byte)
    -- If the byte does not fall on the start of the character, then
    -- align to the start of the next character.
    if offset < 0 then
      byte = byte + str_utf_end(line, byte) + 1
    end
    if byte <= #line then
      --- Convert to 0 based for input, and from 0 based for output
      char = str_utfindex(line, offset_encoding, byte - 1) + 1
    else
      char = str_utfindex(line, offset_encoding) + 1
    end
    -- Extending line, find the nearest utf codepoint for the last valid character
  end
  return byte, char
end

---@class vim.lsp.sync.Range
---@field line_idx integer
---@field byte_idx integer
---@field char_idx integer

--- Finds the first line, byte, and char index of the difference between the previous and current lines buffer normalized to the previous codepoint.
---@param prev_lines string[] list of lines from previous buffer
---@param curr_lines string[] list of lines from current buffer
---@param firstline integer firstline from on_lines, adjusted to 1-index
---@param lastline integer lastline from on_lines, adjusted to 1-index
---@param new_lastline integer new_lastline from on_lines, adjusted to 1-index
---@param offset_encoding string utf-8|utf-16|utf-32|nil (fallback to utf-8)
---@return vim.lsp.sync.Range result table include line_idx, byte_idx, and char_idx of first change position
local function compute_start_range(
  prev_lines,
  curr_lines,
  firstline,
  lastline,
  new_lastline,
  offset_encoding
)
  local char_idx --- @type integer?
  local byte_idx --- @type integer?
  -- If firstline == lastline, no existing text is changed. All edit operations
  -- occur on a new line pointed to by lastline. This occurs during insertion of
  -- new lines(O), the new newline is inserted at the line indicated by
  -- new_lastline.
  if firstline == lastline then
    local line_idx --- @type integer
    local line = prev_lines[firstline - 1]
    if line then
      line_idx = firstline - 1
      byte_idx = #line + 1
      char_idx = str_utfindex(line, offset_encoding) + 1
    else
      line_idx = firstline
      byte_idx = 1
      char_idx = 1
    end
    return { line_idx = line_idx, byte_idx = byte_idx, char_idx = char_idx }
  end

  -- If firstline == new_lastline, the first change occurred on a line that was deleted.
  -- In this case, the first byte change is also at the first byte of firstline
  if firstline == new_lastline then
    return { line_idx = firstline, byte_idx = 1, char_idx = 1 }
  end

  local prev_line = prev_lines[firstline]
  local curr_line = curr_lines[firstline]

  -- Iterate across previous and current line containing first change
  -- to find the first different byte.
  -- Note: *about -> a*about will register the second a as the first
  -- difference, regardless of edit since we do not receive the first
  -- column of the edit from on_lines.
  local start_byte_idx = 1
  for idx = 1, #prev_line + 1 do
    start_byte_idx = idx
    if str_byte(prev_line, idx) ~= str_byte(curr_line, idx) then
      break
    end
  end

  -- Convert byte to codepoint if applicable
  if start_byte_idx == 1 or (#prev_line == 0 and start_byte_idx == 1) then
    byte_idx = start_byte_idx
    char_idx = 1
  elseif start_byte_idx == #prev_line + 1 then
    byte_idx = start_byte_idx
    char_idx = str_utfindex(prev_line, offset_encoding) + 1
  else
    byte_idx = start_byte_idx + str_utf_start(prev_line, start_byte_idx)
    --- Convert to 0 based for input, and from 0 based for output
    char_idx = vim.str_utfindex(prev_line, offset_encoding, byte_idx - 1) + 1
  end

  -- Return the start difference (shared for new and prev lines)
  return { line_idx = firstline, byte_idx = byte_idx, char_idx = char_idx }
end

--- Finds the last line and byte index of the differences between prev and current buffer.
--- Normalized to the next codepoint.
--- prev_end_range is the text range sent to the server representing the changed region.
--- curr_end_range is the text that should be collected and sent to the server.
---
---@param prev_lines string[] list of lines
---@param curr_lines string[] list of lines
---@param start_range vim.lsp.sync.Range
---@param firstline integer
---@param lastline integer
---@param new_lastline integer
---@param offset_encoding string
---@return vim.lsp.sync.Range prev_end_range
---@return vim.lsp.sync.Range curr_end_range
local function compute_end_range(
  prev_lines,
  curr_lines,
  start_range,
  firstline,
  lastline,
  new_lastline,
  offset_encoding
)
  -- A special case for the following `firstline == new_lastline` case where lines are deleted.
  -- Even if the buffer has become empty, nvim behaves as if it has an empty line with eol.
  if #curr_lines == 1 and curr_lines[1] == '' then
    local prev_line = prev_lines[lastline - 1]
    return {
      line_idx = lastline - 1,
      byte_idx = #prev_line + 1,
      char_idx = str_utfindex(prev_line, offset_encoding) + 1,
    }, { line_idx = 1, byte_idx = 1, char_idx = 1 }
  end
  -- If firstline == new_lastline, the first change occurred on a line that was deleted.
  -- In this case, the last_byte...
  if firstline == new_lastline then
    return { line_idx = (lastline - new_lastline + firstline), byte_idx = 1, char_idx = 1 }, {
      line_idx = firstline,
      byte_idx = 1,
      char_idx = 1,
    }
  end
  if firstline == lastline then
    return { line_idx = firstline, byte_idx = 1, char_idx = 1 }, {
      line_idx = new_lastline - lastline + firstline,
      byte_idx = 1,
      char_idx = 1,
    }
  end
  -- Compare on last line, at minimum will be the start range
  local start_line_idx = start_range.line_idx

  -- lastline and new_lastline were last lines that were *not* replaced, compare previous lines
  local prev_line_idx = lastline - 1
  local curr_line_idx = new_lastline - 1

  local prev_line = prev_lines[lastline - 1]
  local curr_line = curr_lines[new_lastline - 1]

  local prev_line_length = #prev_line
  local curr_line_length = #curr_line

  local byte_offset = 0

  -- Editing the same line
  -- If the byte offset is zero, that means there is a difference on the last byte (not newline)
  if prev_line_idx == curr_line_idx then
    local max_length --- @type integer
    if start_line_idx == prev_line_idx then
      -- Search until beginning of difference
      max_length = min(
        prev_line_length - start_range.byte_idx,
        curr_line_length - start_range.byte_idx
      ) + 1
    else
      max_length = min(prev_line_length, curr_line_length) + 1
    end
    for idx = 0, max_length do
      byte_offset = idx
      if
        str_byte(prev_line, prev_line_length - byte_offset)
        ~= str_byte(curr_line, curr_line_length - byte_offset)
      then
        break
      end
    end
  end

  -- Iterate from end to beginning of shortest line
  local prev_end_byte_idx = prev_line_length - byte_offset + 1

  -- Handle case where lines match
  if prev_end_byte_idx == 0 then
    prev_end_byte_idx = 1
  end
  local prev_byte_idx, prev_char_idx =
    align_end_position(prev_line, prev_end_byte_idx, offset_encoding)
  local prev_end_range =
    { line_idx = prev_line_idx, byte_idx = prev_byte_idx, char_idx = prev_char_idx }

  local curr_end_range ---@type vim.lsp.sync.Range
  -- Deletion event, new_range cannot be before start
  if curr_line_idx < start_line_idx then
    curr_end_range = { line_idx = start_line_idx, byte_idx = 1, char_idx = 1 }
  else
    local curr_end_byte_idx = curr_line_length - byte_offset + 1
    -- Handle case where lines match
    if curr_end_byte_idx == 0 then
      curr_end_byte_idx = 1
    end
    local curr_byte_idx, curr_char_idx =
      align_end_position(curr_line, curr_end_byte_idx, offset_encoding)
    curr_end_range =
      { line_idx = curr_line_idx, byte_idx = curr_byte_idx, char_idx = curr_char_idx }
  end

  return prev_end_range, curr_end_range
end

--- Get the text of the range defined by start and end line/column
---@param lines table list of lines
---@param start_range table table returned by first_difference
---@param end_range table new_end_range returned by last_difference
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

-- rangelength depends on the offset encoding
-- bytes for utf-8 (clangd with extension)
-- codepoints for utf-16
-- codeunits for utf-32
-- Line endings count here as 2 chars for \r\n (dos), 1 char for \n (unix), and 1 char for \r (mac)
-- These correspond to Windows, Linux/macOS (OSX and newer), and macOS (version 9 and prior)
---@param lines string[]
---@param start_range vim.lsp.sync.Range
---@param end_range vim.lsp.sync.Range
---@param offset_encoding string
---@param line_ending string
---@return integer
local function compute_range_length(lines, start_range, end_range, offset_encoding, line_ending)
  local line_ending_length = #line_ending
  -- Single line case
  if start_range.line_idx == end_range.line_idx then
    return end_range.char_idx - start_range.char_idx
  end

  local start_line = lines[start_range.line_idx]
  local range_length --- @type integer
  if start_line and #start_line > 0 then
    range_length = str_utfindex(start_line, offset_encoding)
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
      range_length = range_length + str_utfindex(lines[idx], offset_encoding) + #line_ending
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
---@param firstline integer line to begin search for first difference
---@param lastline integer line to begin search in old_lines for last difference
---@param new_lastline integer line to begin search in new_lines for last difference
---@param offset_encoding string encoding requested by language server
---@param line_ending string
---@return lsp.TextDocumentContentChangeEvent : see https://microsoft.github.io/language-server-protocol/specification/#textDocumentContentChangeEvent
function M.compute_diff(
  prev_lines,
  curr_lines,
  firstline,
  lastline,
  new_lastline,
  offset_encoding,
  line_ending
)
  -- Find the start of changes between the previous and current buffer. Common between both.
  -- Sent to the server as the start of the changed range.
  -- Used to grab the changed text from the latest buffer.
  local start_range = compute_start_range(
    prev_lines,
    curr_lines,
    firstline + 1,
    lastline + 1,
    new_lastline + 1,
    offset_encoding
  )
  -- Find the last position changed in the previous and current buffer.
  -- prev_end_range is sent to the server as as the end of the changed range.
  -- curr_end_range is used to grab the changed text from the latest buffer.
  local prev_end_range, curr_end_range = compute_end_range(
    prev_lines,
    curr_lines,
    start_range,
    firstline + 1,
    lastline + 1,
    new_lastline + 1,
    offset_encoding
  )

  -- Grab the changed text of from start_range to curr_end_range in the current buffer.
  -- The text range is "" if entire range is deleted.
  local text = extract_text(curr_lines, start_range, curr_end_range, line_ending)

  -- Compute the range of the replaced text. Deprecated but still required for certain language servers
  local range_length =
    compute_range_length(prev_lines, start_range, prev_end_range, offset_encoding, line_ending)

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
