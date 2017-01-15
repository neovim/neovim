" Common preparations for running tests.

" Make sure 'runtimepath' does not include $HOME.
set rtp=$VIM/vimfiles,$VIMRUNTIME,$VIM/vimfiles/after

" Make sure $HOME does not get read or written.
let $HOME = '/does/not/exist'
