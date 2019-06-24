
" Test for :const

func s:noop()
endfunc

func Test_define_var_with_lock()
    const i = 1
    const f = 1.1
    const s = 'vim'
    const F = funcref('s:noop')
    const l = [1, 2, 3]
    const d = {'foo': 10}
    if has('channel')
        const j = test_null_job()
        const c = test_null_channel()
    endif
    const b = v:true
    const n = v:null

    call assert_true(exists('i'))
    call assert_true(exists('f'))
    call assert_true(exists('s'))
    call assert_true(exists('F'))
    call assert_true(exists('l'))
    call assert_true(exists('d'))
    if has('channel')
        call assert_true(exists('j'))
        call assert_true(exists('c'))
    endif
    call assert_true(exists('b'))
    call assert_true(exists('n'))

    call assert_fails('let i = 1', 'E741:')
    call assert_fails('let f = 1.1', 'E741:')
    call assert_fails('let s = "vim"', 'E741:')
    call assert_fails('let F = funcref("s:noop")', 'E741:')
    call assert_fails('let l = [1, 2, 3]', 'E741:')
    call assert_fails('let d = {"foo": 10}', 'E741:')
    if has('channel')
        call assert_fails('let j = test_null_job()', 'E741:')
        call assert_fails('let c = test_null_channel()', 'E741:')
    endif
    call assert_fails('let b = v:true', 'E741:')
    call assert_fails('let n = v:null', 'E741:')

    " Unlet
    unlet i
    unlet f
    unlet s
    unlet F
    unlet l
    unlet d
    if has('channel')
        unlet j
        unlet c
    endif
    unlet b
    unlet n
endfunc

func Test_define_l_var_with_lock()
    " With l: prefix
    const l:i = 1
    const l:f = 1.1
    const l:s = 'vim'
    const l:F = funcref('s:noop')
    const l:l = [1, 2, 3]
    const l:d = {'foo': 10}
    if has('channel')
        const l:j = test_null_job()
        const l:c = test_null_channel()
    endif
    const l:b = v:true
    const l:n = v:null

    call assert_fails('let l:i = 1', 'E741:')
    call assert_fails('let l:f = 1.1', 'E741:')
    call assert_fails('let l:s = "vim"', 'E741:')
    call assert_fails('let l:F = funcref("s:noop")', 'E741:')
    call assert_fails('let l:l = [1, 2, 3]', 'E741:')
    call assert_fails('let l:d = {"foo": 10}', 'E741:')
    if has('channel')
        call assert_fails('let l:j = test_null_job()', 'E741:')
        call assert_fails('let l:c = test_null_channel()', 'E741:')
    endif
    call assert_fails('let l:b = v:true', 'E741:')
    call assert_fails('let l:n = v:null', 'E741:')

    " Unlet
    unlet l:i
    unlet l:f
    unlet l:s
    unlet l:F
    unlet l:l
    unlet l:d
    if has('channel')
        unlet l:j
        unlet l:c
    endif
    unlet l:b
    unlet l:n
endfunc

func Test_define_script_var_with_lock()
    const s:x = 0
    call assert_fails('let s:x = 1', 'E741:')
    unlet s:x
endfunc

func Test_descructuring_with_lock()
    const [a, b, c] = [1, 1.1, 'vim']

    call assert_fails('let a = 1', 'E741:')
    call assert_fails('let b = 1.1', 'E741:')
    call assert_fails('let c = "vim"', 'E741:')

    const [d; e] = [1, 1.1, 'vim']
    call assert_fails('let d = 1', 'E741:')
    call assert_fails('let e = [2.2, "a"]', 'E741:')
endfunc

func Test_cannot_modify_existing_variable()
    let i = 1
    let f = 1.1
    let s = 'vim'
    let F = funcref('s:noop')
    let l = [1, 2, 3]
    let d = {'foo': 10}
    if has('channel')
        let j = test_null_job()
        let c = test_null_channel()
    endif
    let b = v:true
    let n = v:null

    call assert_fails('const i = 1', 'E995:')
    call assert_fails('const f = 1.1', 'E995:')
    call assert_fails('const s = "vim"', 'E995:')
    call assert_fails('const F = funcref("s:noop")', 'E995:')
    call assert_fails('const l = [1, 2, 3]', 'E995:')
    call assert_fails('const d = {"foo": 10}', 'E995:')
    if has('channel')
        call assert_fails('const j = test_null_job()', 'E995:')
        call assert_fails('const c = test_null_channel()', 'E995:')
    endif
    call assert_fails('const b = v:true', 'E995:')
    call assert_fails('const n = v:null', 'E995:')
    call assert_fails('const [i, f, s] = [1, 1.1, "vim"]', 'E995:')

    const i2 = 1
    const f2 = 1.1
    const s2 = 'vim'
    const F2 = funcref('s:noop')
    const l2 = [1, 2, 3]
    const d2 = {'foo': 10}
    if has('channel')
        const j2 = test_null_job()
        const c2 = test_null_channel()
    endif
    const b2 = v:true
    const n2 = v:null

    call assert_fails('const i2 = 1', 'E995:')
    call assert_fails('const f2 = 1.1', 'E995:')
    call assert_fails('const s2 = "vim"', 'E995:')
    call assert_fails('const F2 = funcref("s:noop")', 'E995:')
    call assert_fails('const l2 = [1, 2, 3]', 'E995:')
    call assert_fails('const d2 = {"foo": 10}', 'E995:')
    if has('channel')
        call assert_fails('const j2 = test_null_job()', 'E995:')
        call assert_fails('const c2 = test_null_channel()', 'E995:')
    endif
    call assert_fails('const b2 = v:true', 'E995:')
    call assert_fails('const n2 = v:null', 'E995:')
    call assert_fails('const [i2, f2, s2] = [1, 1.1, "vim"]', 'E995:')
endfunc

func Test_const_with_index_access()
    let l = [1, 2, 3]
    call assert_fails('const l[0] = 4', 'E996:')
    call assert_fails('const l[0:1] = [1, 2]', 'E996:')

    let d = {'aaa': 0}
    call assert_fails("const d['aaa'] = 4", 'E996:')
    call assert_fails("const d.aaa = 4", 'E996:')
endfunc

func Test_const_with_compound_assign()
    let i = 0
    call assert_fails('const i += 4', 'E995:')
    call assert_fails('const i -= 4', 'E995:')
    call assert_fails('const i *= 4', 'E995:')
    call assert_fails('const i /= 4', 'E995:')
    call assert_fails('const i %= 4', 'E995:')

    let s = 'a'
    call assert_fails('const s .= "b"', 'E995:')

    let [a, b, c] = [1, 2, 3]
    call assert_fails('const [a, b, c] += [4, 5, 6]', 'E995:')

    let [d; e] = [1, 2, 3]
    call assert_fails('const [d; e] += [4, 5, 6]', 'E995:')
endfunc

func Test_const_with_special_variables()
    call assert_fails('const $FOO = "hello"', 'E996:')
    call assert_fails('const @a = "hello"', 'E996:')
    call assert_fails('const &filetype = "vim"', 'E996:')
    call assert_fails('const &l:filetype = "vim"', 'E996:')
    call assert_fails('const &g:encoding = "utf-8"', 'E996:')
endfunc

func Test_const_with_eval_name()
    let s = 'foo'

    " eval name with :const should work
    const abc_{s} = 1
    const {s}{s} = 1

    let s2 = 'abc_foo'
    call assert_fails('const {s2} = "bar"', 'E995:')
endfunc

func Test_lock_depth_is_1()
    const l = [1, 2, 3]
    const d = {'foo': 10}

    " Modify list
    call add(l, 4)
    let l[0] = 42

    " Modify dict
    let d['bar'] = 'hello'
    let d.foo = 44
endfunc
