-- Converted into Lua from https://github.com/cyjake/ssh-config
-- TODO (siddhantdev): deal with include directives

local M = {}

local whitespace_pattern = '%s'
local line_break_pattern = '[\r\n]'

---@param param string
local function is_multi_value_directive(param)
  local multi_value_directives = {
    'globalknownhostsfile',
    'host',
    'ipqos',
    'sendenv',
    'userknownhostsfile',
    'proxycommand',
    'match',
    'canonicaldomains',
  }

  return vim.list_contains(multi_value_directives, param:lower())
end

---@param text string The ssh configuration which needs to be parsed
---@return string[] The parsed host names in the configuration
function M.parse_ssh_config(text)
  local i = 1
  local line = 1

  local function consume()
    if i <= #text then
      local char = text:sub(i, i)
      i = i + 1
      return char
    end
    return nil
  end

  local chr = consume()

  local function parse_spaces()
    local spaces = ''
    while chr and chr:match(whitespace_pattern) do
      spaces = spaces .. chr
      chr = consume()
    end
    return spaces
  end

  local function parse_linebreaks()
    local breaks = ''
    while chr and chr:match(line_break_pattern) do
      line = line + 1
      breaks = breaks .. chr
      chr = consume()
    end
    return breaks
  end

  local function parse_parameter_name()
    local param = ''
    while chr and not chr:match('[ \t=]') do
      param = param .. chr
      chr = consume()
    end
    return param
  end

  local function parse_separator()
    local sep = parse_spaces()
    if chr == '=' then
      sep = sep .. chr
      chr = consume()
    end
    return sep .. parse_spaces()
  end

  local function parse_value()
    local val = {}
    local quoted, escaped = false, false

    while chr and not chr:match(line_break_pattern) do
      if escaped then
        table.insert(val, chr == '"' and chr or '\\' .. chr)
        escaped = false
      elseif chr == '"' and (val == {} or quoted) then
        quoted = not quoted
      elseif chr == '\\' then
        escaped = true
      elseif chr == '#' and not quoted then
        break
      else
        table.insert(val, chr)
      end
      chr = consume()
    end

    if quoted or escaped then
      error('Unexpected line break at line ' .. line)
    end

    return vim.trim(table.concat(val))
  end

  local function parse_comment()
    while chr and not chr:match(line_break_pattern) do
      chr = consume()
    end
  end

  ---@return string[]
  local function parse_multiple_values()
    local results = {}
    local val = {}
    local quoted = false
    local escaped = false

    while chr and not chr:match(line_break_pattern) do
      if escaped then
        table.insert(val, chr == '"' and chr or '\\' .. chr)
        escaped = false
      elseif chr == '"' then
        quoted = not quoted
      elseif chr == '\\' then
        escaped = true
      elseif quoted then
        table.insert(val, chr)
      elseif chr:match('[ \t=]') then
        if val ~= {} then
          table.insert(results, vim.trim(table.concat(val)))
          val = {}
        end
      elseif chr == '#' and #results > 0 then
        break
      else
        table.insert(val, chr)
      end
      chr = consume()
    end

    if quoted or escaped then
      error('Unexpected line break at line ' .. line)
    end

    if val ~= {} then
      table.insert(results, vim.trim(table.concat(val)))
    end

    return results
  end

  local function parse_directive()
    local param = parse_parameter_name()
    local multiple = is_multi_value_directive(param)
    local _ = parse_separator()
    local value = multiple and parse_multiple_values() or parse_value()

    local result = {
      param = param,
      value = value,
    }

    return result
  end

  local function parse_line()
    local _ = parse_spaces()
    if chr == '#' then
      parse_comment()
      return nil
    end
    local node = parse_directive()
    local _ = parse_linebreaks()

    return node
  end

  local hostnames = {}

  ---@param value string
  local function is_valid(value)
    return not (value:find('[?*!]') or vim.list_contains(hostnames, value))
  end

  while chr do
    local node = parse_line()
    if node then
      -- This is done just to assign the type
      node.value = node.value ---@type string[]
      if node.param:lower() == 'match' and node.value then
        local current = nil
        for ind, val in ipairs(node.value) do
          if val:lower() == 'host' and ind + 1 <= #node.value and is_valid(node.value[ind + 1]) then
            current = node.value[ind + 1]
          end
        end
        if current then
          table.insert(hostnames, current)
        end
      elseif node.param:lower() == 'host' and node.value then
        for _, value in ipairs(node.value) do
          if is_valid(value) then
            table.insert(hostnames, value)
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

---@class vim.net.SshHost
---@field alias string Host alias from ssh config
---@field hostname? string Resolved Hostname directive
---@field user? string User directive
---@field port? string Port directive
---@field identity_file? string IdentityFile directive

---@param filename? string Path to the SSH config file. Defaults to ~/.ssh/config
---@return vim.net.SshHost[] hosts List of parsed host configurations
function M.get_hosts_full(filename)
  filename = filename or vim.fs.normalize('~/.ssh/config')
  local file = io.open(filename, 'r')
  if not file then
    return {}
  end
  local text = file:read('*a')
  file:close()

  ---@type vim.net.SshHost[]
  local hosts = {}
  ---@type vim.net.SshHost?
  local current_host = nil

  for line in vim.gsplit(text, '\n', { plain = true }) do
    local trimmed = vim.trim(line)
    if trimmed == '' or trimmed:sub(1, 1) == '#' then
      -- skip empty lines and comments
    else
      local key, value = trimmed:match('^(%S+)%s+(.+)$')
      if not key then
        key, value = trimmed:match('^(%S+)=(.+)$')
      end
      if key then
        ---@type string
        local lkey = key:lower()
        if lkey == 'host' then
          if current_host then
            table.insert(hosts, current_host)
          end
          -- skip wildcard-only patterns
          if value:find('[?*!]') then
            current_host = nil
          else
            current_host = { alias = vim.trim(value) }
          end
        elseif lkey == 'match' then
          if current_host then
            table.insert(hosts, current_host)
          end
          current_host = nil
        elseif current_host then
          if lkey == 'hostname' then
            current_host.hostname = vim.trim(value)
          elseif lkey == 'user' then
            current_host.user = vim.trim(value)
          elseif lkey == 'port' then
            current_host.port = vim.trim(value)
          elseif lkey == 'identityfile' then
            current_host.identity_file = vim.trim(value)
          end
        end
      end
    end
  end
  -- flush last host
  if current_host then
    table.insert(hosts, current_host)
  end

  return hosts
end

---@class vim.net.SshUri
---@field host string
---@field user? string
---@field port? string

---@param str string
---@return vim.net.SshUri
function M.parse_uri(str)
  ---@type vim.net.SshUri
  local uri = { host = '' }
  ---@type string?
  local scheme_match = str:match('^ssh://(.*)')
  if scheme_match then
    str = scheme_match
  end
  local user_match = str:match('^(.-)@(.*)')
  if user_match then
    uri.user = str:match('^(.-)@')
    str = str:match('@(.*)')
  end
  local port_match = str:match(':(%d+)$')
  if port_match then
    uri.port = port_match
    str = str:sub(1, -(#port_match + 2))
  end
  uri.host = str
  return uri
end

return M
