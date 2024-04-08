-- Tests for tag search with !_TAG_FILE_ENCODING.

local t = require('test.functional.testutil')(after_each)
local insert, source, clear, expect, write_file =
  t.insert, t.source, t.clear, t.expect, t.write_file

local function has_iconv()
  clear() -- ensures session
  return 1 == t.eval('has("iconv")')
end

describe('tag search with !_TAG_FILE_ENCODING', function()
  setup(function()
    clear()
    -- Create some temp files that are needed for the test run.  In the old
    -- test suite this was done by putting the text inside the file test83.in
    -- and executing some "/first/,/last/w! tmpfile" commands.
    write_file('Xtags1.txt', 'text for tags1\nabcdefghijklmnopqrs\n')
    write_file('Xtags2.txt', 'text for tags2\nＡＢＣ\n')
    write_file('Xtags3.txt', 'text for tags3\nＡＢＣ\n')
    write_file(
      'Xtags1',
      [[
      !_TAG_FILE_ENCODING	utf-8	//
      abcdefghijklmnopqrs	Xtags1.txt	/abcdefghijklmnopqrs
      ]]
    )
    write_file(
      'test83-tags2',
      '!_TAG_FILE_ENCODING	cp932	//\n' .. '\130`\130a\130b	Xtags2.txt	/\130`\130a\130b\n'
    )
    -- The last file is very long but repetitive and can be generated on the
    -- fly.
    local text = t.dedent([[
      !_TAG_FILE_SORTED	1	//
      !_TAG_FILE_ENCODING	cp932	//
      ]])
    local line = '	Xtags3.txt	/\130`\130a\130b\n'
    for i = 1, 100 do
      text = text .. 'abc' .. i .. line
    end
    write_file('test83-tags3', text)
  end)
  teardown(function()
    os.remove('Xtags1')
    os.remove('Xtags1.txt')
    os.remove('Xtags2.txt')
    os.remove('Xtags3.txt')
    os.remove('test83-tags2')
    os.remove('test83-tags3')
  end)

  if not has_iconv() then
    pending('skipped (missing iconv)', function() end)
  else
    it('is working', function()
      insert('Results of test83')

      -- Case1:
      source([[
	new
	set tags=Xtags1
	let v:errmsg = ''
	tag abcdefghijklmnopqrs
	if v:errmsg =~ 'E426:' || getline('.') != 'abcdefghijklmnopqrs'
	  close
	  put ='case1: failed'
	else
	  close
	  put ='case1: ok'
	endif
      ]])

      -- Case2:
      source([[
	new
	set tags=test83-tags2
	let v:errmsg = ''
	tag /.ＢＣ
	if v:errmsg =~ 'E426:' || getline('.') != 'ＡＢＣ'
	  close
	  put ='case2: failed'
	else
	  close
	  put ='case2: ok'
	endif
      ]])

      -- Case3:
      source([[
	new
	set tags=test83-tags3
	let v:errmsg = ''
	tag abc50
	if v:errmsg =~ 'E426:' || getline('.') != 'ＡＢＣ'
	  close
	  put ='case3: failed'
	else
	  close
	  put ='case3: ok'
	endif
      ]])

      -- Assert buffer contents.
      expect([[
	Results of test83
	case1: ok
	case2: ok
	case3: ok]])
    end)
  end
end)
