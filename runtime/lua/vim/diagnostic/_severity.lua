local severity = vim.diagnostic.severity

--- @class (private) vim.diagnostic._severity
local M = {}

--- @param value string|vim.diagnostic.Severity?
--- @return vim.diagnostic.Severity?
function M.to_severity(value)
  if type(value) == 'string' then
    local ret = severity[value:upper()] --[[@as vim.diagnostic.Severity?]]
    if not ret then
      error(('Invalid severity: %s'):format(value))
    end
    return ret
  end

  return value --[[@as vim.diagnostic.Severity?]]
end

--- @param filter vim.diagnostic.SeverityFilter
--- @return fun(d: vim.Diagnostic):boolean
function M.severity_predicate(filter)
  if type(filter) ~= 'table' then
    local severity0 = M.to_severity(filter)
    --- @param d vim.Diagnostic
    return function(d)
      return d.severity == severity0
    end
  end

  --- @diagnostic disable-next-line: undefined-field
  if filter.min or filter.max then
    --- @cast filter {min:vim.diagnostic.Severity,max:vim.diagnostic.Severity}
    local min_severity = M.to_severity(filter.min) or severity.HINT
    local max_severity = M.to_severity(filter.max) or severity.ERROR

    --- @param d vim.Diagnostic
    return function(d)
      return d.severity <= min_severity and d.severity >= max_severity
    end
  end

  --- @cast filter vim.diagnostic.Severity[]
  local severities = {} --- @type table<vim.diagnostic.Severity,true>
  for _, s in ipairs(filter) do
    severities[assert(M.to_severity(s))] = true
  end

  --- @param d vim.Diagnostic
  return function(d)
    return severities[d.severity]
  end
end

--- @param filter vim.diagnostic.SeverityFilter?
--- @param diagnostics vim.Diagnostic[]
--- @return vim.Diagnostic[]
function M.filter_by_severity(filter, diagnostics)
  if not filter then
    return diagnostics
  end

  return vim.tbl_filter(M.severity_predicate(filter), diagnostics)
end

--- Parse a diagnostic from a string.
---
--- @param str string String to parse diagnostics from.
--- @param pat string Lua pattern with capture groups.
--- @param groups string[] List of fields in a |vim.Diagnostic| structure to associate with captures from {pat}.
--- @param severity_map table? A table mapping the severity field from {groups} with an item from |vim.diagnostic.severity|.
--- @param defaults table? Table of default values for any fields not listed in {groups}.
--- @return vim.Diagnostic?
function M.match(str, pat, groups, severity_map, defaults)
  vim.validate('str', str, 'string')
  vim.validate('pat', pat, 'string')
  vim.validate('groups', groups, 'table')
  vim.validate('severity_map', severity_map, 'table', true)
  vim.validate('defaults', defaults, 'table', true)

  --- @type table<string,vim.diagnostic.Severity>
  severity_map = severity_map or severity

  local matches = { str:match(pat) } --- @type any[]
  if vim.tbl_isempty(matches) then
    return
  end

  local diagnostic = {} --- @type table<string,any>
  for i, match in ipairs(matches) do
    local field = groups[i]
    if field == 'severity' then
      diagnostic[field] = severity_map[match]
    elseif field == 'lnum' or field == 'end_lnum' or field == 'col' or field == 'end_col' then
      diagnostic[field] = vim._assert_integer(match) - 1
    elseif field then
      diagnostic[field] = match
    end
  end

  diagnostic = vim.tbl_extend('keep', diagnostic, defaults or {}) --- @type vim.Diagnostic
  diagnostic.severity = diagnostic.severity or severity.ERROR
  diagnostic.col = diagnostic.col or 0
  diagnostic.end_lnum = diagnostic.end_lnum or diagnostic.lnum
  diagnostic.end_col = diagnostic.end_col or diagnostic.col
  return diagnostic
end

return M
