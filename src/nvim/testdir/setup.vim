" Common preparations for running tests.

set noruler
set noshowcmd
set belloff=

" Make sure 'runtimepath' and 'packpath' does not include $HOME.
set rtp=$VIM/vimfiles,$VIMRUNTIME,$VIM/vimfiles/after
let &packpath = &rtp

" Make sure $HOME does not get read or written.
let $HOME = '/does/not/exist'
