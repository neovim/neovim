-- Test for wordcount() function

local helpers = require('test.functional.helpers')(after_each)
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute = helpers.clear, helpers.execute
local eq, eval = helpers.eq, helpers.eval

describe('wordcount', function()
  before_each(clear)

  it('is working', function()
    execute('set selection=inclusive')
    execute('fileformat=unix')
    execute('fileformats=unix')

    insert([=[
      RESULT test:]=])

    execute('new')
    source([=[
      function DoRecordWin(...)
        wincmd k
          if exists("a:1")
            call cursor(a:1)
          endif
          let result=[]
          call add(result, getline(1, '$'))
          call add(result, wordcount())
        wincmd j
        return result
      endfunction
    ]=])

    source([=[
      function PutInWindow(args)
        wincmd k
        %d _
        call append(1, a:args)
        wincmd j
      endfunction
    ]=])

    source([=[
      function! STL()
        if mode() =~? 'V'
          let g:visual_stat=wordcount()
        endif
        return string(wordcount())
      endfunction
    ]=])

    -- Test 1: empty window
    eq(eval('DoRecordWin()'),
       eval([=[
          [[''], {'chars': 0, 'cursor_chars': 0, 'words': 0, 'cursor_words': 0, 'bytes': 0, 'cursor_bytes': 0}]
        ]=])
      )

    -- Test 2: some words, cursor at start
    execute([[call PutInWindow('one two three')]])
    eq(eval('DoRecordWin([1, 1, 0])'),
       eval([=[
          [['', 'one two three'], {'chars': 15, 'cursor_chars': 1, 'words': 3, 'cursor_words': 0, 'bytes': 15, 'cursor_bytes': 1}]
        ]=])
      )

    -- Test 3: some words, cursor at end
    execute([[call PutInWindow('one two three')]])
    eq(eval('DoRecordWin([2, 99, 0])'),
       eval([=[
          [['', 'one two three'], {'chars': 15, 'cursor_chars': 14, 'words': 3, 'cursor_words': 3, 'bytes': 15, 'cursor_bytes': 14}]
        ]=])
      )

    -- Test 4: some words, cursor at end, ve=all
    execute('set ve=all')
    execute([[call PutInWindow('one two three')]])
    eq(eval('DoRecordWin([2,99,0])'),
       eval([=[
          [['', 'one two three'], {'chars': 15, 'cursor_chars': 15, 'words': 3, 'cursor_words': 3, 'bytes': 15, 'cursor_bytes': 15}]
        ]=])
      )
    execute('set ve=')

    -- Test 5: several lines with words
    execute([=[call PutInWindow(['one two three', 'one two three', 'one two three'])]=])
    eq(eval('DoRecordWin([4,99,0])'),
       eval([=[
          [['', 'one two three', 'one two three', 'one two three'], {'chars': 43, 'cursor_chars': 42, 'words': 9, 'cursor_words': 9, 'bytes': 43, 'cursor_bytes': 42}]
        ]=])
      )

    -- Test 6: one line with BOM set
    execute([[call PutInWindow('one two three')]])
    execute('wincmd k')
    execute('set bomb')
    execute('wincmd j')
    eq(eval('DoRecordWin([2,99,0])'),
       eval([=[
          [['', 'one two three'], {'chars': 15, 'cursor_chars': 14, 'words': 3, 'cursor_words': 3, 'bytes': 18, 'cursor_bytes': 14}]
        ]=])
      )
    execute('wincmd k')
    execute('set nobomb')
    execute('wincmd j')

    -- Test 7: one line with multibyte words
    execute([=[call PutInWindow(['Äne M¤ne Müh'])]=])
    eq(eval('DoRecordWin([2,99,0])'),
       eval([=[
          [['', 'Äne M¤ne Müh'], {'chars': 14, 'cursor_chars': 13, 'words': 3, 'cursor_words': 3, 'bytes': 17, 'cursor_bytes': 16}]
        ]=])
      )

    -- Test 8: several lines with multibyte words
    execute([=[call PutInWindow(['Äne M¤ne Müh', 'und raus bist dü!'])]=])
    eq(eval('DoRecordWin([3,99,0])'),
       eval([=[
          [['', 'Äne M¤ne Müh', 'und raus bist dü!'], {'chars': 32, 'cursor_chars': 31, 'words': 7, 'cursor_words': 7, 'bytes': 36, 'cursor_bytes': 35}]
        ]=])
      )

    -- Test 9: visual mode, complete buffer
    execute([=[call PutInWindow(['Äne M¤ne Müh', 'und raus bist dü!'])]=])
    execute('wincmd k')
    execute('set ls=2 stl=%{STL()}')
    -- -- Start visual mode quickly and select complete buffer.
    execute('0')
    feed('V2jy<cr>')
    execute('set stl= ls=1')
    execute('let log=DoRecordWin([3,99,0])')
    execute('let log[1]=g:visual_stat')
    eq(eval('log'),
       eval([=[
          [['', 'Äne M¤ne Müh', 'und raus bist dü!'], {'chars': 32, 'words': 7, 'bytes': 36, 'visual_chars': 32, 'visual_words': 7, 'visual_bytes': 36}]
        ]=])
      )

    -- Test 10: visual mode (empty)
    execute([=[call PutInWindow(['Äne M¤ne Müh', 'und raus bist dü!'])]=])
    execute('wincmd k')
    execute('set ls=2 stl=%{STL()}')
    -- Start visual mode quickly and select complete buffer.
    execute('0')
    feed('v$y<cr>')
    execute('set stl= ls=1')
    execute('let log=DoRecordWin([3,99,0])')
    execute('let log[1]=g:visual_stat')
    eq(eval('log'),
       eval([=[
          [['', 'Äne M¤ne Müh', 'und raus bist dü!'], {'chars': 32, 'words': 7, 'bytes': 36, 'visual_chars': 1, 'visual_words': 0, 'visual_bytes': 1}]
        ]=])
      )

    -- Test 11: visual mode, single line
    execute([=[call PutInWindow(['Äne M¤ne Müh', 'und raus bist dü!'])]=])
    execute('wincmd k')
    execute('set ls=2 stl=%{STL()}')
    -- Start visual mode quickly and select complete buffer.
    execute('2')
    feed('0v$y<cr>')
    execute('set stl= ls=1')
    execute('let log=DoRecordWin([3,99,0])')
    execute('let log[1]=g:visual_stat')
    eq(eval('log'),
       eval([=[
          [['', 'Äne M¤ne Müh', 'und raus bist dü!'], {'chars': 32, 'words': 7, 'bytes': 36, 'visual_chars': 13, 'visual_words': 3, 'visual_bytes': 16}]
        ]=])
      )
  end)
end)
