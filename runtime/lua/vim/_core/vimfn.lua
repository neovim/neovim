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
  return vim.uv.os_environ()
end

return M
