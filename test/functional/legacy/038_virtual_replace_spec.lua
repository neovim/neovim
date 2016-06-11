-- Test Virtual replace mode.

local helpers = require('test.functional.helpers')(after_each)
local feed = helpers.feed
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('Virtual replace mode', function()
  setup(clear)

  it('is working', function()
    -- Make sure that backspace works, no matter what termcap is used.
    execute('set t_kD=x7f t_kb=x08')
    -- Use vi default for 'smarttab'
    execute('set nosmarttab')
    feed('ggdGa<cr>')
    feed('abcdefghi<cr>')
    feed('jk<tab>lmn<cr>')
    feed('<Space><Space><Space><Space>opq<tab>rst<cr>')
    feed('<C-d>uvwxyz<cr>')
    feed('<esc>gg')
    execute('set ai')
    execute('set bs=2')
    feed('gR0<C-d> 1<cr>')
    feed('A<cr>')
    feed('BCDEFGHIJ<cr>')
    feed('<tab>KL<cr>')
    feed('MNO<cr>')
    feed('PQR<esc>G')
    execute('ka')
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
