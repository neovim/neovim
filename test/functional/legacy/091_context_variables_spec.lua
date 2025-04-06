-- Tests for getbufvar(), getwinvar(), gettabvar() and gettabwinvar().

local n = require('test.functional.testnvim')()

local insert, source = n.insert, n.source
local clear, expect = n.clear, n.expect

describe('context variables', function()
  setup(clear)

  it('is working', function()
    insert('start:')

    -- Test for getbufvar().
    -- Use strings to test for memory leaks.
    source([[
      function Getbufscope(buf, ...)
        let ret = call('getbufvar', [a:buf, ''] + a:000)
        if type(ret) == type({})
          return filter(copy(ret), 'v:key isnot# "changedtick"')
        else
          return ret
        endif
      endfunction
      let t:testvar='abcd'
      $put =string(gettabvar(1, 'testvar'))
      $put =string(gettabvar(1, 'testvar'))
      let b:var_num = '1234'
      let def_num = '5678'
      $put =string(getbufvar(1, 'var_num'))
      $put =string(getbufvar(1, 'var_num', def_num))
      $put =string(Getbufscope(1))
      $put =string(Getbufscope(1, def_num))
      unlet b:var_num
      $put =string(getbufvar(1, 'var_num', def_num))
      $put =string(Getbufscope(1))
      $put =string(Getbufscope(1, def_num))
      $put =string(Getbufscope(9))
      $put =string(Getbufscope(9, def_num))
      unlet def_num
      $put =string(getbufvar(1, '&autoindent'))
      $put =string(getbufvar(1, '&autoindent', 1))
    ]])

    -- Open new window with forced option values.
    source([[
      set fileformats=unix,dos
      new ++ff=dos ++bin ++enc=iso-8859-2
      let otherff = getbufvar(bufnr('%'), '&fileformat')
      let otherbin = getbufvar(bufnr('%'), '&bin')
      let otherfenc = getbufvar(bufnr('%'), '&fenc')
      close
      $put =otherff
      $put =string(otherbin)
      $put =otherfenc
      unlet otherff otherbin otherfenc
    ]])

    -- Test for getwinvar().
    source([[
      let w:var_str = "Dance"
      let def_str = "Chance"
      $put =string(getwinvar(1, 'var_str'))
      $put =string(getwinvar(1, 'var_str', def_str))
      $put =string(getwinvar(1, ''))
      $put =string(getwinvar(1, '', def_str))
      unlet w:var_str
      $put =string(getwinvar(1, 'var_str', def_str))
      $put =string(getwinvar(1, ''))
      $put =string(getwinvar(1, '', def_str))
      $put =string(getwinvar(9, ''))
      $put =string(getwinvar(9, '', def_str))
      $put =string(getwinvar(1, '&nu'))
      $put =string(getwinvar(1, '&nu',  1))
      unlet def_str
    ]])

    -- Test for gettabvar().
    source([[
      tabnew
      tabnew
      let t:var_list = [1, 2, 3]
      let t:other = 777
      let def_list = [4, 5, 6, 7]
      tabrewind
      $put =string(gettabvar(3, 'var_list'))
      $put =string(gettabvar(3, 'var_list', def_list))
      $put =string(gettabvar(3, ''))
      $put =string(gettabvar(3, '', def_list))
      tablast
      unlet t:var_list
      tabrewind
      $put =string(gettabvar(3, 'var_list', def_list))
      $put =string(gettabvar(9, ''))
      $put =string(gettabvar(9, '', def_list))
      $put =string(gettabvar(3, '&nu'))
      $put =string(gettabvar(3, '&nu', def_list))
      unlet def_list
      tabonly
    ]])

    -- Test for gettabwinvar().
    source([[
      tabnew
      tabnew
      tabprev
      split
      split
      wincmd w
      vert split
      wincmd w
      let w:var_dict = {'dict': 'tabwin'}
      let def_dict = {'dict2': 'newval'}
      wincmd b
      tabrewind
      $put =string(gettabwinvar(2, 3, 'var_dict'))
      $put =string(gettabwinvar(2, 3, 'var_dict', def_dict))
      $put =string(gettabwinvar(2, 3, ''))
      $put =string(gettabwinvar(2, 3, '', def_dict))
      tabnext
      3wincmd w
      unlet w:var_dict
      tabrewind
      $put =string(gettabwinvar(2, 3, 'var_dict', def_dict))
      $put =string(gettabwinvar(2, 3, ''))
      $put =string(gettabwinvar(2, 3, '', def_dict))
      $put =string(gettabwinvar(2, 9, ''))
      $put =string(gettabwinvar(2, 9, '', def_dict))
      $put =string(gettabwinvar(9, 3, ''))
      $put =string(gettabwinvar(9, 3, '', def_dict))
      unlet def_dict
      $put =string(gettabwinvar(2, 3, '&nux'))
      $put =string(gettabwinvar(2, 3, '&nux', 1))
      tabonly
    ]])

    -- Assert buffer contents.
    expect([[
      start:
      'abcd'
      'abcd'
      '1234'
      '1234'
      {'var_num': '1234'}
      {'var_num': '1234'}
      '5678'
      {}
      {}
      ''
      '5678'
      0
      0
      dos
      1
      iso-8859-2
      'Dance'
      'Dance'
      {'var_str': 'Dance'}
      {'var_str': 'Dance'}
      'Chance'
      {}
      {}
      ''
      'Chance'
      0
      0
      [1, 2, 3]
      [1, 2, 3]
      {'var_list': [1, 2, 3], 'other': 777}
      {'var_list': [1, 2, 3], 'other': 777}
      [4, 5, 6, 7]
      ''
      [4, 5, 6, 7]
      ''
      [4, 5, 6, 7]
      {'dict': 'tabwin'}
      {'dict': 'tabwin'}
      {'var_dict': {'dict': 'tabwin'}}
      {'var_dict': {'dict': 'tabwin'}}
      {'dict2': 'newval'}
      {}
      {}
      ''
      {'dict2': 'newval'}
      ''
      {'dict2': 'newval'}
      ''
      1]])
  end)
end)
