scriptencoding utf-8

func Run_cjk_linebreak_after()
  set textwidth=12
  for punct in [
        \ '!', '%', ')', ',', ':', ';', '>', '?', ']', '}', '’', '”', '†', '‡',
        \ '…', '‰', '‱', '‼', '⁇', '⁈', '⁉', '℃', '℉', '、', '。', '〉', '》',
        \ '」', '』', '】', '〕', '〗', '〙', '〛', '！', '）', '，', '．', '：',
        \ '；', '？', '］', '｝']
    call setline('.', '这是一个测试'.punct.'试试 CJK 行禁则补丁。')
    normal gqq
    call assert_equal('这是一个测试'.punct, getline(1))
    %d_
  endfor
endfunc

func Test_cjk_linebreak_after()
  set formatoptions=croqn2mB1j
  call Run_cjk_linebreak_after()
endfunc

" TODO: this test fails
"func Test_cjk_linebreak_after_rigorous()
"  set formatoptions=croqn2mB1j]
"  call Run_cjk_linebreak_after()
"endfunc

func Run_cjk_linebreak_before()
  set textwidth=12
  for punct in [
        \ '(', '<', '[', '`', '{', '‘', '“', '〈', '《', '「', '『', '【', '〔',
        \ '〖', '〘', '〚', '（', '［', '｛']
    call setline('.', '这是个测试'.punct.'试试 CJK 行禁则补丁。')
    normal gqq
    call assert_equal('这是个测试', getline(1))
    %d_
  endfor
endfunc

func Test_cjk_linebreak_before()
  set formatoptions=croqn2mB1j
  call Run_cjk_linebreak_before()
endfunc

func Test_cjk_linebreak_before_rigorous()
  set formatoptions=croqn2mB1j]
  call Run_cjk_linebreak_before()
endfunc

func Run_cjk_linebreak_nobetween()
  " …… must not start a line
  call setline('.', '这是个测试……试试 CJK 行禁则补丁。')
  set textwidth=12 ambiwidth=double
  normal gqq
  " TODO: this fails
  " call assert_equal('这是个测试……', getline(1))
  %d_

  call setline('.', '这是一个测试……试试 CJK 行禁则补丁。')
  set textwidth=12 ambiwidth=double
  normal gqq
  call assert_equal('这是一个测', getline(1))
  %d_

  " but —— can
  call setline('.', '这是个测试——试试 CJK 行禁则补丁。')
  set textwidth=12 ambiwidth=double
  normal gqq
  call assert_equal('这是个测试', getline(1))
endfunc

func Test_cjk_linebreak_nobetween()
  set formatoptions=croqn2mB1j
  call Run_cjk_linebreak_nobetween()
endfunc

func Test_cjk_linebreak_nobetween_rigorous()
  set formatoptions=croqn2mB1j]
  call Run_cjk_linebreak_nobetween()
endfunc

func Test_cjk_linebreak_join_punct()
  for punct in ['——', '〗', '，', '。', '……']
    call setline(1, '文本文本'.punct)
    call setline(2, 'English')
    set formatoptions=croqn2mB1j
    normal ggJ
    call assert_equal('文本文本'.punct.'English', getline(1))
    %d_
  endfor
endfunc
