local t = require('test.functional.testutil')(after_each)

local assert_alive = t.assert_alive
local clear = t.clear
local command = t.command
local eq = t.eq
local exc_exec = t.exc_exec
local expect = t.expect
local feed = t.feed
local feed_command = t.feed_command
local fn = t.fn
local insert = t.insert
local api = t.api
local missing_provider = t.missing_provider
local matches = t.matches
local write_file = t.write_file
local pcall_err = t.pcall_err

do
  clear()
  local reason = missing_provider('ruby')
  if reason then
    it(':ruby reports E319 if provider is missing', function()
      local expected = [[Vim%(ruby.*%):E319: No "ruby" provider found.*]]
      matches(expected, pcall_err(command, 'ruby puts "foo"'))
      matches(expected, pcall_err(command, 'rubyfile foo'))
    end)
    pending(string.format('Missing neovim RubyGem (%s)', reason), function() end)
    return
  end
end

before_each(function()
  clear()
end)

describe('ruby feature test', function()
  it('works', function()
    eq(1, fn.has('ruby'))
  end)
end)

describe(':ruby command', function()
  it('evaluates ruby', function()
    command('ruby VIM.command("let g:set_by_ruby = [100, 0]")')
    eq({ 100, 0 }, api.nvim_get_var('set_by_ruby'))
  end)

  it('supports nesting', function()
    command([[ruby VIM.command('ruby VIM.command("let set_by_nested_ruby = 555")')]])
    eq(555, api.nvim_get_var('set_by_nested_ruby'))
  end)
end)

describe(':rubyfile command', function()
  it('evaluates a ruby file', function()
    local fname = 'rubyfile.rb'
    write_file(fname, 'VIM.command("let set_by_rubyfile = 123")')
    command('rubyfile rubyfile.rb')
    eq(123, api.nvim_get_var('set_by_rubyfile'))
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
    eq(false, api.nvim_get_option_value('modified', {}))
  end)
end)

describe('ruby provider', function()
  it('RPC call to expand("<afile>") during BufDelete #5245 #5617', function()
    t.add_builddir_to_rtp()
    command([=[autocmd BufDelete * ruby VIM::evaluate('expand("<afile>")')]=])
    feed_command('help help')
    assert_alive()
  end)
end)

describe('rubyeval()', function()
  it('evaluates ruby objects', function()
    eq({ 1, 2, { ['key'] = 'val' } }, fn.rubyeval('[1, 2, {key: "val"}]'))
  end)

  it('returns nil for empty strings', function()
    eq(vim.NIL, fn.rubyeval(''))
  end)

  it('errors out when given non-string', function()
    eq('Vim(call):E474: Invalid argument', exc_exec('call rubyeval(10)'))
    eq('Vim(call):E474: Invalid argument', exc_exec('call rubyeval(v:_null_dict)'))
    eq('Vim(call):E474: Invalid argument', exc_exec('call rubyeval(v:_null_list)'))
    eq('Vim(call):E474: Invalid argument', exc_exec('call rubyeval(0.0)'))
    eq('Vim(call):E474: Invalid argument', exc_exec('call rubyeval(function("tr"))'))
    eq('Vim(call):E474: Invalid argument', exc_exec('call rubyeval(v:true)'))
    eq('Vim(call):E474: Invalid argument', exc_exec('call rubyeval(v:false)'))
    eq('Vim(call):E474: Invalid argument', exc_exec('call rubyeval(v:null)'))
  end)
end)
