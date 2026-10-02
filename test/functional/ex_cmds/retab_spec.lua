local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local eq, matches, pcall_err = t.eq, t.matches, t.pcall_err
local clear, command, api, fn = n.clear, n.command, n.api, n.fn

describe(':retab', function()
  before_each(clear)

  it('uses the new tab width for C indentation', function()
    command('setlocal tabstop=8 shiftwidth=0 expandtab')
    api.nvim_buf_set_lines(0, 0, -1, true, { 'int main() {', 'return 0;', '}' })
    command('1retab 4')
    command('normal! gg=G')
    eq(4, fn.indent(2))
  end)

  for _, option in ipairs({ 'tabstop', 'vartabstop' }) do
    it('updates indent folds after changing ' .. option, function()
      command('setlocal shiftwidth=4 foldmethod=indent ' .. option .. '=8')
      api.nvim_buf_set_lines(0, 0, -1, true, { 'top', '\tfirst', '\tsecond', 'end' })
      eq(2, fn.foldlevel(2))

      -- Leave the tabs on lines 2-3 untouched; their width changes with the option.
      command('1retab 4')
      eq(1, fn.foldlevel(2))
    end)
  end

  it('keeps list enabled when the argument is invalid', function()
    command('setlocal list')
    matches('E487:', pcall_err(command, 'retab -1'))
    eq(true, api.nvim_get_option_value('list', { win = 0 }))
  end)

  it('keeps the cursor position set by an OptionSet callback in another buffer', function()
    local other = api.nvim_create_buf(true, false)
    api.nvim_buf_set_lines(other, 0, -1, true, { 'some text' })
    command('autocmd OptionSet tabstop buffer ' .. other .. ' | call cursor(1, 6)')
    command('retab 4')
    eq(other, api.nvim_get_current_buf())
    eq({ 1, 5 }, api.nvim_win_get_cursor(0))
  end)
end)
