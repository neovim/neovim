describe(':call command', function()
  local ito, itoe
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
  end
  ito('Calls user functions', [[
    function A0()
      echo 0
    endfunction
    function A1(a)
      echo a:a
      echo 1
    endfunction
    function A3(a, b, c)
      echo a:a
      echo a:b
      echo a:c
      echo 3
    endfunction
    function Av(...)
      echo a:0
      echo a:000
      echo 'v'
    endfunction
    function A3v(a, b, c, ...)
      echo a:a
      echo a:b
      echo a:c
      echo a:0
      echo a:000
      echo '3v'
    endfunction
    call A0()
    call A1('a1')
    call A3('a3_1', 'a3_2', 'a3_3')
    call Av()
    call Av('av_1', 'av_2')
    call A3v('a3v_1', 'a3v_2', 'a3v_3')
    call A3v('a3v_1', 'a3v_2', 'a3v_3', 'a3v_4', 'a3v_5')
    delfunction A0
    delfunction A1
    delfunction A3
    delfunction Av
    delfunction A3v
  ]], {
    0,
    'a1', 1,
    'a3_1', 'a3_2', 'a3_3', 3,
    0, {_t='list'}, 'v',
    2, {'av_1', 'av_2'}, 'v',
    'a3v_1', 'a3v_2', 'a3v_3', 0, {_t='list'}, '3v',
    'a3v_1', 'a3v_2', 'a3v_3', 2, {'a3v_4', 'a3v_5'}, '3v',
  })
  ito('Calls user dictionary functions', [[
    function D() dict
      echo self.a
    endfunction
    let d = {'f': function('D'), 'a': 1024}
    call d.f()
    unlet d
    delfunction D
  ]], {1024})
end)
