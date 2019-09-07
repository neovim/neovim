local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local curbufmeths = helpers.curbufmeths
local eq = helpers.eq
local eval = helpers.eval
local expect = helpers.expect
local feed = helpers.feed
local feed_command = helpers.feed_command
local funcs = helpers.funcs
local insert = helpers.insert
local meths = helpers.meths
local missing_provider = helpers.missing_provider
local matches = helpers.matches
local write_file = helpers.write_file
local pcall_err = helpers.pcall_err

do
  clear()
  if missing_provider('ruby') then
    it(':ruby reports E319 if provider is missing', function()
      local expected = [[Vim%(ruby.*%):E319: No "ruby" provider found.*]]
      matches(expected, pcall_err(command, 'ruby puts "foo"'))
      matches(expected, pcall_err(command, 'rubyfile foo'))
    end)
    pending("Missing neovim RubyGem.", function() end)
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

describe('ruby provider', function()
  it('RPC call to expand("<afile>") during BufDelete #5245 #5617', function()
    helpers.add_builddir_to_rtp()
    command([=[autocmd BufDelete * ruby VIM::evaluate('expand("<afile>")')]=])
    feed_command('help help')
    eq(2, eval('1+1'))  -- Still alive?
  end)
end)
