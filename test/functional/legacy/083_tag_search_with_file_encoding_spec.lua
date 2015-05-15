-- Tests for tag search with !_TAG_FILE_ENCODING.

local helpers = require('test.functional.helpers')
local insert, source, clear, expect, write_file = helpers.insert,
  helpers.source, helpers.clear, helpers.expect, helpers.write_file

describe('tag search with !_TAG_FILE_ENCODING', function()
  setup(clear)

  it('is working', function()
    -- Create some temp files that are needed for the test run.  In the old
    -- test suite this was done by putting the text inside the file test83.in
    -- and executing some "/first/,/last/w! tmpfile" commands.
    write_file('Xtags1.txt', [[
      text for tags1
      abcdefghijklmnopqrs
      ]])
    write_file('Xtags2.txt', [[
      text for tags2
      ＡＢＣ
      ]])
    write_file('Xtags3.txt', [[
      text for tags3
      ＡＢＣ
      ]])
    write_file('Xtags1', [[
      !_TAG_FILE_ENCODING	utf-8	//
      abcdefghijklmnopqrs	Xtags1.txt	/abcdefghijklmnopqrs
      ]])
    write_file('test83-tags2',
      '!_TAG_FILE_ENCODING	cp932	//\n' ..
      '\x82`\x82a\x82b	Xtags2.txt	/\x82`\x82a\x82b\n'
      )
    write_file('test83-tags3',
      '!_TAG_FILE_SORTED	1	//\n' ..
      '!_TAG_FILE_ENCODING	cp932	//\n' ..
      'abc1	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc2	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc3	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc4	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc5	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc6	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc7	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc8	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc9	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc10	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc11	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc12	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc13	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc14	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc15	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc16	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc17	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc18	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc19	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc20	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc21	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc22	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc23	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc24	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc25	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc26	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc27	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc28	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc29	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc30	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc31	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc32	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc33	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc34	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc35	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc36	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc37	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc38	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc39	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc40	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc41	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc42	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc43	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc44	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc45	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc46	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc47	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc48	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc49	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc50	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc51	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc52	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc53	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc54	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc55	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc56	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc57	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc58	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc59	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc60	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc61	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc62	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc63	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc64	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc65	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc66	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc67	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc68	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc69	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc70	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc71	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc72	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc73	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc74	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc75	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc76	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc77	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc78	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc79	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc80	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc81	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc82	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc83	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc84	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc85	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc86	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc87	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc88	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc89	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc90	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc91	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc92	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc93	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc94	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc95	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc96	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc97	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc98	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc99	Xtags3.txt	/\x82`\x82a\x82b\n' ..
      'abc100	Xtags3.txt	/\x82`\x82a\x82b\n'
      )

    -- TODO what about the availability of iconv in neovim?
    --source([[
    --  set enc=utf8
    --  if !has('iconv') || iconv("\x82\x60", "cp932", "utf-8") != "\uff21"
    --    e! test.ok
    --    w! test.out
    --    qa!
    --  endif
    --]])

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
    expect([=[
      Results of test83
      case1: ok
      case2: ok
      case3: ok]=])
  end)

  teardown(function()
    os.remove('Xtags1')
    os.remove('Xtags1.txt')
    os.remove('Xtags2.txt')
    os.remove('Xtags3.txt')
    os.remove('test83-tags2')
    os.remove('test83-tags3')
  end)
end)
