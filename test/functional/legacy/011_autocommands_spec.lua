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
local clear, feed_command, expect, eq, neq, dedent, write_file, feed =
  helpers.clear, helpers.feed_command, helpers.expect, helpers.eq, helpers.neq,
  helpers.dedent, helpers.write_file, helpers.feed

local function has_gzip()
  local null = helpers.iswin() and 'nul' or '/dev/null'
  return os.execute('gzip --help >' .. null .. ' 2>&1') == 0
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
      feed_command('let $GZIP = ""')
      --execute('au FileChangedShell * echo "caught FileChangedShell"')
      feed_command('set bin')
      feed_command("au FileReadPost    *.gz   '[,']!gzip -d")
      -- Read and decompress the testfile.
      feed_command('$r Xtestfile.gz')
      expect('\n'..text1)
    end)

    it('BufReadPre, BufReadPost (using gzip)', function()
      prepare_gz_file('Xtestfile', text1)
      local gzip_data = io.open('Xtestfile.gz'):read('*all')
      feed_command('let $GZIP = ""')
      -- Setup autocommands to decompress before reading and re-compress afterwards.
      feed_command("au BufReadPre   *.gz  exe '!gzip -d ' . shellescape(expand('<afile>'))")
      feed_command("au BufReadPre   *.gz  call rename(expand('<afile>:r'), expand('<afile>'))")
      feed_command("au BufReadPost  *.gz  call rename(expand('<afile>'), expand('<afile>:r'))")
      feed_command("au BufReadPost  *.gz  exe '!gzip ' . shellescape(expand('<afile>:r'))")
      -- Edit compressed file.
      feed_command('e! Xtestfile.gz')
      -- Discard all prompts and messages.
      feed('<C-L>')
      -- Expect the decompressed file in the buffer.
      expect(text1)
      -- Expect the original file to be unchanged.
      eq(gzip_data, io.open('Xtestfile.gz'):read('*all'))
    end)

    -- luacheck: ignore 621 (Indentation)
    -- luacheck: ignore 611 (Line contains only whitespaces)
    it('FileReadPre, FileReadPost', function()
      prepare_gz_file('Xtestfile', text1)
      feed_command('au! FileReadPre    *.gz   exe "silent !gzip -d " . shellescape(expand("<afile>"))')
      feed_command('au  FileReadPre    *.gz   call rename(expand("<afile>:r"), expand("<afile>"))')
      feed_command("au! FileReadPost   *.gz   '[,']s/l/L/")
      -- Read compressed file.
      feed_command('$r Xtestfile.gz')
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
    feed_command('au BufNewFile      *.c    read Xtest.c')
    -- Will load Xtest.c.
    feed_command('e! foo.c')
    feed_command("au FileAppendPre   *.out  '[,']s/new/NEW/")
    feed_command('au FileAppendPost  *.out  !cat Xtest.c >>test.out')
    -- Append it to the output file.
    feed_command('w>>test.out')
    -- Discard all prompts and messages.
    feed('<C-L>')
    -- Expect the decompressed file in the buffer.
    feed_command('e test.out')
    expect([[
      
      /*
       * Here is a NEW .c file
       */]])
  end)

  it('FilterReadPre, FilterReadPost', function()
    if helpers.pending_win32(pending) then return end
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
    feed_command('set shelltemp')
    feed_command('au FilterReadPre   *.out  call rename(expand("<afile>"), expand("<afile>") . ".t")')
    feed_command('au FilterReadPre   *.out  exe "silent !sed s/e/E/ " . shellescape(expand("<afile>")) . ".t >" . shellescape(expand("<afile>"))')
    feed_command('au FilterReadPre   *.out  exe "silent !rm " . shellescape(expand("<afile>")) . ".t"')
    feed_command("au FilterReadPost  *.out  '[,']s/x/X/g")
    -- Edit the output file.
    feed_command('e! test.out')
    feed_command('23,$!cat')
    -- Discard all prompts and messages.
    feed('<C-L>')
    -- Remove CR for when sed adds them.
    feed_command([[23,$s/\r$//]])
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
