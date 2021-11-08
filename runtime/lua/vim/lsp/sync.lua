---@private
--- Finds the first line and column of the difference between old and new lines
---@param old_lines table list of lines
---@param new_lines table list of lines
---@returns (int, int) start_line_idx and start_col_idx of range
local function first_difference(old_lines, new_lines, start_line_idx)
  local line_count = math.min(#old_lines, #new_lines)
  if line_count == 0 then return 1, 1 end
  if not start_line_idx then
    for i = 1, line_count do
      start_line_idx = i
      if old_lines[start_line_idx] ~= new_lines[start_line_idx] then
        break
      end
    end
  end
  local old_line = old_lines[start_line_idx]
  local new_line = new_lines[start_line_idx]
  local length = math.min(#old_line, #new_line)
  local start_col_idx = 1
  while start_col_idx <= length do
    if string.sub(old_line, start_col_idx, start_col_idx) ~= string.sub(new_line, start_col_idx, start_col_idx) then
      break
    end
    start_col_idx  = start_col_idx  + 1
  end
  return start_line_idx, start_col_idx
end


---@private
--- Finds the last line and column of the differences between old and new lines
---@param old_lines table list of lines
---@param new_lines table list of lines
---@param start_char integer First different character idx of range
---@returns (int, int) end_line_idx and end_col_idx of range
local function last_difference(old_lines, new_lines, start_char, end_line_idx)
  local line_count = math.min(#old_lines, #new_lines)
  if line_count == 0 then return 0,0 end
  if not end_line_idx then
    end_line_idx = -1
  end
  for i = end_line_idx, -line_count, -1  do
    if old_lines[#old_lines + i + 1] ~= new_lines[#new_lines + i + 1] then
      end_line_idx = i
      break
    end
  end
  local old_line
  local new_line
  if end_line_idx <= -line_count then
    end_line_idx = -line_count
    old_line  = string.sub(old_lines[#old_lines + end_line_idx + 1], start_char)
    new_line  = string.sub(new_lines[#new_lines + end_line_idx + 1], start_char)
  else
    old_line  = old_lines[#old_lines + end_line_idx + 1]
    new_line  = new_lines[#new_lines + end_line_idx + 1]
  end
  local old_line_length = #old_line
  local new_line_length = #new_line
  local length = math.min(old_line_length, new_line_length)
  local end_col_idx = -1
  while end_col_idx >= -length do
    local old_char =  string.sub(old_line, old_line_length + end_col_idx + 1, old_line_length + end_col_idx + 1)
    local new_char =  string.sub(new_line, new_line_length + end_col_idx + 1, new_line_length + end_col_idx + 1)
    if old_char ~= new_char then
      break
    end
    end_col_idx = end_col_idx - 1
  end
  return end_line_idx, end_col_idx

end

---@private
--- Get the text of the range defined by start and end line/column
---@param lines table list of lines
---@param start_char integer First different character idx of range
---@param end_char integer Last different character idx of range
---@param start_line integer First different line idx of range
---@param end_line integer Last different line idx of range
---@returns string text extracted from defined region
local function extract_text(lines, start_line, start_char, end_line, end_char)
  if start_line == #lines + end_line + 1 then
    if end_line == 0 then return '' end
    local line = lines[start_line]
    local length = #line + end_char - start_char
    return string.sub(line, start_char, start_char + length + 1)
  end
  local result = string.sub(lines[start_line], start_char) .. '\n'
  for line_idx = start_line + 1, #lines + end_line do
    result = result .. lines[line_idx] .. '\n'
  end
  if end_line ~= 0 then
    local line = lines[#lines + end_line + 1]
    local length = #line + end_char + 1
    result = result .. string.sub(line, 1, length)
  end
  return result
end

---@private
--- Compute the length of the substituted range
---@param lines table list of lines
---@param start_char integer First different character idx of range
---@param end_char integer Last different character idx of range
---@param start_line integer First different line idx of range
---@param end_line integer Last different line idx of range
---@returns (int, int) end_line_idx and end_col_idx of range
local function compute_length(lines, start_line, start_char, end_line, end_char)
  local adj_end_line = #lines + end_line + 1
  local adj_end_char
  if adj_end_line > #lines then
    adj_end_char =  end_char - 1
  else
    adj_end_char = #lines[adj_end_line] + end_char
  end
  if start_line == adj_end_line then
    return adj_end_char - start_char + 1
  end
  local result = #lines[start_line] - start_char + 1
  for line = start_line + 1, adj_end_line -1 do
    result = result + #lines[line] + 1
  end
  result = result + adj_end_char + 1
  return result
end

--- Returns the range table for the difference between old and new lines
---@param old_lines table list of lines
---@param new_lines table list of lines
---@param start_line_idx int line to begin search for first difference
---@param end_line_idx int line to begin search for last difference
---@param offset_encoding string encoding requested by language server
---@returns table start_line_idx and start_col_idx of range
function M.compute_diff(old_lines, new_lines, start_line_idx, end_line_idx, offset_encoding)
  local start_line, start_char = first_difference(old_lines, new_lines, start_line_idx)
  local end_line, end_char = last_difference(vim.list_slice(old_lines, start_line, #old_lines),
      vim.list_slice(new_lines, start_line, #new_lines), start_char, end_line_idx)
  local text = extract_text(new_lines, start_line, start_char, end_line, end_char)
  local length = compute_length(old_lines, start_line, start_char, end_line, end_char)

  local adj_end_line = #old_lines + end_line
  local adj_end_char
  if end_line == 0 then
    adj_end_char = 0
  else
    adj_end_char = #old_lines[#old_lines + end_line + 1] + end_char + 1
  end

  local _
  if offset_encoding == "utf-16" then
    _, start_char = vim.str_utfindex(old_lines[start_line], start_char - 1)
    _, end_char = vim.str_utfindex(old_lines[#old_lines + end_line + 1], adj_end_char)
  else
    start_char = start_char - 1
    end_char = adj_end_char
  end

  local result = {
    range = {
      start = { line = start_line - 1, character = start_char},
      ["end"] = { line = adj_end_line, character = end_char}
    },
    text = text,
    rangeLength = length + 1,
  }

  return result
end
