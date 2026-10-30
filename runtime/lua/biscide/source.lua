-- The declarations' code as their files have it (a file's buffer when it
-- is loaded: the text being edited), read once per layout (the lanes read
-- many): a declaration's lines, where a name is used in it.

local M = {}

---@type table<string, string[]>
local cache = {}

--- Forgets what was read (the files may have changed).
function M.clear()
  cache = {}
end

---@param path string
---@return string[]
local function file_lines(path)
  local lines = cache[path]
  -- The buffer of the file, when it is loaded: its text as being edited.
  local buf = not lines and vim.fn.bufnr(path) or -1
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    cache[path] = lines
  end
  if not lines then
    local f = io.open(path, "rb")
    local text = f and f:read("*a") or ""
    if f then
      f:close()
    end
    lines = vim.split(text, "\n", { plain = true })
    for k, l in ipairs(lines) do
      lines[k] = l:gsub("\r$", "")
    end
    cache[path] = lines
  end
  return lines
end

--- A file's lines (its buffer's when it is loaded).
---@param path string
---@return string[]
function M.file(path)
  return file_lines(path)
end

--- A declaration's lines.
---@param n table a graph node
---@return string[]
function M.lines(n)
  local all = file_lines(n.path)
  return vim.list_slice(all, n.srow + 1, math.min(n.erow + 1, #all))
end

local function is_word(c)
  return c ~= "" and (c:match("[%w_]") ~= nil or c:byte() >= 0x80)
end

--- Every place `name` is used, as a whole word, in node `n`'s code:
--- { row (from the declaration's first line, from 0), start byte, end byte }.
---@param n table
---@param name string
---@param first_only? boolean
---@return { [1]: integer, [2]: integer, [3]: integer }[]
function M.uses(n, name, first_only)
  local out = {}
  if not name or name == "" then
    return out
  end
  for k, line in ipairs(M.lines(n)) do
    local from = 1
    while true do
      local s, e = line:find(name, from, true)
      if not s then
        break
      end
      if not is_word(line:sub(s - 1, s - 1)) and not is_word(line:sub(e + 1, e + 1)) then
        out[#out + 1] = { k - 1, s - 1, e }
        if first_only then
          return out
        end
      end
      from = e + 1
    end
  end
  return out
end

--- Where `name` is first used in node `n`'s code, if it is.
---@return { [1]: integer, [2]: integer }?
function M.first_use(n, name)
  local u = M.uses(n, name, true)[1]
  return u and { u[1], u[2] }
end

return M
