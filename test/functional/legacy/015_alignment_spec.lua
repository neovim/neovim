-- Tests for :right on text with embedded TAB.
-- Also test formatting a paragraph.
-- Also test undo after ":%s" and formatting.

local t = require('test.functional.testutil')()
local feed, insert = t.feed, t.insert
local clear, feed_command, expect = t.clear, t.feed_command, t.expect

describe('alignment', function()
  setup(clear)

  -- luacheck: ignore 621 (Indentation)
  it('is working', function()
    insert([[
      	test for :left
      	  a		a
      	    fa		a
      	  dfa		a
      	        sdfa		a
      	  asdfa		a
      	        xasdfa		a
      asxxdfa		a

      	test for :center
      	  a		a
      	    fa		afd asdf
      	  dfa		a
      	        sdfa		afd asdf
      	  asdfa		a
      	        xasdfa		asdfasdfasdfasdfasdf
      asxxdfa		a

      	test for :right
      	a		a
      	fa		a
      	dfa		a
      	sdfa		a
      	asdfa		a
      	xasdfa		a
      	asxxdfa		a
      	asxa;ofa		a
      	asdfaqwer		a
      	a		ax
      	fa		ax
      	dfa		ax
      	sdfa		ax
      	asdfa		ax
      	xasdfa		ax
      	asxxdfa		ax
      	asxa;ofa		ax
      	asdfaqwer		ax
      	a		axx
      	fa		axx
      	dfa		axx
      	sdfa		axx
      	asdfa		axx
      	xasdfa		axx
      	asxxdfa		axx
      	asxa;ofa		axx
      	asdfaqwer		axx
      	a		axxx
      	fa		axxx
      	dfa		axxx
      	sdfa		axxx
      	asdfa		axxx
      	xasdfa		axxx
      	asxxdfa		axxx
      	asxa;ofa		axxx
      	asdfaqwer		axxx
      	a		axxxo
      	fa		axxxo
      	dfa		axxxo
      	sdfa		axxxo
      	asdfa		axxxo
      	xasdfa		axxxo
      	asxxdfa		axxxo
      	asxa;ofa		axxxo
      	asdfaqwer		axxxo
      	a		axxxoi
      	fa		axxxoi
      	dfa		axxxoi
      	sdfa		axxxoi
      	asdfa		axxxoi
      	xasdfa		axxxoi
      	asxxdfa		axxxoi
      	asxa;ofa		axxxoi
      	asdfaqwer		axxxoi
      	a		axxxoik
      	fa		axxxoik
      	dfa		axxxoik
      	sdfa		axxxoik
      	asdfa		axxxoik
      	xasdfa		axxxoik
      	asxxdfa		axxxoik
      	asxa;ofa		axxxoik
      	asdfaqwer		axxxoik
      	a		axxxoike
      	fa		axxxoike
      	dfa		axxxoike
      	sdfa		axxxoike
      	asdfa		axxxoike
      	xasdfa		axxxoike
      	asxxdfa		axxxoike
      	asxa;ofa		axxxoike
      	asdfaqwer		axxxoike
      	a		axxxoikey
      	fa		axxxoikey
      	dfa		axxxoikey
      	sdfa		axxxoikey
      	asdfa		axxxoikey
      	xasdfa		axxxoikey
      	asxxdfa		axxxoikey
      	asxa;ofa		axxxoikey
      	asdfaqwer		axxxoikey

      xxxxx xx xxxxxx
      xxxxxxx xxxxxxxxx xxx xxxx xxxxx xxxxx xxx xx
      xxxxxxxxxxxxxxxxxx xxxxx xxxx, xxxx xxxx xxxx xxxx xxx xx xx
      xx xxxxxxx. xxxx xxxx.

      > xx xx, xxxx xxxx xxx xxxx xxx xxxxx xxx xxx xxxxxxx xxx xxxxx
      > xxxxxx xxxxxxx: xxxx xxxxxxx, xx xxxxxx xxxx xxxxxxxxxx

      aa aa aa aa
      bb bb bb bb
      cc cc cc cc]])

    feed_command('set tw=65')

    feed([[:/^\s*test for :left/,/^\s*test for :center/ left<cr>]])
    feed([[:/^\s*test for :center/,/^\s*test for :right/ center<cr>]])
    feed([[:/^\s*test for :right/,/^xxx/-1 right<cr>]])

    feed_command('set fo+=tcroql tw=72')

    feed('/xxxxxxxx$<cr>')
    feed('0gq6kk<cr>')

    -- Undo/redo here to make the next undo only work on the following changes.
    feed('u<cr>')
    feed_command('map gg :.,.+2s/^/x/<CR>kk:set tw=3<CR>gqq')
    feed_command('/^aa')
    feed('ggu<cr>')

    -- Assert buffer contents.
    expect([[
      test for :left
      a		a
      fa		a
      dfa		a
      sdfa		a
      asdfa		a
      xasdfa		a
      asxxdfa		a

      			test for :center
      			 a		a
      		      fa		afd asdf
      			 dfa		a
      		    sdfa		afd asdf
      			 asdfa		a
      	      xasdfa		asdfasdfasdfasdfasdf
      			asxxdfa		a

      						  test for :right
      						      a		a
      						     fa		a
      						    dfa		a
      						   sdfa		a
      						  asdfa		a
      						 xasdfa		a
      						asxxdfa		a
      					       asxa;ofa		a
      					      asdfaqwer		a
      					      a		ax
      					     fa		ax
      					    dfa		ax
      					   sdfa		ax
      					  asdfa		ax
      					 xasdfa		ax
      					asxxdfa		ax
      				       asxa;ofa		ax
      				      asdfaqwer		ax
      					      a		axx
      					     fa		axx
      					    dfa		axx
      					   sdfa		axx
      					  asdfa		axx
      					 xasdfa		axx
      					asxxdfa		axx
      				       asxa;ofa		axx
      				      asdfaqwer		axx
      					      a		axxx
      					     fa		axxx
      					    dfa		axxx
      					   sdfa		axxx
      					  asdfa		axxx
      					 xasdfa		axxx
      					asxxdfa		axxx
      				       asxa;ofa		axxx
      				      asdfaqwer		axxx
      					      a		axxxo
      					     fa		axxxo
      					    dfa		axxxo
      					   sdfa		axxxo
      					  asdfa		axxxo
      					 xasdfa		axxxo
      					asxxdfa		axxxo
      				       asxa;ofa		axxxo
      				      asdfaqwer		axxxo
      					      a		axxxoi
      					     fa		axxxoi
      					    dfa		axxxoi
      					   sdfa		axxxoi
      					  asdfa		axxxoi
      					 xasdfa		axxxoi
      					asxxdfa		axxxoi
      				       asxa;ofa		axxxoi
      				      asdfaqwer		axxxoi
      					      a		axxxoik
      					     fa		axxxoik
      					    dfa		axxxoik
      					   sdfa		axxxoik
      					  asdfa		axxxoik
      					 xasdfa		axxxoik
      					asxxdfa		axxxoik
      				       asxa;ofa		axxxoik
      				      asdfaqwer		axxxoik
      					      a		axxxoike
      					     fa		axxxoike
      					    dfa		axxxoike
      					   sdfa		axxxoike
      					  asdfa		axxxoike
      					 xasdfa		axxxoike
      					asxxdfa		axxxoike
      				       asxa;ofa		axxxoike
      				      asdfaqwer		axxxoike
      					      a		axxxoikey
      					     fa		axxxoikey
      					    dfa		axxxoikey
      					   sdfa		axxxoikey
      					  asdfa		axxxoikey
      					 xasdfa		axxxoikey
      					asxxdfa		axxxoikey
      				       asxa;ofa		axxxoikey
      				      asdfaqwer		axxxoikey

      xxxxx xx xxxxxx xxxxxxx xxxxxxxxx xxx xxxx xxxxx xxxxx xxx xx
      xxxxxxxxxxxxxxxxxx xxxxx xxxx, xxxx xxxx xxxx xxxx xxx xx xx xx xxxxxxx.
      xxxx xxxx.

      > xx xx, xxxx xxxx xxx xxxx xxx xxxxx xxx xxx xxxxxxx xxx xxxxx xxxxxx
      > xxxxxxx: xxxx xxxxxxx, xx xxxxxx xxxx xxxxxxxxxx

      aa aa aa aa
      bb bb bb bb
      cc cc cc cc]])
  end)
end)
