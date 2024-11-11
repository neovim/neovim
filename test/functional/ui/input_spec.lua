local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear, feed_command = n.clear, n.feed_command
local feed, next_msg, eq = n.feed, n.next_msg, t.eq
local command = n.command
local expect = n.expect
local curbuf_contents = n.curbuf_contents
local api = n.api
local exec_lua = n.exec_lua
local write_file = t.write_file
local fn = n.fn
local eval = n.eval

before_each(clear)

describe('mappings', function()
  local add_mapping = function(mapping, send)
    local cmd = 'nnoremap '
      .. mapping
      .. " :call rpcnotify(1, 'mapped', '"
      .. send:gsub('<', '<lt>')
      .. "')<cr>"
    feed_command(cmd)
  end

  local check_mapping = function(mapping, expected)
    feed(mapping)
    eq({ 'notification', 'mapped', { expected } }, next_msg())
  end

  before_each(function()
    add_mapping('<A-l>', '<A-l>')
    add_mapping('<A-L>', '<A-L>')
    add_mapping('<D-l>', '<D-l>')
    add_mapping('<D-L>', '<D-L>')
    add_mapping('<C-L>', '<C-L>')
    add_mapping('<C-S-L>', '<C-S-L>')
    add_mapping('<s-up>', '<s-up>')
    add_mapping('<s-up>', '<s-up>')
    add_mapping('<c-s-up>', '<c-s-up>')
    add_mapping('<c-s-a-up>', '<c-s-a-up>')
    add_mapping('<c-s-a-d-up>', '<c-s-a-d-up>')
    add_mapping('<c-d-a>', '<c-d-a>')
    add_mapping('<d-1>', '<d-1>')
    add_mapping('<khome>', '<khome>')
    add_mapping('<kup>', '<kup>')
    add_mapping('<kpageup>', '<kpageup>')
    add_mapping('<kleft>', '<kleft>')
    add_mapping('<korigin>', '<korigin>')
    add_mapping('<kright>', '<kright>')
    add_mapping('<kend>', '<kend>')
    add_mapping('<kdown>', '<kdown>')
    add_mapping('<kpagedown>', '<kpagedown>')
    add_mapping('<kinsert>', '<kinsert>')
    add_mapping('<kdel>', '<kdel>')
    add_mapping('<kdivide>', '<kdivide>')
    add_mapping('<kmultiply>', '<kmultiply>')
    add_mapping('<kminus>', '<kminus>')
    add_mapping('<kplus>', '<kplus>')
    add_mapping('<kenter>', '<kenter>')
    add_mapping('<kcomma>', '<kcomma>')
    add_mapping('<kequal>', '<kequal>')
    add_mapping('<f38>', '<f38>')
    add_mapping('<f63>', '<f63>')
  end)

  it('ok', function()
    check_mapping('<A-l>', '<A-l>')
    check_mapping('<A-L>', '<A-L>')
    check_mapping('<A-S-l>', '<A-L>')
    check_mapping('<A-S-L>', '<A-L>')
    check_mapping('<D-l>', '<D-l>')
    check_mapping('<D-L>', '<D-L>')
    check_mapping('<D-S-l>', '<D-L>')
    check_mapping('<D-S-L>', '<D-L>')
    check_mapping('<C-l>', '<C-L>')
    check_mapping('<C-L>', '<C-L>')
    check_mapping('<C-S-l>', '<C-S-L>')
    check_mapping('<C-S-L>', '<C-S-L>')
    check_mapping('<s-up>', '<s-up>')
    check_mapping('<c-s-up>', '<c-s-up>')
    check_mapping('<s-c-up>', '<c-s-up>')
    check_mapping('<c-s-a-up>', '<c-s-a-up>')
    check_mapping('<s-c-a-up>', '<c-s-a-up>')
    check_mapping('<c-a-s-up>', '<c-s-a-up>')
    check_mapping('<s-a-c-up>', '<c-s-a-up>')
    check_mapping('<a-c-s-up>', '<c-s-a-up>')
    check_mapping('<a-s-c-up>', '<c-s-a-up>')
    check_mapping('<c-s-a-d-up>', '<c-s-a-d-up>')
    check_mapping('<s-a-d-c-up>', '<c-s-a-d-up>')
    check_mapping('<d-s-a-c-up>', '<c-s-a-d-up>')
    check_mapping('<c-d-a>', '<c-d-a>')
    check_mapping('<d-c-a>', '<c-d-a>')
    check_mapping('<d-1>', '<d-1>')
    check_mapping('<khome>', '<khome>')
    check_mapping('<KP7>', '<khome>')
    check_mapping('<kup>', '<kup>')
    check_mapping('<KP8>', '<kup>')
    check_mapping('<kpageup>', '<kpageup>')
    check_mapping('<KP9>', '<kpageup>')
    check_mapping('<kleft>', '<kleft>')
    check_mapping('<KP4>', '<kleft>')
    check_mapping('<korigin>', '<korigin>')
    check_mapping('<KP5>', '<korigin>')
    check_mapping('<kright>', '<kright>')
    check_mapping('<KP6>', '<kright>')
    check_mapping('<kend>', '<kend>')
    check_mapping('<KP1>', '<kend>')
    check_mapping('<kdown>', '<kdown>')
    check_mapping('<KP2>', '<kdown>')
    check_mapping('<kpagedown>', '<kpagedown>')
    check_mapping('<KP3>', '<kpagedown>')
    check_mapping('<kinsert>', '<kinsert>')
    check_mapping('<KP0>', '<kinsert>')
    check_mapping('<kdel>', '<kdel>')
    check_mapping('<KPPeriod>', '<kdel>')
    check_mapping('<kdivide>', '<kdivide>')
    check_mapping('<KPDiv>', '<kdivide>')
    check_mapping('<kmultiply>', '<kmultiply>')
    check_mapping('<KPMult>', '<kmultiply>')
    check_mapping('<kminus>', '<kminus>')
    check_mapping('<KPMinus>', '<kminus>')
    check_mapping('<kplus>', '<kplus>')
    check_mapping('<KPPlus>', '<kplus>')
    check_mapping('<kenter>', '<kenter>')
    check_mapping('<KPEnter>', '<kenter>')
    check_mapping('<kcomma>', '<kcomma>')
    check_mapping('<KPComma>', '<kcomma>')
    check_mapping('<kequal>', '<kequal>')
    check_mapping('<KPEquals>', '<kequal>')
    check_mapping('<f38>', '<f38>')
    check_mapping('<f63>', '<f63>')
  end)

  it('support meta + multibyte char mapping', function()
    add_mapping('<m-ä>', '<m-ä>')
    check_mapping('<m-ä>', '<m-ä>')
  end)
end)

describe('input utf sequences that contain K_SPECIAL (0x80)', function()
  it('ok', function()
    feed('i…<esc>')
    expect('…')
  end)

  it('can be mapped', function()
    command('inoremap … E280A6')
    feed('i…<esc>')
    expect('E280A6')
  end)
end)

describe('input utf sequences that contain CSI (0x9B)', function()
  it('ok', function()
    feed('iě<esc>')
    expect('ě')
  end)

  it('can be mapped', function()
    command('inoremap ě C49B')
    feed('iě<esc>')
    expect('C49B')
  end)
end)

describe('input split utf sequences', function()
  it('ok', function()
    local str = '►'
    feed('i' .. str:sub(1, 1))
    vim.uv.sleep(10)
    feed(str:sub(2, 3))
    expect('►')
  end)

  it('can be mapped', function()
    command('inoremap ► E296BA')
    local str = '►'
    feed('i' .. str:sub(1, 1))
    vim.uv.sleep(10)
    feed(str:sub(2, 3))
    expect('E296BA')
  end)
end)

describe('input pairs', function()
  describe('<tab> / <c-i>', function()
    it('ok', function()
      feed('i<tab><c-i><esc>')
      eq('\t\t', curbuf_contents())
    end)

    describe('can be mapped separately', function()
      it('if <tab> is mapped after <c-i>', function()
        command('inoremap <c-i> CTRL-I!')
        command('inoremap <tab> TAB!')
        feed('i<tab><c-i><esc>')
        eq('TAB!CTRL-I!', curbuf_contents())
      end)

      it('if <tab> is mapped before <c-i>', function()
        command('inoremap <tab> TAB!')
        command('inoremap <c-i> CTRL-I!')
        feed('i<tab><c-i><esc>')
        eq('TAB!CTRL-I!', curbuf_contents())
      end)
    end)
  end)

  describe('<cr> / <c-m>', function()
    it('ok', function()
      feed('iunos<c-m>dos<cr>tres<esc>')
      eq('unos\ndos\ntres', curbuf_contents())
    end)

    describe('can be mapped separately', function()
      it('if <cr> is mapped after <c-m>', function()
        command('inoremap <c-m> SNIPPET!')
        command('inoremap <cr> , and then<cr>')
        feed('iunos<c-m>dos<cr>tres<esc>')
        eq('unosSNIPPET!dos, and then\ntres', curbuf_contents())
      end)

      it('if <cr> is mapped before <c-m>', function()
        command('inoremap <cr> , and then<cr>')
        command('inoremap <c-m> SNIPPET!')
        feed('iunos<c-m>dos<cr>tres<esc>')
        eq('unosSNIPPET!dos, and then\ntres', curbuf_contents())
      end)
    end)
  end)

  describe('<esc> / <c-[>', function()
    it('ok', function()
      feed('2adouble<c-[>asingle<esc>')
      eq('doubledoublesingle', curbuf_contents())
    end)

    describe('can be mapped separately', function()
      it('if <esc> is mapped after <c-[>', function()
        command('inoremap <c-[> HALLOJ!')
        command('inoremap <esc> ,<esc>')
        feed('2adubbel<c-[>upp<esc>')
        eq('dubbelHALLOJ!upp,dubbelHALLOJ!upp,', curbuf_contents())
      end)

      it('if <esc> is mapped before <c-[>', function()
        command('inoremap <esc> ,<esc>')
        command('inoremap <c-[> HALLOJ!')
        feed('2adubbel<c-[>upp<esc>')
        eq('dubbelHALLOJ!upp,dubbelHALLOJ!upp,', curbuf_contents())
      end)
    end)
  end)
end)

it('Ctrl-6 is Ctrl-^ vim-patch:8.1.2333', function()
  command('split aaa')
  command('edit bbb')
  feed('<C-6>')
  eq('aaa', fn.bufname())
end)

it('c_CTRL-R_CTRL-R, i_CTRL-R_CTRL-R, i_CTRL-G_CTRL-K work properly vim-patch:8.1.2346', function()
  command('set timeoutlen=10')

  command([[let @a = 'aaa']])
  feed([[:let x = '<C-R><C-R>a'<CR>]])
  eq([[let x = 'aaa']], eval('@:'))

  feed('a<C-R><C-R>a<Esc>')
  expect('aaa')
  command('bwipe!')

  feed('axx<CR>yy<C-G><C-K>a<Esc>')
  expect([[
  axx
  yy]])
end)

it('typing a simplifiable key at hit-enter prompt triggers mapping vim-patch:8.2.0839', function()
  local screen = Screen.new(60, 8)
  command([[nnoremap <C-6> <Cmd>echo 'hit ctrl-6'<CR>]])
  feed_command('ls')
  screen:expect([[
                                                                |
    {1:~                                                           }|*3
    {3:                                                            }|
    :ls                                                         |
      1 %a   "[No Name]"                    line 1              |
    {6:Press ENTER or type command to continue}^                     |
  ]])
  feed('<C-6>')
  screen:expect([[
    ^                                                            |
    {1:~                                                           }|*6
    hit ctrl-6                                                  |
  ]])
end)

it('mixing simplified and unsimplified keys can trigger mapping vim-patch:8.2.0916', function()
  command('set timeoutlen=10')
  command([[imap ' <C-W>]])
  command('imap <C-W><C-A> c-a')
  feed([[a'<C-A>]])
  expect('c-a')
end)

it('unsimplified mapping works when there was a partial match vim-patch:8.2.4504', function()
  command('set timeoutlen=10')
  command('nnoremap <C-J> a')
  command('nnoremap <NL> x')
  command('nnoremap <C-J>x <Nop>')
  fn.setline(1, 'x')
  -- CTRL-J b should have trigger the <C-J> mapping and then insert "b"
  feed('<C-J>b<Esc>')
  expect('xb')
end)

describe('input non-printable chars', function()
  after_each(function()
    os.remove('Xtest-overwrite')
  end)

  it("doesn't crash when echoing them back", function()
    write_file('Xtest-overwrite', [[foobar]])
    local screen = Screen.new(60, 8)
    command('set shortmess-=F')

    feed_command('e Xtest-overwrite')
    screen:expect([[
      ^foobar                                                      |
      {1:~                                                           }|*6
      "Xtest-overwrite" [noeol] 1L, 6B                            |
    ]])

    -- Wait for some time so that the timestamp changes.
    vim.uv.sleep(10)
    write_file('Xtest-overwrite', [[smurf]])
    feed_command('w')
    screen:expect([[
      foobar                                                      |
      {1:~                                                           }|*3
      {3:                                                            }|
      "Xtest-overwrite"                                           |
      {9:WARNING: The file has been changed since reading it!!!}      |
      {6:Do you really want to write to it (y/n)?}^                    |
    ]])

    feed('u')
    screen:expect([[
      foobar                                                      |
      {1:~                                                           }|*2
      {3:                                                            }|
      "Xtest-overwrite"                                           |
      {9:WARNING: The file has been changed since reading it!!!}      |
      {6:Do you really want to write to it (y/n)?}u                   |
      {6:Do you really want to write to it (y/n)?}^                    |
    ]])

    feed('\005')
    screen:expect([[
      foobar                                                      |
      {1:~                                                           }|
      {3:                                                            }|
      "Xtest-overwrite"                                           |
      {9:WARNING: The file has been changed since reading it!!!}      |
      {6:Do you really want to write to it (y/n)?}u                   |
      {6:Do you really want to write to it (y/n)?}                    |
      {6:Do you really want to write to it (y/n)?}^                    |
    ]])

    feed('n')
    screen:expect([[
      foobar                                                      |
      {3:                                                            }|
      "Xtest-overwrite"                                           |
      {9:WARNING: The file has been changed since reading it!!!}      |
      {6:Do you really want to write to it (y/n)?}u                   |
      {6:Do you really want to write to it (y/n)?}                    |
      {6:Do you really want to write to it (y/n)?}n                   |
      {6:Press ENTER or type command to continue}^                     |
    ]])

    feed('<cr>')
    screen:expect([[
      ^foobar                                                      |
      {1:~                                                           }|*6
                                                                  |
    ]])
  end)
end)

describe('event processing and input', function()
  it('not blocked by event bursts', function()
    api.nvim_set_keymap(
      '',
      '<f2>',
      "<cmd>lua vim.rpcnotify(1, 'stop') winning = true <cr>",
      { noremap = true }
    )

    exec_lua [[
      winning = false
      burst = vim.schedule_wrap(function(tell)
        if tell then
          vim.rpcnotify(1, 'start')
        end
        -- Are we winning, son?
        if not winning then
          burst(false)
        end
      end)
      burst(true)
    ]]

    eq({ 'notification', 'start', {} }, next_msg())
    feed '<f2>'
    eq({ 'notification', 'stop', {} }, next_msg())
  end)
end)

describe('display is updated', function()
  local screen
  before_each(function()
    screen = Screen.new(60, 8)
  end)

  it('in Insert mode after <Nop> mapping #17911', function()
    command('imap <Plug>test <Nop>')
    command('imap <F2> abc<CR><Plug>test')
    feed('i<F2>')
    screen:expect([[
      abc                                                         |
      ^                                                            |
      {1:~                                                           }|*5
      {5:-- INSERT --}                                                |
    ]])
  end)

  it('in Insert mode after empty string <expr> mapping #17911', function()
    command('imap <expr> <Plug>test ""')
    command('imap <F2> abc<CR><Plug>test')
    feed('i<F2>')
    screen:expect([[
      abc                                                         |
      ^                                                            |
      {1:~                                                           }|*5
      {5:-- INSERT --}                                                |
    ]])
  end)
end)
