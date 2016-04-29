-- Tests for 'packpath' and :packadd

local helpers = require('test.functional.helpers')(after_each)
local clear, source = helpers.clear, helpers.source
local call, eq, nvim = helpers.call, helpers.eq, helpers.meths

local function expected_empty()
  eq({}, nvim.get_vvar('errors'))
end

describe('packadd', function()
  before_each(function()
    clear()

    source([=[
      func SetUp()
        let s:topdir = expand('%:p:h') . '/Xdir'
        exe 'set packpath=' . s:topdir
        let s:plugdir = s:topdir . '/pack/mine/opt/mytest'
      endfunc

      func TearDown()
        call delete(s:topdir, 'rf')
      endfunc

      func Test_packadd()
        call mkdir(s:plugdir . '/plugin', 'p')
        call mkdir(s:plugdir . '/ftdetect', 'p')
        set rtp&
        let rtp = &rtp
        filetype on

        exe 'split ' . s:plugdir . '/plugin/test.vim'
        call setline(1, 'let g:plugin_works = 42')
        wq

        exe 'split ' . s:plugdir . '/ftdetect/test.vim'
        call setline(1, 'let g:ftdetect_works = 17')
        wq

        packadd mytest

        call assert_true(42, g:plugin_works)
        call assert_true(17, g:ftdetect_works)
        call assert_true(len(&rtp) > len(rtp))
        call assert_true(&rtp =~ (s:plugdir . '\($\|,\)'))
      endfunc

      func Test_packadd_noload()
        call mkdir(s:plugdir . '/plugin', 'p')
        call mkdir(s:plugdir . '/syntax', 'p')
        set rtp&
        let rtp = &rtp

        exe 'split ' . s:plugdir . '/plugin/test.vim'
        call setline(1, 'let g:plugin_works = 42')
        wq
        let g:plugin_works = 0

        packadd! mytest

        call assert_true(len(&rtp) > len(rtp))
        call assert_true(&rtp =~ (s:plugdir . '\($\|,\)'))
        call assert_equal(0, g:plugin_works)

        " check the path is not added twice
        let new_rtp = &rtp
        packadd! mytest
        call assert_equal(new_rtp, &rtp)
      endfunc
    ]=])
    call('SetUp')
  end)

  after_each(function()
    call('TearDown')
  end)

  it('is working', function()
    call('Test_packadd')
    expected_empty()
  end)

  it('works with packadd!', function()
    call('Test_packadd_noload')
    expected_empty()
  end)
end)
