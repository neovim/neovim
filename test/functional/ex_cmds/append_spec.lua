local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local feed = helpers.feed
local clear = helpers.clear
local funcs = helpers.funcs
local command = helpers.command
local curbufmeths = helpers.curbufmeths

before_each(function()
  clear()
  curbufmeths.set_lines(0, 1, true, { 'foo', 'bar', 'baz' })
end)

local buffer_contents = function()
  return curbufmeths.get_lines(0, -1, false)
end

local cmdtest = function(cmd, prep, ret1)
  describe(':' .. cmd, function()
    it(cmd .. 's' .. prep .. ' the current line by default', function()
      command(cmd .. '\nabc\ndef\n')
      eq(ret1, buffer_contents())
    end)
    -- Used to crash because this invokes history processing which uses
    -- hist_char2type which after fdb68e35e4c729c7ed097d8ade1da29e5b3f4b31
    -- crashed.
    it(cmd .. 's' .. prep .. ' the current line by default when feeding',
    function()
      feed(':' .. cmd .. '\nabc\ndef\n.\n')
      eq(ret1, buffer_contents())
    end)
    -- This used to crash since that commit as well.
    it('opens empty cmdline window', function()
      local hisline = '" Some comment to be stored in history'
      feed(':' .. hisline .. '<CR>')
      feed(':' .. cmd .. '<CR>abc<CR>def<C-f>')
      eq({ 'def' }, buffer_contents())
      eq(hisline, funcs.histget(':', -2))
      eq(cmd, funcs.histget(':'))
      -- Test that command-line window was launched
      eq('nofile', curbufmeths.get_option('buftype'))
      eq('n', funcs.mode(1))
      feed('<CR>')
      eq('c', funcs.mode(1))
      feed('.<CR>')
      eq('n', funcs.mode(1))
      eq(ret1, buffer_contents())
    end)
  end)
end
cmdtest('insert', ' before', { 'abc', 'def', 'foo', 'bar', 'baz' })
cmdtest('append', ' after', { 'foo', 'abc', 'def', 'bar', 'baz' })
cmdtest('change', '', { 'abc', 'def', 'bar', 'baz' })
