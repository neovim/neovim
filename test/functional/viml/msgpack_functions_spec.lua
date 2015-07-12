local helpers = require('test.functional.helpers')
local clear, feed, execute = helpers.clear, helpers.feed, helpers.execute
local eval, eq, neq = helpers.eval, helpers.eq, helpers.neq
local execute, source = helpers.execute, helpers.source
local nvim = helpers.nvim
describe('msgpack*() functions', function()
  before_each(function()
    clear()
  end)
  local obj_test = function(msg, obj)
    it(msg, function()
      nvim('set_var', 'obj', obj)
      eq(obj, eval('msgpackparse(msgpackdump(g:obj))'))
    end)
  end
  -- Regression test: msgpack_list_write was failing to write buffer with zero 
  -- length.
  obj_test('are able to dump and restore {"file": ""}', {{file=''}})
  -- Regression test: msgpack_list_write was failing to write buffer with NL at 
  -- the end.
  obj_test('are able to dump and restore {0, "echo mpack"}', {{0, 'echo mpack'}})
  obj_test('are able to dump and restore "Test\\n"', {'Test\n'})
  -- Regression test: msgpack_list_write was failing to write buffer with NL 
  -- inside.
  obj_test('are able to dump and restore "Test\\nTest 2"', {'Test\nTest 2'})
  -- Test that big objects (requirement: dump to something that is bigger then 
  -- IOSIZE) are also fine. This particular object is obtained by concatenating 
  -- 5 identical shada files.
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

  it('dump funcref as nil and restore as zero', function()
    execute('let dumped = msgpackdump([function("tr")])')
    eq({"\192"}, eval('dumped'))
    eq({0}, eval('msgpackparse(dumped)'))
  end)

  it('restore boolean false as zero', function()
    execute('let dumped = ["\\xC2"]')
    eq({0}, eval('msgpackparse(dumped)'))
  end)

  it('restore boolean true as one', function()
    execute('let dumped = ["\\xC3"]')
    eq({1}, eval('msgpackparse(dumped)'))
  end)

  it('dump string as BIN 8', function()
    nvim('set_var', 'obj', {'Test'})
    eq({"\196\004Test"}, eval('msgpackdump(obj)'))
  end)

  it('restore FIXSTR as string', function()
    execute('let dumped = ["\\xa2ab"]')
    eq({'ab'}, eval('msgpackparse(dumped)'))
  end)

  it('restore BIN 8 as string', function()
    execute('let dumped = ["\\xC4\\x02ab"]')
    eq({'ab'}, eval('msgpackparse(dumped)'))
  end)
end)
