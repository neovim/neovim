-- Script creates the following tables in unicode_tables.generated.h:
--
-- 1. doublewidth and ambiguous tables: sorted list of non-overlapping closed 
--    intervals. Codepoints in these intervals have double (W or F) or ambiguous 
--    (A) east asian width respectively.
-- 2. combining table: same as the above, but characters inside are combining 
--    characters (i.e. have general categories equal to Mn, Mc or Me).
-- 3. foldCase, toLower and toUpper tables used to convert characters to 
--    folded/lower/upper variants. In these tables first two values are 
--    character ranges: like in previous tables they are sorted and must be 
--    non-overlapping. Third value means step inside the range: e.g. if it is 
--    2 then interval applies only to first, third, fifth, … character in range. 
--    Fourth value is number that should be added to the codepoint to yield 
--    folded/lower/upper codepoint.
if arg[1] == '--help' then
  print('Usage:')
  print('  genunicodetables.lua UnicodeData.txt CaseFolding.txt ' ..
        'EastAsianWidth.txt')
  print('                       unicode_tables.generated.h')
  os.exit(0)
end

local unicodedata_fname = arg[1]
local casefolding_fname = arg[2]
local eastasianwidth_fname = arg[3]

local utf_tables_fname = arg[4]

local split_on_semicolons = function(s)
  local ret = {}
  local idx = 1
  while idx <= #s + 1 do
    item = s:match('^[^;]*', idx)
    idx = idx + #item + 1
    if idx <= #s + 1 then
      assert(s:sub(idx - 1, idx - 1) == ';')
    end
    item = item:gsub('^%s*', '')
    item = item:gsub('%s*$', '')
    table.insert(ret, item)
  end
  return ret
end

local fp_lines_to_lists = function(fp, n, has_comments)
  local ret = {}
  local line
  local i = 0
  while true do
    i = i + 1
    line = fp:read('*l')
    if not line then
      break
    end
    if (not has_comments
        or (line:sub(1, 1) ~= '#' and not line:match('^%s*$'))) then
      local l = split_on_semicolons(line)
      if #l ~= n then
        io.stderr:write(('Found %s items in line %u, expected %u\n'):format(
          #l, i, n))
        io.stderr:write('Line: ' .. line .. '\n')
        return nil
      end
      table.insert(ret, l)
    end
  end
  return ret
end

local parse_data_to_props = function(ud_fp)
  return fp_lines_to_lists(ud_fp, 15, false)
end

local parse_fold_props = function(cf_fp)
  return fp_lines_to_lists(cf_fp, 4, true)
end

local parse_width_props = function(eaw_fp)
  return fp_lines_to_lists(eaw_fp, 2, true)
end

local make_range = function(start, end_, step, add)
  if step and add then
    return ('  {0x%x, 0x%x, %d, %d},\n'):format(
      start, end_, step == 0 and -1 or step, add)
  else
    return ('  {0x%04x, 0x%04x},\n'):format(start, end_)
  end
end

local build_convert_table = function(ut_fp, props, cond_func, nl_index,
                                     table_name)
  ut_fp:write('static const convertStruct ' .. table_name .. '[] = {\n')
  local start = -1
  local end_ = -1
  local step = 0
  local add = -1
  for _, p in ipairs(props) do
    if cond_func(p) then
      local n = tonumber(p[1], 16)
      local nl = tonumber(p[nl_index], 16)
      if start >= 0 and add == (nl - n) and (step == 0 or n - end_ == step) then
        -- Continue with the same range.
        step = n - end_
        end_ = n
      else
        if start >= 0 then
          -- Produce previous range.
          ut_fp:write(make_range(start, end_, step, add))
        end
        start = n
        end_ = n
        step = 0
        add = nl - n
      end
    end
  end
  if start >= 0 then
    ut_fp:write(make_range(start, end_, step, add))
  end
  ut_fp:write('};\n')
end

local build_case_table = function(ut_fp, dataprops, table_name, index)
  local cond_func = function(p)
    return p[index] ~= ''
  end
  return build_convert_table(ut_fp, dataprops, cond_func, index,
                             'to' .. table_name)
end

local build_fold_table = function(ut_fp, foldprops)
  local cond_func = function(p)
    return (p[2] == 'C' or p[2] == 'S')
  end
  return build_convert_table(ut_fp, foldprops, cond_func, 3, 'foldCase')
end

local build_combining_table = function(ut_fp, dataprops)
  ut_fp:write('static const struct interval combining[] = {\n')
  local start = -1
  local end_ = -1
  for _, p in ipairs(dataprops) do
    if (({Mn=true, Mc=true, Me=true})[p[3]]) then
      local n = tonumber(p[1], 16)
      if start >= 0 and end_ + 1 == n then
        -- Continue with the same range.
        end_ = n
      else
        if start >= 0 then
          -- Produce previous range.
          ut_fp:write(make_range(start, end_))
        end
        start = n
        end_ = n
      end
    end
  end
  if start >= 0 then
    ut_fp:write(make_range(start, end_))
  end
  ut_fp:write('};\n')
end

local build_width_table = function(ut_fp, dataprops, widthprops, widths,
                                   table_name)
  ut_fp:write('static const struct interval ' .. table_name .. '[] = {\n')
  local start = -1
  local end_ = -1
  local dataidx = 1
  for _, p in ipairs(widthprops) do
    if widths[p[2]:sub(1, 1)] then
      local rng_start, rng_end = p[1]:find('%.%.')
      local n, n_last
      if rng_start then
        -- It is a range. We don’t check for composing char then.
        n = tonumber(p[1]:sub(1, rng_start - 1), 16)
        n_last = tonumber(p[1]:sub(rng_end + 1), 16)
      else
        n = tonumber(p[1], 16)
        n_last = n
      end
      local dn
      while true do
        dn = tonumber(dataprops[dataidx][1], 16)
        if dn >= n then
          break
        end
        dataidx = dataidx + 1
      end
      if dn ~= n and n_last == n then
        io.stderr:write('Cannot find character ' .. n .. ' in data table.\n')
      end
      -- Only use the char when it’s not a composing char.
      -- But use all chars from a range.
      local dp = dataprops[dataidx]
      if (n_last > n) or (not (({Mn=true, Mc=true, Me=true})[dp[3]])) then
        if start >= 0 and end_ + 1 == n then
          -- Continue with the same range.
        else
          if start >= 0 then
            ut_fp:write(make_range(start, end_))
          end
          start = n
        end
        end_ = n_last
      end
    end
  end
  if start >= 0 then
    ut_fp:write(make_range(start, end_))
  end
  ut_fp:write('};\n')
end

local ud_fp = io.open(unicodedata_fname, 'r')
local dataprops = parse_data_to_props(ud_fp)
ud_fp:close()

local ut_fp = io.open(utf_tables_fname, 'w')

build_case_table(ut_fp, dataprops, 'Lower', 14)
build_case_table(ut_fp, dataprops, 'Upper', 13)
build_combining_table(ut_fp, dataprops)

local cf_fp = io.open(casefolding_fname, 'r')
local foldprops = parse_fold_props(cf_fp)
cf_fp:close()

build_fold_table(ut_fp, foldprops)

local eaw_fp = io.open(eastasianwidth_fname, 'r')
local widthprops = parse_width_props(eaw_fp)
eaw_fp:close()

build_width_table(ut_fp, dataprops, widthprops, {W=true, F=true}, 'doublewidth')
build_width_table(ut_fp, dataprops, widthprops, {A=true}, 'ambiguous')

ut_fp:close()
