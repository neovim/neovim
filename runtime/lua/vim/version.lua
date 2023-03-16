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
  return type(key) == "number" and ({ self.major, self.minor, self.patch })[key] or Semver[key]
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
  local ret = table.concat({ self.major, self.minor, self.patch }, ".")
  if self.prerelease then
    ret = ret .. "-" .. self.prerelease
  end
  if self.build then
    ret = ret .. "+" .. self.build
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
  return (self.prerelease or "") < (other.prerelease or "")
end

---@param other Semver
function Semver:__le(other)
  return self < other or self == other
end

---@param version string|number[]
---@return Semver?
function LazyM.parse(version)
  if type(version) == "table" then
    return setmetatable({
      major = version[1] or 0,
      minor = version[2] or 0,
      patch = version[3] or 0,
    }, Semver)
  end
  local major, minor, patch, prerelease, build = version:match("^v?(%d+)%.?(%d*)%.?(%d*)%-?([^+]*)+?(.*)$")
  if major then
    return setmetatable({
      major = tonumber(major),
      minor = minor == "" and 0 or tonumber(minor),
      patch = patch == "" and 0 or tonumber(patch),
      prerelease = prerelease ~= "" and prerelease or nil,
      build = build ~= "" and build or nil,
    }, Semver)
  end
end

---@generic T: Semver
---@param versions T[]
---@return T?
function LazyM.last(versions)
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
  if type(version) == "string" then
    ---@diagnostic disable-next-line: cast-local-type
    version = LazyM.parse(version)
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
  if spec == "*" or spec == "" then
    return setmetatable({ from = LazyM.parse("0.0.0") }, { __index = Range })
  end

  ---@type number?
  local hyphen = spec:find(" - ", 1, true)
  if hyphen then
    local a = spec:sub(1, hyphen - 1)
    local b = spec:sub(hyphen + 3)
    local parts = vim.split(b, ".", { plain = true })
    local ra = LazyM.range(a)
    local rb = LazyM.range(b)
    return setmetatable({
      from = ra and ra.from,
      to = rb and (#parts == 3 and rb.from or rb.to),
    }, { __index = Range })
  end
  ---@type string, string
  local mods, version = spec:lower():match("^([%^=>~]*)(.*)$")
  version = version:gsub("%.[%*x]", "")
  local parts = vim.split(version:gsub("%-.*", ""), ".", { plain = true })
  if #parts < 3 and mods == "" then
    mods = "~"
  end

  local semver = LazyM.parse(version)
  if semver then
    local from = semver
    local to = vim.deepcopy(semver)
    if mods == "" or mods == "=" then
      to.patch = to.patch + 1
    elseif mods == ">" then
      from.patch = from.patch + 1
      to = nil
    elseif mods == ">=" then
      to = nil
    elseif mods == "~" then
      if #parts >= 2 then
        to[2] = to[2] + 1
        to[3] = 0
      else
        to[1] = to[1] + 1
        to[2] = 0
        to[3] = 0
      end
    elseif mods == "^" then
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
---@param version string
---@return string
local function create_err_msg(v)
  if type(v) == 'string' then
    return string.format('invalid version: "%s"', tostring(v))
  end
  return string.format('invalid version: %s (%s)', tostring(v), type(v))
end

---@private
--- Throws an error if `version` cannot be parsed.
---@param version string
local function assert_version(version, opt)
  local rv = M.parse(version, opt)
  if rv == nil then
    error(create_err_msg(version))
  end
  return rv
end

---@private
--- Compares the prerelease component of the two versions.
local function cmp_prerelease(v1, v2)
  if v1.prerelease and not v2.prerelease then
    return -1
  end
  if not v1.prerelease and v2.prerelease then
    return 1
  end
  if not v1.prerelease and not v2.prerelease then
    return 0
  end

  local v1_identifiers = vim.split(v1.prerelease, '.', { plain = true })
  local v2_identifiers = vim.split(v2.prerelease, '.', { plain = true })
  local i = 1
  local max = math.max(vim.tbl_count(v1_identifiers), vim.tbl_count(v2_identifiers))
  while i <= max do
    local v1_identifier = v1_identifiers[i]
    local v2_identifier = v2_identifiers[i]
    if v1_identifier ~= v2_identifier then
      local v1_num = tonumber(v1_identifier)
      local v2_num = tonumber(v2_identifier)
      local is_number = v1_num and v2_num
      if is_number then
        -- Number comparisons
        if not v1_num and v2_num then
          return -1
        end
        if v1_num and not v2_num then
          return 1
        end
        if v1_num == v2_num then
          return 0
        end
        if v1_num > v2_num then
          return 1
        end
        if v1_num < v2_num then
          return -1
        end
      else
        -- String comparisons
        if v1_identifier and not v2_identifier then
          return 1
        end
        if not v1_identifier and v2_identifier then
          return -1
        end
        if v1_identifier < v2_identifier then
          return -1
        end
        if v1_identifier > v2_identifier then
          return 1
        end
        if v1_identifier == v2_identifier then
          return 0
        end
      end
    end
    i = i + 1
  end

  return 0
end

---@private
local function cmp_version_core(v1, v2)
  if v1.major == v2.major and v1.minor == v2.minor and v1.patch == v2.patch then
    return 0
  end
  if
    v1.major > v2.major
    or (v1.major == v2.major and v1.minor > v2.minor)
    or (v1.major == v2.major and v1.minor == v2.minor and v1.patch > v2.patch)
  then
    return 1
  end
  return -1
end

--- Compares two strings (`v1` and `v2`) in semver format.
---@param v1 string Version.
---@param v2 string Version to compare with v1.
---@param opts table|nil Optional keyword arguments:
---                      - strict (boolean):  see `semver.parse` for details. Defaults to false.
---@return integer `-1` if `v1 < v2`, `0` if `v1 == v2`, `1` if `v1 > v2`.
function M.cmp(v1, v2, opts)
  opts = opts or { strict = false }
  local v1_parsed = assert_version(v1, opts)
  local v2_parsed = assert_version(v2, opts)

  local result = cmp_version_core(v1_parsed, v2_parsed)
  if result == 0 then
    result = cmp_prerelease(v1_parsed, v2_parsed)
  end
  return result
end

---@private
---@param labels string Prerelease and build component of semantic version string e.g. "-rc1+build.0".
---@return string|nil
local function parse_prerelease(labels)
  -- This pattern matches "-(alpha)+build.15".
  -- '^%-[%w%.]+$'
  local result = labels:match('^%-([%w%.]+)+.+$')
  if result then
    return result
  end
  -- This pattern matches "-(alpha)".
  result = labels:match('^%-([%w%.]+)')
  if result then
    return result
  end

  return nil
end

---@private
---@param labels string Prerelease and build component of semantic version string e.g. "-rc1+build.0".
---@return string|nil
local function parse_build(labels)
  -- Pattern matches "-alpha+(build.15)".
  local result = labels:match('^%-[%w%.]+%+([%w%.]+)$')
  if result then
    return result
  end

  -- Pattern matches "+(build.15)".
  result = labels:match('^%+([%w%.]+)$')
  if result then
    return result
  end

  return nil
end

---@private
--- Extracts the major, minor, patch and preprelease and build components from
--- `version`.
---@param version string Version string
local function extract_components_strict(version)
  local major, minor, patch, prerelease_and_build = version:match('^v?(%d+)%.(%d+)%.(%d+)(.*)$')
  return tonumber(major), tonumber(minor), tonumber(patch), prerelease_and_build
end

---@private
--- Extracts the major, minor, patch and preprelease and build components from
--- `version`. When `minor` and `patch` components are not found (nil), coerce
--- them to 0.
---@param version string Version string
local function extract_components_loose(version)
  local major, minor, patch, prerelease_and_build = version:match('^v?(%d+)%.?(%d*)%.?(%d*)(.*)$')
  major = tonumber(major)
  minor = tonumber(minor) or 0
  patch = tonumber(patch) or 0
  return major, minor, patch, prerelease_and_build
end

---@private
--- Validates the prerelease and build string e.g. "-rc1+build.0". If the
--- prerelease, build or both are valid forms then it will return true, if it
--- is not of any valid form, it will return false.
---@param prerelease_and_build string
---@return boolean
local function is_prerelease_and_build_valid(prerelease_and_build)
  if prerelease_and_build == '' then
    return true
  end
  local has_build = parse_build(prerelease_and_build) ~= nil
  local has_prerelease = parse_prerelease(prerelease_and_build) ~= nil
  local has_prerelease_and_build = has_prerelease and has_build
  return has_build or has_prerelease or has_prerelease_and_build
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

  version = vim.trim(version)

  local extract_components = opts.strict and extract_components_strict or extract_components_loose
  local major, minor, patch, prerelease_and_build = extract_components(version)

  -- If major is nil then that means that the version does not begin with a
  -- digit with or without a "v" prefix.
  if major == nil or not is_prerelease_and_build_valid(prerelease_and_build) then
    return nil
  end

  local prerelease = nil
  local build = nil
  if prerelease_and_build ~= nil then
    prerelease = parse_prerelease(prerelease_and_build)
    build = parse_build(prerelease_and_build)
  end

  return {
    major = major,
    minor = minor,
    patch = patch,
    prerelease = prerelease,
    build = build,
  }
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
