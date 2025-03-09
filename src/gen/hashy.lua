-- HASHY McHASHFACE

local M = {}
_G.d = M

local function setdefault(table, key)
  local val = table[key]
  if val == nil then
    val = {}
    table[key] = val
  end
  return val
end

function M.build_pos_hash(strings)
  local len_buckets = {}
  local maxlen = 0
  for _, s in ipairs(strings) do
    table.insert(setdefault(len_buckets, #s), s)
    if #s > maxlen then
      maxlen = #s
    end
  end

  local len_pos_buckets = {}
  local worst_buck_size = 0

  for len = 1, maxlen do
    local strs = len_buckets[len]
    if strs then
      -- the best position so far generates `best_bucket`
      -- with `minsize` worst case collisions
      local bestpos, minsize, best_bucket = nil, #strs * 2, nil
      for pos = 1, len do
        local try_bucket = {}
        for _, str in ipairs(strs) do
          local poschar = string.sub(str, pos, pos)
          table.insert(setdefault(try_bucket, poschar), str)
        end
        local maxsize = 1
        for _, pos_strs in pairs(try_bucket) do
          maxsize = math.max(maxsize, #pos_strs)
        end
        if maxsize < minsize then
          bestpos = pos
          minsize = maxsize
          best_bucket = try_bucket
        end
      end
      len_pos_buckets[len] = { bestpos, best_bucket }
      worst_buck_size = math.max(worst_buck_size, minsize)
    end
  end
  return len_pos_buckets, maxlen, worst_buck_size
end

function M.switcher(put, tab, maxlen, worst_buck_size, icase)
  local neworder = {} --- @type string[]
  put '  switch (len) {\n'
  local bucky = worst_buck_size > 1
  for len = 1, maxlen do
    local vals = tab[len]
    if vals then
      put('    case ' .. len .. ': ')
      local pos, posbuck = unpack(vals)
      local keys = vim.tbl_keys(posbuck)
      if #keys > 1 then
        table.sort(keys)
        put('switch (str[' .. (pos - 1) .. ']) {\n')
        for _, c in ipairs(keys) do
          local buck = posbuck[c]
          local startidx = #neworder
          vim.list_extend(neworder, buck)
          local endidx = #neworder
          if icase and c:upper() ~= c:lower() then
            put(("      case '%s': case '%s': "):format(c:upper(), c:lower()))
          else
            put(("      case '%s': "):format(c))
          end
          if len == 1 then
            put('return ' .. startidx .. ';\n')
          else
            put('low = ' .. startidx .. '; ')
            if bucky then
              put('high = ' .. endidx .. '; ')
            end
            put 'break;\n'
          end
        end
        put '      default: break;\n'
        put '    }\n    '
      else
        local startidx = #neworder
        table.insert(neworder, posbuck[keys[1]][1])
        local endidx = #neworder
        put('low = ' .. startidx .. '; ')
        if bucky then
          put('high = ' .. endidx .. '; ')
        end
      end
      put 'break;\n'
    end
  end
  put '    default: break;\n'
  put '  }\n'
  return neworder
end

--- @param icase? boolean generate a case-insensitive hash function.
---                       `strings` must not have mixed case when using this.
function M.hashy_hash(name, strings, access, icase)
  local stats = {}
  local put = function(str)
    table.insert(stats, str)
  end
  local len_pos_buckets, maxlen, worst_buck_size = M.build_pos_hash(strings)
  put('int ' .. name .. '_hash(const char *str, size_t len)\n{\n')
  if maxlen == 1 then
    put('\n') -- nothing
  elseif worst_buck_size > 1 then
    put('  int low = 0, high = 0;\n')
  else
    put('  int low = -1;\n')
  end
  local neworder = M.switcher(put, len_pos_buckets, maxlen, worst_buck_size, icase)
  if maxlen == 1 then
    put([[
  return -1;
]])
  elseif worst_buck_size > 1 then
    put(([[
  for (int i = low; i < high; i++) {
    if (!%s(str, %s, len)) {
      return i;
    }
  }
  return -1;
]]):format(icase and 'vim_strnicmp_asc' or 'memcmp', access('i')))
  else
    put(([[
  if (low < 0 || %s(str, %s, len)) {
    return -1;
  }
  return low;
]]):format(icase and 'vim_strnicmp_asc' or 'memcmp', access('low')))
  end
  put '}\n\n'
  return neworder, table.concat(stats)
end

return M
