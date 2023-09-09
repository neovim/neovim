local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local neq = helpers.neq
local command = helpers.command
local exec_capture = helpers.exec_capture
local write_file = helpers.write_file
local meths = helpers.meths
local clear = helpers.clear
local dedent = helpers.dedent
local exc_exec = helpers.exc_exec
local missing_provider = helpers.missing_provider

local tmpfile = 'X_ex_cmds_script'

before_each(clear)

local function source(code)
  write_file(tmpfile, code)
  command('source '..tmpfile)
end

describe('script_get-based command', function()
  local garbage = ')}{+*({}]*[;(+}{&[]}{*])('

  after_each(function()
    os.remove(tmpfile)
  end)

  local function test_garbage_exec(cmd, check_neq)
    describe(cmd, function()
      it('works correctly when skipping oneline variant', function()
        eq(true, pcall(source, (dedent([[
          if 0
            %s %s
          endif
        ]])):format(cmd, garbage)))
        eq('', exec_capture('messages'))
        if check_neq then
          neq(0, exc_exec(dedent([[
            %s %s
          ]])):format(cmd, garbage))
        end
      end)
      it('works correctly when skipping HEREdoc variant', function()
        eq(true, pcall(source, (dedent([[
          if 0
          %s << EOF
          %s
          EOF
          endif
        ]])):format(cmd, garbage)))
        eq('', exec_capture('messages'))
        if check_neq then
          eq(true, pcall(source, (dedent([[
            let g:exc = 0
            try
            %s << EOF
            %s
            EOF
            catch
            let g:exc = v:exception
            endtry
          ]])):format(cmd, garbage)))
          neq(0, meths.get_var('exc'))
        end
      end)
    end)
  end

  clear()

  -- Built-in scripts
  test_garbage_exec('lua', true)

  -- Provider-based scripts
  test_garbage_exec('ruby', not missing_provider('ruby'))
  test_garbage_exec('python3', not missing_provider('python3'))

  -- Missing scripts
  test_garbage_exec('python', false)
  test_garbage_exec('tcl', false)
  test_garbage_exec('mzscheme', false)
  test_garbage_exec('perl', false)

  -- Not really a script
  test_garbage_exec('xxxinvalidlanguagexxx', true)
end)
