-- Tests for autocommands
-- - FileWritePre		writing a compressed file
-- - FileReadPost		reading a compressed file
-- - BufNewFile			reading a file template
-- - BufReadPre			decompressing the file to be read
-- - FilterReadPre		substituting characters in the temp file
-- - FilterReadPost		substituting characters after filtering
-- - FileReadPre		set options for decompression
-- - FileReadPost		decompress the file
-- Note: This test is skipped if "gzip" is not available.
-- $GZIP is made empty, "-v" would cause trouble.
-- Use a FileChangedShell autocommand to avoid a prompt for "Xtestfile.gz"
-- being modified outside of Vim (noticed on Solaris).

local helpers= require('test.functional.helpers')(after_each)
local lfs = require('lfs')
local clear, execute, expect, eq, neq, dedent, write_file, feed =
  helpers.clear, helpers.execute, helpers.expect, helpers.eq, helpers.neq,
  helpers.dedent, helpers.write_file, helpers.feed

local function has_gzip()
  return os.execute('gzip --help >/dev/null 2>&1') == 0
end

local function prepare_gz_file(name, text)
  write_file(name, text..'\n')
  -- Compress the file with gzip.
  os.execute('gzip --force '..name)
  -- This should create the .gz file and delete the original.
  neq(nil, lfs.attributes(name..'.gz'))
  eq(nil, lfs.attributes(name))
end

describe('file reading, writing and bufnew and filter autocommands', function()
  local text1 = dedent([[
      start of testfile
      line 2	Abcdefghijklmnopqrstuvwxyz
      line 3	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
      line 4	Abcdefghijklmnopqrstuvwxyz
      line 5	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
      line 6	Abcdefghijklmnopqrstuvwxyz
      line 7	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
      line 8	Abcdefghijklmnopqrstuvwxyz
      line 9	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
      line 10 Abcdefghijklmnopqrstuvwxyz
      end of testfile]])
  setup(function()
    write_file('Xtest.c', [[
      /*
       * Here is a new .c file
       */
      ]])
  end)
  before_each(clear)
  teardown(function()
    os.remove('Xtestfile.gz')
    os.remove('Xtest.c')
    os.remove('test.out')
  end)

  if not has_gzip() then
    pending('skipped (missing `gzip` utility)', function() end)
  else

    it('FileReadPost (using gzip)', function()
      prepare_gz_file('Xtestfile', text1)
      execute('let $GZIP = ""')
      --execute('au FileChangedShell * echo "caught FileChangedShell"')
      execute('set bin')
      execute("au FileReadPost    *.gz   '[,']!gzip -d")
      -- Read and decompress the testfile.
      execute('$r Xtestfile.gz')
      expect('\n'..text1)
    end)

    it('BufReadPre, BufReadPost (using gzip)', function()
      prepare_gz_file('Xtestfile', text1)
      local gzip_data = io.open('Xtestfile.gz'):read('*all')
      execute('let $GZIP = ""')
      -- Setup autocommands to decompress before reading and re-compress afterwards.
      execute("au BufReadPre   *.gz  exe '!gzip -d ' . shellescape(expand('<afile>'))")
      execute("au BufReadPre   *.gz  call rename(expand('<afile>:r'), expand('<afile>'))")
      execute("au BufReadPost  *.gz  call rename(expand('<afile>'), expand('<afile>:r'))")
      execute("au BufReadPost  *.gz  exe '!gzip ' . shellescape(expand('<afile>:r'))")
      -- Edit compressed file.
      execute('e! Xtestfile.gz')
      -- Discard all prompts and messages.
      feed('<C-L>')
      -- Expect the decompressed file in the buffer.
      expect(text1)
      -- Expect the original file to be unchanged.
      eq(gzip_data, io.open('Xtestfile.gz'):read('*all'))
    end)

    it('FileReadPre, FileReadPost', function()
      prepare_gz_file('Xtestfile', text1)
      execute('au! FileReadPre    *.gz   exe "silent !gzip -d " . shellescape(expand("<afile>"))')
      execute('au  FileReadPre    *.gz   call rename(expand("<afile>:r"), expand("<afile>"))')
      execute("au! FileReadPost   *.gz   '[,']s/l/L/")
      -- Read compressed file.
      execute('$r Xtestfile.gz')
      -- Discard all prompts and messages.
      feed('<C-L>')
      expect([[
	
	start of testfiLe
	Line 2	Abcdefghijklmnopqrstuvwxyz
	Line 3	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	Line 4	Abcdefghijklmnopqrstuvwxyz
	Line 5	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	Line 6	Abcdefghijklmnopqrstuvwxyz
	Line 7	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	Line 8	Abcdefghijklmnopqrstuvwxyz
	Line 9	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	Line 10 Abcdefghijklmnopqrstuvwxyz
	end of testfiLe]])
    end)

  end

  it('FileAppendPre, FileAppendPost', function()
    execute('au BufNewFile      *.c    read Xtest.c')
    -- Will load Xtest.c.
    execute('e! foo.c')
    execute("au FileAppendPre   *.out  '[,']s/new/NEW/")
    execute('au FileAppendPost  *.out  !cat Xtest.c >>test.out')
    -- Append it to the output file.
    execute('w>>test.out')
    -- Discard all prompts and messages.
    feed('<C-L>')
    -- Expect the decompressed file in the buffer.
    execute('e test.out')
    expect([[
      
      /*
       * Here is a NEW .c file
       */]])
  end)

  it('FilterReadPre, FilterReadPost', function()
    -- Write a special input file for this test block.
    write_file('test.out', dedent([[
      startstart
      ]]) .. text1 .. dedent([[
      
      
      start of test.c
      /*
       * Here is a new .c file
       */
      end of test.c
      ]]) .. text1 .. dedent([[
      
      
      /*
       * Here is a NEW .c file
       */
      /*
       * Here is a new .c file
       */
      ]]) .. text1 .. dedent([[
      
      /*
       * Here is a new .c file
       */]]))
    -- Need temp files here.
    execute('set shelltemp')
    execute('au FilterReadPre   *.out  call rename(expand("<afile>"), expand("<afile>") . ".t")')
    execute('au FilterReadPre   *.out  exe "silent !sed s/e/E/ " . shellescape(expand("<afile>")) . ".t >" . shellescape(expand("<afile>"))')
    execute('au FilterReadPre   *.out  exe "silent !rm " . shellescape(expand("<afile>")) . ".t"')
    execute("au FilterReadPost  *.out  '[,']s/x/X/g")
    -- Edit the output file.
    execute('e! test.out')
    execute('23,$!cat')
    -- Discard all prompts and messages.
    feed('<C-L>')
    -- Remove CR for when sed adds them.
    execute([[23,$s/\r$//]])
    expect([[
      startstart
      start of testfile
      line 2	Abcdefghijklmnopqrstuvwxyz
      line 3	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
      line 4	Abcdefghijklmnopqrstuvwxyz
      line 5	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
      line 6	Abcdefghijklmnopqrstuvwxyz
      line 7	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
      line 8	Abcdefghijklmnopqrstuvwxyz
      line 9	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
      line 10 Abcdefghijklmnopqrstuvwxyz
      end of testfile
      
      start of test.c
      /*
       * Here is a new .c file
       */
      end of test.c
      start of testfile
      line 2	Abcdefghijklmnopqrstuvwxyz
      line 3	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
      line 4	Abcdefghijklmnopqrstuvwxyz
      linE 5	XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      linE 6	AbcdefghijklmnopqrstuvwXyz
      linE 7	XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      linE 8	AbcdefghijklmnopqrstuvwXyz
      linE 9	XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      linE 10 AbcdefghijklmnopqrstuvwXyz
      End of testfile
      
      /*
       * HEre is a NEW .c file
       */
      /*
       * HEre is a new .c file
       */
      start of tEstfile
      linE 2	AbcdefghijklmnopqrstuvwXyz
      linE 3	XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      linE 4	AbcdefghijklmnopqrstuvwXyz
      linE 5	XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      linE 6	AbcdefghijklmnopqrstuvwXyz
      linE 7	XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      linE 8	AbcdefghijklmnopqrstuvwXyz
      linE 9	XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      linE 10 AbcdefghijklmnopqrstuvwXyz
      End of testfile
      /*
       * HEre is a new .c file
       */]])
  end)
end)
