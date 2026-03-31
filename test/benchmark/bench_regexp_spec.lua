-- Test for benchmarking the RE engine.

local n = require('test.functional.testnvim')()

local insert, source = n.insert, n.source
local clear, command = n.clear, n.command

-- Temporary file for gathering benchmarking results for each regexp engine.
local result_file = 'benchmark.out'
-- Fixture containing an HTML fragment that can make a search appear to freeze.
local sample_file = 'test/old/testdir/samples/re.freeze.txt'

-- Vim script code that does both the work and the benchmarking of that work.
local measure_cmd = [[call Measure(%d, ']] .. sample_file .. [[', '\s\+\%%#\@<!$', '+5')]]
local measure_script = [[
    func Measure(re, file, pattern, arg)
      let sstart = reltime()

      execute 'set re=' .. a:re
      execute 'split' a:arg a:file
      call search(a:pattern, '', '', 10000)
      quit!

      $put =printf('file: %s, re: %d, time: %s', a:file, a:re, reltimestr(reltime(sstart)))
    endfunc]]

describe('regexp search', function()
  -- The test cases rely on a temporary result file, which we prepare and write
  -- to disk.
  setup(function()
    clear()
    source(measure_script)
    insert('" Benchmark_results:')
    command('write! ' .. result_file)
  end)

  -- At the end of the test run we just print the contents of the result file
  -- for human inspection and promptly delete the file.
  teardown(function()
    print ''
    for line in io.lines(result_file) do
      print(line)
    end
    os.remove(result_file)
  end)

  it('is working with regexpengine=0', function()
    local regexpengine = 0
    command(string.format(measure_cmd, regexpengine))
    command('write')
  end)

  it('is working with regexpengine=1', function()
    local regexpengine = 1
    command(string.format(measure_cmd, regexpengine))
    command('write')
  end)

  it('is working with regexpengine=2', function()
    local regexpengine = 2
    command(string.format(measure_cmd, regexpengine))
    command('write')
  end)
end)
