local inspect = {
  _VERSION = 'inspect.lua 3.1.0',
  _URL = 'http://github.com/kikito/inspect.lua',
  _DESCRIPTION = 'human-readable representations of tables',
  _LICENSE = [[
    MIT LICENSE

    Copyright (c) 2013 Enrique García Cota

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  ]],
}

inspect.KEY = setmetatable({}, {
  __tostring = function()
    return 'inspect.KEY'
  end,
})
inspect.METATABLE = setmetatable({}, {
  __tostring = function()
    return 'inspect.METATABLE'
  end,
})

local tostring = tostring
local rep = string.rep
local match = string.match
local char = string.char
local gsub = string.gsub
local fmt = string.format

local function rawpairs(t)
  return next, t, nil
end

-- Apostrophizes the string if it has quotes, but not aphostrophes
-- Otherwise, it returns a regular quoted string
local function smartQuote(str)
  if match(str, '"') and not match(str, "'") then
    return "'" .. str .. "'"
  end
  return '"' .. gsub(str, '"', '\\"') .. '"'
end

-- \a => '\\a', \0 => '\\0', 31 => '\31'
local shortControlCharEscapes = {
  ['\a'] = '\\a',
  ['\b'] = '\\b',
  ['\f'] = '\\f',
  ['\n'] = '\\n',
  ['\r'] = '\\r',
  ['\t'] = '\\t',
  ['\v'] = '\\v',
  ['\127'] = '\\127',
}
local longControlCharEscapes = { ['\127'] = '\127' }
for i = 0, 31 do
  local ch = char(i)
  if not shortControlCharEscapes[ch] then
    shortControlCharEscapes[ch] = '\\' .. i
    longControlCharEscapes[ch] = fmt('\\%03d', i)
  end
end

local function escape(str)
  return (
    gsub(
      gsub(gsub(str, '\\', '\\\\'), '(%c)%f[0-9]', longControlCharEscapes),
      '%c',
      shortControlCharEscapes
    )
  )
end

-- List of lua keywords
local luaKeywords = {
  ['and'] = true,
  ['break'] = true,
  ['do'] = true,
  ['else'] = true,
  ['elseif'] = true,
  ['end'] = true,
  ['false'] = true,
  ['for'] = true,
  ['function'] = true,
  ['goto'] = true,
  ['if'] = true,
  ['in'] = true,
  ['local'] = true,
  ['nil'] = true,
  ['not'] = true,
  ['or'] = true,
  ['repeat'] = true,
  ['return'] = true,
  ['then'] = true,
  ['true'] = true,
  ['until'] = true,
  ['while'] = true,
}

local function isIdentifier(str)
  return type(str) == 'string'
    -- identifier must start with a letter and underscore, and be followed by letters, numbers, and underscores
    and not not str:match('^[_%a][_%a%d]*$')
    -- lua keywords are not valid identifiers
    and not luaKeywords[str]
end

local flr = math.floor
local function isSequenceKey(k, sequenceLength)
  return type(k) == 'number' and flr(k) == k and 1 <= k and k <= sequenceLength
end

local defaultTypeOrders = {
  ['number'] = 1,
  ['boolean'] = 2,
  ['string'] = 3,
  ['table'] = 4,
  ['function'] = 5,
  ['userdata'] = 6,
  ['thread'] = 7,
}

local function sortKeys(a, b)
  local ta, tb = type(a), type(b)

  -- strings and numbers are sorted numerically/alphabetically
  if ta == tb and (ta == 'string' or ta == 'number') then
    return a < b
  end

  local dta = defaultTypeOrders[ta] or 100
  local dtb = defaultTypeOrders[tb] or 100
  -- Two default types are compared according to the defaultTypeOrders table

  -- custom types are sorted out alphabetically
  return dta == dtb and ta < tb or dta < dtb
end

local function getKeys(t)
  local seqLen = 1
  while rawget(t, seqLen) ~= nil do
    seqLen = seqLen + 1
  end
  seqLen = seqLen - 1

  local keys, keysLen = {}, 0
  for k in rawpairs(t) do
    if not isSequenceKey(k, seqLen) then
      keysLen = keysLen + 1
      keys[keysLen] = k
    end
  end
  table.sort(keys, sortKeys)
  return keys, keysLen, seqLen
end

local function countCycles(x, cycles)
  if type(x) == 'table' then
    if cycles[x] then
      cycles[x] = cycles[x] + 1
    else
      cycles[x] = 1
      for k, v in rawpairs(x) do
        countCycles(k, cycles)
        countCycles(v, cycles)
      end
      countCycles(getmetatable(x), cycles)
    end
  end
end

local function makePath(path, a, b)
  local newPath = {}
  local len = #path
  for i = 1, len do
    newPath[i] = path[i]
  end

  newPath[len + 1] = a
  newPath[len + 2] = b

  return newPath
end

local function processRecursive(process, item, path, visited)
  if item == nil then
    return nil
  end
  if visited[item] then
    return visited[item]
  end

  local processed = process(item, path)
  if type(processed) == 'table' then
    local processedCopy = {}
    visited[item] = processedCopy
    local processedKey

    for k, v in rawpairs(processed) do
      processedKey = processRecursive(process, k, makePath(path, k, inspect.KEY), visited)
      if processedKey ~= nil then
        processedCopy[processedKey] =
          processRecursive(process, v, makePath(path, processedKey), visited)
      end
    end

    local mt =
      processRecursive(process, getmetatable(processed), makePath(path, inspect.METATABLE), visited)
    if type(mt) ~= 'table' then
      mt = nil
    end
    setmetatable(processedCopy, mt)
    processed = processedCopy
  end
  return processed
end

local function puts(buf, str)
  buf.n = buf.n + 1
  buf[buf.n] = str
end

local Inspector = {}

local Inspector_mt = { __index = Inspector }

local function tabify(inspector)
  puts(inspector.buf, inspector.newline .. rep(inspector.indent, inspector.level))
end

function Inspector:getId(v)
  local id = self.ids[v]
  local ids = self.ids
  if not id then
    local tv = type(v)
    id = (ids[tv] or 0) + 1
    ids[v], ids[tv] = id, id
  end
  return tostring(id)
end

function Inspector:putValue(v)
  local buf = self.buf
  local tv = type(v)
  if tv == 'string' then
    puts(buf, smartQuote(escape(v)))
  elseif
    tv == 'number'
    or tv == 'boolean'
    or tv == 'nil'
    or tv == 'cdata'
    or tv == 'ctype'
    or (vim and v == vim.NIL)
  then
    puts(buf, tostring(v))
  elseif tv == 'table' and not self.ids[v] then
    local t = v

    if t == inspect.KEY or t == inspect.METATABLE then
      puts(buf, tostring(t))
    elseif self.level >= self.depth then
      puts(buf, '{...}')
    else
      if self.cycles[t] > 1 then
        puts(buf, fmt('<%d>', self:getId(t)))
      end

      local keys, keysLen, seqLen = getKeys(t)
      local mt = getmetatable(t)

      if vim and seqLen == 0 and keysLen == 0 and mt == vim._empty_dict_mt then
        puts(buf, tostring(t))
        return
      end

      puts(buf, '{')
      self.level = self.level + 1

      for i = 1, seqLen + keysLen do
        if i > 1 then
          puts(buf, ',')
        end
        if i <= seqLen then
          puts(buf, ' ')
          self:putValue(t[i])
        else
          local k = keys[i - seqLen]
          tabify(self)
          if isIdentifier(k) then
            puts(buf, k)
          else
            puts(buf, '[')
            self:putValue(k)
            puts(buf, ']')
          end
          puts(buf, ' = ')
          self:putValue(t[k])
        end
      end

      if type(mt) == 'table' then
        if seqLen + keysLen > 0 then
          puts(buf, ',')
        end
        tabify(self)
        puts(buf, '<metatable> = ')
        self:putValue(mt)
      end

      self.level = self.level - 1

      if keysLen > 0 or type(mt) == 'table' then
        tabify(self)
      elseif seqLen > 0 then
        puts(buf, ' ')
      end

      puts(buf, '}')
    end
  else
    puts(buf, fmt('<%s %d>', tv, self:getId(v)))
  end
end

function inspect.inspect(root, options)
  options = options or {}

  local depth = options.depth or math.huge
  local newline = options.newline or '\n'
  local indent = options.indent or '  '
  local process = options.process

  if process then
    root = processRecursive(process, root, {}, {})
  end

  local cycles = {}
  countCycles(root, cycles)

  local inspector = setmetatable({
    buf = { n = 0 },
    ids = {},
    cycles = cycles,
    depth = depth,
    level = 0,
    newline = newline,
    indent = indent,
  }, Inspector_mt)

  inspector:putValue(root)

  return table.concat(inspector.buf)
end

setmetatable(inspect, {
  __call = function(_, root, options)
    return inspect.inspect(root, options)
  end,
})

return inspect
