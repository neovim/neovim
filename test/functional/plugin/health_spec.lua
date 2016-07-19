local helpers = require('test.functional.helpers')(after_each)
local nvim_eval = helpers.eval
local nvim_command = helpers.command

local plugin_helpers = require('test.functional.plugin.helpers')
local reset = plugin_helpers.reset

describe('health#check()', function()
  before_each(function()
    reset()
  end)

  it('Should find the default nvim checker', function()
      print(nvim_eval('echo "hello"'))
  end)
end)

local helpers = require('test.functional.helpers')(after_each)
local plugin_helpers = require('test.functional.plugin.helpers')

describe('health.vim', function()
  before_each(function()
    plugin_helpers.reset()
  end)

  it('basic operation', function()
    helpers.execute([[
      call health#report_start('Foo')
      call health#report_ok('Bar status')
      call health#report_start('Baz')
      call health#report_warn('Zub')
      call health#report_warn('Zim', ['suggestion 1', 'suggestion 2']) ]])

    helpers.expect([[
      - Foo
        - SUCCESS: Bar status
      - Baz
        - WARNING: Zub
        - WARNING: Zim
          - suggestion 1
          - suggestion 2]])
  end)
end)
