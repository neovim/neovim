local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local fn = n.fn
local eval, eq = n.eval, t.eq
local command = n.command
local api = n.api
local exc_exec = n.exc_exec
local is_os = t.is_os

describe('msgpack*() functions', function()
  before_each(clear)

  local obj_test = function(msg, obj)
    it(msg, function()
      api.nvim_set_var('obj', obj)
      eq(obj, eval('msgpackparse(msgpackdump(g:obj))'))
      eq(obj, eval('msgpackparse(msgpackdump(g:obj, "B"))'))
    end)
  end

  -- Regression test: msgpack_list_write was failing to write buffer with zero
  -- length.
  obj_test('are able to dump and restore {"file": ""}', { { file = '' } })
  -- Regression test: msgpack_list_write was failing to write buffer with NL at
  -- the end.
  obj_test('are able to dump and restore {0, "echo mpack"}', { { 0, 'echo mpack' } })
  obj_test('are able to dump and restore "Test\\n"', { 'Test\n' })
  -- Regression test: msgpack_list_write was failing to write buffer with NL
  -- inside.
  obj_test('are able to dump and restore "Test\\nTest 2"', { 'Test\nTest 2' })
  -- Test that big objects (requirement: dump to something that is bigger then
  -- IOSIZE) are also fine. This particular object is obtained by concatenating
  -- 5 identical shada files.
  -- stylua: ignore
  local big_obj = {
    1, 1436711454, 78, {
      encoding="utf-8",
      max_kbyte=10,
      pid=19269,
      version="NVIM 0.0.0-alpha+201507121634"
    },
    8, 1436711451, 40, { file="/home/zyx/.nvim/shada/main.shada" },
    8, 1436711391, 8, { file="" },
    4, 1436700940, 30, { 0, "call mkdir('/tmp/tty/tty')" },
    4, 1436701355, 35, { 0, "call mkdir('/tmp/tty/tty', 'p')" },
    4, 1436701368, 24, { 0, "call mkdir('/', 'p')" },
    4, 1436701375, 26, { 0, "call mkdir('/tty/tty')" },
    4, 1436701383, 30, { 0, "call mkdir('/tty/tty/tty')" },
    4, 1436701407, 35, { 0, "call mkdir('/usr/tty/tty', 'p')" },
    4, 1436701666, 35, { 0, "call mkdir('/tty/tty/tty', 'p')" },
    4, 1436708101, 25, { 0, "echo msgpackdump([1])" },
    4, 1436708966, 6, { 0, "cq" },
    4, 1436709606, 25, { 0, "echo msgpackdump([5])" },
    4, 1436709610, 26, { 0, "echo msgpackdump([10])" },
    4, 1436709615, 31, { 0, "echo msgpackdump([5, 5, 5])" },
    4, 1436709618, 35, { 0, "echo msgpackdump([5, 5, 5, 10])" },
    4, 1436709634, 57, {
      0,
      "echo msgpackdump([5, 5, 5, 10, [10, 20, {\"abc\": 1}]])"
    },
    4, 1436709651, 67, {
      0,
      "echo msgpackdump([5, 5, 5, 10, [10, 20, {\"abc\": 1, \"def\": 0}]])"
    },
    4, 1436709660, 70, {
      0,
      "echo msgpackdump([5, 5, 5, 10, [10, 20, {\"abc\": 1, \"def\": 0}], 0])"
    },
    4, 1436710095, 29, { 0, "echo msgpackparse([\"\\n\"])" },
    4, 1436710100, 28, { 0, "echo msgpackparse([\"j\"])" },
    4, 1436710109, 31, { 0, "echo msgpackparse([\"\", \"\"])" },
    4, 1436710424, 33, { 0, "echo msgpackparse([\"\", \"\\n\"])" },
    4, 1436710428, 32, { 0, "echo msgpackparse([\"\", \"j\"])" },
    4, 1436711142, 14, { 0, "echo mpack" },
    4, 1436711196, 45, { 0, "let lengths = map(mpack[:], 'len(v:val)')" },
    4, 1436711206, 16, { 0, "echo lengths" },
    4, 1436711244, 92, {
      0,
      ("let sum = len(lengths) - 1 | call map(copy(lengths), "
       .. "'extend(g:, {\"sum\": sum + v:val})')")
    },
    4, 1436711245, 12, { 0, "echo sum" },
    4, 1436711398, 10, { 0, "echo s" },
    4, 1436711404, 41, { 0, "let mpack = readfile('/tmp/foo', 'b')" },
    4, 1436711408, 41, { 0, "let shada_objects=msgpackparse(mpack)" },
    4, 1436711415, 22, { 0, "echo shada_objects" },
    4, 1436711451, 30, { 0, "e ~/.nvim/shada/main.shada" },
    4, 1436711454, 6, { 0, "qa" },
    4, 1436711442, 9, { 1, "test", 47 },
    4, 1436711443, 15, { 1, "aontsuesan", 47 },
    2, 1436711443, 38, { hlsearch=1, pat="aontsuesan", smartcase=1 },
    2, 0, 31, { islast=0, pat="", smartcase=1, sub=1 },
    3, 0, 3, { "" },
    10, 1436711451, 40, { file="/home/zyx/.nvim/shada/main.shada" },
    1, 1436711454, 78, {
      encoding="utf-8",
      max_kbyte=10,
      pid=19269,
      version="NVIM 0.0.0-alpha+201507121634"
    },
    8, 1436711451, 40, { file="/home/zyx/.nvim/shada/main.shada" },
    8, 1436711391, 8, { file="" },
    4, 1436700940, 30, { 0, "call mkdir('/tmp/tty/tty')" },
    4, 1436701355, 35, { 0, "call mkdir('/tmp/tty/tty', 'p')" },
    4, 1436701368, 24, { 0, "call mkdir('/', 'p')" },
    4, 1436701375, 26, { 0, "call mkdir('/tty/tty')" },
    4, 1436701383, 30, { 0, "call mkdir('/tty/tty/tty')" },
    4, 1436701407, 35, { 0, "call mkdir('/usr/tty/tty', 'p')" },
    4, 1436701666, 35, { 0, "call mkdir('/tty/tty/tty', 'p')" },
    4, 1436708101, 25, { 0, "echo msgpackdump([1])" },
    4, 1436708966, 6, { 0, "cq" },
    4, 1436709606, 25, { 0, "echo msgpackdump([5])" },
    4, 1436709610, 26, { 0, "echo msgpackdump([10])" },
    4, 1436709615, 31, { 0, "echo msgpackdump([5, 5, 5])" },
    4, 1436709618, 35, { 0, "echo msgpackdump([5, 5, 5, 10])" },
    4, 1436709634, 57, {
      0,
      "echo msgpackdump([5, 5, 5, 10, [10, 20, {\"abc\": 1}]])"
    },
    4, 1436709651, 67, {
      0,
      "echo msgpackdump([5, 5, 5, 10, [10, 20, {\"abc\": 1, \"def\": 0}]])"
    },
    4, 1436709660, 70, {
      0,
      "echo msgpackdump([5, 5, 5, 10, [10, 20, {\"abc\": 1, \"def\": 0}], 0])"
    },
    4, 1436710095, 29, { 0, "echo msgpackparse([\"\\n\"])" },
    4, 1436710100, 28, { 0, "echo msgpackparse([\"j\"])" },
    4, 1436710109, 31, { 0, "echo msgpackparse([\"\", \"\"])" },
    4, 1436710424, 33, { 0, "echo msgpackparse([\"\", \"\\n\"])" },
    4, 1436710428, 32, { 0, "echo msgpackparse([\"\", \"j\"])" },
    4, 1436711142, 14, { 0, "echo mpack" },
    4, 1436711196, 45, { 0, "let lengths = map(mpack[:], 'len(v:val)')" },
    4, 1436711206, 16, { 0, "echo lengths" },
    4, 1436711244, 92, {
      0,
      ("let sum = len(lengths) - 1 | call map(copy(lengths), "
       .. "'extend(g:, {\"sum\": sum + v:val})')")
    },
    4, 1436711245, 12, { 0, "echo sum" },
    4, 1436711398, 10, { 0, "echo s" },
    4, 1436711404, 41, { 0, "let mpack = readfile('/tmp/foo', 'b')" },
    4, 1436711408, 41, { 0, "let shada_objects=msgpackparse(mpack)" },
    4, 1436711415, 22, { 0, "echo shada_objects" },
    4, 1436711451, 30, { 0, "e ~/.nvim/shada/main.shada" },
    4, 1436711454, 6, { 0, "qa" },
    4, 1436711442, 9, { 1, "test", 47 },
    4, 1436711443, 15, { 1, "aontsuesan", 47 },
    2, 1436711443, 38, { hlsearch=1, pat="aontsuesan", smartcase=1 },
    2, 0, 31, { islast=0, pat="", smartcase=1, sub=1 },
    3, 0, 3, { "" },
    10, 1436711451, 40, { file="/home/zyx/.nvim/shada/main.shada" },
    1, 1436711454, 78, {
      encoding="utf-8",
      max_kbyte=10,
      pid=19269,
      version="NVIM 0.0.0-alpha+201507121634"
    },
    8, 1436711451, 40, { file="/home/zyx/.nvim/shada/main.shada" },
    8, 1436711391, 8, { file="" },
    4, 1436700940, 30, { 0, "call mkdir('/tmp/tty/tty')" },
    4, 1436701355, 35, { 0, "call mkdir('/tmp/tty/tty', 'p')" },
    4, 1436701368, 24, { 0, "call mkdir('/', 'p')" },
    4, 1436701375, 26, { 0, "call mkdir('/tty/tty')" },
    4, 1436701383, 30, { 0, "call mkdir('/tty/tty/tty')" },
    4, 1436701407, 35, { 0, "call mkdir('/usr/tty/tty', 'p')" },
    4, 1436701666, 35, { 0, "call mkdir('/tty/tty/tty', 'p')" },
    4, 1436708101, 25, { 0, "echo msgpackdump([1])" },
    4, 1436708966, 6, { 0, "cq" },
    4, 1436709606, 25, { 0, "echo msgpackdump([5])" },
    4, 1436709610, 26, { 0, "echo msgpackdump([10])" },
    4, 1436709615, 31, { 0, "echo msgpackdump([5, 5, 5])" },
    4, 1436709618, 35, { 0, "echo msgpackdump([5, 5, 5, 10])" },
    4, 1436709634, 57, {
      0,
      "echo msgpackdump([5, 5, 5, 10, [10, 20, {\"abc\": 1}]])"
    },
    4, 1436709651, 67, {
      0,
      "echo msgpackdump([5, 5, 5, 10, [10, 20, {\"abc\": 1, \"def\": 0}]])"
    },
    4, 1436709660, 70, {
      0,
      "echo msgpackdump([5, 5, 5, 10, [10, 20, {\"abc\": 1, \"def\": 0}], 0])"
    },
    4, 1436710095, 29, { 0, "echo msgpackparse([\"\\n\"])" },
    4, 1436710100, 28, { 0, "echo msgpackparse([\"j\"])" },
    4, 1436710109, 31, { 0, "echo msgpackparse([\"\", \"\"])" },
    4, 1436710424, 33, { 0, "echo msgpackparse([\"\", \"\\n\"])" },
    4, 1436710428, 32, { 0, "echo msgpackparse([\"\", \"j\"])" },
    4, 1436711142, 14, { 0, "echo mpack" },
    4, 1436711196, 45, { 0, "let lengths = map(mpack[:], 'len(v:val)')" },
    4, 1436711206, 16, { 0, "echo lengths" },
    4, 1436711244, 92, {
      0,
      ("let sum = len(lengths) - 1 | call map(copy(lengths), "
       .. "'extend(g:, {\"sum\": sum + v:val})')")
    },
    4, 1436711245, 12, { 0, "echo sum" },
    4, 1436711398, 10, { 0, "echo s" },
    4, 1436711404, 41, { 0, "let mpack = readfile('/tmp/foo', 'b')" },
    4, 1436711408, 41, { 0, "let shada_objects=msgpackparse(mpack)" },
    4, 1436711415, 22, { 0, "echo shada_objects" },
    4, 1436711451, 30, { 0, "e ~/.nvim/shada/main.shada" },
    4, 1436711454, 6, { 0, "qa" },
    4, 1436711442, 9, { 1, "test", 47 },
    4, 1436711443, 15, { 1, "aontsuesan", 47 },
    2, 1436711443, 38, { hlsearch=1, pat="aontsuesan", smartcase=1 },
    2, 0, 31, { islast=0, pat="", smartcase=1, sub=1 },
    3, 0, 3, { "" },
    10, 1436711451, 40, { file="/home/zyx/.nvim/shada/main.shada" },
    1, 1436711454, 78, {
      encoding="utf-8",
      max_kbyte=10,
      pid=19269,
      version="NVIM 0.0.0-alpha+201507121634"
    },
    8, 1436711451, 40, { file="/home/zyx/.nvim/shada/main.shada" },
    8, 1436711391, 8, { file="" },
    4, 1436700940, 30, { 0, "call mkdir('/tmp/tty/tty')" },
    4, 1436701355, 35, { 0, "call mkdir('/tmp/tty/tty', 'p')" },
    4, 1436701368, 24, { 0, "call mkdir('/', 'p')" },
    4, 1436701375, 26, { 0, "call mkdir('/tty/tty')" },
    4, 1436701383, 30, { 0, "call mkdir('/tty/tty/tty')" },
    4, 1436701407, 35, { 0, "call mkdir('/usr/tty/tty', 'p')" },
    4, 1436701666, 35, { 0, "call mkdir('/tty/tty/tty', 'p')" },
    4, 1436708101, 25, { 0, "echo msgpackdump([1])" },
    4, 1436708966, 6, { 0, "cq" },
    4, 1436709606, 25, { 0, "echo msgpackdump([5])" },
    4, 1436709610, 26, { 0, "echo msgpackdump([10])" },
    4, 1436709615, 31, { 0, "echo msgpackdump([5, 5, 5])" },
    4, 1436709618, 35, { 0, "echo msgpackdump([5, 5, 5, 10])" },
    4, 1436709634, 57, {
      0,
      "echo msgpackdump([5, 5, 5, 10, [10, 20, {\"abc\": 1}]])"
    },
    4, 1436709651, 67, {
      0,
      "echo msgpackdump([5, 5, 5, 10, [10, 20, {\"abc\": 1, \"def\": 0}]])"
    },
    4, 1436709660, 70, {
      0,
      "echo msgpackdump([5, 5, 5, 10, [10, 20, {\"abc\": 1, \"def\": 0}], 0])"
    },
    4, 1436710095, 29, { 0, "echo msgpackparse([\"\\n\"])" },
    4, 1436710100, 28, { 0, "echo msgpackparse([\"j\"])" },
    4, 1436710109, 31, { 0, "echo msgpackparse([\"\", \"\"])" },
    4, 1436710424, 33, { 0, "echo msgpackparse([\"\", \"\\n\"])" },
    4, 1436710428, 32, { 0, "echo msgpackparse([\"\", \"j\"])" },
    4, 1436711142, 14, { 0, "echo mpack" },
    4, 1436711196, 45, { 0, "let lengths = map(mpack[:], 'len(v:val)')" },
    4, 1436711206, 16, { 0, "echo lengths" },
    4, 1436711244, 92, {
      0,
      ("let sum = len(lengths) - 1 | call map(copy(lengths), "
       .. "'extend(g:, {\"sum\": sum + v:val})')")
    },
    4, 1436711245, 12, { 0, "echo sum" },
    4, 1436711398, 10, { 0, "echo s" },
    4, 1436711404, 41, { 0, "let mpack = readfile('/tmp/foo', 'b')" },
    4, 1436711408, 41, { 0, "let shada_objects=msgpackparse(mpack)" },
    4, 1436711415, 22, { 0, "echo shada_objects" },
    4, 1436711451, 30, { 0, "e ~/.nvim/shada/main.shada" },
    4, 1436711454, 6, { 0, "qa" },
    4, 1436711442, 9, { 1, "test", 47 },
    4, 1436711443, 15, { 1, "aontsuesan", 47 },
    2, 1436711443, 38, { hlsearch=1, pat="aontsuesan", smartcase=1 },
    2, 0, 31, { islast=0, pat="", smartcase=1, sub=1 },
    3, 0, 3, { "" },
    10, 1436711451, 40, { file="/home/zyx/.nvim/shada/main.shada" },
    1, 1436711454, 78, {
      encoding="utf-8",
      max_kbyte=10,
      pid=19269,
      version="NVIM 0.0.0-alpha+201507121634"
    },
    8, 1436711451, 40, { file="/home/zyx/.nvim/shada/main.shada" },
    8, 1436711391, 8, { file="" },
    4, 1436700940, 30, { 0, "call mkdir('/tmp/tty/tty')" },
    4, 1436701355, 35, { 0, "call mkdir('/tmp/tty/tty', 'p')" },
    4, 1436701368, 24, { 0, "call mkdir('/', 'p')" },
    4, 1436701375, 26, { 0, "call mkdir('/tty/tty')" },
    4, 1436701383, 30, { 0, "call mkdir('/tty/tty/tty')" },
    4, 1436701407, 35, { 0, "call mkdir('/usr/tty/tty', 'p')" },
    4, 1436701666, 35, { 0, "call mkdir('/tty/tty/tty', 'p')" },
    4, 1436708101, 25, { 0, "echo msgpackdump([1])" },
    4, 1436708966, 6, { 0, "cq" },
    4, 1436709606, 25, { 0, "echo msgpackdump([5])" },
    4, 1436709610, 26, { 0, "echo msgpackdump([10])" },
    4, 1436709615, 31, { 0, "echo msgpackdump([5, 5, 5])" },
    4, 1436709618, 35, { 0, "echo msgpackdump([5, 5, 5, 10])" },
    4, 1436709634, 57, {
      0,
      "echo msgpackdump([5, 5, 5, 10, [10, 20, {\"abc\": 1}]])"
    },
    4, 1436709651, 67, {
      0,
      "echo msgpackdump([5, 5, 5, 10, [10, 20, {\"abc\": 1, \"def\": 0}]])"
    },
    4, 1436709660, 70, {
      0,
      "echo msgpackdump([5, 5, 5, 10, [10, 20, {\"abc\": 1, \"def\": 0}], 0])"
    },
    4, 1436710095, 29, { 0, "echo msgpackparse([\"\\n\"])" },
    4, 1436710100, 28, { 0, "echo msgpackparse([\"j\"])" },
    4, 1436710109, 31, { 0, "echo msgpackparse([\"\", \"\"])" },
    4, 1436710424, 33, { 0, "echo msgpackparse([\"\", \"\\n\"])" },
    4, 1436710428, 32, { 0, "echo msgpackparse([\"\", \"j\"])" },
    4, 1436711142, 14, { 0, "echo mpack" },
    4, 1436711196, 45, { 0, "let lengths = map(mpack[:], 'len(v:val)')" },
    4, 1436711206, 16, { 0, "echo lengths" },
    4, 1436711244, 92, {
      0,
      ("let sum = len(lengths) - 1 | call map(copy(lengths), "
       .. "'extend(g:, {\"sum\": sum + v:val})')")
    },
    4, 1436711245, 12, { 0, "echo sum" },
    4, 1436711398, 10, { 0, "echo s" },
    4, 1436711404, 41, { 0, "let mpack = readfile('/tmp/foo', 'b')" },
    4, 1436711408, 41, { 0, "let shada_objects=msgpackparse(mpack)" },
    4, 1436711415, 22, { 0, "echo shada_objects" },
    4, 1436711451, 30, { 0, "e ~/.nvim/shada/main.shada" },
    4, 1436711454, 6, { 0, "qa" },
    4, 1436711442, 9, { 1, "test", 47 },
    4, 1436711443, 15, { 1, "aontsuesan", 47 },
    2, 1436711443, 38, { hlsearch=1, pat="aontsuesan", smartcase=1 },
    2, 0, 31, { islast=0, pat="", smartcase=1, sub=1 },
    3, 0, 3, { "" },
    10, 1436711451, 40, { file="/home/zyx/.nvim/shada/main.shada" }
  }
  obj_test('are able to dump and restore rather big object', big_obj)

  obj_test('are able to dump and restore floating-point value', { 0.125 })

  it('can restore and dump UINT64_MAX', function()
    command('let dumped = ["\\xCF" . repeat("\\xFF", 8)]')
    command('let parsed = msgpackparse(dumped)')
    command('let dumped2 = msgpackdump(parsed)')
    eq(1, eval('type(parsed[0]) == type(0) ' .. '|| parsed[0]._TYPE is v:msgpack_types.integer'))
    if eval('type(parsed[0]) == type(0)') == 1 then
      command('call assert_equal(0xFFFFFFFFFFFFFFFF, parsed[0])')
      eq({}, eval('v:errors'))
    else
      eq({ _TYPE = {}, _VAL = { 1, 3, 0x7FFFFFFF, 0x7FFFFFFF } }, eval('parsed[0]'))
    end
    eq(1, eval('dumped ==# dumped2'))
  end)

  it('can restore and dump INT64_MIN', function()
    command('let dumped = ["\\xD3\\x80" . repeat("\\n", 7)]')
    command('let parsed = msgpackparse(dumped)')
    command('let dumped2 = msgpackdump(parsed)')
    eq(1, eval('type(parsed[0]) == type(0) ' .. '|| parsed[0]._TYPE is v:msgpack_types.integer'))
    if eval('type(parsed[0]) == type(0)') == 1 then
      command('call assert_equal(-0x7fffffffffffffff - 1, parsed[0])')
      eq({}, eval('v:errors'))
    else
      eq({ _TYPE = {}, _VAL = { -1, 2, 0, 0 } }, eval('parsed[0]'))
    end
    eq(1, eval('dumped ==# dumped2'))
  end)

  it('can restore and dump BIN string with zero byte', function()
    command('let dumped = ["\\xC4\\x01\\n"]')
    command('let parsed = msgpackparse(dumped)')
    command('let dumped2 = msgpackdump(parsed)')
    eq({ '\000' }, eval('parsed'))
    eq(1, eval('dumped ==# dumped2'))
  end)

  it('can restore and dump STR string contents with zero byte', function()
    command('let dumped = ["\\xA1\\n"]')
    command('let parsed = msgpackparse(dumped)')
    command('let dumped2 = msgpackdump(parsed)')
    eq({ '\000' }, eval('parsed'))
    eq(eval('v:t_blob'), eval('type(parsed[0])'))
    -- type is not preserved: prefer BIN for binary contents
    eq(0, eval('dumped ==# dumped2'))
  end)

  it('can restore and dump BIN string with NL', function()
    command('let dumped = ["\\xC4\\x01", ""]')
    command('let parsed = msgpackparse(dumped)')
    command('let dumped2 = msgpackdump(parsed)')
    eq({ '\n' }, eval('parsed'))
    eq(1, eval('dumped ==# dumped2'))
  end)

  it('dump and restore special mapping with floating-point value', function()
    command('let todump = {"_TYPE": v:msgpack_types.float, "_VAL": 0.125}')
    eq({ 0.125 }, eval('msgpackparse(msgpackdump([todump]))'))
  end)
end)

local blobstr = function(list)
  local l = {}
  for i, v in ipairs(list) do
    l[i] = v:gsub('\n', '\000')
  end
  return table.concat(l, '\n')
end

-- Test msgpackparse() with a readfile()-style list and a blob argument
local parse_eq = function(expect, list_arg)
  local blob_expr = '0z'
    .. blobstr(list_arg):gsub('(.)', function(c)
      return ('%.2x'):format(c:byte())
    end)
  eq(expect, fn.msgpackparse(list_arg))
  command('let g:parsed = msgpackparse(' .. blob_expr .. ')')
  eq(expect, eval('g:parsed'))
end

describe('msgpackparse() function', function()
  before_each(clear)

  it('restores nil as v:null', function()
    parse_eq(eval('[v:null]'), { '\192' })
  end)

  it('restores boolean false as v:false', function()
    parse_eq({ false }, { '\194' })
  end)

  it('restores boolean true as v:true', function()
    parse_eq({ true }, { '\195' })
  end)

  it('restores FIXSTR as string', function()
    parse_eq({ 'ab' }, { '\162ab' })
  end)

  it('restores BIN 8 as string', function()
    parse_eq({ 'ab' }, { '\196\002ab' })
  end)

  it('restores FIXEXT1 as special dictionary', function()
    parse_eq({ { _TYPE = {}, _VAL = { 0x10, { '', '' } } } }, { '\212\016', '' })
    eq(1, eval('g:parsed[0]._TYPE is v:msgpack_types.ext'))
  end)

  it('restores MAP with BIN key as ordinary dictionary', function()
    parse_eq({ { a = '' } }, { '\129\196\001a\196\n' })
  end)

  it('restores MAP with duplicate STR keys as special dictionary', function()
    command('let dumped = ["\\x82\\xA1a\\xC4\\n\\xA1a\\xC4\\n"]')
    -- FIXME Internal error bug, can't use parse_eq() here
    command('silent! let parsed = msgpackparse(dumped)')
    eq({
      {
        _TYPE = {},
        _VAL = {
          { 'a', '' },
          { 'a', '' },
        },
      },
    }, eval('parsed'))
    eq(1, eval('g:parsed[0]._TYPE is v:msgpack_types.map'))
    eq(eval('v:t_string'), eval('type(g:parsed[0]._VAL[0][0])'))
    eq(eval('v:t_string'), eval('type(g:parsed[0]._VAL[1][0])'))
  end)

  it('restores MAP with MAP key as special dictionary', function()
    parse_eq({ { _TYPE = {}, _VAL = { { {}, '' } } } }, { '\129\128\196\n' })
    eq(1, eval('g:parsed[0]._TYPE is v:msgpack_types.map'))
  end)

  it('msgpackparse(systemlist(...)) does not segfault. #3135', function()
    local cmd = "sort(keys(msgpackparse(systemlist('" .. n.nvim_prog .. " --api-info'))[0]))"
    eval(cmd)
    eval(cmd) -- do it again (try to force segfault)
    local api_info = eval(cmd) -- do it again
    if is_os('win') then
      n.assert_alive()
      pending('msgpackparse() has a bug on windows')
      return
    end
    eq({ 'error_types', 'functions', 'types', 'ui_events', 'ui_options', 'version' }, api_info)
  end)

  it('fails when called with no arguments', function()
    eq(
      'Vim(call):E119: Not enough arguments for function: msgpackparse',
      exc_exec('call msgpackparse()')
    )
  end)

  it('fails when called with two arguments', function()
    eq(
      'Vim(call):E118: Too many arguments for function: msgpackparse',
      exc_exec('call msgpackparse(["", ""], 1)')
    )
  end)

  it('fails to parse a string', function()
    eq(
      'Vim(call):E899: Argument of msgpackparse() must be a List or Blob',
      exc_exec('call msgpackparse("abcdefghijklmnopqrstuvwxyz")')
    )
  end)

  it('fails to parse a number', function()
    eq(
      'Vim(call):E899: Argument of msgpackparse() must be a List or Blob',
      exc_exec('call msgpackparse(127)')
    )
  end)

  it('fails to parse a dictionary', function()
    eq(
      'Vim(call):E899: Argument of msgpackparse() must be a List or Blob',
      exc_exec('call msgpackparse({})')
    )
  end)

  it('fails to parse a funcref', function()
    eq(
      'Vim(call):E899: Argument of msgpackparse() must be a List or Blob',
      exc_exec('call msgpackparse(function("tr"))')
    )
  end)

  it('fails to parse a partial', function()
    command('function T() dict\nendfunction')
    eq(
      'Vim(call):E899: Argument of msgpackparse() must be a List or Blob',
      exc_exec('call msgpackparse(function("T", [1, 2], {}))')
    )
  end)

  it('fails to parse a float', function()
    eq(
      'Vim(call):E899: Argument of msgpackparse() must be a List or Blob',
      exc_exec('call msgpackparse(0.0)')
    )
  end)

  it('fails on incomplete msgpack string', function()
    local expected = 'Vim(call):E475: Invalid argument: Incomplete msgpack string'
    eq(expected, exc_exec([[call msgpackparse(["\xc4"])]]))
    eq(expected, exc_exec([[call msgpackparse(["\xca", "\x02\x03"])]]))
    eq(expected, exc_exec('call msgpackparse(0zc4)'))
    eq(expected, exc_exec('call msgpackparse(0zca0a0203)'))
  end)

  it('fails when unable to parse msgpack string', function()
    local expected = 'Vim(call):E475: Invalid argument: Failed to parse msgpack string'
    eq(expected, exc_exec([[call msgpackparse(["\xc1"])]]))
    eq(expected, exc_exec('call msgpackparse(0zc1)'))
  end)
end)

describe('msgpackdump() function', function()
  before_each(clear)

  local dump_eq = function(exp_list, arg_expr)
    eq(exp_list, eval('msgpackdump(' .. arg_expr .. ')'))
    eq(blobstr(exp_list), eval('msgpackdump(' .. arg_expr .. ', "B")'))
  end

  it('dumps string as BIN 8', function()
    dump_eq({ '\196\004Test' }, '["Test"]')
  end)

  it('dumps blob as BIN 8', function()
    dump_eq({ '\196\005Bl\nb!' }, '[0z426c006221]')
  end)

  it('can dump generic mapping with generic mapping keys and values', function()
    command('let todump = {"_TYPE": v:msgpack_types.map, "_VAL": []}')
    command('let todumpv1 = {"_TYPE": v:msgpack_types.map, "_VAL": []}')
    command('let todumpv2 = {"_TYPE": v:msgpack_types.map, "_VAL": []}')
    command('call add(todump._VAL, [todumpv1, todumpv2])')
    dump_eq({ '\129\128\128' }, '[todump]')
  end)

  it('can dump v:true', function()
    dump_eq({ '\195' }, '[v:true]')
  end)

  it('can dump v:false', function()
    dump_eq({ '\194' }, '[v:false]')
  end)

  it('can dump v:null', function()
    dump_eq({ '\192' }, '[v:null]')
  end)

  it('can dump special bool mapping (true)', function()
    command('let todump = {"_TYPE": v:msgpack_types.boolean, "_VAL": 1}')
    dump_eq({ '\195' }, '[todump]')
  end)

  it('can dump special bool mapping (false)', function()
    command('let todump = {"_TYPE": v:msgpack_types.boolean, "_VAL": 0}')
    dump_eq({ '\194' }, '[todump]')
  end)

  it('can dump special nil mapping', function()
    command('let todump = {"_TYPE": v:msgpack_types.nil, "_VAL": 0}')
    dump_eq({ '\192' }, '[todump]')
  end)

  it('can dump special ext mapping', function()
    command('let todump = {"_TYPE": v:msgpack_types.ext, "_VAL": [5, ["",""]]}')
    dump_eq({ '\212\005', '' }, '[todump]')
  end)

  it('can dump special array mapping', function()
    command('let todump = {"_TYPE": v:msgpack_types.array, "_VAL": [5, [""]]}')
    dump_eq({ '\146\005\145\196\n' }, '[todump]')
  end)

  it('can dump special UINT64_MAX mapping', function()
    command('let todump = {"_TYPE": v:msgpack_types.integer}')
    command('let todump._VAL = [1, 3, 0x7FFFFFFF, 0x7FFFFFFF]')
    dump_eq({ '\207\255\255\255\255\255\255\255\255' }, '[todump]')
  end)

  it('can dump special INT64_MIN mapping', function()
    command('let todump = {"_TYPE": v:msgpack_types.integer}')
    command('let todump._VAL = [-1, 2, 0, 0]')
    dump_eq({ '\211\128\n\n\n\n\n\n\n' }, '[todump]')
  end)

  it('fails to dump a function reference', function()
    command('let Todump = function("tr")')
    eq(
      'Vim(call):E5004: Error while dumping msgpackdump() argument, index 0, itself: attempt to dump function reference',
      exc_exec('call msgpackdump([Todump])')
    )
  end)

  it('fails to dump a partial', function()
    command('function T() dict\nendfunction')
    command('let Todump = function("T", [1, 2], {})')
    eq(
      'Vim(call):E5004: Error while dumping msgpackdump() argument, index 0, itself: attempt to dump function reference',
      exc_exec('call msgpackdump([Todump])')
    )
  end)

  it('fails to dump a function reference in a list', function()
    command('let todump = [function("tr")]')
    eq(
      'Vim(call):E5004: Error while dumping msgpackdump() argument, index 0, index 0: attempt to dump function reference',
      exc_exec('call msgpackdump([todump])')
    )
  end)

  it('fails to dump a recursive list', function()
    command('let todump = [[[]]]')
    command('call add(todump[0][0], todump)')
    eq(
      'Vim(call):E5005: Unable to dump msgpackdump() argument, index 0: container references itself in index 0, index 0, index 0',
      exc_exec('call msgpackdump([todump])')
    )
  end)

  it('fails to dump a recursive dict', function()
    command('let todump = {"d": {"d": {}}}')
    command('call extend(todump.d.d, {"d": todump})')
    eq(
      "Vim(call):E5005: Unable to dump msgpackdump() argument, index 0: container references itself in key 'd', key 'd', key 'd'",
      exc_exec('call msgpackdump([todump])')
    )
  end)

  it('can dump dict with two same dicts inside', function()
    command('let inter = {}')
    command('let todump = {"a": inter, "b": inter}')
    dump_eq({ '\130\161a\128\161b\128' }, '[todump]')
  end)

  it('can dump list with two same lists inside', function()
    command('let inter = []')
    command('let todump = [inter, inter]')
    dump_eq({ '\146\144\144' }, '[todump]')
  end)

  it('fails to dump a recursive list in a special dict', function()
    command('let todump = {"_TYPE": v:msgpack_types.array, "_VAL": []}')
    command('call add(todump._VAL, todump)')
    eq(
      'Vim(call):E5005: Unable to dump msgpackdump() argument, index 0: container references itself in index 0',
      exc_exec('call msgpackdump([todump])')
    )
  end)

  it('fails to dump a recursive (key) map in a special dict', function()
    command('let todump = {"_TYPE": v:msgpack_types.map, "_VAL": []}')
    command('call add(todump._VAL, [todump, 0])')
    eq(
      'Vim(call):E5005: Unable to dump msgpackdump() argument, index 0: container references itself in index 0',
      exc_exec('call msgpackdump([todump])')
    )
  end)

  it('fails to dump a recursive (val) map in a special dict', function()
    command('let todump = {"_TYPE": v:msgpack_types.map, "_VAL": []}')
    command('call add(todump._VAL, [0, todump])')
    eq(
      'Vim(call):E5005: Unable to dump msgpackdump() argument, index 0: container references itself in key 0 at index 0 from special map',
      exc_exec('call msgpackdump([todump])')
    )
  end)

  it('fails to dump a recursive (key) map in a special dict, _VAL reference', function()
    command('let todump = {"_TYPE": v:msgpack_types.map, "_VAL": [[[], []]]}')
    command('call add(todump._VAL[0][0], todump._VAL)')
    eq(
      'Vim(call):E5005: Unable to dump msgpackdump() argument, index 0: container references itself in key [[[[...@0], []]]] at index 0 from special map, index 0',
      exc_exec('call msgpackdump([todump])')
    )
  end)

  it('fails to dump a recursive (val) map in a special dict, _VAL reference', function()
    command('let todump = {"_TYPE": v:msgpack_types.map, "_VAL": [[[], []]]}')
    command('call add(todump._VAL[0][1], todump._VAL)')
    eq(
      'Vim(call):E5005: Unable to dump msgpackdump() argument, index 0: container references itself in key [] at index 0 from special map, index 0',
      exc_exec('call msgpackdump([todump])')
    )
  end)

  it('fails to dump a recursive (val) special list in a special dict', function()
    command('let todump = {"_TYPE": v:msgpack_types.array, "_VAL": []}')
    command('call add(todump._VAL, [0, todump._VAL])')
    eq(
      'Vim(call):E5005: Unable to dump msgpackdump() argument, index 0: container references itself in index 0, index 1',
      exc_exec('call msgpackdump([todump])')
    )
  end)

  it('fails when called with no arguments', function()
    eq(
      'Vim(call):E119: Not enough arguments for function: msgpackdump',
      exc_exec('call msgpackdump()')
    )
  end)

  it('fails when called with three arguments', function()
    eq(
      'Vim(call):E118: Too many arguments for function: msgpackdump',
      exc_exec('call msgpackdump(["", ""], 1, 2)')
    )
  end)

  it('fails to dump a string', function()
    eq(
      'Vim(call):E686: Argument of msgpackdump() must be a List',
      exc_exec('call msgpackdump("abcdefghijklmnopqrstuvwxyz")')
    )
  end)

  it('fails to dump a number', function()
    eq(
      'Vim(call):E686: Argument of msgpackdump() must be a List',
      exc_exec('call msgpackdump(127)')
    )
  end)

  it('fails to dump a dictionary', function()
    eq('Vim(call):E686: Argument of msgpackdump() must be a List', exc_exec('call msgpackdump({})'))
  end)

  it('fails to dump a funcref', function()
    eq(
      'Vim(call):E686: Argument of msgpackdump() must be a List',
      exc_exec('call msgpackdump(function("tr"))')
    )
  end)

  it('fails to dump a partial', function()
    command('function T() dict\nendfunction')
    eq(
      'Vim(call):E686: Argument of msgpackdump() must be a List',
      exc_exec('call msgpackdump(function("T", [1, 2], {}))')
    )
  end)

  it('fails to dump a float', function()
    eq(
      'Vim(call):E686: Argument of msgpackdump() must be a List',
      exc_exec('call msgpackdump(0.0)')
    )
  end)

  it('fails to dump special value', function()
    for _, val in ipairs({ 'v:true', 'v:false', 'v:null' }) do
      eq(
        'Vim(call):E686: Argument of msgpackdump() must be a List',
        exc_exec('call msgpackdump(' .. val .. ')')
      )
    end
  end)

  it('can dump NULL string', function()
    dump_eq({ '\196\n' }, '[$XXX_UNEXISTENT_VAR_XXX]')
    dump_eq({ '\196\n' }, '[v:_null_blob]')
    dump_eq({ '\160' }, '[{"_TYPE": v:msgpack_types.string, "_VAL": [$XXX_UNEXISTENT_VAR_XXX]}]')
  end)

  it('can dump NULL blob', function()
    eq({ '\196\n' }, eval('msgpackdump([v:_null_blob])'))
  end)

  it('can dump NULL list', function()
    eq({ '\144' }, eval('msgpackdump([v:_null_list])'))
  end)

  it('can dump NULL dictionary', function()
    eq({ '\128' }, eval('msgpackdump([v:_null_dict])'))
  end)
end)
