local helpers = require('test.unit.helpers')(after_each)
local global_helpers = require('test.helpers')
local itp = helpers.gen_itp(it)
local viml_helpers = require('test.unit.viml.helpers')

local make_enum_conv_tab = helpers.make_enum_conv_tab
local child_call_once = helpers.child_call_once
local alloc_log_new = helpers.alloc_log_new
local kvi_destroy = helpers.kvi_destroy
local conv_enum = helpers.conv_enum
local ptr2key = helpers.ptr2key
local cimport = helpers.cimport
local ffi = helpers.ffi
local eq = helpers.eq

local conv_ccs = viml_helpers.conv_ccs
local pline2lua = viml_helpers.pline2lua
local new_pstate = viml_helpers.new_pstate
local intchar2lua = viml_helpers.intchar2lua
local conv_cmp_type = viml_helpers.conv_cmp_type
local pstate_set_str = viml_helpers.pstate_set_str

local format_string = global_helpers.format_string
local format_luav = global_helpers.format_luav

local lib = cimport('./src/nvim/viml/parser/expressions.h')

local alloc_log = alloc_log_new()

local function format_check(expr, flags, ast, hls)
  -- That forces specific order.
  print(  format_string('\ncheck_parsing(%r, %u, {', expr, flags))
  local digits = '  --           '
  local digits2 = '  --  '
  for i = 0, #expr - 1 do
    if i % 10 == 0 then
      digits2 = ('%s%10u'):format(digits2, i / 10)
    end
    digits = ('%s%u'):format(digits, i % 10)
  end
  print(digits)
  if #expr > 10 then
    print(digits2)
  end
  print('  ast = ' .. format_luav(ast.ast, '  ') .. ',')
  if ast.err then
    print('  err = {')
    print('    arg = ' .. format_luav(ast.err.arg) .. ',')
    print('    msg = ' .. format_luav(ast.err.msg) .. ',')
    print('  },')
  end
  print('}, {')
  local next_col = 0
  for _, v in ipairs(hls) do
    local group, line, col, str = v:match('NVim([a-zA-Z]+):(%d+):(%d+):(.*)')
    col = tonumber(col)
    line = tonumber(line)
    assert(line == 0)
    local col_shift = col - next_col
    assert(col_shift >= 0)
    next_col = col + #str
    print(format_string('  hl(%r, %r%s),',
                        group,
                        str,
                        (col_shift == 0 and '' or (', %u'):format(col_shift))))
  end
  print('})')
end

local east_node_type_tab
make_enum_conv_tab(lib, {
  'kExprNodeMissing',
  'kExprNodeOpMissing',
  'kExprNodeTernary',
  'kExprNodeTernaryValue',
  'kExprNodeRegister',
  'kExprNodeSubscript',
  'kExprNodeListLiteral',
  'kExprNodeUnaryPlus',
  'kExprNodeBinaryPlus',
  'kExprNodeNested',
  'kExprNodeCall',
  'kExprNodePlainIdentifier',
  'kExprNodePlainKey',
  'kExprNodeComplexIdentifier',
  'kExprNodeUnknownFigure',
  'kExprNodeLambda',
  'kExprNodeDictLiteral',
  'kExprNodeCurlyBracesIdentifier',
  'kExprNodeComma',
  'kExprNodeColon',
  'kExprNodeArrow',
  'kExprNodeComparison',
  'kExprNodeConcat',
  'kExprNodeConcatOrSubscript',
  'kExprNodeInteger',
  'kExprNodeFloat',
  'kExprNodeSingleQuotedString',
  'kExprNodeDoubleQuotedString',
  'kExprNodeOr',
  'kExprNodeAnd',
  'kExprNodeUnaryMinus',
  'kExprNodeBinaryMinus',
  'kExprNodeNot',
  'kExprNodeMultiplication',
  'kExprNodeDivision',
  'kExprNodeMod',
  'kExprNodeOption',
  'kExprNodeEnvironment',
}, 'kExprNode', function(ret) east_node_type_tab = ret end)

local function conv_east_node_type(typ)
  return conv_enum(east_node_type_tab, typ)
end

local eastnodelist2lua

local function eastnode2lua(pstate, eastnode, checked_nodes)
  local key = ptr2key(eastnode)
  if checked_nodes[key] then
    checked_nodes[key].duplicate_key = key
    return { duplicate = key }
  end
  local typ = conv_east_node_type(eastnode.type)
  local ret = {}
  checked_nodes[key] = ret
  ret.children = eastnodelist2lua(pstate, eastnode.children, checked_nodes)
  local str = pstate_set_str(pstate, eastnode.start, eastnode.len)
  local ret_str
  if str.error then
    ret_str = 'error:' .. str.error
  else
    ret_str = ('%u:%u:%s'):format(str.start.line, str.start.col, str.str)
  end
  if typ == 'Register' then
    typ = typ .. ('(name=%s)'):format(
      tostring(intchar2lua(eastnode.data.reg.name)))
  elseif typ == 'PlainIdentifier' then
    typ = typ .. ('(scope=%s,ident=%s)'):format(
      tostring(intchar2lua(eastnode.data.var.scope)),
      ffi.string(eastnode.data.var.ident, eastnode.data.var.ident_len))
  elseif typ == 'PlainKey' then
    typ = typ .. ('(key=%s)'):format(
      ffi.string(eastnode.data.var.ident, eastnode.data.var.ident_len))
  elseif (typ == 'UnknownFigure' or typ == 'DictLiteral'
          or typ == 'CurlyBracesIdentifier' or typ == 'Lambda') then
    typ = typ .. ('(%s)'):format(
      (eastnode.data.fig.type_guesses.allow_lambda and '\\' or '-')
      .. (eastnode.data.fig.type_guesses.allow_dict and 'd' or '-')
      .. (eastnode.data.fig.type_guesses.allow_ident and 'i' or '-'))
  elseif typ == 'Comparison' then
    typ = typ .. ('(type=%s,inv=%u,ccs=%s)'):format(
      conv_cmp_type(eastnode.data.cmp.type), eastnode.data.cmp.inv and 1 or 0,
      conv_ccs(eastnode.data.cmp.ccs))
  elseif typ == 'Integer' then
    typ = typ .. ('(val=%u)'):format(tonumber(eastnode.data.num.value))
  elseif typ == 'Float' then
    typ = typ .. ('(val=%e)'):format(tonumber(eastnode.data.flt.value))
  elseif typ == 'SingleQuotedString' or typ == 'DoubleQuotedString' then
    if eastnode.data.str.value == nil then
      typ = typ .. '(val=NULL)'
    else
      local s = ffi.string(eastnode.data.str.value, eastnode.data.str.size)
      typ = format_string('%s(val=%q)', typ, s)
    end
  elseif typ == 'Option' then
    typ = ('%s(scope=%s,ident=%s)'):format(
      typ,
      tostring(intchar2lua(eastnode.data.opt.scope)),
      ffi.string(eastnode.data.opt.ident, eastnode.data.opt.ident_len))
  elseif typ == 'Environment' then
    typ = ('%s(ident=%s)'):format(
      typ,
      ffi.string(eastnode.data.env.ident, eastnode.data.env.ident_len))
  end
  ret_str = typ .. ':' .. ret_str
  local can_simplify = true
  for k, v in pairs(ret) do
    can_simplify = false
  end
  if can_simplify then
    ret = ret_str
  else
    ret[1] = ret_str
  end
  return ret
end

eastnodelist2lua = function(pstate, eastnode, checked_nodes)
  local ret = {}
  while eastnode ~= nil do
    ret[#ret + 1] = eastnode2lua(pstate, eastnode, checked_nodes)
    eastnode = eastnode.next
  end
  if #ret == 0 then
    ret = nil
  end
  return ret
end

local function east2lua(pstate, east)
  local checked_nodes = {}
  return {
    err = east.err.msg ~= nil and {
      msg = ffi.string(east.err.msg),
      arg = ('%s'):format(
        ffi.string(east.err.arg, east.err.arg_len)),
    } or nil,
    ast = eastnodelist2lua(pstate, east.root, checked_nodes),
  }
end

local function phl2lua(pstate)
  local ret = {}
  for i = 0, (tonumber(pstate.colors.size) - 1) do
    local chunk = pstate.colors.items[i]
    local chunk_tbl = pstate_set_str(
      pstate, chunk.start, chunk.end_col - chunk.start.col, {
        group = ffi.string(chunk.group),
      })
    chunk_str = ('%s:%u:%u:%s'):format(
      chunk_tbl.group,
      chunk_tbl.start.line,
      chunk_tbl.start.col,
      chunk_tbl.str)
    ret[i + 1] = chunk_str
  end
  return ret
end

child_call_once(function()
  assert:set_parameter('TableFormatLevel', 1000000)
end)

describe('Expressions parser', function()
  local function check_parsing(str, flags, exp_ast, exp_highlighting_fs)
    local err, msg = pcall(function()
      flags = flags or 0

      if os.getenv('NVIM_TEST_PARSER_SPEC_PRINT_TEST_CASE') == '1' then
        print(str, flags)
      end
      alloc_log:check({})

      local pstate = new_pstate({str})
      local east = lib.viml_pexpr_parse(pstate, flags)
      local ast = east2lua(pstate, east)
      local hls = phl2lua(pstate)
      if exp_ast == nil then
        format_check(str, flags, ast, hls)
        return
      end
      eq(exp_ast, ast)
      if exp_highlighting_fs then
        local exp_highlighting = {}
        local next_col = 0
        for i, h in ipairs(exp_highlighting_fs) do
          exp_highlighting[i], next_col = h(next_col)
        end
        eq(exp_highlighting, hls)
      end
      lib.viml_pexpr_free_ast(east)
      kvi_destroy(pstate.colors)
      alloc_log:clear_tmp_allocs(true)
      alloc_log:check({})
    end)
    if not err then
      msg = format_string('Error while processing test (%r, %u):\n%s', str, flags, msg)
      error(msg)
    end
  end
  local function hl(group, str, shift)
    return function(next_col)
      local col = next_col + (shift or 0)
      return (('%s:%u:%u:%s'):format(
        'NVim' .. group,
        0,
        col,
        str)), (col + #str)
    end
  end
  itp('works with + and @a', function()
    check_parsing('@a', 0, {
      ast = {
        'Register(name=a):0:0:@a',
      },
    }, {
      hl('Register', '@a'),
    })
    check_parsing('+@a', 0, {
      ast = {
        {
          'UnaryPlus:0:0:+',
          children = {
            'Register(name=a):0:1:@a',
          },
        },
      },
    }, {
      hl('UnaryPlus', '+'),
      hl('Register', '@a'),
    })
    check_parsing('@a+@b', 0, {
      ast = {
        {
          'BinaryPlus:0:2:+',
          children = {
            'Register(name=a):0:0:@a',
            'Register(name=b):0:3:@b',
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('BinaryPlus', '+'),
      hl('Register', '@b'),
    })
    check_parsing('@a+@b+@c', 0, {
      ast = {
        {
          'BinaryPlus:0:5:+',
          children = {
            {
              'BinaryPlus:0:2:+',
              children = {
                'Register(name=a):0:0:@a',
                'Register(name=b):0:3:@b',
              },
            },
            'Register(name=c):0:6:@c',
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('BinaryPlus', '+'),
      hl('Register', '@b'),
      hl('BinaryPlus', '+'),
      hl('Register', '@c'),
    })
    check_parsing('+@a+@b', 0, {
      ast = {
        {
          'BinaryPlus:0:3:+',
          children = {
            {
              'UnaryPlus:0:0:+',
              children = {
                'Register(name=a):0:1:@a',
              },
            },
            'Register(name=b):0:4:@b',
          },
        },
      },
    }, {
      hl('UnaryPlus', '+'),
      hl('Register', '@a'),
      hl('BinaryPlus', '+'),
      hl('Register', '@b'),
    })
    check_parsing('+@a++@b', 0, {
      ast = {
        {
          'BinaryPlus:0:3:+',
          children = {
            {
              'UnaryPlus:0:0:+',
              children = {
                'Register(name=a):0:1:@a',
              },
            },
            {
              'UnaryPlus:0:4:+',
              children = {
                'Register(name=b):0:5:@b',
              },
            },
          },
        },
      },
    }, {
      hl('UnaryPlus', '+'),
      hl('Register', '@a'),
      hl('BinaryPlus', '+'),
      hl('UnaryPlus', '+'),
      hl('Register', '@b'),
    })
    check_parsing('@a@b', 0, {
      ast = {
        {
          'OpMissing:0:2:',
          children = {
            'Register(name=a):0:0:@a',
            'Register(name=b):0:2:@b',
          },
        },
      },
      err = {
        arg = '@b',
        msg = 'E15: Missing operator: %.*s',
      },
    }, {
      hl('Register', '@a'),
      hl('InvalidRegister', '@b'),
    })
    check_parsing(' @a \t @b', 0, {
      ast = {
        {
          'OpMissing:0:3:',
          children = {
            'Register(name=a):0:0: @a',
            'Register(name=b):0:3: \t @b',
          },
        },
      },
      err = {
        arg = '@b',
        msg = 'E15: Missing operator: %.*s',
      },
    }, {
      hl('Register', '@a', 1),
      hl('InvalidSpacing', ' \t '),
      hl('Register', '@b'),
    })
    check_parsing('+', 0, {
      ast = {
        'UnaryPlus:0:0:+',
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('UnaryPlus', '+'),
    })
    check_parsing(' +', 0, {
      ast = {
        'UnaryPlus:0:0: +',
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('UnaryPlus', '+', 1),
    })
    check_parsing('@a+  ', 0, {
      ast = {
        {
          'BinaryPlus:0:2:+',
          children = {
            'Register(name=a):0:0:@a',
          },
        },
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('Register', '@a'),
      hl('BinaryPlus', '+'),
    })
  end)
  itp('works with @a, + and parenthesis', function()
    check_parsing('(@a)', 0, {
      ast = {
        {
          'Nested:0:0:(',
          children = {
            'Register(name=a):0:1:@a',
          },
        },
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Register', '@a'),
      hl('NestingParenthesis', ')'),
    })
    check_parsing('()', 0, {
      ast = {
        {
          'Nested:0:0:(',
          children = {
            'Missing:0:1:',
          },
        },
      },
      err = {
        arg = ')',
        msg = 'E15: Expected value, got parenthesis: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('InvalidNestingParenthesis', ')'),
    })
    check_parsing(')', 0, {
      ast = {
        {
          'Nested:0:0:',
          children = {
            'Missing:0:0:',
          },
        },
      },
      err = {
        arg = ')',
        msg = 'E15: Expected value, got parenthesis: %.*s',
      },
    }, {
      hl('InvalidNestingParenthesis', ')'),
    })
    check_parsing('+)', 0, {
      ast = {
        {
          'Nested:0:1:',
          children = {
            {
              'UnaryPlus:0:0:+',
              children = {
                'Missing:0:1:',
              },
            },
          },
        },
      },
      err = {
        arg = ')',
        msg = 'E15: Expected value, got parenthesis: %.*s',
      },
    }, {
      hl('UnaryPlus', '+'),
      hl('InvalidNestingParenthesis', ')'),
    })
    check_parsing('+@a(@b)', 0, {
      ast = {
        {
          'UnaryPlus:0:0:+',
          children = {
            {
              'Call:0:3:(',
              children = {
                'Register(name=a):0:1:@a',
                'Register(name=b):0:4:@b',
              },
            },
          },
        },
      },
    }, {
      hl('UnaryPlus', '+'),
      hl('Register', '@a'),
      hl('CallingParenthesis', '('),
      hl('Register', '@b'),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('@a+@b(@c)', 0, {
      ast = {
        {
          'BinaryPlus:0:2:+',
          children = {
            'Register(name=a):0:0:@a',
            {
              'Call:0:5:(',
              children = {
                'Register(name=b):0:3:@b',
                'Register(name=c):0:6:@c',
              },
            },
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('BinaryPlus', '+'),
      hl('Register', '@b'),
      hl('CallingParenthesis', '('),
      hl('Register', '@c'),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('@a()', 0, {
      ast = {
        {
          'Call:0:2:(',
          children = {
            'Register(name=a):0:0:@a',
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('CallingParenthesis', '('),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('@a ()', 0, {
      ast = {
        {
          'OpMissing:0:2:',
          children = {
            'Register(name=a):0:0:@a',
            {
              'Nested:0:2: (',
              children = {
                'Missing:0:4:',
              },
            },
          },
        },
      },
      err = {
        arg = '()',
        msg = 'E15: Missing operator: %.*s',
      },
    }, {
      hl('Register', '@a'),
      hl('InvalidSpacing', ' '),
      hl('NestingParenthesis', '('),
      hl('InvalidNestingParenthesis', ')'),
    })
    check_parsing(
      '@a + (@b)', 0, {
        ast = {
          {
            'BinaryPlus:0:2: +',
            children = {
              'Register(name=a):0:0:@a',
              {
                'Nested:0:4: (',
                children = {
                  'Register(name=b):0:6:@b',
                },
              },
            },
          },
        },
      }, {
        hl('Register', '@a'),
        hl('BinaryPlus', '+', 1),
        hl('NestingParenthesis', '(', 1),
        hl('Register', '@b'),
        hl('NestingParenthesis', ')'),
      })
    check_parsing(
      '@a + (+@b)', 0, {
        ast = {
          {
            'BinaryPlus:0:2: +',
            children = {
              'Register(name=a):0:0:@a',
              {
                'Nested:0:4: (',
                children = {
                  {
                    'UnaryPlus:0:6:+',
                    children = {
                      'Register(name=b):0:7:@b',
                    },
                  },
                },
              },
            },
          },
        },
      }, {
        hl('Register', '@a'),
        hl('BinaryPlus', '+', 1),
        hl('NestingParenthesis', '(', 1),
        hl('UnaryPlus', '+'),
        hl('Register', '@b'),
        hl('NestingParenthesis', ')'),
      })
    check_parsing(
      '@a + (@b + @c)', 0, {
        ast = {
          {
            'BinaryPlus:0:2: +',
            children = {
              'Register(name=a):0:0:@a',
              {
                'Nested:0:4: (',
                children = {
                  {
                    'BinaryPlus:0:8: +',
                    children = {
                      'Register(name=b):0:6:@b',
                      'Register(name=c):0:10: @c',
                    },
                  },
                },
              },
            },
          },
        },
      }, {
        hl('Register', '@a'),
        hl('BinaryPlus', '+', 1),
        hl('NestingParenthesis', '(', 1),
        hl('Register', '@b'),
        hl('BinaryPlus', '+', 1),
        hl('Register', '@c', 1),
        hl('NestingParenthesis', ')'),
      })
    check_parsing('(@a)+@b', 0, {
      ast = {
        {
          'BinaryPlus:0:4:+',
          children = {
            {
              'Nested:0:0:(',
              children = {
                'Register(name=a):0:1:@a',
              },
            },
            'Register(name=b):0:5:@b',
          },
        },
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Register', '@a'),
      hl('NestingParenthesis', ')'),
      hl('BinaryPlus', '+'),
      hl('Register', '@b'),
    })
    check_parsing('@a+(@b)(@c)', 0, {
      --           01234567890
      ast = {
        {
          'BinaryPlus:0:2:+',
          children = {
            'Register(name=a):0:0:@a',
            {
              'Call:0:7:(',
              children = {
                {
                  'Nested:0:3:(',
                  children = { 'Register(name=b):0:4:@b' },
                },
                'Register(name=c):0:8:@c',
              },
            },
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('BinaryPlus', '+'),
      hl('NestingParenthesis', '('),
      hl('Register', '@b'),
      hl('NestingParenthesis', ')'),
      hl('CallingParenthesis', '('),
      hl('Register', '@c'),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('@a+((@b))(@c)', 0, {
      --           01234567890123456890123456789
      --           0         1        2
      ast = {
        {
          'BinaryPlus:0:2:+',
          children = {
            'Register(name=a):0:0:@a',
            {
              'Call:0:9:(',
              children = {
                {
                  'Nested:0:3:(',
                  children = {
                    {
                      'Nested:0:4:(',
                      children = { 'Register(name=b):0:5:@b' }
                    },
                  },
                },
                'Register(name=c):0:10:@c',
              },
            },
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('BinaryPlus', '+'),
      hl('NestingParenthesis', '('),
      hl('NestingParenthesis', '('),
      hl('Register', '@b'),
      hl('NestingParenthesis', ')'),
      hl('NestingParenthesis', ')'),
      hl('CallingParenthesis', '('),
      hl('Register', '@c'),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('@a+((@b))+@c', 0, {
      --           01234567890123456890123456789
      --           0         1        2
      ast = {
        {
          'BinaryPlus:0:9:+',
          children = {
            {
              'BinaryPlus:0:2:+',
              children = {
                'Register(name=a):0:0:@a',
                {
                  'Nested:0:3:(',
                  children = {
                    {
                      'Nested:0:4:(',
                      children = { 'Register(name=b):0:5:@b' }
                    },
                  },
                },
              },
            },
            'Register(name=c):0:10:@c',
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('BinaryPlus', '+'),
      hl('NestingParenthesis', '('),
      hl('NestingParenthesis', '('),
      hl('Register', '@b'),
      hl('NestingParenthesis', ')'),
      hl('NestingParenthesis', ')'),
      hl('BinaryPlus', '+'),
      hl('Register', '@c'),
    })
    check_parsing(
      '@a + (@b + @c) + @d(@e) + (+@f) + ((+@g(@h))(@j)(@k))(@l)', 0, {--[[
       | | | | | |   | |  ||  | | ||  | | ||| ||   ||  ||   ||
       000000000011111111112222222222333333333344444444445555555
       012345678901234567890123456789012345678901234567890123456
      ]]
        ast = {{
          'BinaryPlus:0:31: +',
          children = {
            {
              'BinaryPlus:0:23: +',
              children = {
                {
                  'BinaryPlus:0:14: +',
                  children = {
                    {
                      'BinaryPlus:0:2: +',
                      children = {
                        'Register(name=a):0:0:@a',
                        {
                          'Nested:0:4: (',
                          children = {
                            {
                              'BinaryPlus:0:8: +',
                              children = {
                                'Register(name=b):0:6:@b',
                                'Register(name=c):0:10: @c',
                              },
                            },
                          },
                        },
                      },
                    },
                    {
                      'Call:0:19:(',
                      children = {
                        'Register(name=d):0:16: @d',
                        'Register(name=e):0:20:@e',
                      },
                    },
                  },
                },
                {
                  'Nested:0:25: (',
                  children = {
                    {
                      'UnaryPlus:0:27:+',
                      children = {
                        'Register(name=f):0:28:@f',
                      },
                    },
                  },
                },
              },
            },
            {
              'Call:0:53:(',
              children = {
                {
                  'Nested:0:33: (',
                  children = {
                    {
                      'Call:0:48:(',
                      children = {
                        {
                          'Call:0:44:(',
                          children = {
                            {
                              'Nested:0:35:(',
                              children = {
                                {
                                  'UnaryPlus:0:36:+',
                                  children = {
                                    {
                                      'Call:0:39:(',
                                      children = {
                                        'Register(name=g):0:37:@g',
                                        'Register(name=h):0:40:@h',
                                      },
                                    },
                                  },
                                },
                              },
                            },
                            'Register(name=j):0:45:@j',
                          },
                        },
                        'Register(name=k):0:49:@k',
                      },
                    },
                  },
                },
                'Register(name=l):0:54:@l',
              },
            },
          },
        }},
      }, {
        hl('Register', '@a'),
        hl('BinaryPlus', '+', 1),
        hl('NestingParenthesis', '(', 1),
        hl('Register', '@b'),
        hl('BinaryPlus', '+', 1),
        hl('Register', '@c', 1),
        hl('NestingParenthesis', ')'),
        hl('BinaryPlus', '+', 1),
        hl('Register', '@d', 1),
        hl('CallingParenthesis', '('),
        hl('Register', '@e'),
        hl('CallingParenthesis', ')'),
        hl('BinaryPlus', '+', 1),
        hl('NestingParenthesis', '(', 1),
        hl('UnaryPlus', '+'),
        hl('Register', '@f'),
        hl('NestingParenthesis', ')'),
        hl('BinaryPlus', '+', 1),
        hl('NestingParenthesis', '(', 1),
        hl('NestingParenthesis', '('),
        hl('UnaryPlus', '+'),
        hl('Register', '@g'),
        hl('CallingParenthesis', '('),
        hl('Register', '@h'),
        hl('CallingParenthesis', ')'),
        hl('NestingParenthesis', ')'),
        hl('CallingParenthesis', '('),
        hl('Register', '@j'),
        hl('CallingParenthesis', ')'),
        hl('CallingParenthesis', '('),
        hl('Register', '@k'),
        hl('CallingParenthesis', ')'),
        hl('NestingParenthesis', ')'),
        hl('CallingParenthesis', '('),
        hl('Register', '@l'),
        hl('CallingParenthesis', ')'),
      })
    check_parsing('@a)', 0, {
      --           012
      ast = {
        {
          'Nested:0:2:',
          children = {
            'Register(name=a):0:0:@a',
          },
        },
      },
      err = {
        arg = ')',
        msg = 'E15: Unexpected closing parenthesis: %.*s',
      },
    }, {
      hl('Register', '@a'),
      hl('InvalidNestingParenthesis', ')'),
    })
    check_parsing('(@a', 0, {
      --           012
      ast = {
        {
          'Nested:0:0:(',
          children = {
            'Register(name=a):0:1:@a',
          },
        },
      },
      err = {
        arg = '(@a',
        msg = 'E110: Missing closing parenthesis for nested expression: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Register', '@a'),
    })
    check_parsing('@a(@b', 0, {
      --           01234
      ast = {
        {
          'Call:0:2:(',
          children = {
            'Register(name=a):0:0:@a',
            'Register(name=b):0:3:@b',
          },
        },
      },
      err = {
        arg = '(@b',
        msg = 'E116: Missing closing parenthesis for function call: %.*s',
      },
    }, {
      hl('Register', '@a'),
      hl('CallingParenthesis', '('),
      hl('Register', '@b'),
    })
    check_parsing('@a(@b, @c, @d, @e)', 0, {
      --           012345678901234567
      --           0         1
      ast = {
        {
          'Call:0:2:(',
          children = {
            'Register(name=a):0:0:@a',
            {
              'Comma:0:5:,',
              children = {
                'Register(name=b):0:3:@b',
                {
                  'Comma:0:9:,',
                  children = {
                    'Register(name=c):0:6: @c',
                    {
                      'Comma:0:13:,',
                      children = {
                        'Register(name=d):0:10: @d',
                        'Register(name=e):0:14: @e',
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('CallingParenthesis', '('),
      hl('Register', '@b'),
      hl('Comma', ','),
      hl('Register', '@c', 1),
      hl('Comma', ','),
      hl('Register', '@d', 1),
      hl('Comma', ','),
      hl('Register', '@e', 1),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('@a(@b(@c))', 0, {
      --           01234567890123456789012345678901234567
      --           0         1         2         3
      ast = {
        {
          'Call:0:2:(',
          children = {
            'Register(name=a):0:0:@a',
            {
              'Call:0:5:(',
              children = {
                'Register(name=b):0:3:@b',
                'Register(name=c):0:6:@c',
              },
            },
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('CallingParenthesis', '('),
      hl('Register', '@b'),
      hl('CallingParenthesis', '('),
      hl('Register', '@c'),
      hl('CallingParenthesis', ')'),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('@a(@b(@c(@d(@e), @f(@g(@h), @i(@j)))))', 0, {
      --           01234567890123456789012345678901234567
      --           0         1         2         3
      ast = {
        {
          'Call:0:2:(',
          children = {
            'Register(name=a):0:0:@a',
            {
              'Call:0:5:(',
              children = {
                'Register(name=b):0:3:@b',
                {
                  'Call:0:8:(',
                  children = {
                    'Register(name=c):0:6:@c',
                    {
                      'Comma:0:15:,',
                      children = {
                        {
                          'Call:0:11:(',
                          children = {
                            'Register(name=d):0:9:@d',
                            'Register(name=e):0:12:@e',
                          },
                        },
                        {
                          'Call:0:19:(',
                          children = {
                            'Register(name=f):0:16: @f',
                            {
                              'Comma:0:26:,',
                              children = {
                                {
                                  'Call:0:22:(',
                                  children = {
                                    'Register(name=g):0:20:@g',
                                    'Register(name=h):0:23:@h',
                                  },
                                },
                                {
                                  'Call:0:30:(',
                                  children = {
                                    'Register(name=i):0:27: @i',
                                    'Register(name=j):0:31:@j',
                                  },
                                },
                              },
                            },
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('CallingParenthesis', '('),
      hl('Register', '@b'),
      hl('CallingParenthesis', '('),
      hl('Register', '@c'),
      hl('CallingParenthesis', '('),
      hl('Register', '@d'),
      hl('CallingParenthesis', '('),
      hl('Register', '@e'),
      hl('CallingParenthesis', ')'),
      hl('Comma', ','),
      hl('Register', '@f', 1),
      hl('CallingParenthesis', '('),
      hl('Register', '@g'),
      hl('CallingParenthesis', '('),
      hl('Register', '@h'),
      hl('CallingParenthesis', ')'),
      hl('Comma', ','),
      hl('Register', '@i', 1),
      hl('CallingParenthesis', '('),
      hl('Register', '@j'),
      hl('CallingParenthesis', ')'),
      hl('CallingParenthesis', ')'),
      hl('CallingParenthesis', ')'),
      hl('CallingParenthesis', ')'),
      hl('CallingParenthesis', ')'),
    })
  end)
  itp('works with variable names, including curly braces ones', function()
    check_parsing('var', 0, {
        ast = {
          'PlainIdentifier(scope=0,ident=var):0:0:var',
        },
    }, {
      hl('Identifier', 'var'),
    })
    check_parsing('g:var', 0, {
        ast = {
          'PlainIdentifier(scope=g,ident=var):0:0:g:var',
        },
    }, {
      hl('IdentifierScope', 'g'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('Identifier', 'var'),
    })
    check_parsing('g:', 0, {
        ast = {
          'PlainIdentifier(scope=g,ident=):0:0:g:',
        },
    }, {
      hl('IdentifierScope', 'g'),
      hl('IdentifierScopeDelimiter', ':'),
    })
    check_parsing('{a}', 0, {
      --           012
      ast = {
        {
          'CurlyBracesIdentifier(-di):0:0:{',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:1:a',
          },
        },
      },
    }, {
      hl('Curly', '{'),
      hl('Identifier', 'a'),
      hl('Curly', '}'),
    })
    check_parsing('{a:b}', 0, {
      --           012
      ast = {
        {
          'CurlyBracesIdentifier(-di):0:0:{',
          children = {
            'PlainIdentifier(scope=a,ident=b):0:1:a:b',
          },
        },
      },
    }, {
      hl('Curly', '{'),
      hl('IdentifierScope', 'a'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('Identifier', 'b'),
      hl('Curly', '}'),
    })
    check_parsing('{a:@b}', 0, {
      --           012345
      ast = {
        {
          'CurlyBracesIdentifier(-di):0:0:{',
          children = {
            {
              'OpMissing:0:3:',
              children={
                'PlainIdentifier(scope=a,ident=):0:1:a:',
                'Register(name=b):0:3:@b',
              },
            },
          },
        },
      },
      err = {
        arg = '@b}',
        msg = 'E15: Missing operator: %.*s',
      },
    }, {
      hl('Curly', '{'),
      hl('IdentifierScope', 'a'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('InvalidRegister', '@b'),
      hl('Curly', '}'),
    })
    check_parsing('{@a}', 0, {
      ast = {
        {
          'CurlyBracesIdentifier(-di):0:0:{',
          children = {
            'Register(name=a):0:1:@a',
          },
        },
      },
    }, {
      hl('Curly', '{'),
      hl('Register', '@a'),
      hl('Curly', '}'),
    })
    check_parsing('{@a}{@b}', 0, {
      --           01234567
      ast = {
        {
          'ComplexIdentifier:0:4:',
          children = {
            {
              'CurlyBracesIdentifier(-di):0:0:{',
              children = {
                'Register(name=a):0:1:@a',
              },
            },
            {
              'CurlyBracesIdentifier(--i):0:4:{',
              children = {
                'Register(name=b):0:5:@b',
              },
            },
          },
        },
      },
    }, {
      hl('Curly', '{'),
      hl('Register', '@a'),
      hl('Curly', '}'),
      hl('Curly', '{'),
      hl('Register', '@b'),
      hl('Curly', '}'),
    })
    check_parsing('g:{@a}', 0, {
      --           01234567
      ast = {
        {
          'ComplexIdentifier:0:2:',
          children = {
            'PlainIdentifier(scope=g,ident=):0:0:g:',
            {
              'CurlyBracesIdentifier(--i):0:2:{',
              children = {
                'Register(name=a):0:3:@a',
              },
            },
          },
        },
      },
    }, {
      hl('IdentifierScope', 'g'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('Curly', '{'),
      hl('Register', '@a'),
      hl('Curly', '}'),
    })
    check_parsing('{@a}_test', 0, {
      --           012345678
      ast = {
        {
          'ComplexIdentifier:0:4:',
          children = {
            {
              'CurlyBracesIdentifier(-di):0:0:{',
              children = {
                'Register(name=a):0:1:@a',
              },
            },
            'PlainIdentifier(scope=0,ident=_test):0:4:_test',
          },
        },
      },
    }, {
      hl('Curly', '{'),
      hl('Register', '@a'),
      hl('Curly', '}'),
      hl('Identifier', '_test'),
    })
    check_parsing('g:{@a}_test', 0, {
      --           01234567890
      ast = {
        {
          'ComplexIdentifier:0:2:',
          children = {
            'PlainIdentifier(scope=g,ident=):0:0:g:',
            {
              'ComplexIdentifier:0:6:',
              children = {
                {
                  'CurlyBracesIdentifier(--i):0:2:{',
                  children = {
                    'Register(name=a):0:3:@a',
                  },
                },
                'PlainIdentifier(scope=0,ident=_test):0:6:_test',
              },
            },
          },
        },
      },
    }, {
      hl('IdentifierScope', 'g'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('Curly', '{'),
      hl('Register', '@a'),
      hl('Curly', '}'),
      hl('Identifier', '_test'),
    })
    check_parsing('g:{@a}_test()', 0, {
      --           0123456789012
      ast = {
        {
          'Call:0:11:(',
          children = {
            {
              'ComplexIdentifier:0:2:',
              children = {
                'PlainIdentifier(scope=g,ident=):0:0:g:',
                {
                  'ComplexIdentifier:0:6:',
                  children = {
                    {
                      'CurlyBracesIdentifier(--i):0:2:{',
                      children = {
                        'Register(name=a):0:3:@a',
                      },
                    },
                    'PlainIdentifier(scope=0,ident=_test):0:6:_test',
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('IdentifierScope', 'g'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('Curly', '{'),
      hl('Register', '@a'),
      hl('Curly', '}'),
      hl('Identifier', '_test'),
      hl('CallingParenthesis', '('),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('{@a} ()', 0, {
      --           0123456789012
      ast = {
        {
          'Call:0:4: (',
          children = {
            {
              'CurlyBracesIdentifier(-di):0:0:{',
              children = {
                'Register(name=a):0:1:@a',
              },
            },
          },
        },
      },
    }, {
      hl('Curly', '{'),
      hl('Register', '@a'),
      hl('Curly', '}'),
      hl('CallingParenthesis', '(', 1),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('g:{@a} ()', 0, {
      --           0123456789012
      ast = {
        {
          'Call:0:6: (',
          children = {
            {
              'ComplexIdentifier:0:2:',
              children = {
                'PlainIdentifier(scope=g,ident=):0:0:g:',
                {
                  'CurlyBracesIdentifier(--i):0:2:{',
                  children = {
                    'Register(name=a):0:3:@a',
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('IdentifierScope', 'g'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('Curly', '{'),
      hl('Register', '@a'),
      hl('Curly', '}'),
      hl('CallingParenthesis', '(', 1),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('{@a', 0, {
      --           012
      ast = {
        {
          'UnknownFigure(-di):0:0:{',
          children = {
            'Register(name=a):0:1:@a',
          },
        },
      },
      err = {
        arg = '{@a',
        msg = 'E15: Missing closing figure brace: %.*s',
      },
    }, {
      hl('FigureBrace', '{'),
      hl('Register', '@a'),
    })
  end)
  itp('works with lambdas and dictionaries', function()
    check_parsing('{}', 0, {
      ast = {
        'DictLiteral(-di):0:0:{',
      },
    }, {
      hl('Dict', '{'),
      hl('Dict', '}'),
    })
    check_parsing('{->@a}', 0, {
      ast = {
        {
          'Lambda(\\di):0:0:{',
          children = {
            {
              'Arrow:0:1:->',
              children = {
                'Register(name=a):0:3:@a',
              },
            },
          },
        },
      },
    }, {
      hl('Lambda', '{'),
      hl('Arrow', '->'),
      hl('Register', '@a'),
      hl('Lambda', '}'),
    })
    check_parsing('{->@a+@b}', 0, {
      --           012345678
      ast = {
        {
          'Lambda(\\di):0:0:{',
          children = {
            {
              'Arrow:0:1:->',
              children = {
                {
                  'BinaryPlus:0:5:+',
                  children = {
                    'Register(name=a):0:3:@a',
                    'Register(name=b):0:6:@b',
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('Lambda', '{'),
      hl('Arrow', '->'),
      hl('Register', '@a'),
      hl('BinaryPlus', '+'),
      hl('Register', '@b'),
      hl('Lambda', '}'),
    })
    check_parsing('{a->@a}', 0, {
      --           012345678
      ast = {
        {
          'Lambda(\\di):0:0:{',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:1:a',
            {
              'Arrow:0:2:->',
              children = {
                'Register(name=a):0:4:@a',
              },
            },
          },
        },
      },
    }, {
      hl('Lambda', '{'),
      hl('Identifier', 'a'),
      hl('Arrow', '->'),
      hl('Register', '@a'),
      hl('Lambda', '}'),
    })
    check_parsing('{a,b->@a}', 0, {
      --           012345678
      ast = {
        {
          'Lambda(\\di):0:0:{',
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                'PlainIdentifier(scope=0,ident=b):0:3:b',
              },
            },
            {
              'Arrow:0:4:->',
              children = {
                'Register(name=a):0:6:@a',
              },
            },
          },
        },
      },
    }, {
      hl('Lambda', '{'),
      hl('Identifier', 'a'),
      hl('Comma', ','),
      hl('Identifier', 'b'),
      hl('Arrow', '->'),
      hl('Register', '@a'),
      hl('Lambda', '}'),
    })
    check_parsing('{a,b,c->@a}', 0, {
      --           01234567890
      ast = {
        {
          'Lambda(\\di):0:0:{',
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                {
                  'Comma:0:4:,',
                  children = {
                    'PlainIdentifier(scope=0,ident=b):0:3:b',
                    'PlainIdentifier(scope=0,ident=c):0:5:c',
                  },
                },
              },
            },
            {
              'Arrow:0:6:->',
              children = {
                'Register(name=a):0:8:@a',
              },
            },
          },
        },
      },
    }, {
      hl('Lambda', '{'),
      hl('Identifier', 'a'),
      hl('Comma', ','),
      hl('Identifier', 'b'),
      hl('Comma', ','),
      hl('Identifier', 'c'),
      hl('Arrow', '->'),
      hl('Register', '@a'),
      hl('Lambda', '}'),
    })
    check_parsing('{a,b,c,d->@a}', 0, {
      --           0123456789012
      ast = {
        {
          'Lambda(\\di):0:0:{',
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                {
                  'Comma:0:4:,',
                  children = {
                    'PlainIdentifier(scope=0,ident=b):0:3:b',
                    {
                      'Comma:0:6:,',
                      children = {
                        'PlainIdentifier(scope=0,ident=c):0:5:c',
                        'PlainIdentifier(scope=0,ident=d):0:7:d',
                      },
                    },
                  },
                },
              },
            },
            {
              'Arrow:0:8:->',
              children = {
                'Register(name=a):0:10:@a',
              },
            },
          },
        },
      },
    }, {
      hl('Lambda', '{'),
      hl('Identifier', 'a'),
      hl('Comma', ','),
      hl('Identifier', 'b'),
      hl('Comma', ','),
      hl('Identifier', 'c'),
      hl('Comma', ','),
      hl('Identifier', 'd'),
      hl('Arrow', '->'),
      hl('Register', '@a'),
      hl('Lambda', '}'),
    })
    check_parsing('{a,b,c,d,->@a}', 0, {
      --           01234567890123
      ast = {
        {
          'Lambda(\\di):0:0:{',
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                {
                  'Comma:0:4:,',
                  children = {
                    'PlainIdentifier(scope=0,ident=b):0:3:b',
                    {
                      'Comma:0:6:,',
                      children = {
                        'PlainIdentifier(scope=0,ident=c):0:5:c',
                        {
                          'Comma:0:8:,',
                          children = {
                            'PlainIdentifier(scope=0,ident=d):0:7:d',
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
            {
              'Arrow:0:9:->',
              children = {
                'Register(name=a):0:11:@a',
              },
            },
          },
        },
      },
    }, {
      hl('Lambda', '{'),
      hl('Identifier', 'a'),
      hl('Comma', ','),
      hl('Identifier', 'b'),
      hl('Comma', ','),
      hl('Identifier', 'c'),
      hl('Comma', ','),
      hl('Identifier', 'd'),
      hl('Comma', ','),
      hl('Arrow', '->'),
      hl('Register', '@a'),
      hl('Lambda', '}'),
    })
    check_parsing('{a,b->{c,d->{e,f->@a}}}', 0, {
      --           01234567890123456789012
      --           0         1         2
      ast = {
        {
          'Lambda(\\di):0:0:{',
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                'PlainIdentifier(scope=0,ident=b):0:3:b',
              },
            },
            {
              'Arrow:0:4:->',
              children = {
                {
                  'Lambda(\\di):0:6:{',
                  children = {
                    {
                      'Comma:0:8:,',
                      children = {
                        'PlainIdentifier(scope=0,ident=c):0:7:c',
                        'PlainIdentifier(scope=0,ident=d):0:9:d',
                      },
                    },
                    {
                      'Arrow:0:10:->',
                      children = {
                        {
                          'Lambda(\\di):0:12:{',
                          children = {
                            {
                              'Comma:0:14:,',
                              children = {
                                'PlainIdentifier(scope=0,ident=e):0:13:e',
                                'PlainIdentifier(scope=0,ident=f):0:15:f',
                              },
                            },
                            {
                              'Arrow:0:16:->',
                              children = {
                                'Register(name=a):0:18:@a',
                              },
                            },
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('Lambda', '{'),
      hl('Identifier', 'a'),
      hl('Comma', ','),
      hl('Identifier', 'b'),
      hl('Arrow', '->'),
      hl('Lambda', '{'),
      hl('Identifier', 'c'),
      hl('Comma', ','),
      hl('Identifier', 'd'),
      hl('Arrow', '->'),
      hl('Lambda', '{'),
      hl('Identifier', 'e'),
      hl('Comma', ','),
      hl('Identifier', 'f'),
      hl('Arrow', '->'),
      hl('Register', '@a'),
      hl('Lambda', '}'),
      hl('Lambda', '}'),
      hl('Lambda', '}'),
    })
    check_parsing('{a,b->c,d}', 0, {
      --           0123456789
      ast = {
        {
          'Lambda(\\di):0:0:{',
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                'PlainIdentifier(scope=0,ident=b):0:3:b',
              },
            },
            {
              'Arrow:0:4:->',
              children = {
                {
                  'Comma:0:7:,',
                  children = {
                    'PlainIdentifier(scope=0,ident=c):0:6:c',
                    'PlainIdentifier(scope=0,ident=d):0:8:d',
                  },
                },
              },
            },
          },
        },
      },
      err = {
        arg = ',d}',
        msg = 'E15: Comma outside of call, lambda or literal: %.*s',
      },
    }, {
      hl('Lambda', '{'),
      hl('Identifier', 'a'),
      hl('Comma', ','),
      hl('Identifier', 'b'),
      hl('Arrow', '->'),
      hl('Identifier', 'c'),
      hl('InvalidComma', ','),
      hl('Identifier', 'd'),
      hl('Lambda', '}'),
    })
    check_parsing('a,b,c,d', 0, {
      --           0123456789
      ast = {
        {
          'Comma:0:1:,',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'Comma:0:3:,',
              children = {
              'PlainIdentifier(scope=0,ident=b):0:2:b',
                {
                  'Comma:0:5:,',
                  children = {
                    'PlainIdentifier(scope=0,ident=c):0:4:c',
                    'PlainIdentifier(scope=0,ident=d):0:6:d',
                  },
                },
              },
            },
          },
        },
      },
      err = {
        arg = ',b,c,d',
        msg = 'E15: Comma outside of call, lambda or literal: %.*s',
      },
    }, {
      hl('Identifier', 'a'),
      hl('InvalidComma', ','),
      hl('Identifier', 'b'),
      hl('InvalidComma', ','),
      hl('Identifier', 'c'),
      hl('InvalidComma', ','),
      hl('Identifier', 'd'),
    })
    check_parsing('a,b,c,d,', 0, {
      --           0123456789
      ast = {
        {
          'Comma:0:1:,',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'Comma:0:3:,',
              children = {
              'PlainIdentifier(scope=0,ident=b):0:2:b',
                {
                  'Comma:0:5:,',
                  children = {
                    'PlainIdentifier(scope=0,ident=c):0:4:c',
                    {
                      'Comma:0:7:,',
                      children = {
                        'PlainIdentifier(scope=0,ident=d):0:6:d',
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
      err = {
        arg = ',b,c,d,',
        msg = 'E15: Comma outside of call, lambda or literal: %.*s',
      },
    }, {
      hl('Identifier', 'a'),
      hl('InvalidComma', ','),
      hl('Identifier', 'b'),
      hl('InvalidComma', ','),
      hl('Identifier', 'c'),
      hl('InvalidComma', ','),
      hl('Identifier', 'd'),
      hl('InvalidComma', ','),
    })
    check_parsing(',', 0, {
      --           0123456789
      ast = {
        {
          'Comma:0:0:,',
          children = {
            'Missing:0:0:',
          },
        },
      },
      err = {
        arg = ',',
        msg = 'E15: Expected value, got comma: %.*s',
      },
    }, {
      hl('InvalidComma', ','),
    })
    check_parsing('{,a->@a}', 0, {
      --           0123456789
      ast = {
        {
          'CurlyBracesIdentifier(-di):0:0:{',
          children = {
            {
              'Arrow:0:3:->',
              children = {
                {
                  'Comma:0:1:,',
                  children = {
                    'Missing:0:1:',
                    'PlainIdentifier(scope=0,ident=a):0:2:a',
                  },
                },
                'Register(name=a):0:5:@a',
              },
            },
          },
        },
      },
      err = {
        arg = ',a->@a}',
        msg = 'E15: Expected value, got comma: %.*s',
      },
    }, {
      hl('Curly', '{'),
      hl('InvalidComma', ','),
      hl('Identifier', 'a'),
      hl('InvalidArrow', '->'),
      hl('Register', '@a'),
      hl('Curly', '}'),
    })
    check_parsing('}', 0, {
      --           0123456789
      ast = {
        'UnknownFigure(---):0:0:',
      },
      err = {
        arg = '}',
        msg = 'E15: Unexpected closing figure brace: %.*s',
      },
    }, {
      hl('InvalidFigureBrace', '}'),
    })
    check_parsing('{->}', 0, {
      --           0123456789
      ast = {
        {
          'Lambda(\\di):0:0:{',
          children = {
            'Arrow:0:1:->',
          },
        },
      },
      err = {
        arg = '}',
        msg = 'E15: Expected value, got closing figure brace: %.*s',
      },
    }, {
      hl('Lambda', '{'),
      hl('Arrow', '->'),
      hl('InvalidLambda', '}'),
    })
    check_parsing('{a,b}', 0, {
      --           0123456789
      ast = {
        {
          'Lambda(-di):0:0:{',
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                'PlainIdentifier(scope=0,ident=b):0:3:b',
              },
            },
          },
        },
      },
      err = {
        arg = '}',
        msg = 'E15: Expected lambda arguments list or arrow: %.*s',
      },
    }, {
      hl('Lambda', '{'),
      hl('Identifier', 'a'),
      hl('Comma', ','),
      hl('Identifier', 'b'),
      hl('InvalidLambda', '}'),
    })
    check_parsing('{a,}', 0, {
      --           0123456789
      ast = {
        {
          'Lambda(-di):0:0:{',
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
              },
            },
          },
        },
      },
      err = {
        arg = '}',
        msg = 'E15: Expected lambda arguments list or arrow: %.*s',
      },
    }, {
      hl('Lambda', '{'),
      hl('Identifier', 'a'),
      hl('Comma', ','),
      hl('InvalidLambda', '}'),
    })
    check_parsing('{@a:@b}', 0, {
      --           0123456789
      ast = {
        {
          'DictLiteral(-di):0:0:{',
          children = {
            {
              'Colon:0:3::',
              children = {
                'Register(name=a):0:1:@a',
                'Register(name=b):0:4:@b',
              },
            },
          },
        },
      },
    }, {
      hl('Dict', '{'),
      hl('Register', '@a'),
      hl('Colon', ':'),
      hl('Register', '@b'),
      hl('Dict', '}'),
    })
    check_parsing('{@a:@b,@c:@d}', 0, {
      --           0123456789012
      --           0         1
      ast = {
        {
          'DictLiteral(-di):0:0:{',
          children = {
            {
              'Comma:0:6:,',
              children = {
                {
                  'Colon:0:3::',
                  children = {
                    'Register(name=a):0:1:@a',
                    'Register(name=b):0:4:@b',
                  },
                },
                {
                  'Colon:0:9::',
                  children = {
                    'Register(name=c):0:7:@c',
                    'Register(name=d):0:10:@d',
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('Dict', '{'),
      hl('Register', '@a'),
      hl('Colon', ':'),
      hl('Register', '@b'),
      hl('Comma', ','),
      hl('Register', '@c'),
      hl('Colon', ':'),
      hl('Register', '@d'),
      hl('Dict', '}'),
    })
    check_parsing('{@a:@b,@c:@d,@e:@f,}', 0, {
      --           01234567890123456789
      --           0         1
      ast = {
        {
          'DictLiteral(-di):0:0:{',
          children = {
            {
              'Comma:0:6:,',
              children = {
                {
                  'Colon:0:3::',
                  children = {
                    'Register(name=a):0:1:@a',
                    'Register(name=b):0:4:@b',
                  },
                },
                {
                  'Comma:0:12:,',
                  children = {
                    {
                      'Colon:0:9::',
                      children = {
                        'Register(name=c):0:7:@c',
                        'Register(name=d):0:10:@d',
                      },
                    },
                    {
                      'Comma:0:18:,',
                      children = {
                        {
                          'Colon:0:15::',
                          children = {
                            'Register(name=e):0:13:@e',
                            'Register(name=f):0:16:@f',
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('Dict', '{'),
      hl('Register', '@a'),
      hl('Colon', ':'),
      hl('Register', '@b'),
      hl('Comma', ','),
      hl('Register', '@c'),
      hl('Colon', ':'),
      hl('Register', '@d'),
      hl('Comma', ','),
      hl('Register', '@e'),
      hl('Colon', ':'),
      hl('Register', '@f'),
      hl('Comma', ','),
      hl('Dict', '}'),
    })
    check_parsing('{@a:@b,@c:@d,@e:@f,@g:}', 0, {
      --           01234567890123456789012
      --           0         1         2
      ast = {
        {
          'DictLiteral(-di):0:0:{',
          children = {
            {
              'Comma:0:6:,',
              children = {
                {
                  'Colon:0:3::',
                  children = {
                    'Register(name=a):0:1:@a',
                    'Register(name=b):0:4:@b',
                  },
                },
                {
                  'Comma:0:12:,',
                  children = {
                    {
                      'Colon:0:9::',
                      children = {
                        'Register(name=c):0:7:@c',
                        'Register(name=d):0:10:@d',
                      },
                    },
                    {
                      'Comma:0:18:,',
                      children = {
                        {
                          'Colon:0:15::',
                          children = {
                            'Register(name=e):0:13:@e',
                            'Register(name=f):0:16:@f',
                          },
                        },
                        {
                          'Colon:0:21::',
                          children = {
                            'Register(name=g):0:19:@g',
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
      err = {
        arg = '}',
        msg = 'E15: Expected value, got closing figure brace: %.*s',
      },
    }, {
      hl('Dict', '{'),
      hl('Register', '@a'),
      hl('Colon', ':'),
      hl('Register', '@b'),
      hl('Comma', ','),
      hl('Register', '@c'),
      hl('Colon', ':'),
      hl('Register', '@d'),
      hl('Comma', ','),
      hl('Register', '@e'),
      hl('Colon', ':'),
      hl('Register', '@f'),
      hl('Comma', ','),
      hl('Register', '@g'),
      hl('Colon', ':'),
      hl('InvalidDict', '}'),
    })
    check_parsing('{@a:@b,}', 0, {
      --           01234567890123
      --           0         1
      ast = {
        {
          'DictLiteral(-di):0:0:{',
          children = {
            {
              'Comma:0:6:,',
              children = {
                {
                  'Colon:0:3::',
                  children = {
                    'Register(name=a):0:1:@a',
                    'Register(name=b):0:4:@b',
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('Dict', '{'),
      hl('Register', '@a'),
      hl('Colon', ':'),
      hl('Register', '@b'),
      hl('Comma', ','),
      hl('Dict', '}'),
    })
    check_parsing('{({f -> g})(@h)(@i)}', 0, {
      --           01234567890123456789
      --           0         1
      ast = {
        {
          'CurlyBracesIdentifier(-di):0:0:{',
          children = {
            {
              'Call:0:15:(',
              children = {
                {
                  'Call:0:11:(',
                  children = {
                    {
                      'Nested:0:1:(',
                      children = {
                        {
                          'Lambda(\\di):0:2:{',
                          children = {
                            'PlainIdentifier(scope=0,ident=f):0:3:f',
                            {
                              'Arrow:0:4: ->',
                              children = {
                                'PlainIdentifier(scope=0,ident=g):0:7: g',
                              },
                            },
                          },
                        },
                      },
                    },
                    'Register(name=h):0:12:@h',
                  },
                },
                'Register(name=i):0:16:@i',
              },
            },
          },
        },
      },
    }, {
      hl('Curly', '{'),
      hl('NestingParenthesis', '('),
      hl('Lambda', '{'),
      hl('Identifier', 'f'),
      hl('Arrow', '->', 1),
      hl('Identifier', 'g', 1),
      hl('Lambda', '}'),
      hl('NestingParenthesis', ')'),
      hl('CallingParenthesis', '('),
      hl('Register', '@h'),
      hl('CallingParenthesis', ')'),
      hl('CallingParenthesis', '('),
      hl('Register', '@i'),
      hl('CallingParenthesis', ')'),
      hl('Curly', '}'),
    })
    check_parsing('a:{b()}c', 0, {
      --           01234567
      ast = {
        {
          'ComplexIdentifier:0:2:',
          children = {
            'PlainIdentifier(scope=a,ident=):0:0:a:',
            {
              'ComplexIdentifier:0:7:',
              children = {
                {
                  'CurlyBracesIdentifier(--i):0:2:{',
                  children = {
                    {
                      'Call:0:4:(',
                      children = {
                        'PlainIdentifier(scope=0,ident=b):0:3:b',
                      },
                    },
                  },
                },
                'PlainIdentifier(scope=0,ident=c):0:7:c',
              },
            },
          },
        },
      },
    }, {
      hl('IdentifierScope', 'a'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('Curly', '{'),
      hl('Identifier', 'b'),
      hl('CallingParenthesis', '('),
      hl('CallingParenthesis', ')'),
      hl('Curly', '}'),
      hl('Identifier', 'c'),
    })
    check_parsing('a:{{b, c -> @d + @e + ({f -> g})(@h)}(@i)}j', 0, {
      --           01234567890123456789012345678901234567890123456
      --           0         1         2         3         4
      ast = {
        {
          'ComplexIdentifier:0:2:',
          children = {
            'PlainIdentifier(scope=a,ident=):0:0:a:',
            {
              'ComplexIdentifier:0:42:',
              children = {
                {
                  'CurlyBracesIdentifier(--i):0:2:{',
                  children = {
                    {
                      'Call:0:37:(',
                      children = {
                        {
                          'Lambda(\\di):0:3:{',
                          children = {
                            {
                              'Comma:0:5:,',
                              children = {
                                'PlainIdentifier(scope=0,ident=b):0:4:b',
                                'PlainIdentifier(scope=0,ident=c):0:6: c',
                              },
                            },
                            {
                              'Arrow:0:8: ->',
                              children = {
                                {
                                  'BinaryPlus:0:19: +',
                                  children = {
                                    {
                                      'BinaryPlus:0:14: +',
                                      children = {
                                        'Register(name=d):0:11: @d',
                                        'Register(name=e):0:16: @e',
                                      },
                                    },
                                    {
                                      'Call:0:32:(',
                                      children = {
                                        {
                                          'Nested:0:21: (',
                                          children = {
                                            {
                                              'Lambda(\\di):0:23:{',
                                              children = {
                                                'PlainIdentifier(scope=0,ident=f):0:24:f',
                                                {
                                                  'Arrow:0:25: ->',
                                                  children = {
                                                    'PlainIdentifier(scope=0,ident=g):0:28: g',
                                                  },
                                                },
                                              },
                                            },
                                          },
                                        },
                                        'Register(name=h):0:33:@h',
                                      },
                                    },
                                  },
                                },
                              },
                            },
                          },
                        },
                        'Register(name=i):0:38:@i',
                      },
                    },
                  },
                },
                'PlainIdentifier(scope=0,ident=j):0:42:j',
              },
            },
          },
        },
      },
    }, {
      hl('IdentifierScope', 'a'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('Curly', '{'),
      hl('Lambda', '{'),
      hl('Identifier', 'b'),
      hl('Comma', ','),
      hl('Identifier', 'c', 1),
      hl('Arrow', '->', 1),
      hl('Register', '@d', 1),
      hl('BinaryPlus', '+', 1),
      hl('Register', '@e', 1),
      hl('BinaryPlus', '+', 1),
      hl('NestingParenthesis', '(', 1),
      hl('Lambda', '{'),
      hl('Identifier', 'f'),
      hl('Arrow', '->', 1),
      hl('Identifier', 'g', 1),
      hl('Lambda', '}'),
      hl('NestingParenthesis', ')'),
      hl('CallingParenthesis', '('),
      hl('Register', '@h'),
      hl('CallingParenthesis', ')'),
      hl('Lambda', '}'),
      hl('CallingParenthesis', '('),
      hl('Register', '@i'),
      hl('CallingParenthesis', ')'),
      hl('Curly', '}'),
      hl('Identifier', 'j'),
    })
    check_parsing('{@a + @b : @c + @d, @e + @f : @g + @i}', 0, {
      --           01234567890123456789012345678901234567
      --           0         1         2         3
      ast = {
        {
          'DictLiteral(-di):0:0:{',
          children = {
            {
              'Comma:0:18:,',
              children = {
                {
                  'Colon:0:8: :',
                  children = {
                    {
                      'BinaryPlus:0:3: +',
                      children = {
                        'Register(name=a):0:1:@a',
                        'Register(name=b):0:5: @b',
                      },
                    },
                    {
                      'BinaryPlus:0:13: +',
                      children = {
                        'Register(name=c):0:10: @c',
                        'Register(name=d):0:15: @d',
                      },
                    },
                  },
                },
                {
                  'Colon:0:27: :',
                  children = {
                    {
                      'BinaryPlus:0:22: +',
                      children = {
                        'Register(name=e):0:19: @e',
                        'Register(name=f):0:24: @f',
                      },
                    },
                    {
                      'BinaryPlus:0:32: +',
                      children = {
                        'Register(name=g):0:29: @g',
                        'Register(name=i):0:34: @i',
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('Dict', '{'),
      hl('Register', '@a'),
      hl('BinaryPlus', '+', 1),
      hl('Register', '@b', 1),
      hl('Colon', ':', 1),
      hl('Register', '@c', 1),
      hl('BinaryPlus', '+', 1),
      hl('Register', '@d', 1),
      hl('Comma', ','),
      hl('Register', '@e', 1),
      hl('BinaryPlus', '+', 1),
      hl('Register', '@f', 1),
      hl('Colon', ':', 1),
      hl('Register', '@g', 1),
      hl('BinaryPlus', '+', 1),
      hl('Register', '@i', 1),
      hl('Dict', '}'),
    })
    check_parsing('-> -> ->', 0, {
      --           01234567
      ast = {
        {
          'Arrow:0:0:->',
          children = {
            'Missing:0:0:',
            {
              'Arrow:0:2: ->',
              children = {
                'Missing:0:2:',
                {
                  'Arrow:0:5: ->',
                  children = {
                    'Missing:0:5:',
                  },
                },
              },
            },
          },
        },
      },
      err = {
        arg = '-> -> ->',
        msg = 'E15: Unexpected arrow: %.*s',
      },
    }, {
      hl('InvalidArrow', '->'),
      hl('InvalidArrow', '->', 1),
      hl('InvalidArrow', '->', 1),
    })
    check_parsing('a -> b -> c -> d', 0, {
      --           0123456789012345
      --           0         1
      ast = {
        {
          'Arrow:0:1: ->',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'Arrow:0:6: ->',
              children = {
                'PlainIdentifier(scope=0,ident=b):0:4: b',
                {
                  'Arrow:0:11: ->',
                  children = {
                    'PlainIdentifier(scope=0,ident=c):0:9: c',
                    'PlainIdentifier(scope=0,ident=d):0:14: d',
                  },
                },
              },
            },
          },
        },
      },
      err = {
        arg = '-> b -> c -> d',
        msg = 'E15: Arrow outside of lambda: %.*s',
      },
    }, {
      hl('Identifier', 'a'),
      hl('InvalidArrow', '->', 1),
      hl('Identifier', 'b', 1),
      hl('InvalidArrow', '->', 1),
      hl('Identifier', 'c', 1),
      hl('InvalidArrow', '->', 1),
      hl('Identifier', 'd', 1),
    })
    check_parsing('{a -> b -> c}', 0, {
      --           0123456789012
      --           0         1
      ast = {
        {
          'Lambda(\\di):0:0:{',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:1:a',
            {
              'Arrow:0:2: ->',
              children = {
                {
                  'Arrow:0:7: ->',
                  children = {
                    'PlainIdentifier(scope=0,ident=b):0:5: b',
                    'PlainIdentifier(scope=0,ident=c):0:10: c',
                  },
                },
              },
            },
          },
        },
      },
      err = {
        arg = '-> c}',
        msg = 'E15: Arrow outside of lambda: %.*s',
      },
    }, {
      hl('Lambda', '{'),
      hl('Identifier', 'a'),
      hl('Arrow', '->', 1),
      hl('Identifier', 'b', 1),
      hl('InvalidArrow', '->', 1),
      hl('Identifier', 'c', 1),
      hl('Lambda', '}'),
    })
    check_parsing('{a: -> b}', 0, {
      --           012345678
      ast = {
        {
          'CurlyBracesIdentifier(-di):0:0:{',
          children = {
            {
              'Arrow:0:3: ->',
              children = {
                'PlainIdentifier(scope=a,ident=):0:1:a:',
                'PlainIdentifier(scope=0,ident=b):0:6: b',
              },
            },
          },
        },
      },
      err = {
        arg = '-> b}',
        msg = 'E15: Arrow outside of lambda: %.*s',
      },
    }, {
      hl('Curly', '{'),
      hl('IdentifierScope', 'a'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('InvalidArrow', '->', 1),
      hl('Identifier', 'b', 1),
      hl('Curly', '}'),
    })

    check_parsing('{a:b -> b}', 0, {
      --           0123456789
      ast = {
        {
          'CurlyBracesIdentifier(-di):0:0:{',
          children = {
            {
              'Arrow:0:4: ->',
              children = {
                'PlainIdentifier(scope=a,ident=b):0:1:a:b',
                'PlainIdentifier(scope=0,ident=b):0:7: b',
              },
            },
          },
        },
      },
      err = {
        arg = '-> b}',
        msg = 'E15: Arrow outside of lambda: %.*s',
      },
    }, {
      hl('Curly', '{'),
      hl('IdentifierScope', 'a'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('Identifier', 'b'),
      hl('InvalidArrow', '->', 1),
      hl('Identifier', 'b', 1),
      hl('Curly', '}'),
    })

    check_parsing('{a#b -> b}', 0, {
      --           0123456789
      ast = {
        {
          'CurlyBracesIdentifier(-di):0:0:{',
          children = {
            {
              'Arrow:0:4: ->',
              children = {
                'PlainIdentifier(scope=0,ident=a#b):0:1:a#b',
                'PlainIdentifier(scope=0,ident=b):0:7: b',
              },
            },
          },
        },
      },
      err = {
        arg = '-> b}',
        msg = 'E15: Arrow outside of lambda: %.*s',
      },
    }, {
      hl('Curly', '{'),
      hl('Identifier', 'a#b'),
      hl('InvalidArrow', '->', 1),
      hl('Identifier', 'b', 1),
      hl('Curly', '}'),
    })
    check_parsing('{a : b : c}', 0, {
      --           01234567890
      --           0         1
      ast = {
        {
          'DictLiteral(-di):0:0:{',
          children = {
            {
              'Colon:0:2: :',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                {
                  'Colon:0:6: :',
                  children = {
                    'PlainIdentifier(scope=0,ident=b):0:4: b',
                    'PlainIdentifier(scope=0,ident=c):0:8: c',
                  },
                },
              },
            },
          },
        },
      },
      err = {
        arg = ': c}',
        msg = 'E15: Colon outside of dictionary or ternary operator: %.*s',
      },
    }, {
      hl('Dict', '{'),
      hl('Identifier', 'a'),
      hl('Colon', ':', 1),
      hl('Identifier', 'b', 1),
      hl('InvalidColon', ':', 1),
      hl('Identifier', 'c', 1),
      hl('Dict', '}'),
    })
    check_parsing('{', 0, {
      --           0
      ast = {
        'UnknownFigure(\\di):0:0:{',
      },
      err = {
        arg = '{',
        msg = 'E15: Missing closing figure brace: %.*s',
      },
    }, {
      hl('FigureBrace', '{'),
    })
    check_parsing('{a', 0, {
      --           01
      ast = {
        {
          'UnknownFigure(\\di):0:0:{',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:1:a',
          },
        },
      },
      err = {
        arg = '{a',
        msg = 'E15: Missing closing figure brace: %.*s',
      },
    }, {
      hl('FigureBrace', '{'),
      hl('Identifier', 'a'),
    })
    check_parsing('{a,b', 0, {
      --           0123
      ast = {
        {
          'Lambda(\\di):0:0:{',
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                'PlainIdentifier(scope=0,ident=b):0:3:b',
              },
            },
          },
        },
      },
      err = {
        arg = '{a,b',
        msg = 'E15: Missing closing figure brace for lambda: %.*s',
      },
    }, {
      hl('Lambda', '{'),
      hl('Identifier', 'a'),
      hl('Comma', ','),
      hl('Identifier', 'b'),
    })
    check_parsing('{a,b->', 0, {
      --           012345
      ast = {
        {
          'Lambda(\\di):0:0:{',
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                'PlainIdentifier(scope=0,ident=b):0:3:b',
              },
            },
            'Arrow:0:4:->',
          },
        },
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('Lambda', '{'),
      hl('Identifier', 'a'),
      hl('Comma', ','),
      hl('Identifier', 'b'),
      hl('Arrow', '->'),
    })
    check_parsing('{a,b->c', 0, {
      --           0123456
      ast = {
        {
          'Lambda(\\di):0:0:{',
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                'PlainIdentifier(scope=0,ident=b):0:3:b',
              },
            },
            {
              'Arrow:0:4:->',
              children = {
                'PlainIdentifier(scope=0,ident=c):0:6:c',
              },
            },
          },
        },
      },
      err = {
        arg = '{a,b->c',
        msg = 'E15: Missing closing figure brace for lambda: %.*s',
      },
    }, {
      hl('Lambda', '{'),
      hl('Identifier', 'a'),
      hl('Comma', ','),
      hl('Identifier', 'b'),
      hl('Arrow', '->'),
      hl('Identifier', 'c'),
    })
    check_parsing('{a : b', 0, {
      --           012345
      ast = {
        {
          'DictLiteral(-di):0:0:{',
          children = {
            {
              'Colon:0:2: :',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                'PlainIdentifier(scope=0,ident=b):0:4: b',
              },
            },
          },
        },
      },
      err = {
        arg = '{a : b',
        msg = 'E723: Missing end of Dictionary \'}\': %.*s',
      },
    }, {
      hl('Dict', '{'),
      hl('Identifier', 'a'),
      hl('Colon', ':', 1),
      hl('Identifier', 'b', 1),
    })
    check_parsing('{a : b,', 0, {
      --           0123456
      ast = {
        {
          'DictLiteral(-di):0:0:{',
          children = {
            {
              'Comma:0:6:,',
              children = {
                {
                  'Colon:0:2: :',
                  children = {
                    'PlainIdentifier(scope=0,ident=a):0:1:a',
                    'PlainIdentifier(scope=0,ident=b):0:4: b',
                  },
                },
              },
            },
          },
        },
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('Dict', '{'),
      hl('Identifier', 'a'),
      hl('Colon', ':', 1),
      hl('Identifier', 'b', 1),
      hl('Comma', ','),
    })
  end)
  itp('works with ternary operator', function()
    check_parsing('a ? b : c', 0, {
      --           012345678
      ast = {
        {
          'Ternary:0:1: ?',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'TernaryValue:0:5: :',
              children = {
                'PlainIdentifier(scope=0,ident=b):0:3: b',
                'PlainIdentifier(scope=0,ident=c):0:7: c',
              },
            },
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('Ternary', '?', 1),
      hl('Identifier', 'b', 1),
      hl('TernaryColon', ':', 1),
      hl('Identifier', 'c', 1),
    })
    check_parsing('@a?@b?@c:@d:@e', 0, {
      --           01234567890123
      --           0         1
      ast = {
        {
          'Ternary:0:2:?',
          children = {
            'Register(name=a):0:0:@a',
            {
              'TernaryValue:0:11::',
              children = {
                {
                  'Ternary:0:5:?',
                  children = {
                    'Register(name=b):0:3:@b',
                    {
                      'TernaryValue:0:8::',
                      children = {
                        'Register(name=c):0:6:@c',
                        'Register(name=d):0:9:@d',
                      },
                    },
                  },
                },
                'Register(name=e):0:12:@e',
              },
            },
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('Ternary', '?'),
      hl('Register', '@b'),
      hl('Ternary', '?'),
      hl('Register', '@c'),
      hl('TernaryColon', ':'),
      hl('Register', '@d'),
      hl('TernaryColon', ':'),
      hl('Register', '@e'),
    })
    check_parsing('@a?@b:@c?@d:@e', 0, {
      --           01234567890123
      --           0         1
      ast = {
        {
          'Ternary:0:2:?',
          children = {
            'Register(name=a):0:0:@a',
            {
              'TernaryValue:0:5::',
              children = {
                'Register(name=b):0:3:@b',
                {
                  'Ternary:0:8:?',
                  children = {
                    'Register(name=c):0:6:@c',
                    {
                      'TernaryValue:0:11::',
                      children = {
                        'Register(name=d):0:9:@d',
                        'Register(name=e):0:12:@e',
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('Ternary', '?'),
      hl('Register', '@b'),
      hl('TernaryColon', ':'),
      hl('Register', '@c'),
      hl('Ternary', '?'),
      hl('Register', '@d'),
      hl('TernaryColon', ':'),
      hl('Register', '@e'),
    })
    check_parsing('@a?@b?@c?@d:@e?@f:@g:@h?@i:@j:@k', 0, {
      --           01234567890123456789012345678901
      --           0         1         2         3
      ast = {
        {
          'Ternary:0:2:?',
          children = {
            'Register(name=a):0:0:@a',
            {
              'TernaryValue:0:29::',
              children = {
                {
                  'Ternary:0:5:?',
                  children = {
                    'Register(name=b):0:3:@b',
                    {
                      'TernaryValue:0:20::',
                      children = {
                        {
                          'Ternary:0:8:?',
                          children = {
                            'Register(name=c):0:6:@c',
                            {
                              'TernaryValue:0:11::',
                              children = {
                                'Register(name=d):0:9:@d',
                                {
                                  'Ternary:0:14:?',
                                  children = {
                                    'Register(name=e):0:12:@e',
                                    {
                                      'TernaryValue:0:17::',
                                      children = {
                                        'Register(name=f):0:15:@f',
                                        'Register(name=g):0:18:@g',
                                      },
                                    },
                                  },
                                },
                              },
                            },
                          },
                        },
                        {
                          'Ternary:0:23:?',
                          children = {
                            'Register(name=h):0:21:@h',
                            {
                              'TernaryValue:0:26::',
                              children = {
                                'Register(name=i):0:24:@i',
                                'Register(name=j):0:27:@j',
                              },
                            },
                          },
                        },
                      },
                    },
                  },
                },
                'Register(name=k):0:30:@k',
              },
            },
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('Ternary', '?'),
      hl('Register', '@b'),
      hl('Ternary', '?'),
      hl('Register', '@c'),
      hl('Ternary', '?'),
      hl('Register', '@d'),
      hl('TernaryColon', ':'),
      hl('Register', '@e'),
      hl('Ternary', '?'),
      hl('Register', '@f'),
      hl('TernaryColon', ':'),
      hl('Register', '@g'),
      hl('TernaryColon', ':'),
      hl('Register', '@h'),
      hl('Ternary', '?'),
      hl('Register', '@i'),
      hl('TernaryColon', ':'),
      hl('Register', '@j'),
      hl('TernaryColon', ':'),
      hl('Register', '@k'),
    })
    check_parsing('?', 0, {
      --           0
      ast = {
        {
          'Ternary:0:0:?',
          children = {
            'Missing:0:0:',
            'TernaryValue:0:0:?',
          },
        },
      },
      err = {
        arg = '?',
        msg = 'E15: Expected value, got question mark: %.*s',
      },
    }, {
      hl('InvalidTernary', '?'),
    })

    check_parsing('?:', 0, {
      --           01
      ast = {
        {
          'Ternary:0:0:?',
          children = {
            'Missing:0:0:',
            {
              'TernaryValue:0:1::',
              children = {
                'Missing:0:1:',
              },
            },
          },
        },
      },
      err = {
        arg = '?:',
        msg = 'E15: Expected value, got question mark: %.*s',
      },
    }, {
      hl('InvalidTernary', '?'),
      hl('InvalidTernaryColon', ':'),
    })

    check_parsing('?::', 0, {
      --           012
      ast = {
        {
          'Colon:0:2::',
          children = {
            {
              'Ternary:0:0:?',
              children = {
                'Missing:0:0:',
                {
                  'TernaryValue:0:1::',
                  children = {
                    'Missing:0:1:',
                    'Missing:0:2:',
                  },
                },
              },
            },
          },
        },
      },
      err = {
        arg = '?::',
        msg = 'E15: Expected value, got question mark: %.*s',
      },
    }, {
      hl('InvalidTernary', '?'),
      hl('InvalidTernaryColon', ':'),
      hl('InvalidColon', ':'),
    })

    check_parsing('a?b', 0, {
      --           012
      ast = {
        {
          'Ternary:0:1:?',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'TernaryValue:0:1:?',
              children = {
                'PlainIdentifier(scope=0,ident=b):0:2:b',
              },
            },
          },
        },
      },
      err = {
        arg = '?b',
        msg = 'E109: Missing \':\' after \'?\': %.*s',
      },
    }, {
      hl('Identifier', 'a'),
      hl('Ternary', '?'),
      hl('Identifier', 'b'),
    })
    check_parsing('a?b:', 0, {
      --           0123
      ast = {
        {
          'Ternary:0:1:?',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'TernaryValue:0:1:?',
              children = {
                'PlainIdentifier(scope=b,ident=):0:2:b:',
              },
            },
          },
        },
      },
      err = {
        arg = '?b:',
        msg = 'E109: Missing \':\' after \'?\': %.*s',
      },
    }, {
      hl('Identifier', 'a'),
      hl('Ternary', '?'),
      hl('IdentifierScope', 'b'),
      hl('IdentifierScopeDelimiter', ':'),
    })

    check_parsing('a?b::c', 0, {
      --           012345
      ast = {
        {
          'Ternary:0:1:?',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'TernaryValue:0:4::',
              children = {
                'PlainIdentifier(scope=b,ident=):0:2:b:',
                'PlainIdentifier(scope=0,ident=c):0:5:c',
              },
            },
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('Ternary', '?'),
      hl('IdentifierScope', 'b'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('TernaryColon', ':'),
      hl('Identifier', 'c'),
    })

    check_parsing('a?b :', 0, {
      --           01234
      ast = {
        {
          'Ternary:0:1:?',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'TernaryValue:0:3: :',
              children = {
                'PlainIdentifier(scope=0,ident=b):0:2:b',
              },
            },
          },
        },
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('Identifier', 'a'),
      hl('Ternary', '?'),
      hl('Identifier', 'b'),
      hl('TernaryColon', ':', 1),
    })

    check_parsing('(@a?@b:@c)?@d:@e', 0, {
      --           0123456789012345
      --           0         1
      ast = {
        {
          'Ternary:0:10:?',
          children = {
            {
              'Nested:0:0:(',
              children = {
                {
                  'Ternary:0:3:?',
                  children = {
                    'Register(name=a):0:1:@a',
                    {
                      'TernaryValue:0:6::',
                      children = {
                        'Register(name=b):0:4:@b',
                        'Register(name=c):0:7:@c',
                      },
                    },
                  },
                },
              },
            },
            {
              'TernaryValue:0:13::',
              children = {
                'Register(name=d):0:11:@d',
                'Register(name=e):0:14:@e',
              },
            },
          },
        },
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Register', '@a'),
      hl('Ternary', '?'),
      hl('Register', '@b'),
      hl('TernaryColon', ':'),
      hl('Register', '@c'),
      hl('NestingParenthesis', ')'),
      hl('Ternary', '?'),
      hl('Register', '@d'),
      hl('TernaryColon', ':'),
      hl('Register', '@e'),
    })

    check_parsing('(@a?@b:@c)?(@d?@e:@f):(@g?@h:@i)', 0, {
      --           01234567890123456789012345678901
      --           0         1         2         3
      ast = {
        {
          'Ternary:0:10:?',
          children = {
            {
              'Nested:0:0:(',
              children = {
                {
                  'Ternary:0:3:?',
                  children = {
                    'Register(name=a):0:1:@a',
                    {
                      'TernaryValue:0:6::',
                      children = {
                        'Register(name=b):0:4:@b',
                        'Register(name=c):0:7:@c',
                      },
                    },
                  },
                },
              },
            },
            {
              'TernaryValue:0:21::',
              children = {
                {
                  'Nested:0:11:(',
                  children = {
                    {
                      'Ternary:0:14:?',
                      children = {
                        'Register(name=d):0:12:@d',
                        {
                          'TernaryValue:0:17::',
                          children = {
                            'Register(name=e):0:15:@e',
                            'Register(name=f):0:18:@f',
                          },
                        },
                      },
                    },
                  },
                },
                {
                  'Nested:0:22:(',
                  children = {
                    {
                      'Ternary:0:25:?',
                      children = {
                        'Register(name=g):0:23:@g',
                        {
                          'TernaryValue:0:28::',
                          children = {
                            'Register(name=h):0:26:@h',
                            'Register(name=i):0:29:@i',
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Register', '@a'),
      hl('Ternary', '?'),
      hl('Register', '@b'),
      hl('TernaryColon', ':'),
      hl('Register', '@c'),
      hl('NestingParenthesis', ')'),
      hl('Ternary', '?'),
      hl('NestingParenthesis', '('),
      hl('Register', '@d'),
      hl('Ternary', '?'),
      hl('Register', '@e'),
      hl('TernaryColon', ':'),
      hl('Register', '@f'),
      hl('NestingParenthesis', ')'),
      hl('TernaryColon', ':'),
      hl('NestingParenthesis', '('),
      hl('Register', '@g'),
      hl('Ternary', '?'),
      hl('Register', '@h'),
      hl('TernaryColon', ':'),
      hl('Register', '@i'),
      hl('NestingParenthesis', ')'),
    })

    check_parsing('(@a?@b:@c)?@d?@e:@f:@g?@h:@i', 0, {
      --           0123456789012345678901234567
      --           0         1         2
      ast = {
        {
          'Ternary:0:10:?',
          children = {
            {
              'Nested:0:0:(',
              children = {
                {
                  'Ternary:0:3:?',
                  children = {
                    'Register(name=a):0:1:@a',
                    {
                      'TernaryValue:0:6::',
                      children = {
                        'Register(name=b):0:4:@b',
                        'Register(name=c):0:7:@c',
                      },
                    },
                  },
                },
              },
            },
            {
              'TernaryValue:0:19::',
              children = {
                {
                  'Ternary:0:13:?',
                  children = {
                    'Register(name=d):0:11:@d',
                    {
                      'TernaryValue:0:16::',
                      children = {
                        'Register(name=e):0:14:@e',
                        'Register(name=f):0:17:@f',
                      },
                    },
                  },
                },
                {
                  'Ternary:0:22:?',
                  children = {
                    'Register(name=g):0:20:@g',
                    {
                      'TernaryValue:0:25::',
                      children = {
                        'Register(name=h):0:23:@h',
                        'Register(name=i):0:26:@i',
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Register', '@a'),
      hl('Ternary', '?'),
      hl('Register', '@b'),
      hl('TernaryColon', ':'),
      hl('Register', '@c'),
      hl('NestingParenthesis', ')'),
      hl('Ternary', '?'),
      hl('Register', '@d'),
      hl('Ternary', '?'),
      hl('Register', '@e'),
      hl('TernaryColon', ':'),
      hl('Register', '@f'),
      hl('TernaryColon', ':'),
      hl('Register', '@g'),
      hl('Ternary', '?'),
      hl('Register', '@h'),
      hl('TernaryColon', ':'),
      hl('Register', '@i'),
    })
    check_parsing('a?b{cdef}g:h', 0, {
      --           012345678901
      --           0         1
      ast = {
        {
          'Ternary:0:1:?',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'TernaryValue:0:10::',
              children = {
                {
                  'ComplexIdentifier:0:3:',
                  children = {
                    'PlainIdentifier(scope=0,ident=b):0:2:b',
                    {
                      'ComplexIdentifier:0:9:',
                      children = {
                        {
                          'CurlyBracesIdentifier(--i):0:3:{',
                          children = {
                            'PlainIdentifier(scope=0,ident=cdef):0:4:cdef',
                          },
                        },
                        'PlainIdentifier(scope=0,ident=g):0:9:g',
                      },
                    },
                  },
                },
                'PlainIdentifier(scope=0,ident=h):0:11:h',
              },
            },
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('Ternary', '?'),
      hl('Identifier', 'b'),
      hl('Curly', '{'),
      hl('Identifier', 'cdef'),
      hl('Curly', '}'),
      hl('Identifier', 'g'),
      hl('TernaryColon', ':'),
      hl('Identifier', 'h'),
    })
    check_parsing('a ? b : c : d', 0, {
      --           0123456789012
      --           0         1
      ast = {
        {
          'Colon:0:9: :',
          children = {
            {
              'Ternary:0:1: ?',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:0:a',
                {
                  'TernaryValue:0:5: :',
                  children = {
                    'PlainIdentifier(scope=0,ident=b):0:3: b',
                    'PlainIdentifier(scope=0,ident=c):0:7: c',
                  },
                },
              },
            },
            'PlainIdentifier(scope=0,ident=d):0:11: d',
          },
        },
      },
      err = {
        arg = ': d',
        msg = 'E15: Colon outside of dictionary or ternary operator: %.*s',
      },
    }, {
      hl('Identifier', 'a'),
      hl('Ternary', '?', 1),
      hl('Identifier', 'b', 1),
      hl('TernaryColon', ':', 1),
      hl('Identifier', 'c', 1),
      hl('InvalidColon', ':', 1),
      hl('Identifier', 'd', 1),
    })
  end)
  itp('works with comparison operators', function()
    check_parsing('a == b', 0, {
      --           012345
      ast = {
        {
          'Comparison(type=Equal,inv=0,ccs=UseOption):0:1: ==',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:4: b',
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('ComparisonOperator', '==', 1),
      hl('Identifier', 'b', 1),
    })

    check_parsing('a ==? b', 0, {
      --           0123456
      ast = {
        {
          'Comparison(type=Equal,inv=0,ccs=IgnoreCase):0:1: ==?',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:5: b',
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('ComparisonOperator', '==', 1),
      hl('ComparisonOperatorModifier', '?'),
      hl('Identifier', 'b', 1),
    })

    check_parsing('a ==# b', 0, {
      --           0123456
      ast = {
        {
          'Comparison(type=Equal,inv=0,ccs=MatchCase):0:1: ==#',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:5: b',
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('ComparisonOperator', '==', 1),
      hl('ComparisonOperatorModifier', '#'),
      hl('Identifier', 'b', 1),
    })

    check_parsing('a !=# b', 0, {
      --           0123456
      ast = {
        {
          'Comparison(type=Equal,inv=1,ccs=MatchCase):0:1: !=#',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:5: b',
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('ComparisonOperator', '!=', 1),
      hl('ComparisonOperatorModifier', '#'),
      hl('Identifier', 'b', 1),
    })

    check_parsing('a <=# b', 0, {
      --           0123456
      ast = {
        {
          'Comparison(type=Greater,inv=1,ccs=MatchCase):0:1: <=#',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:5: b',
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('ComparisonOperator', '<=', 1),
      hl('ComparisonOperatorModifier', '#'),
      hl('Identifier', 'b', 1),
    })

    check_parsing('a >=# b', 0, {
      --           0123456
      ast = {
        {
          'Comparison(type=GreaterOrEqual,inv=0,ccs=MatchCase):0:1: >=#',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:5: b',
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('ComparisonOperator', '>=', 1),
      hl('ComparisonOperatorModifier', '#'),
      hl('Identifier', 'b', 1),
    })

    check_parsing('a ># b', 0, {
      --           012345
      ast = {
        {
          'Comparison(type=Greater,inv=0,ccs=MatchCase):0:1: >#',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:4: b',
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('ComparisonOperator', '>', 1),
      hl('ComparisonOperatorModifier', '#'),
      hl('Identifier', 'b', 1),
    })

    check_parsing('a <# b', 0, {
      --           012345
      ast = {
        {
          'Comparison(type=GreaterOrEqual,inv=1,ccs=MatchCase):0:1: <#',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:4: b',
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('ComparisonOperator', '<', 1),
      hl('ComparisonOperatorModifier', '#'),
      hl('Identifier', 'b', 1),
    })

    check_parsing('a is#b', 0, {
      --           012345
      ast = {
        {
          'Comparison(type=Identical,inv=0,ccs=MatchCase):0:1: is#',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:5:b',
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('ComparisonOperator', 'is', 1),
      hl('ComparisonOperatorModifier', '#'),
      hl('Identifier', 'b'),
    })

    check_parsing('a is?b', 0, {
      --           012345
      ast = {
        {
          'Comparison(type=Identical,inv=0,ccs=IgnoreCase):0:1: is?',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:5:b',
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('ComparisonOperator', 'is', 1),
      hl('ComparisonOperatorModifier', '?'),
      hl('Identifier', 'b'),
    })

    check_parsing('a isnot b', 0, {
      --           012345678
      ast = {
        {
          'Comparison(type=Identical,inv=1,ccs=UseOption):0:1: isnot',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:7: b',
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('ComparisonOperator', 'isnot', 1),
      hl('Identifier', 'b', 1),
    })

    check_parsing('a < b < c', 0, {
      --           012345678
      ast = {
        {
          'Comparison(type=GreaterOrEqual,inv=1,ccs=UseOption):0:1: <',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'Comparison(type=GreaterOrEqual,inv=1,ccs=UseOption):0:5: <',
              children = {
                'PlainIdentifier(scope=0,ident=b):0:3: b',
                'PlainIdentifier(scope=0,ident=c):0:7: c',
              },
            },
          },
        },
      },
      err = {
        arg = ' < c',
        msg = 'E15: Operator is not associative: %.*s',
      },
    }, {
      hl('Identifier', 'a'),
      hl('ComparisonOperator', '<', 1),
      hl('Identifier', 'b', 1),
      hl('InvalidComparisonOperator', '<', 1),
      hl('Identifier', 'c', 1),
    })
    check_parsing('a += b', 0, {
      --           012345
      ast = {
        {
          'Comparison(type=Equal,inv=0,ccs=UseOption):0:3:=',
          children = {
            {
              'BinaryPlus:0:1: +',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:0:a',
                'Missing:0:3:',
              },
            },
            'PlainIdentifier(scope=0,ident=b):0:4: b',
          },
        },
      },
      err = {
        arg = '= b',
        msg = 'E15: Expected == or =~: %.*s',
      },
    }, {
      hl('Identifier', 'a'),
      hl('BinaryPlus', '+', 1),
      hl('InvalidComparisonOperator', '='),
      hl('Identifier', 'b', 1),
    })
    check_parsing('a + b == c + d', 0, {
      --           01234567890123
      --           0         1
      ast = {
        {
          'Comparison(type=Equal,inv=0,ccs=UseOption):0:5: ==',
          children = {
            {
              'BinaryPlus:0:1: +',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:0:a',
                'PlainIdentifier(scope=0,ident=b):0:3: b',
              },
            },
            {
              'BinaryPlus:0:10: +',
              children = {
                'PlainIdentifier(scope=0,ident=c):0:8: c',
                'PlainIdentifier(scope=0,ident=d):0:12: d',
              },
            },
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('BinaryPlus', '+', 1),
      hl('Identifier', 'b', 1),
      hl('ComparisonOperator', '==', 1),
      hl('Identifier', 'c', 1),
      hl('BinaryPlus', '+', 1),
      hl('Identifier', 'd', 1),
    })
    check_parsing('+ a == + b', 0, {
      --           0123456789
      ast = {
        {
          'Comparison(type=Equal,inv=0,ccs=UseOption):0:3: ==',
          children = {
            {
              'UnaryPlus:0:0:+',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1: a',
              },
            },
            {
              'UnaryPlus:0:6: +',
              children = {
                'PlainIdentifier(scope=0,ident=b):0:8: b',
              },
            },
          },
        },
      },
    }, {
      hl('UnaryPlus', '+'),
      hl('Identifier', 'a', 1),
      hl('ComparisonOperator', '==', 1),
      hl('UnaryPlus', '+', 1),
      hl('Identifier', 'b', 1),
    })
  end)
  itp('works with concat/subscript', function()
    check_parsing('.', 0, {
      --           0
      ast = {
        {
          'ConcatOrSubscript:0:0:.',
          children = {
            'Missing:0:0:',
          },
        },
      },
      err = {
        arg = '.',
        msg = 'E15: Unexpected dot: %.*s',
      },
    }, {
      hl('InvalidConcatOrSubscript', '.'),
    })

    check_parsing('a.', 0, {
      --           01
      ast = {
        {
          'ConcatOrSubscript:0:1:.',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
          },
        },
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('Identifier', 'a'),
      hl('ConcatOrSubscript', '.'),
    })

    check_parsing('a.b', 0, {
      --           012
      ast = {
        {
          'ConcatOrSubscript:0:1:.',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainKey(key=b):0:2:b',
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('ConcatOrSubscript', '.'),
      hl('IdentifierKey', 'b'),
    })

    check_parsing('1.2', 0, {
      --           012
      ast = {
        'Float(val=1.200000e+00):0:0:1.2',
      },
    }, {
      hl('Float', '1.2'),
    })

    check_parsing('1.2 + 1.3e-5', 0, {
      --           012345678901
      --           0         1
      ast = {
        {
          'BinaryPlus:0:3: +',
          children = {
            'Float(val=1.200000e+00):0:0:1.2',
            'Float(val=1.300000e-05):0:5: 1.3e-5',
          },
        },
      },
    }, {
      hl('Float', '1.2'),
      hl('BinaryPlus', '+', 1),
      hl('Float', '1.3e-5', 1),
    })

    check_parsing('a . 1.2 + 1.3e-5', 0, {
      --           0123456789012345
      --           0         1
      ast = {
        {
          'BinaryPlus:0:7: +',
          children = {
            {
              'Concat:0:1: .',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:0:a',
                {
                  'ConcatOrSubscript:0:5:.',
                  children = {
                    'Integer(val=1):0:3: 1',
                    'PlainKey(key=2):0:6:2',
                  },
                },
              },
            },
            'Float(val=1.300000e-05):0:9: 1.3e-5',
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('Concat', '.', 1),
      hl('Number', '1', 1),
      hl('ConcatOrSubscript', '.'),
      hl('IdentifierKey', '2'),
      hl('BinaryPlus', '+', 1),
      hl('Float', '1.3e-5', 1),
    })

    check_parsing('1.3e-5 + 1.2 . a', 0, {
      --           0123456789012345
      --           0         1
      ast = {
        {
          'Concat:0:12: .',
          children = {
            {
              'BinaryPlus:0:6: +',
              children = {
                'Float(val=1.300000e-05):0:0:1.3e-5',
                'Float(val=1.200000e+00):0:8: 1.2',
              },
            },
            'PlainIdentifier(scope=0,ident=a):0:14: a',
          },
        },
      },
    }, {
      hl('Float', '1.3e-5'),
      hl('BinaryPlus', '+', 1),
      hl('Float', '1.2', 1),
      hl('Concat', '.', 1),
      hl('Identifier', 'a', 1),
    })

    check_parsing('1.3e-5 + a . 1.2', 0, {
      --           0123456789012345
      --           0         1
      ast = {
        {
          'Concat:0:10: .',
          children = {
            {
              'BinaryPlus:0:6: +',
              children = {
                'Float(val=1.300000e-05):0:0:1.3e-5',
                'PlainIdentifier(scope=0,ident=a):0:8: a',
              },
            },
            {
              'ConcatOrSubscript:0:14:.',
              children = {
                'Integer(val=1):0:12: 1',
                'PlainKey(key=2):0:15:2',
              },
            },
          },
        },
      },
    }, {
      hl('Float', '1.3e-5'),
      hl('BinaryPlus', '+', 1),
      hl('Identifier', 'a', 1),
      hl('Concat', '.', 1),
      hl('Number', '1', 1),
      hl('ConcatOrSubscript', '.'),
      hl('IdentifierKey', '2'),
    })

    check_parsing('1.2.3', 0, {
      --           01234
      ast = {
        {
          'ConcatOrSubscript:0:3:.',
          children = {
            {
              'ConcatOrSubscript:0:1:.',
              children = {
                'Integer(val=1):0:0:1',
                'PlainKey(key=2):0:2:2',
              },
            },
            'PlainKey(key=3):0:4:3',
          },
        },
      },
    }, {
      hl('Number', '1'),
      hl('ConcatOrSubscript', '.'),
      hl('IdentifierKey', '2'),
      hl('ConcatOrSubscript', '.'),
      hl('IdentifierKey', '3'),
    })

    check_parsing('a.1.2', 0, {
      --           01234
      ast = {
        {
          'ConcatOrSubscript:0:3:.',
          children = {
            {
              'ConcatOrSubscript:0:1:.',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:0:a',
                'PlainKey(key=1):0:2:1',
              },
            },
            'PlainKey(key=2):0:4:2',
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('ConcatOrSubscript', '.'),
      hl('IdentifierKey', '1'),
      hl('ConcatOrSubscript', '.'),
      hl('IdentifierKey', '2'),
    })

    check_parsing('a . 1.2', 0, {
      --           0123456
      ast = {
        {
          'Concat:0:1: .',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'ConcatOrSubscript:0:5:.',
              children = {
                'Integer(val=1):0:3: 1',
                'PlainKey(key=2):0:6:2',
              },
            },
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('Concat', '.', 1),
      hl('Number', '1', 1),
      hl('ConcatOrSubscript', '.'),
      hl('IdentifierKey', '2'),
    })

    check_parsing('+a . +b', 0, {
      --           0123456
      ast = {
        {
          'Concat:0:2: .',
          children = {
            {
              'UnaryPlus:0:0:+',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
              },
            },
            {
              'UnaryPlus:0:4: +',
              children = {
                'PlainIdentifier(scope=0,ident=b):0:6:b',
              },
            },
          },
        },
      },
    }, {
      hl('UnaryPlus', '+'),
      hl('Identifier', 'a'),
      hl('Concat', '.', 1),
      hl('UnaryPlus', '+', 1),
      hl('Identifier', 'b'),
    })

    check_parsing('a. b', 0, {
      --           0123
      ast = {
        {
          'Concat:0:1:.',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=0,ident=b):0:2: b',
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('ConcatOrSubscript', '.'),
      hl('Identifier', 'b', 1),
    })

    check_parsing('a. 1', 0, {
      --           0123
      ast = {
        {
          'Concat:0:1:.',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'Integer(val=1):0:2: 1',
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('ConcatOrSubscript', '.'),
      hl('Number', '1', 1),
    })
  end)
  itp('works with bracket subscripts', function()
    check_parsing(':', 0, {
      --           0
      ast = {
        {
          'Colon:0:0::',
          children = {
            'Missing:0:0:',
          },
        },
      },
      err = {
        arg = ':',
        msg = 'E15: Colon outside of dictionary or ternary operator: %.*s',
      },
    }, {
      hl('InvalidColon', ':'),
    })
    check_parsing('a[]', 0, {
      --           012
      ast = {
        {
          'Subscript:0:1:[',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
          },
        },
      },
      err = {
        arg = ']',
        msg = 'E15: Expected value, got closing bracket: %.*s',
      },
    }, {
      hl('Identifier', 'a'),
      hl('Subscript', '['),
      hl('InvalidSubscript', ']'),
    })
    check_parsing('a[b:]', 0, {
      --           01234
      ast = {
        {
          'Subscript:0:1:[',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=b,ident=):0:2:b:',
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('Subscript', '['),
      hl('IdentifierScope', 'b'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('Subscript', ']'),
    })

    check_parsing('a[b:c]', 0, {
      --           012345
      ast = {
        {
          'Subscript:0:1:[',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            'PlainIdentifier(scope=b,ident=c):0:2:b:c',
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('Subscript', '['),
      hl('IdentifierScope', 'b'),
      hl('IdentifierScopeDelimiter', ':'),
      hl('Identifier', 'c'),
      hl('Subscript', ']'),
    })
    check_parsing('a[b : c]', 0, {
      --           01234567
      ast = {
        {
          'Subscript:0:1:[',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'Colon:0:3: :',
              children = {
                'PlainIdentifier(scope=0,ident=b):0:2:b',
                'PlainIdentifier(scope=0,ident=c):0:5: c',
              },
            },
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('Subscript', '['),
      hl('Identifier', 'b'),
      hl('SubscriptColon', ':', 1),
      hl('Identifier', 'c', 1),
      hl('Subscript', ']'),
    })

    check_parsing('a[: b]', 0, {
      --           012345
      ast = {
        {
          'Subscript:0:1:[',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'Colon:0:2::',
              children = {
                'Missing:0:2:',
                'PlainIdentifier(scope=0,ident=b):0:3: b',
              },
            },
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('Subscript', '['),
      hl('SubscriptColon', ':'),
      hl('Identifier', 'b', 1),
      hl('Subscript', ']'),
    })

    check_parsing('a[b :]', 0, {
      --           012345
      ast = {
        {
          'Subscript:0:1:[',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
            {
              'Colon:0:3: :',
              children = {
                'PlainIdentifier(scope=0,ident=b):0:2:b',
              },
            },
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('Subscript', '['),
      hl('Identifier', 'b'),
      hl('SubscriptColon', ':', 1),
      hl('Subscript', ']'),
    })
    check_parsing('a[b][c][d](e)(f)(g)', 0, {
      --           0123456789012345678
      --           0         1
      ast = {
        {
          'Call:0:16:(',
          children = {
            {
              'Call:0:13:(',
              children = {
                {
                  'Call:0:10:(',
                  children = {
                    {
                      'Subscript:0:7:[',
                      children = {
                        {
                          'Subscript:0:4:[',
                          children = {
                            {
                              'Subscript:0:1:[',
                              children = {
                                'PlainIdentifier(scope=0,ident=a):0:0:a',
                                'PlainIdentifier(scope=0,ident=b):0:2:b',
                              },
                            },
                            'PlainIdentifier(scope=0,ident=c):0:5:c',
                          },
                        },
                        'PlainIdentifier(scope=0,ident=d):0:8:d',
                      },
                    },
                    'PlainIdentifier(scope=0,ident=e):0:11:e',
                  },
                },
                'PlainIdentifier(scope=0,ident=f):0:14:f',
              },
            },
            'PlainIdentifier(scope=0,ident=g):0:17:g',
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('Subscript', '['),
      hl('Identifier', 'b'),
      hl('Subscript', ']'),
      hl('Subscript', '['),
      hl('Identifier', 'c'),
      hl('Subscript', ']'),
      hl('Subscript', '['),
      hl('Identifier', 'd'),
      hl('Subscript', ']'),
      hl('CallingParenthesis', '('),
      hl('Identifier', 'e'),
      hl('CallingParenthesis', ')'),
      hl('CallingParenthesis', '('),
      hl('Identifier', 'f'),
      hl('CallingParenthesis', ')'),
      hl('CallingParenthesis', '('),
      hl('Identifier', 'g'),
      hl('CallingParenthesis', ')'),
    })
    check_parsing('{a}{b}{c}[d][e][f]', 0, {
      --           012345678901234567
      --           0         1
      ast = {
        {
          'Subscript:0:15:[',
          children = {
            {
              'Subscript:0:12:[',
              children = {
                {
                  'Subscript:0:9:[',
                  children = {
                    {
                      'ComplexIdentifier:0:3:',
                      children = {
                        {
                          'CurlyBracesIdentifier(-di):0:0:{',
                          children = {
                            'PlainIdentifier(scope=0,ident=a):0:1:a',
                          },
                        },
                        {
                          'ComplexIdentifier:0:6:',
                          children = {
                            {
                              'CurlyBracesIdentifier(--i):0:3:{',
                              children = {
                                'PlainIdentifier(scope=0,ident=b):0:4:b',
                              },
                            },
                            {
                              'CurlyBracesIdentifier(--i):0:6:{',
                              children = {
                                'PlainIdentifier(scope=0,ident=c):0:7:c',
                              },
                            },
                          },
                        },
                      },
                    },
                    'PlainIdentifier(scope=0,ident=d):0:10:d',
                  },
                },
                'PlainIdentifier(scope=0,ident=e):0:13:e',
              },
            },
            'PlainIdentifier(scope=0,ident=f):0:16:f',
          },
        },
      },
    }, {
      hl('Curly', '{'),
      hl('Identifier', 'a'),
      hl('Curly', '}'),
      hl('Curly', '{'),
      hl('Identifier', 'b'),
      hl('Curly', '}'),
      hl('Curly', '{'),
      hl('Identifier', 'c'),
      hl('Curly', '}'),
      hl('Subscript', '['),
      hl('Identifier', 'd'),
      hl('Subscript', ']'),
      hl('Subscript', '['),
      hl('Identifier', 'e'),
      hl('Subscript', ']'),
      hl('Subscript', '['),
      hl('Identifier', 'f'),
      hl('Subscript', ']'),
    })
  end)
  itp('supports list literals', function()
    check_parsing('[]', 0, {
      --           01
      ast = {
        'ListLiteral:0:0:[',
      },
    }, {
      hl('List', '['),
      hl('List', ']'),
    })

    check_parsing('[a]', 0, {
      --           012
      ast = {
        {
          'ListLiteral:0:0:[',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:1:a',
          },
        },
      },
    }, {
      hl('List', '['),
      hl('Identifier', 'a'),
      hl('List', ']'),
    })

    check_parsing('[a, b]', 0, {
      --           012345
      ast = {
        {
          'ListLiteral:0:0:[',
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                'PlainIdentifier(scope=0,ident=b):0:3: b',
              },
            },
          },
        },
      },
    }, {
      hl('List', '['),
      hl('Identifier', 'a'),
      hl('Comma', ','),
      hl('Identifier', 'b', 1),
      hl('List', ']'),
    })

    check_parsing('[a, b, c]', 0, {
      --           012345678
      ast = {
        {
          'ListLiteral:0:0:[',
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                {
                  'Comma:0:5:,',
                  children = {
                    'PlainIdentifier(scope=0,ident=b):0:3: b',
                    'PlainIdentifier(scope=0,ident=c):0:6: c',
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('List', '['),
      hl('Identifier', 'a'),
      hl('Comma', ','),
      hl('Identifier', 'b', 1),
      hl('Comma', ','),
      hl('Identifier', 'c', 1),
      hl('List', ']'),
    })

    check_parsing('[a, b, c, ]', 0, {
      --           01234567890
      --           0         1
      ast = {
        {
          'ListLiteral:0:0:[',
          children = {
            {
              'Comma:0:2:,',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                {
                  'Comma:0:5:,',
                  children = {
                    'PlainIdentifier(scope=0,ident=b):0:3: b',
                    {
                      'Comma:0:8:,',
                      children = {
                        'PlainIdentifier(scope=0,ident=c):0:6: c',
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    }, {
      hl('List', '['),
      hl('Identifier', 'a'),
      hl('Comma', ','),
      hl('Identifier', 'b', 1),
      hl('Comma', ','),
      hl('Identifier', 'c', 1),
      hl('Comma', ','),
      hl('List', ']', 1),
    })

    check_parsing('[a : b, c : d]', 0, {
      --           01234567890123
      --           0         1
      ast = {
        {
          'ListLiteral:0:0:[',
          children = {
            {
              'Comma:0:6:,',
              children = {
                {
                  'Colon:0:2: :',
                  children = {
                    'PlainIdentifier(scope=0,ident=a):0:1:a',
                    'PlainIdentifier(scope=0,ident=b):0:4: b',
                  },
                },
                {
                  'Colon:0:9: :',
                  children = {
                    'PlainIdentifier(scope=0,ident=c):0:7: c',
                    'PlainIdentifier(scope=0,ident=d):0:11: d',
                  },
                },
              },
            },
          },
        },
      },
      err = {
        arg = ': b, c : d]',
        msg = 'E15: Colon outside of dictionary or ternary operator: %.*s',
      },
    }, {
      hl('List', '['),
      hl('Identifier', 'a'),
      hl('InvalidColon', ':', 1),
      hl('Identifier', 'b', 1),
      hl('Comma', ','),
      hl('Identifier', 'c', 1),
      hl('InvalidColon', ':', 1),
      hl('Identifier', 'd', 1),
      hl('List', ']'),
    })

    check_parsing(']', 0, {
      --           0
      ast = {
        'ListLiteral:0:0:',
      },
      err = {
        arg = ']',
        msg = 'E15: Unexpected closing figure brace: %.*s',
      },
    }, {
      hl('InvalidList', ']'),
    })

    check_parsing('a]', 0, {
      --           01
      ast = {
        {
          'ListLiteral:0:1:',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
          },
        },
      },
      err = {
        arg = ']',
        msg = 'E15: Unexpected closing figure brace: %.*s',
      },
    }, {
      hl('Identifier', 'a'),
      hl('InvalidList', ']'),
    })

    check_parsing('[] []', 0, {
      --           01234
      ast = {
        {
          'OpMissing:0:2:',
          children = {
            'ListLiteral:0:0:[',
            'ListLiteral:0:2: [',
          },
        },
      },
      err = {
        arg = '[]',
        msg = 'E15: Missing operator: %.*s',
      },
    }, {
      hl('List', '['),
      hl('List', ']'),
      hl('InvalidSpacing', ' '),
      hl('List', '['),
      hl('List', ']'),
    })

    check_parsing('[][]', 0, {
      --           0123
      ast = {
        {
          'Subscript:0:2:[',
          children = {
            'ListLiteral:0:0:[',
          },
        },
      },
      err = {
        arg = ']',
        msg = 'E15: Expected value, got closing bracket: %.*s',
      },
    }, {
      hl('List', '['),
      hl('List', ']'),
      hl('Subscript', '['),
      hl('InvalidSubscript', ']'),
    })

    check_parsing('[', 0, {
      --           0
      ast = {
        'ListLiteral:0:0:[',
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('List', '['),
    })

    check_parsing('[1', 0, {
      --           01
      ast = {
        {
          'ListLiteral:0:0:[',
          children = {
            'Integer(val=1):0:1:1',
          },
        },
      },
      err = {
        arg = '[1',
        msg = 'E697: Missing end of List \']\': %.*s',
      },
    }, {
      hl('List', '['),
      hl('Number', '1'),
    })
  end)
  itp('works with strings', function()
    check_parsing('\'abc\'', 0, {
      --           01234
      ast = {
        'SingleQuotedString(val="abc"):0:0:\'abc\'',
      },
    }, {
      hl('SingleQuotedString', '\''),
      hl('SingleQuotedBody', 'abc'),
      hl('SingleQuotedString', '\''),
    })
    check_parsing('"abc"', 0, {
      --           01234
      ast = {
        'DoubleQuotedString(val="abc"):0:0:"abc"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedBody', 'abc'),
      hl('DoubleQuotedString', '"'),
    })
    check_parsing('\'\'', 0, {
      --           01
      ast = {
        'SingleQuotedString(val=NULL):0:0:\'\'',
      },
    }, {
      hl('SingleQuotedString', '\''),
      hl('SingleQuotedString', '\''),
    })
    check_parsing('""', 0, {
      --           01
      ast = {
        'DoubleQuotedString(val=NULL):0:0:""',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedString', '"'),
    })
    check_parsing('"', 0, {
      --           0
      ast = {
        'DoubleQuotedString(val=NULL):0:0:"',
      },
      err = {
        arg = '"',
        msg = 'E114: Missing double quote: %.*s',
      },
    }, {
      hl('InvalidDoubleQuotedString', '"'),
    })
    check_parsing('\'', 0, {
      --           0
      ast = {
        'SingleQuotedString(val=NULL):0:0:\'',
      },
      err = {
        arg = '\'',
        msg = 'E115: Missing single quote: %.*s',
      },
    }, {
      hl('InvalidSingleQuotedString', '\''),
    })
    check_parsing('"a', 0, {
      --           01
      ast = {
        'DoubleQuotedString(val="a"):0:0:"a',
      },
      err = {
        arg = '"a',
        msg = 'E114: Missing double quote: %.*s',
      },
    }, {
      hl('InvalidDoubleQuotedString', '"'),
      hl('InvalidDoubleQuotedBody', 'a'),
    })
    check_parsing('\'a', 0, {
      --           01
      ast = {
        'SingleQuotedString(val="a"):0:0:\'a',
      },
      err = {
        arg = '\'a',
        msg = 'E115: Missing single quote: %.*s',
      },
    }, {
      hl('InvalidSingleQuotedString', '\''),
      hl('InvalidSingleQuotedBody', 'a'),
    })
    check_parsing('\'abc\'\'def\'', 0, {
      --           0123456789
      ast = {
        'SingleQuotedString(val="abc\'def"):0:0:\'abc\'\'def\'',
      },
    }, {
      hl('SingleQuotedString', '\''),
      hl('SingleQuotedBody', 'abc'),
      hl('SingleQuotedQuote', '\'\''),
      hl('SingleQuotedBody', 'def'),
      hl('SingleQuotedString', '\''),
    })
    check_parsing('\'abc\'\'', 0, {
      --           012345
      ast = {
        'SingleQuotedString(val="abc\'"):0:0:\'abc\'\'',
      },
      err = {
        arg = '\'abc\'\'',
        msg = 'E115: Missing single quote: %.*s',
      },
    }, {
      hl('InvalidSingleQuotedString', '\''),
      hl('InvalidSingleQuotedBody', 'abc'),
      hl('InvalidSingleQuotedQuote', '\'\''),
    })
    check_parsing('\'\'\'\'\'\'\'\'', 0, {
      --           01234567
      ast = {
        'SingleQuotedString(val="\'\'\'"):0:0:\'\'\'\'\'\'\'\'',
      },
    }, {
      hl('SingleQuotedString', '\''),
      hl('SingleQuotedQuote', '\'\''),
      hl('SingleQuotedQuote', '\'\''),
      hl('SingleQuotedQuote', '\'\''),
      hl('SingleQuotedString', '\''),
    })
    check_parsing('\'\'\'a\'\'\'\'bc\'', 0, {
      --           01234567890
      --           0         1
      ast = {
        'SingleQuotedString(val="\'a\'\'bc"):0:0:\'\'\'a\'\'\'\'bc\'',
      },
    }, {
      hl('SingleQuotedString', '\''),
      hl('SingleQuotedQuote', '\'\''),
      hl('SingleQuotedBody', 'a'),
      hl('SingleQuotedQuote', '\'\''),
      hl('SingleQuotedQuote', '\'\''),
      hl('SingleQuotedBody', 'bc'),
      hl('SingleQuotedString', '\''),
    })
    check_parsing('"\\"\\"\\"\\""', 0, {
      --           0123456789
      ast = {
        'DoubleQuotedString(val="\\"\\"\\"\\""):0:0:"\\"\\"\\"\\""',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\"'),
      hl('DoubleQuotedEscape', '\\"'),
      hl('DoubleQuotedEscape', '\\"'),
      hl('DoubleQuotedEscape', '\\"'),
      hl('DoubleQuotedString', '"'),
    })
    check_parsing('"abc\\"def\\"ghi\\"jkl\\"mno"', 0, {
      --           0123456789012345678901234
      --           0         1         2
      ast = {
        'DoubleQuotedString(val="abc\\"def\\"ghi\\"jkl\\"mno"):0:0:"abc\\"def\\"ghi\\"jkl\\"mno"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedBody', 'abc'),
      hl('DoubleQuotedEscape', '\\"'),
      hl('DoubleQuotedBody', 'def'),
      hl('DoubleQuotedEscape', '\\"'),
      hl('DoubleQuotedBody', 'ghi'),
      hl('DoubleQuotedEscape', '\\"'),
      hl('DoubleQuotedBody', 'jkl'),
      hl('DoubleQuotedEscape', '\\"'),
      hl('DoubleQuotedBody', 'mno'),
      hl('DoubleQuotedString', '"'),
    })
    check_parsing('"\\b\\e\\f\\r\\t\\\\"', 0, {
      --           0123456789012345
      --           0         1
      ast = {
        [[DoubleQuotedString(val="\8\27\12\13\9\\"):0:0:"\b\e\f\r\t\\"]],
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\b'),
      hl('DoubleQuotedEscape', '\\e'),
      hl('DoubleQuotedEscape', '\\f'),
      hl('DoubleQuotedEscape', '\\r'),
      hl('DoubleQuotedEscape', '\\t'),
      hl('DoubleQuotedEscape', '\\\\'),
      hl('DoubleQuotedString', '"'),
    })
    check_parsing('"\\n\n"', 0, {
      --           01234
      ast = {
        'DoubleQuotedString(val="\\\n\\\n"):0:0:"\\n\n"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\n'),
      hl('DoubleQuotedBody', '\n'),
      hl('DoubleQuotedString', '"'),
    })
    check_parsing('"\\x00"', 0, {
      --           012345
      ast = {
        'DoubleQuotedString(val="\\0"):0:0:"\\x00"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\x00'),
      hl('DoubleQuotedString', '"'),
    })
    check_parsing('"\\xFF"', 0, {
      --           012345
      ast = {
        'DoubleQuotedString(val="\255"):0:0:"\\xFF"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\xFF'),
      hl('DoubleQuotedString', '"'),
    })
    check_parsing('"\\xF"', 0, {
      --           012345
      ast = {
        'DoubleQuotedString(val="\\15"):0:0:"\\xF"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\xF'),
      hl('DoubleQuotedString', '"'),
    })
    check_parsing('"\\u00AB"', 0, {
      --           01234567
      ast = {
        'DoubleQuotedString(val="«"):0:0:"\\u00AB"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\u00AB'),
      hl('DoubleQuotedString', '"'),
    })
    check_parsing('"\\U000000AB"', 0, {
      --           01234567
      ast = {
        'DoubleQuotedString(val="«"):0:0:"\\U000000AB"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\U000000AB'),
      hl('DoubleQuotedString', '"'),
    })
    check_parsing('"\\x"', 0, {
      --           0123
      ast = {
        'DoubleQuotedString(val="x"):0:0:"\\x"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedUnknownEscape', '\\x'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\x', 0, {
      --           012
      ast = {
        'DoubleQuotedString(val="x"):0:0:"\\x',
      },
      err = {
        arg = '"\\x',
        msg = 'E114: Missing double quote: %.*s',
      },
    }, {
      hl('InvalidDoubleQuotedString', '"'),
      hl('InvalidDoubleQuotedUnknownEscape', '\\x'),
    })

    check_parsing('"\\xF', 0, {
      --           0123
      ast = {
        'DoubleQuotedString(val="\\15"):0:0:"\\xF',
      },
      err = {
        arg = '"\\xF',
        msg = 'E114: Missing double quote: %.*s',
      },
    }, {
      hl('InvalidDoubleQuotedString', '"'),
      hl('InvalidDoubleQuotedEscape', '\\xF'),
    })

    check_parsing('"\\u"', 0, {
      --           0123
      ast = {
        'DoubleQuotedString(val="u"):0:0:"\\u"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedUnknownEscape', '\\u'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\u', 0, {
      --           012
      ast = {
        'DoubleQuotedString(val="u"):0:0:"\\u',
      },
      err = {
        arg = '"\\u',
        msg = 'E114: Missing double quote: %.*s',
      },
    }, {
      hl('InvalidDoubleQuotedString', '"'),
      hl('InvalidDoubleQuotedUnknownEscape', '\\u'),
    })

    check_parsing('"\\U', 0, {
      --           012
      ast = {
        'DoubleQuotedString(val="U"):0:0:"\\U',
      },
      err = {
        arg = '"\\U',
        msg = 'E114: Missing double quote: %.*s',
      },
    }, {
      hl('InvalidDoubleQuotedString', '"'),
      hl('InvalidDoubleQuotedUnknownEscape', '\\U'),
    })

    check_parsing('"\\U"', 0, {
      --           0123
      ast = {
        'DoubleQuotedString(val="U"):0:0:"\\U"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedUnknownEscape', '\\U'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\xFX"', 0, {
      --           012345
      ast = {
        'DoubleQuotedString(val="\\15X"):0:0:"\\xFX"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\xF'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\XFX"', 0, {
      --           012345
      ast = {
        'DoubleQuotedString(val="\\15X"):0:0:"\\XFX"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\XF'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\xX"', 0, {
      --           01234
      ast = {
        'DoubleQuotedString(val="xX"):0:0:"\\xX"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedUnknownEscape', '\\x'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\XX"', 0, {
      --           01234
      ast = {
        'DoubleQuotedString(val="XX"):0:0:"\\XX"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedUnknownEscape', '\\X'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\uX"', 0, {
      --           01234
      ast = {
        'DoubleQuotedString(val="uX"):0:0:"\\uX"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedUnknownEscape', '\\u'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\UX"', 0, {
      --           01234
      ast = {
        'DoubleQuotedString(val="UX"):0:0:"\\UX"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedUnknownEscape', '\\U'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\x0X"', 0, {
      --           012345
      ast = {
        'DoubleQuotedString(val="\\0X"):0:0:"\\x0X"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\x0'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\X0X"', 0, {
      --           012345
      ast = {
        'DoubleQuotedString(val="\\0X"):0:0:"\\X0X"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\X0'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\u0X"', 0, {
      --           012345
      ast = {
        'DoubleQuotedString(val="\\0X"):0:0:"\\u0X"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\u0'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\U0X"', 0, {
      --           012345
      ast = {
        'DoubleQuotedString(val="\\0X"):0:0:"\\U0X"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\U0'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\x00X"', 0, {
      --           0123456
      ast = {
        'DoubleQuotedString(val="\\0X"):0:0:"\\x00X"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\x00'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\X00X"', 0, {
      --           0123456
      ast = {
        'DoubleQuotedString(val="\\0X"):0:0:"\\X00X"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\X00'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\u00X"', 0, {
      --           0123456
      ast = {
        'DoubleQuotedString(val="\\0X"):0:0:"\\u00X"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\u00'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\U00X"', 0, {
      --           0123456
      ast = {
        'DoubleQuotedString(val="\\0X"):0:0:"\\U00X"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\U00'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\u000X"', 0, {
      --           01234567
      ast = {
        'DoubleQuotedString(val="\\0X"):0:0:"\\u000X"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\u000'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\U000X"', 0, {
      --           01234567
      ast = {
        'DoubleQuotedString(val="\\0X"):0:0:"\\U000X"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\U000'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\u0000X"', 0, {
      --           012345678
      ast = {
        'DoubleQuotedString(val="\\0X"):0:0:"\\u0000X"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\u0000'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\U0000X"', 0, {
      --           012345678
      ast = {
        'DoubleQuotedString(val="\\0X"):0:0:"\\U0000X"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\U0000'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\U00000X"', 0, {
      --           0123456789
      ast = {
        'DoubleQuotedString(val="\\0X"):0:0:"\\U00000X"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\U00000'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\U000000X"', 0, {
      --           01234567890
      --           0         1
      ast = {
        'DoubleQuotedString(val="\\0X"):0:0:"\\U000000X"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\U000000'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\U0000000X"', 0, {
      --           012345678901
      --           0         1
      ast = {
        'DoubleQuotedString(val="\\0X"):0:0:"\\U0000000X"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\U0000000'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\U00000000X"', 0, {
      --           0123456789012
      --           0         1
      ast = {
        'DoubleQuotedString(val="\\0X"):0:0:"\\U00000000X"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\U00000000'),
      hl('DoubleQuotedBody', 'X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\x000X"', 0, {
      --           01234567
      ast = {
        'DoubleQuotedString(val="\\0000X"):0:0:"\\x000X"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\x00'),
      hl('DoubleQuotedBody', '0X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\X000X"', 0, {
      --           01234567
      ast = {
        'DoubleQuotedString(val="\\0000X"):0:0:"\\X000X"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\X00'),
      hl('DoubleQuotedBody', '0X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\u00000X"', 0, {
      --           0123456789
      ast = {
        'DoubleQuotedString(val="\\0000X"):0:0:"\\u00000X"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\u0000'),
      hl('DoubleQuotedBody', '0X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\U000000000X"', 0, {
      --           01234567890123
      --           0         1
      ast = {
        'DoubleQuotedString(val="\\0000X"):0:0:"\\U000000000X"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\U00000000'),
      hl('DoubleQuotedBody', '0X'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\0"', 0, {
      --           0123
      ast = {
        'DoubleQuotedString(val="\\0"):0:0:"\\0"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\0'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\00"', 0, {
      --           01234
      ast = {
        'DoubleQuotedString(val="\\0"):0:0:"\\00"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\00'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\000"', 0, {
      --           012345
      ast = {
        'DoubleQuotedString(val="\\0"):0:0:"\\000"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\000'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\0000"', 0, {
      --           0123456
      ast = {
        'DoubleQuotedString(val="\\0000"):0:0:"\\0000"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\000'),
      hl('DoubleQuotedBody', '0'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\8"', 0, {
      --           0123
      ast = {
        'DoubleQuotedString(val="8"):0:0:"\\8"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedUnknownEscape', '\\8'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\08"', 0, {
      --           01234
      ast = {
        'DoubleQuotedString(val="\\0008"):0:0:"\\08"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\0'),
      hl('DoubleQuotedBody', '8'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\008"', 0, {
      --           012345
      ast = {
        'DoubleQuotedString(val="\\0008"):0:0:"\\008"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\00'),
      hl('DoubleQuotedBody', '8'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\0008"', 0, {
      --           0123456
      ast = {
        'DoubleQuotedString(val="\\0008"):0:0:"\\0008"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\000'),
      hl('DoubleQuotedBody', '8'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\777"', 0, {
      --           012345
      ast = {
        'DoubleQuotedString(val="\255"):0:0:"\\777"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\777'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\050"', 0, {
      --           012345
      ast = {
        'DoubleQuotedString(val="\40"):0:0:"\\050"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\050'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\<C-u>"', 0, {
      --           012345
      ast = {
        'DoubleQuotedString(val="\\21"):0:0:"\\<C-u>"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\<C-u>'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\<', 0, {
      --           012
      ast = {
        'DoubleQuotedString(val="<"):0:0:"\\<',
      },
      err = {
        arg = '"\\<',
        msg = 'E114: Missing double quote: %.*s',
      },
    }, {
      hl('InvalidDoubleQuotedString', '"'),
      hl('InvalidDoubleQuotedUnknownEscape', '\\<'),
    })

    check_parsing('"\\<"', 0, {
      --           0123
      ast = {
        'DoubleQuotedString(val="<"):0:0:"\\<"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedUnknownEscape', '\\<'),
      hl('DoubleQuotedString', '"'),
    })

    check_parsing('"\\<C-u"', 0, {
      --           0123456
      ast = {
        'DoubleQuotedString(val="<C-u"):0:0:"\\<C-u"',
      },
    }, {
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedUnknownEscape', '\\<'),
      hl('DoubleQuotedBody', 'C-u'),
      hl('DoubleQuotedString', '"'),
    })
  end)
  itp('works with multiplication-like operators', function()
    check_parsing('2+2*2', 0, {
      --           01234
      ast = {
        {
          'BinaryPlus:0:1:+',
          children = {
            'Integer(val=2):0:0:2',
            {
              'Multiplication:0:3:*',
              children = {
                'Integer(val=2):0:2:2',
                'Integer(val=2):0:4:2',
              },
            },
          },
        },
      },
    }, {
      hl('Number', '2'),
      hl('BinaryPlus', '+'),
      hl('Number', '2'),
      hl('Multiplication', '*'),
      hl('Number', '2'),
    })

    check_parsing('2+2*', 0, {
      --           0123
      ast = {
        {
          'BinaryPlus:0:1:+',
          children = {
            'Integer(val=2):0:0:2',
            {
              'Multiplication:0:3:*',
              children = {
                'Integer(val=2):0:2:2',
              },
            },
          },
        },
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('Number', '2'),
      hl('BinaryPlus', '+'),
      hl('Number', '2'),
      hl('Multiplication', '*'),
    })

    check_parsing('2+*2', 0, {
      --           0123
      ast = {
        {
          'BinaryPlus:0:1:+',
          children = {
            'Integer(val=2):0:0:2',
            {
              'Multiplication:0:2:*',
              children = {
                'Missing:0:2:',
                'Integer(val=2):0:3:2',
              },
            },
          },
        },
      },
      err = {
        arg = '*2',
        msg = 'E15: Unexpected multiplication-like operator: %.*s',
      },
    }, {
      hl('Number', '2'),
      hl('BinaryPlus', '+'),
      hl('InvalidMultiplication', '*'),
      hl('Number', '2'),
    })

    check_parsing('2+2/2', 0, {
      --           01234
      ast = {
        {
          'BinaryPlus:0:1:+',
          children = {
            'Integer(val=2):0:0:2',
            {
              'Division:0:3:/',
              children = {
                'Integer(val=2):0:2:2',
                'Integer(val=2):0:4:2',
              },
            },
          },
        },
      },
    }, {
      hl('Number', '2'),
      hl('BinaryPlus', '+'),
      hl('Number', '2'),
      hl('Division', '/'),
      hl('Number', '2'),
    })

    check_parsing('2+2/', 0, {
      --           0123
      ast = {
        {
          'BinaryPlus:0:1:+',
          children = {
            'Integer(val=2):0:0:2',
            {
              'Division:0:3:/',
              children = {
                'Integer(val=2):0:2:2',
              },
            },
          },
        },
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('Number', '2'),
      hl('BinaryPlus', '+'),
      hl('Number', '2'),
      hl('Division', '/'),
    })

    check_parsing('2+/2', 0, {
      --           0123
      ast = {
        {
          'BinaryPlus:0:1:+',
          children = {
            'Integer(val=2):0:0:2',
            {
              'Division:0:2:/',
              children = {
                'Missing:0:2:',
                'Integer(val=2):0:3:2',
              },
            },
          },
        },
      },
      err = {
        arg = '/2',
        msg = 'E15: Unexpected multiplication-like operator: %.*s',
      },
    }, {
      hl('Number', '2'),
      hl('BinaryPlus', '+'),
      hl('InvalidDivision', '/'),
      hl('Number', '2'),
    })

    check_parsing('2+2%2', 0, {
      --           01234
      ast = {
        {
          'BinaryPlus:0:1:+',
          children = {
            'Integer(val=2):0:0:2',
            {
              'Mod:0:3:%',
              children = {
                'Integer(val=2):0:2:2',
                'Integer(val=2):0:4:2',
              },
            },
          },
        },
      },
    }, {
      hl('Number', '2'),
      hl('BinaryPlus', '+'),
      hl('Number', '2'),
      hl('Mod', '%'),
      hl('Number', '2'),
    })

    check_parsing('2+2%', 0, {
      --           0123
      ast = {
        {
          'BinaryPlus:0:1:+',
          children = {
            'Integer(val=2):0:0:2',
            {
              'Mod:0:3:%',
              children = {
                'Integer(val=2):0:2:2',
              },
            },
          },
        },
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('Number', '2'),
      hl('BinaryPlus', '+'),
      hl('Number', '2'),
      hl('Mod', '%'),
    })

    check_parsing('2+%2', 0, {
      --           0123
      ast = {
        {
          'BinaryPlus:0:1:+',
          children = {
            'Integer(val=2):0:0:2',
            {
              'Mod:0:2:%',
              children = {
                'Missing:0:2:',
                'Integer(val=2):0:3:2',
              },
            },
          },
        },
      },
      err = {
        arg = '%2',
        msg = 'E15: Unexpected multiplication-like operator: %.*s',
      },
    }, {
      hl('Number', '2'),
      hl('BinaryPlus', '+'),
      hl('InvalidMod', '%'),
      hl('Number', '2'),
    })
  end)
  itp('works with -', function()
    check_parsing('@a', 0, {
      ast = {
        'Register(name=a):0:0:@a',
      },
    }, {
      hl('Register', '@a'),
    })
    check_parsing('-@a', 0, {
      ast = {
        {
          'UnaryMinus:0:0:-',
          children = {
            'Register(name=a):0:1:@a',
          },
        },
      },
    }, {
      hl('UnaryMinus', '-'),
      hl('Register', '@a'),
    })
    check_parsing('@a-@b', 0, {
      ast = {
        {
          'BinaryMinus:0:2:-',
          children = {
            'Register(name=a):0:0:@a',
            'Register(name=b):0:3:@b',
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('BinaryMinus', '-'),
      hl('Register', '@b'),
    })
    check_parsing('@a-@b-@c', 0, {
      ast = {
        {
          'BinaryMinus:0:5:-',
          children = {
            {
              'BinaryMinus:0:2:-',
              children = {
                'Register(name=a):0:0:@a',
                'Register(name=b):0:3:@b',
              },
            },
            'Register(name=c):0:6:@c',
          },
        },
      },
    }, {
      hl('Register', '@a'),
      hl('BinaryMinus', '-'),
      hl('Register', '@b'),
      hl('BinaryMinus', '-'),
      hl('Register', '@c'),
    })
    check_parsing('-@a-@b', 0, {
      ast = {
        {
          'BinaryMinus:0:3:-',
          children = {
            {
              'UnaryMinus:0:0:-',
              children = {
                'Register(name=a):0:1:@a',
              },
            },
            'Register(name=b):0:4:@b',
          },
        },
      },
    }, {
      hl('UnaryMinus', '-'),
      hl('Register', '@a'),
      hl('BinaryMinus', '-'),
      hl('Register', '@b'),
    })
    check_parsing('-@a--@b', 0, {
      ast = {
        {
          'BinaryMinus:0:3:-',
          children = {
            {
              'UnaryMinus:0:0:-',
              children = {
                'Register(name=a):0:1:@a',
              },
            },
            {
              'UnaryMinus:0:4:-',
              children = {
                'Register(name=b):0:5:@b',
              },
            },
          },
        },
      },
    }, {
      hl('UnaryMinus', '-'),
      hl('Register', '@a'),
      hl('BinaryMinus', '-'),
      hl('UnaryMinus', '-'),
      hl('Register', '@b'),
    })
    check_parsing('@a@b', 0, {
      ast = {
        {
          'OpMissing:0:2:',
          children = {
            'Register(name=a):0:0:@a',
            'Register(name=b):0:2:@b',
          },
        },
      },
      err = {
        arg = '@b',
        msg = 'E15: Missing operator: %.*s',
      },
    }, {
      hl('Register', '@a'),
      hl('InvalidRegister', '@b'),
    })
    check_parsing(' @a \t @b', 0, {
      ast = {
        {
          'OpMissing:0:3:',
          children = {
            'Register(name=a):0:0: @a',
            'Register(name=b):0:3: \t @b',
          },
        },
      },
      err = {
        arg = '@b',
        msg = 'E15: Missing operator: %.*s',
      },
    }, {
      hl('Register', '@a', 1),
      hl('InvalidSpacing', ' \t '),
      hl('Register', '@b'),
    })
    check_parsing('-', 0, {
      ast = {
        'UnaryMinus:0:0:-',
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('UnaryMinus', '-'),
    })
    check_parsing(' -', 0, {
      ast = {
        'UnaryMinus:0:0: -',
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('UnaryMinus', '-', 1),
    })
    check_parsing('@a-  ', 0, {
      ast = {
        {
          'BinaryMinus:0:2:-',
          children = {
            'Register(name=a):0:0:@a',
          },
        },
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('Register', '@a'),
      hl('BinaryMinus', '-'),
    })
  end)
  itp('works with logical operators', function()
    check_parsing('a && b || c && d', 0, {
      --           0123456789012345
      --           0         1
      ast = {
        {
          'Or:0:6: ||',
          children = {
            {
              'And:0:1: &&',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:0:a',
                'PlainIdentifier(scope=0,ident=b):0:4: b',
              },
            },
            {
              'And:0:11: &&',
              children = {
                'PlainIdentifier(scope=0,ident=c):0:9: c',
                'PlainIdentifier(scope=0,ident=d):0:14: d',
              },
            },
          },
        },
      },
    }, {
      hl('Identifier', 'a'),
      hl('And', '&&', 1),
      hl('Identifier', 'b', 1),
      hl('Or', '||', 1),
      hl('Identifier', 'c', 1),
      hl('And', '&&', 1),
      hl('Identifier', 'd', 1),
    })

    check_parsing('&& a', 0, {
      --           0123
      ast = {
        {
          'And:0:0:&&',
          children = {
            'Missing:0:0:',
            'PlainIdentifier(scope=0,ident=a):0:2: a',
          },
        },
      },
      err = {
        arg = '&& a',
        msg = 'E15: Unexpected and operator: %.*s',
      },
    }, {
      hl('InvalidAnd', '&&'),
      hl('Identifier', 'a', 1),
    })

    check_parsing('|| a', 0, {
      --           0123
      ast = {
        {
          'Or:0:0:||',
          children = {
            'Missing:0:0:',
            'PlainIdentifier(scope=0,ident=a):0:2: a',
          },
        },
      },
      err = {
        arg = '|| a',
        msg = 'E15: Unexpected or operator: %.*s',
      },
    }, {
      hl('InvalidOr', '||'),
      hl('Identifier', 'a', 1),
    })

    check_parsing('a||', 0, {
      --           012
      ast = {
        {
          'Or:0:1:||',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
          },
        },
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('Identifier', 'a'),
      hl('Or', '||'),
    })

    check_parsing('a&&', 0, {
      --           012
      ast = {
        {
          'And:0:1:&&',
          children = {
            'PlainIdentifier(scope=0,ident=a):0:0:a',
          },
        },
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('Identifier', 'a'),
      hl('And', '&&'),
    })

    check_parsing('(&&)', 0, {
      --           0123
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'And:0:1:&&',
              children = {
                'Missing:0:1:',
                'Missing:0:3:',
              },
            },
          },
        },
      },
      err = {
        arg = '&&)',
        msg = 'E15: Unexpected and operator: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('InvalidAnd', '&&'),
      hl('InvalidNestingParenthesis', ')'),
    })

    check_parsing('(||)', 0, {
      --           0123
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'Or:0:1:||',
              children = {
                'Missing:0:1:',
                'Missing:0:3:',
              },
            },
          },
        },
      },
      err = {
        arg = '||)',
        msg = 'E15: Unexpected or operator: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('InvalidOr', '||'),
      hl('InvalidNestingParenthesis', ')'),
    })

    check_parsing('(a||)', 0, {
      --           01234
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'Or:0:2:||',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                'Missing:0:4:',
              },
            },
          },
        },
      },
      err = {
        arg = ')',
        msg = 'E15: Expected value, got parenthesis: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Identifier', 'a'),
      hl('Or', '||'),
      hl('InvalidNestingParenthesis', ')'),
    })

    check_parsing('(a&&)', 0, {
      --           01234
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'And:0:2:&&',
              children = {
                'PlainIdentifier(scope=0,ident=a):0:1:a',
                'Missing:0:4:',
              },
            },
          },
        },
      },
      err = {
        arg = ')',
        msg = 'E15: Expected value, got parenthesis: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Identifier', 'a'),
      hl('And', '&&'),
      hl('InvalidNestingParenthesis', ')'),
    })

    check_parsing('(&&a)', 0, {
      --           01234
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'And:0:1:&&',
              children = {
                'Missing:0:1:',
                'PlainIdentifier(scope=0,ident=a):0:3:a',
              },
            },
          },
        },
      },
      err = {
        arg = '&&a)',
        msg = 'E15: Unexpected and operator: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('InvalidAnd', '&&'),
      hl('Identifier', 'a'),
      hl('NestingParenthesis', ')'),
    })

    check_parsing('(||a)', 0, {
      --           01234
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'Or:0:1:||',
              children = {
                'Missing:0:1:',
                'PlainIdentifier(scope=0,ident=a):0:3:a',
              },
            },
          },
        },
      },
      err = {
        arg = '||a)',
        msg = 'E15: Unexpected or operator: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('InvalidOr', '||'),
      hl('Identifier', 'a'),
      hl('NestingParenthesis', ')'),
    })
  end)
  itp('works with &opt', function()
    check_parsing('&', 0, {
      --           0
      ast = {
        'Option(scope=0,ident=):0:0:&',
      },
      err = {
        arg = '&',
        msg = 'E112: Option name missing: %.*s',
      },
    }, {
      hl('InvalidOptionSigil', '&'),
    })

    check_parsing('&opt', 0, {
      --           0123
      ast = {
        'Option(scope=0,ident=opt):0:0:&opt',
      },
    }, {
      hl('OptionSigil', '&'),
      hl('Option', 'opt'),
    })

    check_parsing('&l:opt', 0, {
      --           012345
      ast = {
        'Option(scope=l,ident=opt):0:0:&l:opt',
      },
    }, {
      hl('OptionSigil', '&'),
      hl('OptionScope', 'l'),
      hl('OptionScopeDelimiter', ':'),
      hl('Option', 'opt'),
    })

    check_parsing('&g:opt', 0, {
      --           012345
      ast = {
        'Option(scope=g,ident=opt):0:0:&g:opt',
      },
    }, {
      hl('OptionSigil', '&'),
      hl('OptionScope', 'g'),
      hl('OptionScopeDelimiter', ':'),
      hl('Option', 'opt'),
    })

    check_parsing('&s:opt', 0, {
      --           012345
      ast = {
        {
          'Colon:0:2::',
          children = {
            'Option(scope=0,ident=s):0:0:&s',
            'PlainIdentifier(scope=0,ident=opt):0:3:opt',
          },
        },
      },
      err = {
        arg = ':opt',
        msg = 'E15: Colon outside of dictionary or ternary operator: %.*s',
      },
    }, {
      hl('OptionSigil', '&'),
      hl('Option', 's'),
      hl('InvalidColon', ':'),
      hl('Identifier', 'opt'),
    })

    check_parsing('& ', 0, {
      --           01
      ast = {
        'Option(scope=0,ident=):0:0:&',
      },
      err = {
        arg = '& ',
        msg = 'E112: Option name missing: %.*s',
      },
    }, {
      hl('InvalidOptionSigil', '&'),
    })

    check_parsing('&-', 0, {
      --           01
      ast = {
        {
          'BinaryMinus:0:1:-',
          children = {
            'Option(scope=0,ident=):0:0:&',
          },
        },
      },
      err = {
        arg = '&-',
        msg = 'E112: Option name missing: %.*s',
      },
    }, {
      hl('InvalidOptionSigil', '&'),
      hl('BinaryMinus', '-'),
    })

    check_parsing('&A', 0, {
      --           01
      ast = {
        'Option(scope=0,ident=A):0:0:&A',
      },
    }, {
      hl('OptionSigil', '&'),
      hl('Option', 'A'),
    })

    check_parsing('&xxx_yyy', 0, {
      --           01234567
      ast = {
        {
          'OpMissing:0:4:',
          children = {
            'Option(scope=0,ident=xxx):0:0:&xxx',
            'PlainIdentifier(scope=0,ident=_yyy):0:4:_yyy',
          },
        },
      },
      err = {
        arg = '_yyy',
        msg = 'E15: Missing operator: %.*s',
      },
    }, {
      hl('OptionSigil', '&'),
      hl('Option', 'xxx'),
      hl('InvalidIdentifier', '_yyy'),
    })

    check_parsing('(1+&)', 0, {
      --           01234
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'BinaryPlus:0:2:+',
              children = {
                'Integer(val=1):0:1:1',
                'Option(scope=0,ident=):0:3:&',
              },
            },
          },
        },
      },
      err = {
        arg = '&)',
        msg = 'E112: Option name missing: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Number', '1'),
      hl('BinaryPlus', '+'),
      hl('InvalidOptionSigil', '&'),
      hl('NestingParenthesis', ')'),
    })

    check_parsing('(&+1)', 0, {
      --           01234
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'BinaryPlus:0:2:+',
              children = {
                'Option(scope=0,ident=):0:1:&',
                'Integer(val=1):0:3:1',
              },
            },
          },
        },
      },
      err = {
        arg = '&+1)',
        msg = 'E112: Option name missing: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('InvalidOptionSigil', '&'),
      hl('BinaryPlus', '+'),
      hl('Number', '1'),
      hl('NestingParenthesis', ')'),
    })
  end)
  itp('works with $ENV', function()
    check_parsing('$', 0, {
      --           0
      ast = {
        'Environment(ident=):0:0:$',
      },
      err = {
        arg = '$',
        msg = 'E15: Environment variable name missing',
      },
    }, {
      hl('InvalidEnvironmentSigil', '$'),
    })

    check_parsing('$g:A', 0, {
      --           0123
      ast = {
        {
          'Colon:0:2::',
          children = {
            'Environment(ident=g):0:0:$g',
            'PlainIdentifier(scope=0,ident=A):0:3:A',
          },
        },
      },
      err = {
        arg = ':A',
        msg = 'E15: Colon outside of dictionary or ternary operator: %.*s',
      },
    }, {
      hl('EnvironmentSigil', '$'),
      hl('Environment', 'g'),
      hl('InvalidColon', ':'),
      hl('Identifier', 'A'),
    })

    check_parsing('$A', 0, {
      --           01
      ast = {
        'Environment(ident=A):0:0:$A',
      },
    }, {
      hl('EnvironmentSigil', '$'),
      hl('Environment', 'A'),
    })

    check_parsing('$ABC', 0, {
      --           0123
      ast = {
        'Environment(ident=ABC):0:0:$ABC',
      },
    }, {
      hl('EnvironmentSigil', '$'),
      hl('Environment', 'ABC'),
    })

    check_parsing('(1+$)', 0, {
      --           01234
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'BinaryPlus:0:2:+',
              children = {
                'Integer(val=1):0:1:1',
                'Environment(ident=):0:3:$',
              },
            },
          },
        },
      },
      err = {
        arg = '$)',
        msg = 'E15: Environment variable name missing',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Number', '1'),
      hl('BinaryPlus', '+'),
      hl('InvalidEnvironmentSigil', '$'),
      hl('NestingParenthesis', ')'),
    })

    check_parsing('($+1)', 0, {
      --           01234
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'BinaryPlus:0:2:+',
              children = {
                'Environment(ident=):0:1:$',
                'Integer(val=1):0:3:1',
              },
            },
          },
        },
      },
      err = {
        arg = '$+1)',
        msg = 'E15: Environment variable name missing',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('InvalidEnvironmentSigil', '$'),
      hl('BinaryPlus', '+'),
      hl('Number', '1'),
      hl('NestingParenthesis', ')'),
    })

    check_parsing('$_ABC', 0, {
      --           01234
      ast = {
        'Environment(ident=_ABC):0:0:$_ABC',
      },
    }, {
      hl('EnvironmentSigil', '$'),
      hl('Environment', '_ABC'),
    })

    check_parsing('$_', 0, {
      --           01
      ast = {
        'Environment(ident=_):0:0:$_',
      },
    }, {
      hl('EnvironmentSigil', '$'),
      hl('Environment', '_'),
    })

    check_parsing('$ABC_DEF', 0, {
      --           01234567
      ast = {
        'Environment(ident=ABC_DEF):0:0:$ABC_DEF',
      },
    }, {
      hl('EnvironmentSigil', '$'),
      hl('Environment', 'ABC_DEF'),
    })
  end)
  itp('works with unary !', function()
    check_parsing('!', 0, {
      --           0
      ast = {
        'Not:0:0:!',
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('Not', '!'),
    })

    check_parsing('!!', 0, {
      --           01
      ast = {
        {
          'Not:0:0:!',
          children = {
            'Not:0:1:!',
          },
        },
      },
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
      hl('Not', '!'),
      hl('Not', '!'),
    })

    check_parsing('!!1', 0, {
      --           012
      ast = {
        {
          'Not:0:0:!',
          children = {
            {
              'Not:0:1:!',
              children = {
                'Integer(val=1):0:2:1',
              },
            },
          },
        },
      },
    }, {
      hl('Not', '!'),
      hl('Not', '!'),
      hl('Number', '1'),
    })

    check_parsing('!1', 0, {
      --           01
      ast = {
        {
          'Not:0:0:!',
          children = {
            'Integer(val=1):0:1:1',
          },
        },
      },
    }, {
      hl('Not', '!'),
      hl('Number', '1'),
    })

    check_parsing('(!1)', 0, {
      --           0123
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'Not:0:1:!',
              children = {
                'Integer(val=1):0:2:1',
              },
            },
          },
        },
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Not', '!'),
      hl('Number', '1'),
      hl('NestingParenthesis', ')'),
    })

    check_parsing('(!)', 0, {
      --           012
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'Not:0:1:!',
              children = {
                'Missing:0:2:',
              },
            },
          },
        },
      },
      err = {
        arg = ')',
        msg = 'E15: Expected value, got parenthesis: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Not', '!'),
      hl('InvalidNestingParenthesis', ')'),
    })

    check_parsing('(1!2)', 0, {
      --           01234
      ast = {
        {
          'Nested:0:0:(',
          children = {
            {
              'OpMissing:0:2:',
              children = {
                'Integer(val=1):0:1:1',
                {
                  'Not:0:2:!',
                  children = {
                    'Integer(val=2):0:3:2',
                  },
                },
              },
            },
          },
        },
      },
      err = {
        arg = '!2)',
        msg = 'E15: Missing operator: %.*s',
      },
    }, {
      hl('NestingParenthesis', '('),
      hl('Number', '1'),
      hl('InvalidNot', '!'),
      hl('Number', '2'),
      hl('NestingParenthesis', ')'),
    })

    check_parsing('1!2', 0, {
      --           012
      ast = {
        {
          'OpMissing:0:1:',
          children = {
            'Integer(val=1):0:0:1',
            {
              'Not:0:1:!',
              children = {
                'Integer(val=2):0:2:2',
              },
            },
          },
        },
      },
      err = {
        arg = '!2',
        msg = 'E15: Missing operator: %.*s',
      },
    }, {
      hl('Number', '1'),
      hl('InvalidNot', '!'),
      hl('Number', '2'),
    })
  end)
  itp('highlights numbers with prefix', function()
    check_parsing('0xABCDEF', 0, {
      --           01234567
      ast = {
        'Integer(val=11259375):0:0:0xABCDEF',
      },
    }, {
      hl('NumberPrefix', '0x'),
      hl('Number', 'ABCDEF'),
    })

    check_parsing('0Xabcdef', 0, {
      --           01234567
      ast = {
        'Integer(val=11259375):0:0:0Xabcdef',
      },
    }, {
      hl('NumberPrefix', '0X'),
      hl('Number', 'abcdef'),
    })

    check_parsing('0XABCDEF', 0, {
      --           01234567
      ast = {
        'Integer(val=11259375):0:0:0XABCDEF',
      },
    }, {
      hl('NumberPrefix', '0X'),
      hl('Number', 'ABCDEF'),
    })

    check_parsing('0xabcdef', 0, {
      --           01234567
      ast = {
        'Integer(val=11259375):0:0:0xabcdef',
      },
    }, {
      hl('NumberPrefix', '0x'),
      hl('Number', 'abcdef'),
    })

    check_parsing('0b001', 0, {
      --           01234
      ast = {
        'Integer(val=1):0:0:0b001',
      },
    }, {
      hl('NumberPrefix', '0b'),
      hl('Number', '001'),
    })

    check_parsing('0B001', 0, {
      --           01234
      ast = {
        'Integer(val=1):0:0:0B001',
      },
    }, {
      hl('NumberPrefix', '0B'),
      hl('Number', '001'),
    })

    check_parsing('0B00', 0, {
      --           0123
      ast = {
        'Integer(val=0):0:0:0B00',
      },
    }, {
      hl('NumberPrefix', '0B'),
      hl('Number', '00'),
    })

    check_parsing('00', 0, {
      --           01
      ast = {
        'Integer(val=0):0:0:00',
      },
    }, {
      hl('NumberPrefix', '0'),
      hl('Number', '0'),
    })

    check_parsing('001', 0, {
      --           012
      ast = {
        'Integer(val=1):0:0:001',
      },
    }, {
      hl('NumberPrefix', '0'),
      hl('Number', '01'),
    })

    check_parsing('01', 0, {
      --           01
      ast = {
        'Integer(val=1):0:0:01',
      },
    }, {
      hl('NumberPrefix', '0'),
      hl('Number', '1'),
    })

    check_parsing('1', 0, {
      --           0
      ast = {
        'Integer(val=1):0:0:1',
      },
    }, {
      hl('Number', '1'),
    })
  end)
  itp('works (KLEE tests)', function()
    check_parsing('\0002&A:\000', 0, {
      ast = nil,
      err = {
        arg = '',
        msg = 'E15: Expected value, got EOC: %.*s',
      },
    }, {
    })
    check_parsing({data='01', size=1}, 0, {
      ast = {
        'Integer(val=0):0:0:0',
      },
    }, {
      hl('Number', '0'),
    })
    check_parsing({data='001', size=2}, 0, {
      ast = {
        'Integer(val=0):0:0:00',
      },
    }, {
      hl('NumberPrefix', '0'),
      hl('Number', '0'),
    })
    check_parsing('"\\U\\', 0, {
      --           0123
      ast = {
        [[DoubleQuotedString(val="U\\"):0:0:"\U\]],
      },
      err = {
        arg = '"\\U\\',
        msg = 'E114: Missing double quote: %.*s',
      },
    }, {
      hl('InvalidDoubleQuotedString', '"'),
      hl('InvalidDoubleQuotedUnknownEscape', '\\U'),
      hl('InvalidDoubleQuotedBody', '\\'),
    })
    check_parsing('"\\U', 0, {
      --           012
      ast = {
        'DoubleQuotedString(val="U"):0:0:"\\U',
      },
      err = {
        arg = '"\\U',
        msg = 'E114: Missing double quote: %.*s',
      },
    }, {
      hl('InvalidDoubleQuotedString', '"'),
      hl('InvalidDoubleQuotedUnknownEscape', '\\U'),
    })
    check_parsing('|"\\U\\', 2, {
      --           01234
      ast = {
        {
          'Or:0:0:|',
          children = {
            'Missing:0:0:',
            'DoubleQuotedString(val="U\\\\"):0:1:"\\U\\',
          },
        },
      },
      err = {
        arg = '|"\\U\\',
        msg = 'E15: Unexpected EOC character: %.*s',
      },
    }, {
      hl('InvalidOr', '|'),
      hl('InvalidDoubleQuotedString', '"'),
      hl('InvalidDoubleQuotedUnknownEscape', '\\U'),
      hl('InvalidDoubleQuotedBody', '\\'),
    })
    check_parsing('|"\\e"', 2, {
      --           01234
      ast = {
        {
          'Or:0:0:|',
          children = {
            'Missing:0:0:',
            'DoubleQuotedString(val="\\27"):0:1:"\\e"',
          },
        },
      },
      err = {
        arg = '|"\\e"',
        msg = 'E15: Unexpected EOC character: %.*s',
      },
    }, {
      hl('InvalidOr', '|'),
      hl('DoubleQuotedString', '"'),
      hl('DoubleQuotedEscape', '\\e'),
      hl('DoubleQuotedString', '"'),
    })
    check_parsing('|\029', 2, {
      --           01
      ast = {
        {
          'Or:0:0:|',
          children = {
            'Missing:0:0:',
            'PlainIdentifier(scope=0,ident=\029):0:1:\029',
          },
        },
      },
      err = {
        arg = '|\029',
        msg = 'E15: Unexpected EOC character: %.*s',
      },
    }, {
      hl('InvalidOr', '|'),
      hl('InvalidIdentifier', '\029'),
    })
    check_parsing('"\\<', 0, {
      --           012
      ast = {
        'DoubleQuotedString(val="<"):0:0:"\\<',
      },
      err = {
        arg = '"\\<',
        msg = 'E114: Missing double quote: %.*s',
      },
    }, {
      hl('InvalidDoubleQuotedString', '"'),
      hl('InvalidDoubleQuotedUnknownEscape', '\\<'),
    })
    check_parsing('"\\1', 0, {
      --           012
      ast = {
        'DoubleQuotedString(val="\\1"):0:0:"\\1',
      },
      err = {
        arg = '"\\1',
        msg = 'E114: Missing double quote: %.*s',
      },
    }, {
      hl('InvalidDoubleQuotedString', '"'),
      hl('InvalidDoubleQuotedEscape', '\\1'),
    })
    check_parsing('}l', 0, {
      --           01
      ast = {
        {
          'OpMissing:0:1:',
          children = {
            'UnknownFigure(---):0:0:',
            'PlainIdentifier(scope=0,ident=l):0:1:l',
          },
        },
      },
      err = {
        arg = '}l',
        msg = 'E15: Unexpected closing figure brace: %.*s',
      },
    }, {
      hl('InvalidFigureBrace', '}'),
      hl('InvalidIdentifier', 'l'),
    })
    check_parsing(':?\000\000\000\000\000\000\000', 0, {
      ast = {
        {
          'Colon:0:0::',
          children = {
            'Missing:0:0:',
            {
              'Ternary:0:1:?',
              children = {
                'Missing:0:1:',
                'TernaryValue:0:1:?',
              },
            },
          },
        },
      },
      err = {
        arg = ':?',
        msg = 'E15: Colon outside of dictionary or ternary operator: %.*s',
      },
    }, {
      hl('InvalidColon', ':'),
      hl('InvalidTernary', '?'),
    })
  end)
end)
