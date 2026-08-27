-- Lua implementations of "vimfn" builtin functions (via `func_lua`).
--
-- Functions defined here are pure Lua, they don't have any explicit C impl, so they are named with
-- the "f_xx" convention, for discoverability.

local M = {}

--- Returns the hostname of the machine.
--- @return string
function M.f_hostname()
  return vim.uv.os_gethostname()
end

--- Returns all environment variables as a dictionary.
--- @return table<string, string>
function M.f_environ()
  local env = vim.uv.os_environ() ---@type table<string, string>
  if vim.fn.has('win32') == 1 then -- Vim/legacy behavior: force uppercase keys on Windows. #39443
    local upper = {} --- @type table<string, string>
    for k, v in pairs(env) do
      upper[k:upper()] = v
    end
    return upper
  end
  return env
end

return M
