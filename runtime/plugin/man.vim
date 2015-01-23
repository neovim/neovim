if get(g:, 'loaded_man', 0)
  finish
endif
let g:loaded_man = 1

command! -nargs=+ Man call man#get_page(<f-args>)
