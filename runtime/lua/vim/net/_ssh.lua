-- Converted into Lua from https://github.com/cyjake/ssh-config
-- TODO (siddhantdev): deal with include directives

local M            = {}

local lpeg         = vim.lpeg

local whitespace   = lpeg.S(" \t")
local newline      = lpeg.P("\r\n") + lpeg.S("\r\n")
local any          = lpeg.P(1)

local keyword      =
    lpeg.C((lpeg.R("az") + lpeg.R("AZ") + lpeg.S("-_")) ^ 1) *
    ((whitespace ^ 0 * lpeg.P('=')) + whitespace ^ 1) *
    (whitespace ^ 0)

local quoted_arg   =
    lpeg.P('"') *
    lpeg.Cs(((lpeg.P('\\"') / '"') + (any - lpeg.P('"'))) ^ 0) *
    lpeg.P('"') *
    (whitespace ^ 0) *
    lpeg.P(",") ^ -1 *
    (whitespace ^ 0)

local bare_arg     =
    lpeg.C((any - (whitespace + newline + lpeg.S("#;,="))) ^ 1) *
    (whitespace ^ 0) *
    lpeg.S(",=") ^ -1 *
    (whitespace ^ 0)

local arg          = quoted_arg + bare_arg
local args         = lpeg.Ct(arg ^ 0)

local line_grammar = lpeg.Ct(
  whitespace ^ 0 *
  lpeg.Cg(keyword, "keyword") *
  lpeg.Cg(args, "args") *
  newline ^ -1
)

---@param text string The ssh configuration which needs to be parsed
---@return string[] The parsed host names in the configuration
function M.parse_ssh_config(text)
  local hostnames = {}

  ---@param hostname string
  local function is_seen(hostname)
    return vim.list_contains(hostnames, hostname)
  end

  for raw_line in (text .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    local parsed = line_grammar:match(raw_line)
    if parsed == nil then
      goto continue
    end

    -- These are done just to assign a type
    parsed.keyword = parsed.keyword ---@type string
    parsed.args = parsed.args ---@type string[]

    parsed.keyword = parsed.keyword:lower()
    if parsed.keyword == "host" then
      for _, hostname in ipairs(parsed.args) do
        if not is_seen(hostname) then
          table.insert(hostnames, hostname)
        end
      end
    elseif parsed.keyword == "match" then
      for ind, val in ipairs(parsed.args) do
        if val:lower() == 'host' and
            ind + 1 <= #parsed.args and
            not is_seen(parsed.args[ind + 1]) then
          table.insert(hostnames, parsed.args[ind + 1])
        end
      end
    end
    ::continue::
  end

  return hostnames
end

---@param filename string
---@return string[] The hostnames configured in the file located at filename
function M.parse_config(filename)
  local file = io.open(filename, 'r')
  if not file then
    error('Cannot read ssh configuration file')
  end
  local config_string = file:read('*a')
  file:close()

  return M.parse_ssh_config(config_string)
end

---@return string[] The hostnames configured in the ssh configuration file
---                 located at "~/.ssh/config".
---                 Note: This does not currently process `Include` directives in the
---                 configuration file.
function M.get_hosts()
  local config_path = vim.fs.normalize('~/.ssh/config') ---@type string

  return M.parse_config(config_path)
end

return M
