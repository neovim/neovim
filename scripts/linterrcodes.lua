-- Checks mismatches between "EXX" error codes (E123, E1234) defined in C sources and those
-- documented in `runtime/doc/*.txt`.
--
-- Usage: nvim -l scripts/linterrcodes.lua

--- Error codes allowed to appear in more than one place. Value is the exact expected
--- occurrence count. A mismatch (actual > or < expected) is reported, to avoid
--- accidental duplicates from slipping in.
--- @type table<string, integer>
local dup_allowed = {
  E109 = 2,
  E1098 = 2,
  E110 = 2,
  E112 = 2,
  E114 = 2,
  E115 = 2,
  E1159 = 2,
  E116 = 2,
  E121 = 2,
  E1502 = 4,
  E151 = 2,
  E155 = 3,
  E158 = 2,
  E170 = 2,
  E173 = 2,
  E180 = 2,
  E212 = 2,
  E216 = 2,
  E298 = 3,
  E303 = 3,
  E312 = 2,
  E317 = 4,
  E319 = 2,
  E423 = 3,
  E474 = 52,
  E475 = 6,
  E482 = 3,
  E484 = 2,
  E488 = 2,
  E5000 = 2,
  E5001 = 2,
  E5002 = 2,
  E5009 = 3,
  E502 = 2,
  E503 = 3,
  E504 = 2,
  E505 = 2,
  E509 = 2,
  E5101 = 2,
  E5102 = 2,
  E5108 = 4,
  E5111 = 2,
  E513 = 2,
  E521 = 2,
  E546 = 2,
  E588 = 2,
  E678 = 2,
  E685 = 5,
  E697 = 2,
  E703 = 2,
  E716 = 2,
  E723 = 2,
  E724 = 3,
  E728 = 2,
  E741 = 2,
  E742 = 2,
  E745 = 2,
  E798 = 2,
  E805 = 2,
  E856 = 2,
  E867 = 2,
  E900 = 3,
  E903 = 2,
  E905 = 2,
  E906 = 2,
  E948 = 2,
  E970 = 2,
  E974 = 2,
  E996 = 5,
}

--- Runs a command, returns stdout lines. Errors on non-zero exit.
--- @param cmd string[]
--- @return string[]
local function run(cmd)
  local result = vim.system(cmd, { text = true }):wait()
  if result.code ~= 0 then
    error('command failed: ' .. table.concat(cmd, ' ') .. '\n' .. (result.stderr or ''))
  end
  return vim.split(result.stdout, '\n', { trimempty = true })
end

--- Extracts error codes from a line of C source, excluding hex literals (0xE000),
--- identifiers (FOO_E123), and inline comments (`//`).
--- @param line string
--- @return string[]
local function extract_codes(line)
  local codes = {} --- @type string[]
  local cmt = line:find('//')
  for pos, code in line:gmatch('()(E%d%d%d%d?)') do
    --- @cast pos integer
    local in_comment = cmt and pos > cmt
    -- Preceded by a word char means the `E` is part of something else.
    local prev = pos > 1 and line:sub(pos - 1, pos - 1) or ''
    local in_word = prev:match('[%w_]') ~= nil
    if not in_comment and not in_word then
      codes[#codes + 1] = code
    end
  end
  return codes
end

--- @return table<string, true> Set of error codes documented in help docs.
local function collect_help_codes()
  local lines = run({
    'git',
    'grep',
    '-hE',
    [[\*E[0-9]{3,4}\*]],
    '--',
    'runtime/doc/*.txt',
  })
  local codes = {} --- @type table<string, true>
  for _, line in ipairs(lines) do
    for code in line:gmatch('E%d%d%d%d?') do
      codes[code] = true
    end
  end
  return codes
end

--- @return table<string, string[]> Map of error code to its occurrences in C sources.
local function collect_c_codes()
  local lines = run({
    'git',
    'grep',
    '-nE',
    'E[0-9]{3,4}',
    '--',
    'src/nvim/*.c',
    'src/nvim/*.h',
  })
  local codes = {} --- @type table<string, string[]>
  for _, line in ipairs(lines) do
    for _, code in ipairs(extract_codes(line)) do
      codes[code] = codes[code] or {}
      table.insert(codes[code], line)
    end
  end
  return codes
end

--- @param a string
--- @param b string
--- @return boolean
local function errcode_lt(a, b)
  return tonumber(a:sub(2)) < tonumber(b:sub(2))
end

--- @param c_codes table<string, string[]>
--- @param help_codes table<string, true>
--- @return integer missing Number of codes missing from help docs.
--- @return integer dups Number of codes with unexpected duplicate usage.
local function report(c_codes, help_codes)
  local missing = {} --- @type string[]
  for code in pairs(c_codes) do
    if not help_codes[code] then
      missing[#missing + 1] = code
    end
  end
  table.sort(missing, errcode_lt)

  local dup_codes = {} --- @type string[]
  for code, occurrences in pairs(c_codes) do
    local allowed = dup_allowed[code]
    if allowed then
      -- Whitelisted: only flag if the actual count doesn't match the expected count.
      if #occurrences ~= allowed then
        dup_codes[#dup_codes + 1] = code
      end
    elseif #occurrences > 1 then
      dup_codes[#dup_codes + 1] = code
    end
  end
  table.sort(dup_codes, errcode_lt)

  if #missing > 0 then
    print('Error codes missing from help docs:')
    for _, code in ipairs(missing) do
      print('  ' .. code)
    end
    print('')
  end

  if #dup_codes > 0 then
    print('Error codes used in more than one place:')
    for _, code in ipairs(dup_codes) do
      print(string.format('  %s (%d occurrences):', code, #c_codes[code]))
      for _, loc in ipairs(c_codes[code]) do
        print('    ' .. loc)
      end
    end
    print('')
  end

  local max_code = 0
  for code in pairs(c_codes) do
    local n = tonumber(code:sub(2)) or 0
    if n > max_code then
      max_code = n
    end
  end

  local n_errcodes = 0
  for _ in pairs(c_codes) do
    n_errcodes = n_errcodes + 1
  end

  print(
    string.format(
      'errcodes=%d dup-codes=%d missing-help=%d highest=E%d',
      n_errcodes,
      #dup_codes,
      #missing,
      max_code
    )
  )

  return #missing, #dup_codes
end

local function main()
  local help_codes = collect_help_codes()
  local c_codes = collect_c_codes()
  local missing, dups = report(c_codes, help_codes)
  if missing > 0 or dups > 0 then
    os.exit(1)
  end
end

main()
