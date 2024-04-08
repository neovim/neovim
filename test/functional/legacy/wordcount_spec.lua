-- Test for wordcount() function

local t = require('test.functional.testutil')(after_each)
local feed, insert, source = t.feed, t.insert, t.source
local clear, command = t.clear, t.command
local eq, eval = t.eq, t.eval
local poke_eventloop = t.poke_eventloop

describe('wordcount', function()
  before_each(clear)

  it('is working', function()
    command('set selection=inclusive fileformat=unix fileformats=unix')

    insert([=[
      RESULT test:]=])
    poke_eventloop()

    command('new')
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
    eq(
      eval([=[
          [[''], {'chars': 0, 'cursor_chars': 0, 'words': 0, 'cursor_words': 0, 'bytes': 0, 'cursor_bytes': 0}]
        ]=]),
      eval('DoRecordWin()')
    )

    -- Test 2: some words, cursor at start
    command([[call PutInWindow('one two three')]])
    eq(
      eval([=[
          [['', 'one two three'], {'chars': 15, 'cursor_chars': 1, 'words': 3, 'cursor_words': 0, 'bytes': 15, 'cursor_bytes': 1}]
        ]=]),
      eval('DoRecordWin([1, 1, 0])')
    )

    -- Test 3: some words, cursor at end
    command([[call PutInWindow('one two three')]])
    eq(
      eval([=[
          [['', 'one two three'], {'chars': 15, 'cursor_chars': 14, 'words': 3, 'cursor_words': 3, 'bytes': 15, 'cursor_bytes': 14}]
        ]=]),
      eval('DoRecordWin([2, 99, 0])')
    )

    -- Test 4: some words, cursor at end, ve=all
    command('set ve=all')
    command([[call PutInWindow('one two three')]])
    eq(
      eval([=[
          [['', 'one two three'], {'chars': 15, 'cursor_chars': 15, 'words': 3, 'cursor_words': 3, 'bytes': 15, 'cursor_bytes': 15}]
        ]=]),
      eval('DoRecordWin([2,99,0])')
    )
    command('set ve=')

    -- Test 5: several lines with words
    command([=[call PutInWindow(['one two three', 'one two three', 'one two three'])]=])
    eq(
      eval([=[
          [['', 'one two three', 'one two three', 'one two three'], {'chars': 43, 'cursor_chars': 42, 'words': 9, 'cursor_words': 9, 'bytes': 43, 'cursor_bytes': 42}]
        ]=]),
      eval('DoRecordWin([4,99,0])')
    )

    -- Test 6: one line with BOM set
    command([[call PutInWindow('one two three')]])
    command('wincmd k')
    command('set bomb')
    command('wincmd j')
    eq(
      eval([=[
          [['', 'one two three'], {'chars': 15, 'cursor_chars': 14, 'words': 3, 'cursor_words': 3, 'bytes': 18, 'cursor_bytes': 14}]
        ]=]),
      eval('DoRecordWin([2,99,0])')
    )
    command('wincmd k')
    command('set nobomb')
    command('wincmd j')

    -- Test 7: one line with multibyte words
    command([=[call PutInWindow(['Äne M¤ne Müh'])]=])
    eq(
      eval([=[
          [['', 'Äne M¤ne Müh'], {'chars': 14, 'cursor_chars': 13, 'words': 3, 'cursor_words': 3, 'bytes': 17, 'cursor_bytes': 16}]
        ]=]),
      eval('DoRecordWin([2,99,0])')
    )

    -- Test 8: several lines with multibyte words
    command([=[call PutInWindow(['Äne M¤ne Müh', 'und raus bist dü!'])]=])
    eq(
      eval([=[
          [['', 'Äne M¤ne Müh', 'und raus bist dü!'], {'chars': 32, 'cursor_chars': 31, 'words': 7, 'cursor_words': 7, 'bytes': 36, 'cursor_bytes': 35}]
        ]=]),
      eval('DoRecordWin([3,99,0])')
    )

    -- Test 9: visual mode, complete buffer
    command([=[call PutInWindow(['Äne M¤ne Müh', 'und raus bist dü!'])]=])
    command('wincmd k')
    command('set ls=2 stl=%{STL()}')
    -- -- Start visual mode quickly and select complete buffer.
    command('0')
    feed('V2jy<cr>')
    poke_eventloop()
    command('set stl= ls=1')
    command('let log=DoRecordWin([3,99,0])')
    command('let log[1]=g:visual_stat')
    eq(
      eval([=[
          [['', 'Äne M¤ne Müh', 'und raus bist dü!'], {'chars': 32, 'words': 7, 'bytes': 36, 'visual_chars': 32, 'visual_words': 7, 'visual_bytes': 36}]
        ]=]),
      eval('log')
    )

    -- Test 10: visual mode (empty)
    command([=[call PutInWindow(['Äne M¤ne Müh', 'und raus bist dü!'])]=])
    command('wincmd k')
    command('set ls=2 stl=%{STL()}')
    -- Start visual mode quickly and select complete buffer.
    command('0')
    feed('v$y<cr>')
    poke_eventloop()
    command('set stl= ls=1')
    command('let log=DoRecordWin([3,99,0])')
    command('let log[1]=g:visual_stat')
    eq(
      eval([=[
          [['', 'Äne M¤ne Müh', 'und raus bist dü!'], {'chars': 32, 'words': 7, 'bytes': 36, 'visual_chars': 1, 'visual_words': 0, 'visual_bytes': 1}]
        ]=]),
      eval('log')
    )

    -- Test 11: visual mode, single line
    command([=[call PutInWindow(['Äne M¤ne Müh', 'und raus bist dü!'])]=])
    command('wincmd k')
    command('set ls=2 stl=%{STL()}')
    -- Start visual mode quickly and select complete buffer.
    command('2')
    feed('0v$y<cr>')
    poke_eventloop()
    command('set stl= ls=1')
    command('let log=DoRecordWin([3,99,0])')
    command('let log[1]=g:visual_stat')
    eq(
      eval([=[
          [['', 'Äne M¤ne Müh', 'und raus bist dü!'], {'chars': 32, 'words': 7, 'bytes': 36, 'visual_chars': 13, 'visual_words': 3, 'visual_bytes': 16}]
        ]=]),
      eval('log')
    )
  end)
end)
