local helpers = require('test.unit.helpers')(after_each)
local global_helpers = require('test.helpers')
local itp = helpers.gen_itp(it)
local viml_helpers = require('test.unit.viml.helpers')

local make_enum_conv_tab = helpers.make_enum_conv_tab
local child_call_once = helpers.child_call_once
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
    flags = flags or 0

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
  end)
end)
