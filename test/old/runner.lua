-- execute old style tests

-- when compared to the testdir/Makefile based approach, this replaces
-- all wrapper process logic:
-- Makefile
-- runnvim.sh and its library test.sh
-- runnvim.vim (wrapper which runs a nested vim inside a terminal)

-- it DOES NOT not replace the logic running inside the nvim-under-test
-- runtest.vim and its libraries setup.vim, shared.vim, check.vim

local nvim_bin = vim.v.progpath -- must be absolute

vim.api.nvim_set_current_dir('test/old/testdir/')

local function readable(fn)
  return vim.fn.filereadable(fn) ~= 0
end

local errlog = 'test.log'
local messages = 'messages'
local starttime = 'starttime'
local gen_opt_log = 'gen_opt_test.log'

function oksystem(args)
  local res = vim.system(args, {}):wait()
  if res.code ~= 0 then
    error(vim.inspect(args) .. ' failed:\n' .. res.stdout .. res.stderr)
  end
  return res
end

function clean_output()
  for _, f in ipairs { errlog, messages, starttime, gen_opt_log, 'opt_test.vim' } do
    vim.uv.fs_unlink(f)
  end
  -- check status, some tests mess with perms so this could fail:
  oksystem { 'bash', '-c', 'rm -rf X* viminfo test.out test.ok' }
end

function if_nonempty(rawtext, name)
  text = vim.trim(rawtext)
  if #text > 0 then
    if name then
      print('== ' .. name)
    end
    print(text)
    print(name and '== END ' .. name or '\n')
  end
end

function if_exists(fn, name)
  local fil = io.open(fn)
  if fil then
    if_nonempty(fil:read '*a', name)
    fil:close()
    return true
  end
end

local verbose = vim.env.VERBOSE

function run_nvim(...)
  local cmd = vim.system(
    { nvim_bin, '-u', 'NONE', '-i', 'NONE', '--headless', ... },
    { env = { VIMRUNTIME = '../../../runtime' } }
  )
  return cmd:wait()
end

function run_test(testfile)
  if not vim.endswith(testfile, '.vim') then
    error 'not an oldtest'
  end

  clean_output()

  if testfile == 'test_options_all.vim' then
    local res = run_nvim(
      '-S',
      'gen_opt_test.vim',
      '../../../src/nvim/options.lua',
      '../../../runtime/doc/options.txt'
    )

    if if_exists(gen_opt_log, 'GEN opt_test.vim') or res.code > 0 then
      return false
    end
  end

  local resfile = string.sub(testfile, 1, -4) .. 'res'
  vim.uv.fs_unlink(resfile)
  assert(not readable(resfile))

  local opts = 'set shortmess-=F backupdir=. undodir=. viewdir=.'
  local res = run_nvim('--cmd', opts, '-S', 'runtest.vim', testfile)
  local passed = (readable(resfile) and res.code == 0)

  if_exists(messages)

  if verbose or not passed then
    if_nonempty(res.stdout, 'STDOUT')
    if_nonempty(res.stderr, 'STDERR')
    -- if_exists(starttime, "starttime")
    if_exists(errlog, 'test.log')
  end
  return passed
end

local function all_tests()
  local nested_tests = {}
  local alot = io.open('test_alot.vim')
  local sourcepat = '^source (test_.*%.vim)$'
  for line in alot:lines() do
    local m = string.match(line, sourcepat)
    if m then
      nested_tests[m] = true
    end
  end
  alot:close()

  local files = {}
  for name, type in vim.fs.dir('.') do
    match = string.match(name, '^test_.*%.vim$')
    if match then
      if nested_tests[match] then
        nested_tests[match] = nil
      elseif match == 'test_largefile.vim' then
        -- ignored: uses too much resources to run on CI
      else
        table.insert(files, match)
      end
    end
  end
  return files
end

local files
if #arg > 0 then
  files = {}
  for _, a in ipairs(arg) do
    table.insert(files, string.match(a, '[^/]*$'))
  end
else
  files = all_tests()
end

local count = #files
local failures = {}
for i, fil in ipairs(files) do
  print('run: ', fil)
  if not run_test(fil) then
    table.insert(failures, fil)
  end
end

if #failures > 0 then
  print('failed:', vim.inspect(failures))
  vim.cmd 'cquit'
end
