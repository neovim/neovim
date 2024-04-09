local t = require('test.functional.testutil')()

local eq = t.eq
local neq = t.neq
local command = t.command
local exec_capture = t.exec_capture
local write_file = t.write_file
local api = t.api
local clear = t.clear
local dedent = t.dedent
local exc_exec = t.exc_exec
local missing_provider = t.missing_provider

local tmpfile = 'X_ex_cmds_script'

before_each(clear)

local function source(code)
  write_file(tmpfile, code)
  command('source ' .. tmpfile)
end

describe('script_get-based command', function()
  local garbage = ')}{+*({}]*[;(+}{&[]}{*])('

  after_each(function()
    os.remove(tmpfile)
  end)

  local function test_garbage_exec(cmd, check_neq)
    describe(cmd, function()
      it('works correctly when skipping oneline variant', function()
        eq(
          true,
          pcall(
            source,
            (dedent([[
          if 0
            %s %s
          endif
        ]])):format(cmd, garbage)
          )
        )
        eq('', exec_capture('messages'))
        if check_neq then
          neq(
            0,
            exc_exec(dedent([[
            %s %s
          ]])):format(cmd, garbage)
          )
        end
      end)
      it('works correctly when skipping HEREdoc variant', function()
        eq(
          true,
          pcall(
            source,
            (dedent([[
          if 0
          %s << EOF
          %s
          EOF
          endif
        ]])):format(cmd, garbage)
          )
        )
        eq('', exec_capture('messages'))
        if check_neq then
          eq(
            true,
            pcall(
              source,
              (dedent([[
            let g:exc = 0
            try
            %s << EOF
            %s
            EOF
            catch
            let g:exc = v:exception
            endtry
          ]])):format(cmd, garbage)
            )
          )
          neq(0, api.nvim_get_var('exc'))
        end
      end)
    end)
  end

  clear()

  -- Built-in scripts
  test_garbage_exec('lua', true)

  -- Provider-based scripts
  test_garbage_exec('ruby', not missing_provider('ruby'))
  test_garbage_exec('python3', not missing_provider('python'))

  -- Missing scripts
  test_garbage_exec('python', false)
  test_garbage_exec('tcl', false)
  test_garbage_exec('mzscheme', false)
  test_garbage_exec('perl', false)

  -- Not really a script
  test_garbage_exec('xxxinvalidlanguagexxx', true)
end)
