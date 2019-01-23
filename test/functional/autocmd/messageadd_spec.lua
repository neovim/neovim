local helpers = require('test.functional.helpers')(after_each)

local clear, command =
  helpers.clear, helpers.command
local eval, eq =
  helpers.eval, helpers.eq
local meths = helpers.meths
local feed = helpers.feed
local insert = helpers.insert


describe('autocmd MessageAdd', function()
  before_each(clear)

  it('triggered by echomsg', function()
    command('autocmd MessageAdd * let g:test = 1')
    command('echomsg "msg"')
    eq(1, eval('g:test'))
    eq('msg', meths.command_output('messages'))
  end)

  it('triggered by echoerr', function()
    command('autocmd MessageAdd * let g:test = 2')
    feed(':echoerr "err"<cr>')
    eq(2, eval('g:test'))
    eq('err', meths.command_output('messages'))
  end)

  it('triggered by erroneous command', function()
    command('autocmd MessageAdd * let g:test = 3')
    feed(':thiscommandisfake<cr>')
    eq(3, eval('g:test'))
    eq('E492: Not an editor command: thiscommandisfake', meths.command_output('messages'))
  end)

  it('triggered by write', function()
    command('autocmd MessageAdd * let g:test = 4')
    insert('test')
    feed(':write test_file<cr>')
    eq(4, eval('g:test'))
    os.remove('test_file')
  end)
end)
