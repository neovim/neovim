local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local feed = helpers.feed
local clear = helpers.clear
local funcs = helpers.funcs
local meths = helpers.meths
local insert = helpers.insert
local expect = helpers.expect
local command = helpers.command
local write_file = helpers.write_file
local curbufmeths = helpers.curbufmeths
local missing_provider = helpers.missing_provider

do
  clear()
  if missing_provider('ruby') then
    pending(
      "Cannot find the neovim RubyGem. Try :checkhealth",
      function() end)
    return
  end
end

before_each(function()
  clear()
end)

describe('ruby feature test', function()
  it('works', function()
    eq(1, funcs.has('ruby'))
  end)
end)

describe(':ruby command', function()
  it('evaluates ruby', function()
    command('ruby VIM.command("let g:set_by_ruby = [100, 0]")')
    eq({100, 0}, meths.get_var('set_by_ruby'))
  end)

  it('supports nesting', function()
    command([[ruby VIM.command('ruby VIM.command("let set_by_nested_ruby = 555")')]])
    eq(555, meths.get_var('set_by_nested_ruby'))
  end)
end)

describe(':rubyfile command', function()
  it('evaluates a ruby file', function()
    local fname = 'rubyfile.rb'
    write_file(fname, 'VIM.command("let set_by_rubyfile = 123")')
    command('rubyfile rubyfile.rb')
    eq(123, meths.get_var('set_by_rubyfile'))
    os.remove(fname)
  end)
end)

describe(':rubydo command', function()
  it('exposes the $_ variable for modifying lines', function()
    insert('abc\ndef\nghi\njkl')
    expect([[
      abc
      def
      ghi
      jkl]])

    feed('ggjvj:rubydo $_.upcase!<CR>')
    expect([[
      abc
      DEF
      GHI
      jkl]])
  end)

  it('operates on all lines when not given a range', function()
    insert('abc\ndef\nghi\njkl')
    expect([[
      abc
      def
      ghi
      jkl]])

    feed(':rubydo $_.upcase!<CR>')
    expect([[
      ABC
      DEF
      GHI
      JKL]])
  end)

  it('does not modify the buffer if no changes are made', function()
    command('normal :rubydo 42')
    eq(false, curbufmeths.get_option('modified'))
  end)
end)
