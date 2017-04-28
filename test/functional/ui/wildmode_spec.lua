local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local eq = helpers.eq
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

    it('does not crash after cycling back to original text', function()
      command('set wildmode=full')
      feed(':j<Tab><Tab><Tab>')
      screen:expect([[
                                 |
        ~                        |
        ~                        |
        join  jumps              |
        :j^                       |
      ]])
      -- This would cause nvim to crash before #6650
      feed('<BS><Tab>')
      screen:expect([[
                                 |
        ~                        |
        ~                        |
        !  #  &  <  =  >  @  >   |
        :!^                       |
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

describe('External command line completion', function()
  local screen
  local items, selected

  before_each(function()
    clear()
    screen = Screen.new(25, 5)
    screen:attach({rgb=true, ext_wildmenu=true})
    screen:set_on_event_handler(function(name, data)
      if name == "wildmenu_show" then
        items = data
      elseif name == "wildmenu_select" then
        selected = data[1]
      elseif name == "wildmenu_hide" then
        items = nil
      end
    end)
  end)

  after_each(function()
    screen:detach()
  end)

  local expected = {
      'define',
      'jump',
      'list',
      'place',
      'undefine',
      'unplace',
  }

  describe("'wildmenu'", function()
    it(':sign <tab> shows wildmenu completions', function()
      command('set wildmode=full')
      command('set wildmenu')
      feed(':sign <tab>')
      screen:expect([[
                                 |
        ~                        |
        ~                        |
        ~                        |
        :sign define^             |
      ]], nil, nil, function()
        eq(expected, items)
        eq(0, selected)
      end)

      feed('<tab>')
      screen:expect([[
                                 |
        ~                        |
        ~                        |
        ~                        |
        :sign jump^               |
      ]], nil, nil, function()
        eq(expected, items)
        eq(1, selected)
      end)

      feed('a')
      screen:expect([[
                                 |
        ~                        |
        ~                        |
        ~                        |
        :sign jumpa^              |
      ]], nil, nil, function()
        eq(nil, items)
      end)
    end)
  end)
end)
