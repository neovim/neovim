--- @brief
--- The `vim.version` module provides functions for comparing versions and ranges
--- conforming to the https://semver.org spec. Plugins, and plugin managers, can use this to check
--- available tools and dependencies on the current system.
---
--- Example:
---
--- ```lua
--- local v = vim.version.parse(vim.fn.system({'tmux', '-V'}), {strict=false})
--- if vim.version.gt(v, {3, 2, 0}) then
---   -- ...
--- end
--- ```
---
--- [vim.version()]() returns the version of the current Nvim process.
---
--- VERSION RANGE SPEC [version-range]()
---
--- A version "range spec" defines a semantic version range which can be tested against a version,
--- using |vim.version.range()|.
---
--- Supported range specs are shown in the following table.
--- Note: suffixed versions (1.2.3-rc1) are not matched.
---
--- ```
--- 1.2.3             is 1.2.3
--- =1.2.3            is 1.2.3
--- >1.2.3            greater than 1.2.3
--- <1.2.3            before 1.2.3
--- >=1.2.3           at least 1.2.3
--- ~1.2.3            is >=1.2.3 <1.3.0       "reasonably close to 1.2.3"
--- ^1.2.3            is >=1.2.3 <2.0.0       "compatible with 1.2.3"
--- ^0.2.3            is >=0.2.3 <0.3.0       (0.x.x is special)
--- ^0.0.1            is =0.0.1               (0.0.x is special)
--- ^1.2              is >=1.2.0 <2.0.0       (like ^1.2.0)
--- ~1.2              is >=1.2.0 <1.3.0       (like ~1.2.0)
--- ^1                is >=1.0.0 <2.0.0       "compatible with 1"
--- ~1                same                    "reasonably close to 1"
--- 1.x               same
--- 1.*               same
--- 1                 same
--- *                 any version
--- x                 same
---
--- 1.2.3 - 2.3.4     is >=1.2.3 <=2.3.4
---
--- Partial right: missing pieces treated as x (2.3 => 2.3.x).
--- 1.2.3 - 2.3       is >=1.2.3 <2.4.0
--- 1.2.3 - 2         is >=1.2.3 <3.0.0
---
--- Partial left: missing pieces treated as 0 (1.2 => 1.2.0).
--- 1.2 - 2.3.0       is 1.2.0 - 2.3.0
--- ```

local M = {}

---@nodoc
---@class vim.Version
---@field [1] number
---@field [2] number
---@field [3] number
---@field major number
---@field minor number
---@field patch number
---@field prerelease? string
---@field build? string
local Version = {}
Version.__index = Version

--- Compares prerelease strings: per semver, number parts must be must be treated as numbers:
--- "pre1.10" is greater than "pre1.2". https://semver.org/#spec-item-11
---@param prerel1 string?
---@param prerel2 string?
local function cmp_prerel(prerel1, prerel2)
  if not prerel1 or not prerel2 then
    return prerel1 and -1 or (prerel2 and 1 or 0)
  end
  -- TODO(justinmk): not fully spec-compliant; this treats non-dot-delimited digit sequences as
  -- numbers. Maybe better: "(.-)(%.%d*)".
  local iter1 = prerel1:gmatch('([^0-9]*)(%d*)')
  local iter2 = prerel2:gmatch('([^0-9]*)(%d*)')
  while true do
    local word1, n1 = iter1() --- @type string?, string|number|nil
    local word2, n2 = iter2() --- @type string?, string|number|nil
    if word1 == nil and word2 == nil then -- Done iterating.
      return 0
    end
    word1, n1, word2, n2 =
      word1 or '', n1 and tonumber(n1) or 0, word2 or '', n2 and tonumber(n2) or 0
    if word1 ~= word2 then
      return word1 < word2 and -1 or 1
    end
    if n1 ~= n2 then
      return n1 < n2 and -1 or 1
    end
  end
end

function Version:__index(key)
  return type(key) == 'number' and ({ self.major, self.minor, self.patch })[key] or Version[key]
end

function Version:__newindex(key, value)
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

---@param other vim.Version
function Version:__eq(other)
  for i = 1, 3 do
    if self[i] ~= other[i] then
      return false
    end
  end
  return 0 == cmp_prerel(self.prerelease, other.prerelease)
end

function Version:__tostring()
  local ret = table.concat({ self.major, self.minor, self.patch }, '.')
  if self.prerelease then
    ret = ret .. '-' .. self.prerelease
  end
  if self.build and self.build ~= vim.NIL then
    ret = ret .. '+' .. self.build
  end
  return ret
end

---@param other vim.Version
function Version:__lt(other)
  for i = 1, 3 do
    if self[i] > other[i] then
      return false
    elseif self[i] < other[i] then
      return true
    end
  end
  return -1 == cmp_prerel(self.prerelease, other.prerelease)
end

---@param other vim.Version
function Version:__le(other)
  return self < other or self == other
end

--- @private
---
--- Creates a new Version object, or returns `nil` if `version` is invalid.
---
--- @param version string|number[]|vim.Version
--- @param strict? boolean Reject "1.0", "0-x", "3.2a" or other non-conforming version strings
--- @return vim.Version?
function M._version(version, strict) -- Adapted from https://github.com/folke/lazy.nvim
  if type(version) == 'table' then
    if version.major then
      return setmetatable(vim.deepcopy(version, true), Version)
    end
    return setmetatable({
      major = version[1] or 0,
      minor = version[2] or 0,
      patch = version[3] or 0,
    }, Version)
  end

  if not strict then -- TODO: add more "scrubbing".
    --- @cast version string
    version = version:match('%d[^ ]*')
  end

  if version == nil then
    return nil
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
    }, Version)
  end
  return nil -- Invalid version string.
end

---TODO: generalize this, move to func.lua
---
---@generic T: vim.Version
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

---@class vim.VersionRange
---@inlinedoc
---@field from vim.Version
---@field to? vim.Version
local VersionRange = {}

---@nodoc
---@param version string|vim.Version
function VersionRange:has(version)
  if type(version) == 'string' then
    ---@diagnostic disable-next-line: cast-local-type
    version = M.parse(version)
  elseif getmetatable(version) ~= Version then
    -- Need metatable to compare versions.
    version = setmetatable(vim.deepcopy(version, true), Version)
  end
  if version then
    if version.prerelease ~= self.from.prerelease then
      return false
    end
    return version >= self.from and (self.to == nil or version < self.to)
  end
end

--- Parses a semver |version-range| "spec" and returns a range object:
---
--- ```
--- {
---   from: Version
---   to: Version
---   has(v: string|Version)
--- }
--- ```
---
--- `:has()` checks if a version is in the range (inclusive `from`, exclusive `to`).
---
--- Example:
---
--- ```lua
--- local r = vim.version.range('1.0.0 - 2.0.0')
--- print(r:has('1.9.9'))       -- true
--- print(r:has('2.0.0'))       -- false
--- print(r:has(vim.version())) -- check against current Nvim version
--- ```
---
--- Or use cmp(), le(), lt(), ge(), gt(), and/or eq() to compare a version
--- against `.to` and `.from` directly:
---
--- ```lua
--- local r = vim.version.range('1.0.0 - 2.0.0') -- >=1.0, <2.0
--- print(vim.version.ge({1,0,3}, r.from) and vim.version.lt({1,0,3}, r.to))
--- ```
---
--- @see # https://github.com/npm/node-semver#ranges
--- @since 11
---
--- @param spec string Version range "spec"
--- @return vim.VersionRange?
function M.range(spec) -- Adapted from https://github.com/folke/lazy.nvim
  if spec == '*' or spec == '' then
    return setmetatable({ from = M.parse('0.0.0') }, { __index = VersionRange })
  end

  ---@type number?
  local hyphen = spec:find(' - ', 1, true)
  if hyphen then
    local a = spec:sub(1, hyphen - 1)
    local b = spec:sub(hyphen + 3)
    local parts = vim.split(b, '.', { plain = true })
    local ra = M.range(a)
    local rb = M.range(b)
    return setmetatable({
      from = ra and ra.from,
      to = rb and (#parts == 3 and rb.from or rb.to),
    }, { __index = VersionRange })
  end
  ---@type string, string
  local mods, version = spec:lower():match('^([%^=<>~]*)(.*)$')
  version = version:gsub('%.[%*x]', '')
  local parts = vim.split(version:gsub('%-.*', ''), '.', { plain = true })
  if #parts < 3 and mods == '' then
    mods = '~'
  end

  local semver = M.parse(version)
  if semver then
    local from = semver --- @type vim.Version?
    local to = vim.deepcopy(semver, true) --- @type vim.Version?
    ---@diagnostic disable: need-check-nil
    if mods == '' or mods == '=' then
      to.patch = to.patch + 1
    elseif mods == '<' then
      from = M._version({})
    elseif mods == '<=' then
      from = M._version({})
      to.patch = to.patch + 1
    elseif mods == '>' then
      from.patch = from.patch + 1
      to = nil
    elseif mods == '>=' then
      to = nil
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
    ---@diagnostic enable: need-check-nil
    return setmetatable({ from = from, to = to }, { __index = VersionRange })
  end
end

---@param v string|vim.Version
---@return string
local function create_err_msg(v)
  if type(v) == 'string' then
    return string.format('invalid version: "%s"', tostring(v))
  elseif type(v) == 'table' and v.major then
    return string.format('invalid version: %s', vim.inspect(v))
  end
  return string.format('invalid version: %s (%s)', tostring(v), type(v))
end

--- Parses and compares two version objects (the result of |vim.version.parse()|, or
--- specified literally as a `{major, minor, patch}` tuple, e.g. `{1, 0, 3}`).
---
--- Example:
---
--- ```lua
--- if vim.version.cmp({1,0,3}, {0,2,1}) == 0 then
---   -- ...
--- end
--- local v1 = vim.version.parse('1.0.3-pre')
--- local v2 = vim.version.parse('0.2.1')
--- if vim.version.cmp(v1, v2) == 0 then
---   -- ...
--- end
--- ```
---
--- @note Per semver, build metadata is ignored when comparing two otherwise-equivalent versions.
--- @since 11
---
---@param v1 vim.Version|number[]|string Version object.
---@param v2 vim.Version|number[]|string Version to compare with `v1`.
---@return integer -1 if `v1 < v2`, 0 if `v1 == v2`, 1 if `v1 > v2`.
function M.cmp(v1, v2)
  local v1_parsed = assert(M._version(v1), create_err_msg(v1))
  local v2_parsed = assert(M._version(v2), create_err_msg(v1))
  if v1_parsed == v2_parsed then
    return 0
  end
  if v1_parsed > v2_parsed then
    return 1
  end
  return -1
end

---Returns `true` if the given versions are equal. See |vim.version.cmp()| for usage.
---@since 11
---@param v1 vim.Version|number[]|string
---@param v2 vim.Version|number[]|string
---@return boolean
function M.eq(v1, v2)
  return M.cmp(v1, v2) == 0
end

---Returns `true` if `v1 <= v2`. See |vim.version.cmp()| for usage.
---@since 12
---@param v1 vim.Version|number[]|string
---@param v2 vim.Version|number[]|string
---@return boolean
function M.le(v1, v2)
  return M.cmp(v1, v2) <= 0
end

---Returns `true` if `v1 < v2`. See |vim.version.cmp()| for usage.
---@since 11
---@param v1 vim.Version|number[]|string
---@param v2 vim.Version|number[]|string
---@return boolean
function M.lt(v1, v2)
  return M.cmp(v1, v2) == -1
end

---Returns `true` if `v1 >= v2`. See |vim.version.cmp()| for usage.
---@since 12
---@param v1 vim.Version|number[]|string
---@param v2 vim.Version|number[]|string
---@return boolean
function M.ge(v1, v2)
  return M.cmp(v1, v2) >= 0
end

---Returns `true` if `v1 > v2`. See |vim.version.cmp()| for usage.
---@since 11
---@param v1 vim.Version|number[]|string
---@param v2 vim.Version|number[]|string
---@return boolean
function M.gt(v1, v2)
  return M.cmp(v1, v2) == 1
end

--- Parses a semantic version string and returns a version object which can be used with other
--- `vim.version` functions. For example "1.0.1-rc1+build.2" returns:
---
--- ```
--- { major = 1, minor = 0, patch = 1, prerelease = "rc1", build = "build.2" }
--- ```
---
---@see # https://semver.org/spec/v2.0.0.html
---@since 11
---
---@param version string Version string to parse.
---@param opts table|nil Optional keyword arguments:
---                      - strict (boolean):  Default false. If `true`, no coercion is attempted on
---                      input not conforming to semver v2.0.0. If `false`, `parse()` attempts to
---                      coerce input such as "1.0", "0-x", "tmux 3.2a" into valid versions.
---@return vim.Version? parsed_version Version object or `nil` if input is invalid.
function M.parse(version, opts)
  assert(type(version) == 'string', create_err_msg(version))
  opts = opts or { strict = false }
  return M._version(version, opts.strict)
end

setmetatable(M, {
  --- Returns the current Nvim version.
  ---@return vim.Version
  __call = function()
    local version = vim.fn.api_info().version ---@type vim.Version
    -- Workaround: vim.fn.api_info().version reports "prerelease" as a boolean.
    version.prerelease = version.prerelease and 'dev' or nil
    return setmetatable(version, Version)
  end,
})

return M
