-- Test Virtual replace mode.

local helpers = require('test.functional.helpers')(after_each)
local feed = helpers.feed
local clear, feed_command, expect = helpers.clear, helpers.feed_command, helpers.expect

describe('Virtual replace mode', function()
  setup(clear)

  -- luacheck: ignore 621 (Indentation)
  it('is working', function()
    -- Make sure that backspace works, no matter what termcap is used.
    feed_command('set t_kD=x7f t_kb=x08')
    -- Use vi default for 'smarttab'
    feed_command('set nosmarttab')
    feed('ggdGa<cr>')
    feed('abcdefghi<cr>')
    feed('jk<tab>lmn<cr>')
    feed('<Space><Space><Space><Space>opq<tab>rst<cr>')
    feed('<C-d>uvwxyz<cr>')
    feed('<esc>gg')
    feed_command('set ai')
    feed_command('set bs=2')
    feed('gR0<C-d> 1<cr>')
    feed('A<cr>')
    feed('BCDEFGHIJ<cr>')
    feed('<tab>KL<cr>')
    feed('MNO<cr>')
    feed('PQR<esc>G')
    feed_command('ka')
    feed('o0<C-d><cr>')
    feed('abcdefghi<cr>')
    feed('jk<tab>lmn<cr>')
    feed('<Space><Space><Space><Space>opq<tab>rst<cr>')
    feed('<C-d>uvwxyz<cr>')
    feed([[<esc>'ajgR0<C-d> 1<cr>]])
    feed('A<cr>')
    feed('BCDEFGHIJ<cr>')
    feed('<tab>KL<cr>')
    feed('MNO<cr>')
    feed('PQR<C-h><C-h><C-h><C-h><C-h><C-h><C-h><C-h><C-h><C-h><C-h><C-h><C-h><C-h><C-h><C-h><C-h><C-h><C-h><C-h><C-h><C-h><C-h><C-h><C-h><C-h><C-h><C-h><C-h><esc>:$<cr>')
    feed('iab<tab>cdefghi<tab>jkl<esc>0gRAB......CDEFGHI.J<esc>o<esc>:<cr>')
    feed('iabcdefghijklmnopqrst<esc>0gRAB<tab>IJKLMNO<tab>QR<esc>')

    -- Assert buffer contents.
    expect([=[
       1
       A
       BCDEFGHIJ
       	KL
      	MNO
      	PQR
       1
      abcdefghi
      jk	lmn
          opq	rst
      uvwxyz
      AB......CDEFGHI.Jkl
      AB	IJKLMNO	QRst]=])
  end)
end)
