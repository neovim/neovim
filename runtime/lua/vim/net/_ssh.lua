-- Converted into Lua from https://github.com/cyjake/ssh-config
-- TODO (siddhantdev): deal with include directives

local M = {}

local lpeg = vim.lpeg

local whitespace = lpeg.S(' \t')
local newline = lpeg.P('\r\n') + lpeg.S('\r\n')
local letter = lpeg.R('az', 'AZ')
local any = lpeg.P(1)
local comment = lpeg.P('#') * (any - newline) ^ 0

---@param str string
---@param pos integer
---@param message string
local function report_error(str, pos, message)
  local line = 1

  for i = 1, pos - 1 do
    if str:sub(i, i) == '\n' then
      line = line + 1
    end
  end

  error(string.format(message .. " (at line '%s')", line))
end

---@param pattern vim.lpeg.Pattern
---@param message string
local function expect(pattern, message)
  return pattern + lpeg.P(function(str, pos)
    report_error(str, pos, message)
  end)
end

---@param str string
local function case_insensetive_pattern(str)
  local pat = lpeg.P(0)

  for i = 1, #str do
    local c = str:sub(i, i)
    pat = pat * (lpeg.S(c:lower() .. c:upper()))
  end

  return pat
end

---@param pattern vim.lpeg.Pattern
---@param has_args boolean
local function keyword_pattern(pattern, has_args)
  if not has_args then
    return pattern
      / string.lower
      * whitespace ^ 0
      * expect(-lpeg.P('='), 'keyword does not accept arguments')
  end

  return (pattern / string.lower)
    * ((whitespace ^ 0 * lpeg.P('=') * whitespace ^ 0) + whitespace ^ 1)
    * expect(-newline, string.format('expected arguments after keyword'))
end

local function ssh_line_pattern(pattern)
  return whitespace ^ 0 * pattern * comment ^ 0 * newline
end

local empty_line = ssh_line_pattern(true)

local host = keyword_pattern(case_insensetive_pattern('host'), true)
local canonical = keyword_pattern(case_insensetive_pattern('canonical'), false)
local final = keyword_pattern(case_insensetive_pattern('final'), false)
local all = keyword_pattern(case_insensetive_pattern('all'), false)
local exec = keyword_pattern(case_insensetive_pattern('exec'), true)
local localnetwork = keyword_pattern(case_insensetive_pattern('localnetwork'), true)
local originalhost = keyword_pattern(case_insensetive_pattern('originalhost'), true)
local tagged = keyword_pattern(case_insensetive_pattern('tagged'), true)
local command = keyword_pattern(case_insensetive_pattern('command'), true)
local user = keyword_pattern(case_insensetive_pattern('user'), true)
local localuser = keyword_pattern(case_insensetive_pattern('localuser'), true)
local version = keyword_pattern(case_insensetive_pattern('version'), true)
local match = keyword_pattern(case_insensetive_pattern('match'), true)
local arbitray_keyword = keyword_pattern(letter ^ 1, true) - host - match

local quoted_arg = lpeg.P('"')
  * lpeg.Cs(((lpeg.P('\\"') / '"') + (any - newline - lpeg.P('"'))) ^ 0)
  * expect(lpeg.P('"'), 'expected "')
local unquoted_arg = -lpeg.P('#') * lpeg.C((any - whitespace - newline - lpeg.S(',')) ^ 1)
local arg = quoted_arg + unquoted_arg
local args = lpeg.Ct((arg * ((whitespace ^ 0 * lpeg.P(',') * whitespace ^ 0) + whitespace ^ 0)) ^ 1)

local match_condition_without_arg = lpeg.Ct(lpeg.Cg(all + canonical + final, 'criteria'))
local match_condition_with_arg = lpeg.Ct(
  lpeg.Cg(
    host + exec + localnetwork + originalhost + tagged + command + user + localuser + version,
    'criteria'
  )
    * lpeg.Cg(
      expect(
        lpeg.Ct(quoted_arg + (unquoted_arg * lpeg.P(',') ^ 0) ^ 1),
        'expected argument after condition'
      ) * whitespace ^ 0,
      'args'
    )
)
local match_condition = match_condition_without_arg + match_condition_with_arg

local match_declaration = lpeg.Cg(match, 'type')
  * lpeg.Cg(lpeg.Ct(expect(match_condition ^ 1, 'expected condition after match')), 'conditions')
  * whitespace ^ 0
  * expect(#newline + #lpeg.P('#'), 'invalid condition for match')

local host_declaration = lpeg.Cg(host, 'type')
  * lpeg.Cg(expect(args, 'expected arguments after host'), 'patterns')

local declaration = lpeg.Ct(
  lpeg.Cg(arbitray_keyword, 'type')
    * lpeg.Cg(expect(args, 'expected arguments after keyword'), 'args')
)

local host_segment = lpeg.Ct(
  ssh_line_pattern(host_declaration)
    * lpeg.Cg(lpeg.Ct((ssh_line_pattern(declaration) + empty_line) ^ 0), 'declarations')
)

local match_segment = lpeg.Ct(
  ssh_line_pattern(match_declaration)
    * lpeg.Cg(lpeg.Ct((ssh_line_pattern(declaration) + empty_line) ^ 0), 'declarations')
)

local ssh_config = ssh_line_pattern(true) ^ 0
  * lpeg.Ct((host_segment + match_segment) ^ 0)
  * expect(-any, 'unexpected content')
---@param text string The ssh configuration which needs to be parsed
---@return string[] The parsed host names in the configuration
function M.parse_ssh_config(text)
  local hostnames = {}

  ---@param value string
  local function is_valid(value)
    return not (value:find('[?*!]') or vim.list_contains(hostnames, value))
  end

  ---@class HostSegment
  ---@field type "host"
  ---@field patterns string[]
  ---@field declarations table[]

  ---@class MatchCondition
  ---@field criteria string
  ---@field args string[]

  ---@class MatchSegment
  ---@field type "match"
  ---@field conditions MatchCondition[]
  ---@field declarations table[]

  ---@alias SSHConfigSegment HostSegment|MatchSegment

  ---@type SSHConfigSegment[]
  local parsed = ssh_config:match(text .. '\n')
  for _, segment in ipairs(parsed) do
    if segment.type == 'host' then
      for _, pattern in ipairs(segment.patterns) do
        if is_valid(pattern) then
          table.insert(hostnames, pattern)
        end
      end
    else -- if it's not a "Host", then it's a "Match"
      for _, cond in ipairs(segment.conditions) do
        if cond.criteria == 'host' then
          for _, pattern in ipairs(cond.args) do
            if is_valid(pattern) then
              table.insert(hostnames, pattern)
            end
          end
        end
      end
    end
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
