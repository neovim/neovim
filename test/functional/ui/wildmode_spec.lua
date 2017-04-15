local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, command = helpers.clear, helpers.feed, helpers.command
local funcs = helpers.funcs

if helpers.pending_win32(pending) then return end

describe("'wildmode'", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(25, 5)
    screen:attach()
  end)

  after_each(function()
    screen:detach()
  end)

  describe("'wildmenu'", function()
    it(':sign <tab> shows wildmenu completions', function()
      command('set wildmode=full')
      command('set wildmenu')
      feed(':sign <tab>')
      screen:expect([[
                                 |
        ~                        |
        ~                        |
        define  jump  list  >    |
        :sign define^             |
      ]])
    end)
  end)
end)

describe('command line completion', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(40, 5)
    screen:attach()
    screen:set_default_attr_ids({[1]={bold=true, foreground=Screen.colors.Blue}})
  end)

  after_each(function()
    os.remove('Xtest-functional-viml-compl-dir')
  end)

  it('lists directories with empty PATH', function()
    local tmp = funcs.tempname()
    command('e '.. tmp)
    command('cd %:h')
    command("call mkdir('Xtest-functional-viml-compl-dir')")
    command('let $PATH=""')
    feed(':!<tab><bs>')
    screen:expect([[
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      :!Xtest-functional-viml-compl-dir^       |
    ]])
  end)
end)
