-- A small, deterministic benchmark used to compare two Nvim builds (for
-- example a plain Release build against a PGO-optimized one).
--
--     build/bin/nvim --clean -l contrib/pgo_bench.lua
--
-- It prints one tab-separated line per benchmark:
--
--     BENCH<TAB>name<TAB>microseconds
--
-- The numbers are medians over a few repetitions, so they are meant to be
-- compared between two builds on the same machine, not as absolute values.

local uv = vim.uv or vim.loop
local root = vim.fn.getcwd()

local function median(t)
  table.sort(t)
  local n = #t
  if n == 0 then
    return 0
  end
  if n % 2 == 1 then
    return t[math.floor(n / 2) + 1]
  end
  return (t[n / 2] + t[n / 2 + 1]) / 2
end

local results = {}

local function bench(name, f, opts)
  opts = opts or {}
  local reps = opts.reps or 15
  local per = opts.per or 1
  for _ = 1, (opts.warmup or 3) do
    f()
  end
  local samples = {}
  for _ = 1, reps do
    local t0 = uv.hrtime()
    for _ = 1, per do
      f()
    end
    samples[#samples + 1] = (uv.hrtime() - t0) / per / 1000 -- microseconds
  end
  results[#results + 1] = { name, median(samples) }
end

-- Synthetic buffer (~20k lines of C-like text).
local lines = {}
for i = 1, 20000 do
  lines[i] = ('static int foo_%d(char *bar, size_t n) { return n * %d + 1; } /* c%d */'):format(
    i,
    i,
    i
  )
end

-- Keep everything in one scratch buffer.
vim.cmd('enew')
vim.bo.swapfile = false
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)

bench('regex_search', function()
  vim.fn.cursor(1, 1)
  while vim.fn.search([[foo_\d\+]], 'W') ~= 0 do
  end
end, { reps = 8, warmup = 2 })

bench('fn_substitute', function()
  for i = 1, #lines do
    vim.fn.substitute(lines[i], [[\vstatic int (\w+)]], 'public int \1', 'g')
  end
end, { reps = 5, warmup = 1 })

bench('api_setlines', function()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end, { reps = 10, warmup = 2 })

bench('api_getlines', function()
  local _ = vim.api.nvim_buf_get_lines(0, 0, -1, false)
end, { reps = 10, warmup = 2 })

bench('option_get_set', function()
  for _ = 1, 1000 do
    vim.api.nvim_set_option_value('tabstop', vim.api.nvim_get_option_value('tabstop', {}), {})
  end
end, { reps = 10 })

local big = { items = {} }
for i = 1, 2000 do
  big.items[i] = { id = i, name = 'name' .. i, tags = { 'a', 'b', 'c' }, ok = i % 2 == 0 }
end
bench('json_encode', function()
  vim.json.encode(big)
end, { reps = 15 })

local encoded = vim.json.encode(big)
bench('json_decode', function()
  vim.json.decode(encoded)
end, { reps = 15 })

-- Real files: opening/parsing (this exercises the buffer + file-reading paths).
local sample = vim.fn.glob(root .. '/src/nvim/*.c', false, true)
bench('edit_files', function()
  for _, f in ipairs(sample) do
    vim.cmd('silent! edit ' .. vim.fn.fnameescape(f))
  end
end, { reps = 5, warmup = 1 })

-- tree-sitter parsing of a real C file.  get_string_parser() parses from
-- scratch every time, unlike a buffer parser which caches unchanged trees.
-- Guarded: a build that cannot find the C parser skips this one (visibly, so a
-- comparison is not silently missing a benchmark).
local ts_ok, ts_err = pcall(function()
  local ts_content = table.concat(vim.fn.readfile(root .. '/src/nvim/buffer.c'), '\n')
  bench('treesitter_parse', function()
    local parser = vim.treesitter.get_string_parser(ts_content, 'c')
    parser:parse()
  end, { reps = 10, warmup = 2 })
end)
if not ts_ok then
  io.stderr:write(('pgo_bench: skipping treesitter_parse: %s\n'):format(tostring(ts_err)))
end

local tosort = {}
for i = 1, 5000 do
  tosort[i] = ('%08d-%s'):format((i * 7919) % 5000, 'x')
end
bench('fn_sort', function()
  vim.fn.sort(vim.deepcopy(tosort))
end, { reps = 10 })

for _, r in ipairs(results) do
  print(('BENCH\t%s\t%.2f'):format(r[1], r[2]))
end
