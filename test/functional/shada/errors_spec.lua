-- ShaDa errors handling support
local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local t_shada = require('test.functional.shada.testutil')

local nvim_command, eq, exc_exec = n.command, t.eq, n.exc_exec
local reset, clear, get_shada_rw = t_shada.reset, t_shada.clear, t_shada.get_shada_rw

local wshada, sdrcmd, shada_fname, clean = get_shada_rw('Xtest-functional-shada-errors.shada')

describe('ShaDa error handling', function()
  before_each(reset)
  after_each(function()
    clear()
    clean()
  end)

  -- Note: most of tests have additional items like sX, mX, rX. These are for
  -- valgrind tests, to check for memory leaks (i.e. whether error handling code
  -- does (not) forget to call ga_clear). Not needed for array-based items like
  -- history because they are not using ad_ga.

  it('does not fail on empty file', function()
    wshada('')
    eq(0, exc_exec(sdrcmd()))
  end)

  it('fails on zero', function()
    wshada('\000')
    eq(
      'Vim(rshada):E576: Error while reading ShaDa file: expected positive integer at position 1, but got nothing',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on missing item', function()
    wshada('\000\000\000')
    eq(
      'Vim(rshada):E576: Error while reading ShaDa file: there is an item at position 0 that must not be there: Missing items are for internal uses only',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on -2 type', function()
    wshada('\254\000\000')
    eq(
      'Vim(rshada):E576: Error while reading ShaDa file: expected positive integer at position 0',
      exc_exec(sdrcmd())
    )
  end)

  it('does not fail on header with zero length', function()
    -- Header items are skipped when reading.
    wshada('\001\000\000')
    eq(0, exc_exec(sdrcmd()))
  end)

  it('fails on search pattern item with zero length', function()
    wshada('\002\000\000')
    eq(
      'Vim(rshada):E576: Failed to parse ShaDa file: incomplete msgpack string at position 3',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on search pattern item with -2 timestamp', function()
    wshada('\002\254\000')
    eq(
      'Vim(rshada):E576: Error while reading ShaDa file: expected positive integer at position 1',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on search pattern item with -2 length', function()
    wshada('\002\000\254')
    eq(
      'Vim(rshada):E576: Error while reading ShaDa file: expected positive integer at position 2',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on search pattern item with length greater then file length', function()
    wshada('\002\000\002\000')
    eq(
      'Vim(rshada):E576: Error while reading ShaDa file: last entry specified that it occupies 2 bytes, but file ended earlier',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on search pattern item with invalid byte', function()
    -- 195 (== 0xC1) cannot start any valid messagepack entry (the only byte
    -- that cannot do this). Specifically unpack_template.h contains
    --
    --     //case 0xc1:  // string
    --     //  again_terminal_trail(NEXT_CS(p), p+1);
    --
    -- (literally: commented out code) which means that in place of this code
    -- `goto _failed` is used from default: case. I do not know any other way to
    -- get MSGPACK_UNPACK_PARSE_ERROR and not MSGPACK_UNPACK_CONTINUE or
    -- MSGPACK_UNPACK_EXTRA_BYTES.
    wshada('\002\000\001\193')
    eq(
      'Vim(rshada):E576: Failed to parse ShaDa file due to a msgpack parser error at position 3',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on search pattern item with incomplete map', function()
    wshada('\002\000\001\129')
    eq(
      'Vim(rshada):E576: Failed to parse ShaDa file: incomplete msgpack string at position 3',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on search pattern item without a pattern', function()
    wshada('\002\000\005\129\162sX\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: search pattern entry at position 0 has no pattern',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on search pattern with extra bytes', function()
    wshada('\002\000\002\128\000')
    eq(
      'Vim(rshada):E576: Failed to parse ShaDa file: extra bytes in msgpack string at position 3',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on search pattern item with NIL value', function()
    wshada('\002\000\001\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: search pattern entry at position 0 is not a dictionary',
      exc_exec(sdrcmd())
    )
  end)

  -- sp entry is here because it causes an allocation.
  it('fails on search pattern item with BIN key', function()
    wshada('\002\000\014\131\162sp\196\001a\162sX\192\196\000\000')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: search pattern entry at position 0 has key which is not a string',
      exc_exec(sdrcmd())
    )
  end)

  -- sp entry is here because it causes an allocation.
  it('fails on search pattern item with empty key', function()
    wshada('\002\000\013\131\162sp\196\001a\162sX\192\160\000')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: search pattern entry at position 0 has empty key',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on search pattern item with NIL magic key value', function()
    wshada('\002\000\009\130\162sX\192\162sm\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: search pattern entry at position 0 has sm key value which is not a boolean',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on search pattern item with NIL smartcase key value', function()
    wshada('\002\000\009\130\162sX\192\162sc\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: search pattern entry at position 0 has sc key value which is not a boolean',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on search pattern item with NIL search_backward key value', function()
    wshada('\002\000\009\130\162sX\192\162sb\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: search pattern entry at position 0 has sb key value which is not a boolean',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on search pattern item with NIL has_line_offset key value', function()
    wshada('\002\000\009\130\162sX\192\162sl\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: search pattern entry at position 0 has sl key value which is not a boolean',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on search pattern item with NIL place_cursor_at_end key value', function()
    wshada('\002\000\009\130\162sX\192\162se\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: search pattern entry at position 0 has se key value which is not a boolean',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on search pattern item with NIL is_last_used key value', function()
    wshada('\002\000\009\130\162sX\192\162su\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: search pattern entry at position 0 has su key value which is not a boolean',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on search pattern item with NIL is_substitute_pattern key value', function()
    wshada('\002\000\009\130\162sX\192\162ss\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: search pattern entry at position 0 has ss key value which is not a boolean',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on search pattern item with NIL highlighted key value', function()
    wshada('\002\000\009\130\162sX\192\162sh\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: search pattern entry at position 0 has sh key value which is not a boolean',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on search pattern item with NIL offset key value', function()
    wshada('\002\000\009\130\162sX\192\162so\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: search pattern entry at position 0 has so key value which is not an integer',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on search pattern item with NIL pat key value', function()
    wshada('\002\000\009\130\162sX\192\162sp\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: search pattern entry at position 0 has sp key value which is not a binary',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on search pattern item with STR pat key value', function()
    wshada('\002\000\011\130\162sX\192\162sp\162sp')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: search pattern entry at position 0 has sp key value which is not a binary',
      exc_exec(sdrcmd())
    )
  end)

  for _, v in ipairs({
    { name = 'global mark', mpack = '\007' },
    { name = 'jump', mpack = '\008' },
    { name = 'local mark', mpack = '\010' },
    { name = 'change', mpack = '\011' },
  }) do
    local is_mark_test = ({ ['global mark'] = true, ['local mark'] = true })[v.name]

    it('fails on ' .. v.name .. ' item with NIL value', function()
      wshada(v.mpack .. '\000\001\192')
      eq(
        'Vim(rshada):E575: Error while reading ShaDa file: mark entry at position 0 is not a dictionary',
        exc_exec(sdrcmd())
      )
    end)

    -- f entry is here because it causes an allocation.
    it('fails on ' .. v.name .. ' item with BIN key', function()
      wshada(v.mpack .. '\000\013\131\161f\196\001/\162mX\192\196\000\000')
      eq(
        'Vim(rshada):E575: Error while reading ShaDa file: mark entry at position 0 has key which is not a string',
        exc_exec(sdrcmd())
      )
    end)

    -- f entry is here because it causes an allocation.
    it('fails on ' .. v.name .. ' item with empty key', function()
      wshada(v.mpack .. '\000\012\131\161f\196\001/\162mX\192\160\000')
      eq(
        'Vim(rshada):E575: Error while reading ShaDa file: mark entry at position 0 has empty key',
        exc_exec(sdrcmd())
      )
    end)

    it('fails on ' .. v.name .. ' item without f key', function()
      wshada(v.mpack .. '\000\008\130\162mX\192\161l\001')
      eq(
        'Vim(rshada):E575: Error while reading ShaDa file: mark entry at position 0 is missing file name',
        exc_exec(sdrcmd())
      )
    end)

    it('fails on ' .. v.name .. ' item with zero l key', function()
      wshada(v.mpack .. '\000\013\131\162mX\192\161f\196\001/\161l\000')
      eq(
        'Vim(rshada):E575: Error while reading ShaDa file: mark entry at position 0 has invalid line number',
        exc_exec(sdrcmd())
      )
    end)

    it('fails on ' .. v.name .. ' item with negative l key', function()
      wshada(v.mpack .. '\000\013\131\162mX\192\161f\196\001/\161l\255')
      eq(
        'Vim(rshada):E575: Error while reading ShaDa file: mark entry at position 0 has invalid line number',
        exc_exec(sdrcmd())
      )
    end)

    it('fails on ' .. v.name .. ' item with negative c key', function()
      wshada(v.mpack .. '\000\013\131\162mX\192\161f\196\001/\161c\255')
      eq(
        'Vim(rshada):E575: Error while reading ShaDa file: mark entry at position 0 has invalid column number',
        exc_exec(sdrcmd())
      )
    end)

    it('fails on ' .. v.name .. ' item with STR n key value', function()
      wshada(v.mpack .. '\000\011\130\162mX\192\161n\163spa')
      eq(
        is_mark_test
            and 'Vim(rshada):E575: Error while reading ShaDa file: mark entry at position 0 has n key value which is not an unsigned integer'
          or 'Vim(rshada):E575: Error while reading ShaDa file: mark entry at position 0 has n key which is only valid for local and global mark entries',
        exc_exec(sdrcmd())
      )
    end)

    it('fails on ' .. v.name .. ' item with STR l key value', function()
      wshada(v.mpack .. '\000\010\130\162mX\192\161l\162sp')
      eq(
        'Vim(rshada):E575: Error while reading ShaDa file: mark entry at position 0 has l key value which is not an integer',
        exc_exec(sdrcmd())
      )
    end)

    it('fails on ' .. v.name .. ' item with STR c key value', function()
      wshada(v.mpack .. '\000\010\130\162mX\192\161c\162sp')
      eq(
        'Vim(rshada):E575: Error while reading ShaDa file: mark entry at position 0 has c key value which is not an integer',
        exc_exec(sdrcmd())
      )
    end)

    it('fails on ' .. v.name .. ' item with STR f key value', function()
      wshada(v.mpack .. '\000\010\130\162mX\192\161f\162sp')
      eq(
        'Vim(rshada):E575: Error while reading ShaDa file: mark entry at position 0 has f key value which is not a binary',
        exc_exec(sdrcmd())
      )
    end)
  end

  it('fails on register item with NIL value', function()
    wshada('\005\000\001\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: register entry at position 0 is not a dictionary',
      exc_exec(sdrcmd())
    )
  end)

  -- rc entry is here because it causes an allocation
  it('fails on register item with BIN key', function()
    wshada('\005\000\015\131\162rc\145\196\001a\162rX\192\196\000\000')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: register entry at position 0 has key which is not a string',
      exc_exec(sdrcmd())
    )
  end)

  -- rc entry is here because it causes an allocation
  it('fails on register item with BIN key', function()
    wshada('\005\000\014\131\162rc\145\196\001a\162rX\192\160\000')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: register entry at position 0 has empty key',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on register item with NIL rt key value', function()
    wshada('\005\000\009\130\162rX\192\162rt\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: register entry at position 0 has rt key value which is not an unsigned integer',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on register item with NIL rw key value', function()
    wshada('\005\000\009\130\162rX\192\162rw\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: register entry at position 0 has rw key value which is not an unsigned integer',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on register item with NIL rc key value', function()
    wshada('\005\000\009\130\162rX\192\162rc\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: register entry at position 0 has rc key with non-array value',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on register item with empty rc key value', function()
    wshada('\005\000\009\130\162rX\192\162rc\144')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: register entry at position 0 has rc key with empty array',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on register item with NIL in rc array', function()
    wshada('\005\000\013\130\162rX\192\162rc\146\196\001a\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: register entry at position 0 has rc array with non-binary value',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on register item without rc array', function()
    wshada('\005\000\009\129\162rX\146\196\001a\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: register entry at position 0 has missing rc array',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on history item with NIL value', function()
    wshada('\004\000\001\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: history entry at position 0 is not an array',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on history item with empty value', function()
    wshada('\004\000\001\144')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: history entry at position 0 does not have enough elements',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on history item with single element value', function()
    wshada('\004\000\002\145\000')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: history entry at position 0 does not have enough elements',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on history item with NIL first item', function()
    wshada('\004\000\003\146\192\000')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: history entry at position 0 has wrong history type type',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on history item with FIXUINT second item', function()
    wshada('\004\000\003\146\000\000')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: history entry at position 0 has wrong history string type',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on history item with second item with zero byte', function()
    wshada('\004\000\007\146\000\196\003ab\000')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: history entry at position 0 contains string with zero byte inside',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on search history item without third item', function()
    wshada('\004\000\007\146\001\196\003abc')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: search history entry at position 0 does not have separator character',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on search history item with NIL third item', function()
    wshada('\004\000\007\147\001\196\002ab\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: search history entry at position 0 has wrong history separator type',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on variable item with NIL value', function()
    wshada('\006\000\001\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: variable entry at position 0 is not an array',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on variable item with empty value', function()
    wshada('\006\000\001\144')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: variable entry at position 0 does not have enough elements',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on variable item with single element value', function()
    wshada('\006\000\002\145\000')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: variable entry at position 0 does not have enough elements',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on variable item with NIL first item', function()
    wshada('\006\000\003\146\192\000')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: variable entry at position 0 has wrong variable name type',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on variable item with BIN value and type value != VAR_TYPE_BLOB', function()
    wshada('\006\000\007\147\196\001\065\196\000\000')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: variable entry at position 0 has wrong variable type',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on replacement item with NIL value', function()
    wshada('\003\000\001\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: sub string entry at position 0 is not an array',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on replacement item with empty value', function()
    wshada('\003\000\001\144')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: sub string entry at position 0 does not have enough elements',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on replacement item with NIL first item', function()
    wshada('\003\000\002\145\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: sub string entry at position 0 has wrong sub string type',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on buffer list item with NIL value', function()
    nvim_command('set shada+=%')
    wshada('\009\000\001\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: buffer list entry at position 0 is not an array',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on buffer list item with NIL item in the array', function()
    nvim_command('set shada+=%')
    wshada('\009\000\008\146\129\161f\196\001/\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: buffer list at position 0 contains entry that is not a dictionary',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on buffer list item with empty item', function()
    nvim_command('set shada+=%')
    wshada('\009\000\008\146\129\161f\196\001/\128')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: buffer list at position 0 contains entry that does not have a file name',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on buffer list item with NIL l key', function()
    nvim_command('set shada+=%')
    wshada('\009\000\017\146\129\161f\196\001/\130\161f\196\002/a\161l\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: buffer list entry entry at position 0 has l key value which is not an integer',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on buffer list item with zero l key', function()
    nvim_command('set shada+=%')
    wshada('\009\000\017\146\129\161f\196\001/\130\161f\196\002/a\161l\000')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: buffer list at position 0 contains entry with invalid line number',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on buffer list item with negative l key', function()
    nvim_command('set shada+=%')
    wshada('\009\000\017\146\129\161f\196\001/\130\161f\196\002/a\161l\255')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: buffer list at position 0 contains entry with invalid line number',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on buffer list item with negative c key', function()
    nvim_command('set shada+=%')
    wshada('\009\000\017\146\129\161f\196\001/\130\161f\196\002/a\161c\255')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: buffer list at position 0 contains entry with invalid column number',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on buffer list item with NIL c key', function()
    nvim_command('set shada+=%')
    wshada('\009\000\017\146\129\161f\196\001/\130\161f\196\002/a\161c\192')
    eq(
      'Vim(rshada):E575: Error while reading ShaDa file: buffer list entry entry at position 0 has c key value which is not an integer',
      exc_exec(sdrcmd())
    )
  end)

  it('fails on invalid ShaDa file (viminfo file)', function()
    wshada([[# This viminfo file was generated by Vim 7.4.
# You may edit it if you're careful!

# Value of 'encoding' when this file was written
*encoding=utf-8


# hlsearch on (H) or off (h):
~h
# Last Search Pattern:
~MSle0~/buffer=abuf

# Last Substitute Search Pattern:
~MSle0&^$

# Last Substitute String:
$

# Command Line History (newest to oldest):
:cq

# Search String History (newest to oldest):
? \<TMUX\>

# Expression History (newest to oldest):
=system('echo "\xAB"')

# Input Line History (newest to oldest):
@i

# Input Line History (newest to oldest):

# Registers:
"0	LINE	0
	        case FLAG_B: puts("B"); break;
"1	LINE	0
	pick 874a489 shada,functests: Test compatibility support
""-	CHAR	0
	.

# global variables:
!STUF_HISTORY_TRANSLIT	LIS	[]
!TR3_INPUT_HISTORY	LIS	[]

# File marks:
'A  8320  12  ~/a.a/Proj/c/neovim-2076/src/nvim/ex_docmd.c
'0  66  5  ~/a.a/Proj/c/neovim/.git/rebase-merge/git-rebase-todo
'1  7  0  ~/.vam/powerline/.git/MERGE_MSG
'2  64  4  ~/a.a/Proj/c/neovim/.git/rebase-merge/git-rebase-todo
'3  9  0  ~/a.a/Proj/c/neovim/.git/COMMIT_EDITMSG
'4  62  0  ~/a.a/Proj/c/neovim/.git/rebase-merge/git-rebase-todo
'5  57  4  ~/a.a/Proj/c/neovim/.git/rebase-merge/git-rebase-todo
'6  1  0  ~/a.a/Proj/c/neovim/.git/rebase-merge/git-rebase-todo
'7  399  7  /usr/share/vim/vim74/doc/motion.txt
'8  1  0  ~/a.a/Proj/c/zpython/build/CMakeFiles/3.2.2/CMakeCCompiler.cmake
'9  1  0  ~/a.a/Proj/c/vim/README.txt

# Jumplist (newest first):
-'  66  5  ~/a.a/Proj/c/neovim/.git/rebase-merge/git-rebase-todo

# History of marks within files (newest to oldest):

> ~/a.a/Proj/c/neovim/.git/rebase-merge/git-rebase-todo
	"	66	5
	^	66	6
	.	66	5
	+	65	0
	+	65	0
]])
    eq(
      'Vim(rshada):E576: Failed to parse ShaDa file: extra bytes in msgpack string at position 3',
      exc_exec(sdrcmd())
    )
    eq(
      'Vim(wshada):E576: Failed to parse ShaDa file: extra bytes in msgpack string at position 3',
      exc_exec('wshada ' .. shada_fname)
    )
    eq(0, exc_exec('wshada! ' .. shada_fname))
  end)

  it('fails on invalid ShaDa file (wrapper script)', function()
    wshada('#!/bin/sh\n\npowerline "$@" 2>&1 | tee -a powerline\n')
    eq(
      'Vim(rshada):E576: Failed to parse ShaDa file: extra bytes in msgpack string at position 3',
      exc_exec(sdrcmd())
    )
    eq(
      'Vim(wshada):E576: Failed to parse ShaDa file: extra bytes in msgpack string at position 3',
      exc_exec('wshada ' .. shada_fname)
    )
    eq(0, exc_exec('wshada! ' .. shada_fname))
  end)

  it('fails on invalid ShaDa file (failing skip in second item)', function()
    wshada('\001\000\001\128#!/')
    eq(
      'Vim(rshada):E576: Error while reading ShaDa file: last entry specified that it occupies 47 bytes, but file ended earlier',
      exc_exec(sdrcmd())
    )
    eq(
      'Vim(wshada):E576: Error while reading ShaDa file: last entry specified that it occupies 47 bytes, but file ended earlier',
      exc_exec('wshada ' .. shada_fname)
    )
    eq(0, exc_exec('wshada! ' .. shada_fname))
  end)

  it('errors with too large items', function()
    wshada({
      1,
      206,
      70,
      90,
      31,
      179,
      86,
      133,
      169,
      103,
      101,
      110,
      101,
      114,
      97,
      116,
      111,
      114,
      196,
      4,
      145,
      145,
      145,
      145,
      145,
      145,
      96,
      96,
      96,
      96,
      96,
      96,
      96,
      96,
      96,
      96,
      96,
      96,
      96,
      96,
      96,
      96,
      96,
      96,
      96,
      96,
      96,
      145,
      145,
      145,
      145,
      111,
      110,
      196,
      25,
      78,
      86,
      73,
      77,
      32,
      118,
      1,
      46,
      50,
      46,
      48,
      45,
      51,
      48,
      51,
      45,
      103,
      98,
      54,
      55,
      52,
      102,
      100,
      50,
      99,
      169,
      109,
      97,
      120,
      95,
      107,
      98,
      121,
      116,
      101,
      10,
      207,
      207,
      207,
      207,
      207,
      207,
      207,
      207,
      207,
      207,
      207,
      207,
      207,
      207,
      207,
      207,
      207,
      207,
      207,
      207,
      207,
      207,
      16,
      8,
      206,
      89,
      90,
      30,
      253,
      35,
      129,
      161,
      102,
      196,
      30,
      47,
      100,
      101,
      118,
      47,
      115,
      104,
      109,
      47,
      102,
      117,
      122,
      122,
      105,
      110,
      103,
      45,
      110,
      118,
      105,
      109,
      45,
      115,
      104,
      97,
      100,
      97,
      47,
      108,
      115,
      2,
      206,
      89,
      90,
      30,
      251,
      13,
      130,
      162,
      115,
      112,
      196,
      3,
      102,
      111,
      111,
      162,
      115,
      99,
      195,
      3,
      146,
      10,
      0,
    })
    eq(
      'Vim(rshada):E576: Error while reading ShaDa file: there is an item at position 93 that is stated to be too long',
      exc_exec(sdrcmd())
    )
  end)
end)
