local M = {}

local LazyM = {}
M.LazyM = LazyM

---@class Semver
---@field [1] number
---@field [2] number
---@field [3] number
---@field major number
---@field minor number
---@field patch number
---@field prerelease? string
---@field build? string
local Semver = {}
Semver.__index = Semver

function Semver:__index(key)
  return type(key) == 'number' and ({ self.major, self.minor, self.patch })[key] or Semver[key]
end

function Semver:__newindex(key, value)
  if key == 1 then
    self.major = value
  elseif key == 2 then
    self.minor = value
  elseif key == 3 then
    self.patch = value
  else
    rawset(self, key, value)
  end
end

---@param other Semver
function Semver:__eq(other)
  for i = 1, 3 do
    if self[i] ~= other[i] then
      return false
    end
  end
  return self.prerelease == other.prerelease
end

function Semver:__tostring()
  local ret = table.concat({ self.major, self.minor, self.patch }, '.')
  if self.prerelease then
    ret = ret .. '-' .. self.prerelease
  end
  if self.build then
    ret = ret .. '+' .. self.build
  end
  return ret
end

---@param other Semver
function Semver:__lt(other)
  for i = 1, 3 do
    if self[i] > other[i] then
      return false
    elseif self[i] < other[i] then
      return true
    end
  end
  if self.prerelease and not other.prerelease then
    return true
  end
  if other.prerelease and not self.prerelease then
    return false
  end
  return (self.prerelease or '') < (other.prerelease or '')
end

---@param other Semver
function Semver:__le(other)
  return self < other or self == other
end

---@param version string|number[]
---@param strict? boolean Reject "1.0", "0-x" or other non-conforming version strings
---@return Semver?
function LazyM.version(version, strict)
  if type(version) == 'table' then
    return setmetatable({
      major = version[1] or 0,
      minor = version[2] or 0,
      patch = version[3] or 0,
    }, Semver)
  end

  local prerel = version:match('%-([^+]*)')
  local prerel_strict = version:match('%-([0-9A-Za-z-]*)')
  if
    strict
    and prerel
    and (prerel_strict == nil or prerel_strict == '' or not vim.startswith(prerel, prerel_strict))
  then
    return nil -- Invalid prerelease.
  end
  local build = prerel and version:match('%-[^+]*%+(.*)$') or version:match('%+(.*)$')
  local major, minor, patch =
    version:match('^v?(%d+)%.?(%d*)%.?(%d*)' .. (strict and (prerel and '%-' or '$') or ''))

  if
    (not strict and major)
    or (major and minor and patch and major ~= '' and minor ~= '' and patch ~= '')
  then
    return setmetatable({
      major = tonumber(major),
      minor = minor == '' and 0 or tonumber(minor),
      patch = patch == '' and 0 or tonumber(patch),
      prerelease = prerel ~= '' and prerel or nil,
      build = build ~= '' and build or nil,
    }, Semver)
  end
end

---@generic T: Semver
---@param versions T[]
---@return T?
function M.last(versions)
  local last = versions[1]
  for i = 2, #versions do
    if versions[i] > last then
      last = versions[i]
    end
  end
  return last
end

---@class SemverRange
---@field from Semver
---@field to? Semver
local Range = {}

---@param version string|Semver
function Range:matches(version)
  if type(version) == 'string' then
    ---@diagnostic disable-next-line: cast-local-type
    version = M.parse(version)
  end
  if version then
    if version.prerelease ~= self.from.prerelease then
      return false
    end
    return version >= self.from and (self.to == nil or version < self.to)
  end
end

---@param spec string
function LazyM.range(spec)
  if spec == '*' or spec == '' then
    return setmetatable({ from = M.parse('0.0.0') }, { __index = Range })
  end

  ---@type number?
  local hyphen = spec:find(' - ', 1, true)
  if hyphen then
    local a = spec:sub(1, hyphen - 1)
    local b = spec:sub(hyphen + 3)
    local parts = vim.split(b, '.', { plain = true })
    local ra = LazyM.range(a)
    local rb = LazyM.range(b)
    return setmetatable({
      from = ra and ra.from,
      to = rb and (#parts == 3 and rb.from or rb.to),
    }, { __index = Range })
  end
  ---@type string, string
  local mods, version = spec:lower():match('^([%^=>~]*)(.*)$')
  version = version:gsub('%.[%*x]', '')
  local parts = vim.split(version:gsub('%-.*', ''), '.', { plain = true })
  if #parts < 3 and mods == '' then
    mods = '~'
  end

  local semver = M.parse(version)
  if semver then
    local from = semver
    local to = vim.deepcopy(semver)
    if mods == '' or mods == '=' then
      to.patch = to.patch + 1
    elseif mods == '>' then
      from.patch = from.patch + 1
      to = nil ---@diagnostic disable-line: cast-local-type
    elseif mods == '>=' then
      to = nil ---@diagnostic disable-line: cast-local-type
    elseif mods == '~' then
      if #parts >= 2 then
        to[2] = to[2] + 1
        to[3] = 0
      else
        to[1] = to[1] + 1
        to[2] = 0
        to[3] = 0
      end
    elseif mods == '^' then
      for i = 1, 3 do
        if to[i] ~= 0 then
          to[i] = to[i] + 1
          for j = i + 1, 3 do
            to[j] = 0
          end
          break
        end
      end
    end
    return setmetatable({ from = from, to = to }, { __index = Range })
  end
end

---@private
---@param v string
---@return string
local function create_err_msg(v)
  if type(v) == 'string' then
    return string.format('invalid version: "%s"', tostring(v))
  end
  return string.format('invalid version: %s (%s)', tostring(v), type(v))
end

---@private
--- Throws an error if `version` cannot be parsed.
---@param v string
local function assert_version(v, opt)
  local rv = M.parse(v, opt)
  if rv == nil then
    error(create_err_msg(v))
  end
  return rv
end

--- Parses and compares two version strings.
---
--- semver notes:
--- - Build metadata MUST be ignored when comparing versions.
---
---@param v1 string Version.
---@param v2 string Version to compare with v1.
---@param opts table|nil Optional keyword arguments:
---                      - strict (boolean):  see `version.parse` for details. Defaults to false.
---@return integer `-1` if `v1 < v2`, `0` if `v1 == v2`, `1` if `v1 > v2`.
function M.cmp(v1, v2, opts)
  opts = opts or { strict = false }
  local v1_parsed = assert_version(v1, opts)
  local v2_parsed = assert_version(v2, opts)
  if v1_parsed == v2_parsed then
    return 0
  end
  if v1_parsed > v2_parsed then
    return 1
  end
  return -1
end

--- Parses a semantic version string.
---
--- Ignores leading "v" and surrounding whitespace, e.g. " v1.0.1-rc1+build.2",
--- "1.0.1-rc1+build.2", "v1.0.1-rc1+build.2" and "v1.0.1-rc1+build.2 " are all parsed as:
--- <pre>
---   { major = 1, minor = 0, patch = 1, prerelease = "rc1", build = "build.2" }
--- </pre>
---
---@param version string Version string to be parsed.
---@param opts table|nil Optional keyword arguments:
---                      - strict (boolean):  Default false. If `true`, no coercion is attempted on
---                      input not strictly conforming to semver v2.0.0
---                      (https://semver.org/spec/v2.0.0.html). E.g. `parse("v1.2")` returns nil.
---@return table|nil parsed_version Parsed version table or `nil` if `version` is invalid.
function M.parse(version, opts)
  if type(version) ~= 'string' then
    error(create_err_msg(version))
  end
  opts = opts or { strict = false }

  if opts.strict then
    return LazyM.version(version, true)
  end

  version = vim.trim(version) -- TODO: add more "scrubbing".
  return LazyM.version(version, false)
end

---Returns `true` if `v1` are `v2` are equal versions.
---@param v1 string
---@param v2 string
---@return boolean
function M.eq(v1, v2)
  return M.cmp(v1, v2) == 0
end

---Returns `true` if `v1` is less than `v2`.
---@param v1 string
---@param v2 string
---@return boolean
function M.lt(v1, v2)
  return M.cmp(v1, v2) == -1
end

---Returns `true` if `v1` is greater than `v2`.
---@param v1 string
---@param v2 string
---@return boolean
function M.gt(v1, v2)
  return M.cmp(v1, v2) == 1
end

setmetatable(M, {
  __call = function()
    return vim.fn.api_info().version
  end,
})

return M
