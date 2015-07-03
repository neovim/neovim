-- Tests for "vaBiB", end could be wrong.
-- Also test ":s/pat/sub/" with different ~s in sub.
-- Also test for ^Vxff and ^Vo123 in Insert mode.
-- Also test "[m", "]m", "[M" and "]M"
-- Also test search()

local helpers = require('test.functional.helpers')(after_each)
local feed, insert, source, eq, eval, clear, execute, expect =
  helpers.feed, helpers.insert, helpers.source, helpers.eq, helpers.eval,
  helpers.clear, helpers.execute, helpers.expect

local function expect_line(string)
  return eq(string, eval('getline(".")'))
end

describe('legacy test 14:', function()

  before_each(clear)

  it('vaBiB normal mode command selects the right end', function()
    insert([[
      - Bug in "vPPPP" on this text (Webb):
      	{
      		cmd;
      		{
      			cmd;	/* <-- Start cursor here */
      			{
      			}
      		}
      	}
      ]])
    execute('/Start cursor here')
    feed('vaBiBD')
    expect([[
      - Bug in "vPPPP" on this text (Webb):
      	{
      	}
      ]])
  end)

  it(':s/pat/sub/ with different ~s in sub is working', function()
    insert('- Bug in "vPPPP" on this text (Webb):')
    execute('s/u/~u~/')
    expect('- Bug in "vPPPP" on this text (Webb):')
    execute('s/i/~u~/')
    expect('- Bug uuun "vPPPP" on this text (Webb):')
    execute('s/o/~~~/')
    expect('- Bug uuun "vPPPP" uuuuuuuuun this text (Webb):')
  end)

  describe('^Vxff and ^Vo123', function()
    local result = 'ABC !a\x0fg\x078'
    it('are working in insert mode', function()
      feed('i<C-V>65<C-V>x42<C-V>o103 <C-V>33a<C-V>xfg<C-V>o78<ESC>')
      expect(result)
    end)
    it('are working with ":exe normal"', function()
      execute([[let tt = "i\<C-V>65\<C-V>x42\<C-V>o103 \<C-V>33a\<C-V>xfg\<C-V>o78\<Esc>"]])
      execute('exe "normal " . tt')
      expect(result)
    end)
  end)

  it('goto start/end of method is working', function()
    insert([[
      Piece of Java
      {
      	tt m1 {
      		t1;
      	} e1

      	tt m2 {
      		t2;
      	} e2

      	tt m3 {
      		if (x)
      		{
      			t3;
      		}
      	} e3
      }
      ]])
    execute('/^Piece')
    feed('2]maA<esc>')
    expect_line('\ttt m1 {A')
    feed('j]maB<esc>')
    expect_line('\ttt m2 {B')
    feed(']maC<esc>')
    expect_line('\ttt m3 {C')
    feed('[maD<esc>')
    expect_line('\ttt m3 {DC')
    feed('k2[maE<esc>')
    expect_line('\ttt m1 {EA')
    feed('3[maF<esc>')
    expect_line('{F')
    feed(']MaG<esc>')
    expect_line('\t}G e1')
    feed('j2]MaH<esc>')
    expect_line('\t}H e3')
    feed(']M]MaI<esc>')
    expect_line('}I')
    feed('2[MaJ<esc>')
    expect_line('\t}JH e3')
    feed('k[MaK<esc>')
    expect_line('\t}K e2')
    feed('3[MaL<esc>')
    expect_line('{LF')
  end)

  it('search() is working', function()
    insert([[

      foobar

      substitute foo asdf

      one two
      search()
      ]])
    execute('/^foobar')
    execute([[let startline = line('.')]])
    eq(0, eval("search('foobar', 'c') - startline"))
    feed('j')
    eq(1, eval("search('^$', 'c') - startline"))
    eq(1, eval("search('^$', 'bc') - startline"))
    execute('/two')
    execute([[call search('.', 'c')]])
    eq('two', eval("getline('.')[col('.') - 1:]"))
    execute('/^substitute')
    execute('s/foo/bar/')
    eq('foo', eval('@/'))
    execute('/^substitute')
    execute('keeppatterns s/asdf/xyz/')
    eq('^substitute', eval('@/'))
    expect_line('substitute bar xyz')
    execute('/^substitute')
    feed('Y')
    eq('substitute bar xyz\n', eval('@0'))
    execute('/bar /e')
    feed('-')
    execute('keeppatterns /xyz')
    feed('0dn')
    expect_line('xyz')
  end)
end)
