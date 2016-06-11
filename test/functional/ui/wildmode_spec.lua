local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, execute = helpers.clear, helpers.feed, helpers.execute
local funcs = helpers.funcs

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
      execute('set wildmode=full')
      execute('set wildmenu')
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
    screen:set_default_attr_ignore({{bold=true, foreground=Screen.colors.Blue}})
  end)

  after_each(function()
    os.remove('Xtest-functional-viml-compl-dir')
  end)

  it('lists directories with empty PATH', function()
    local tmp = funcs.tempname()
    execute('e '.. tmp)
    execute('cd %:h')
    execute("call mkdir('Xtest-functional-viml-compl-dir')")
    execute('let $PATH=""')
    feed(':!<tab><bs>')
    screen:expect([[
                                              |
      ~                                       |
      ~                                       |
      ~                                       |
      :!Xtest-functional-viml-compl-dir^       |
    ]])
  end)
end)
