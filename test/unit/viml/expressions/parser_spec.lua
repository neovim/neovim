local helpers = require('test.unit.helpers')(after_each)
local viml_helpers = require('test.unit.viml.helpers')
local global_helpers = require('test.helpers')
local itp = helpers.gen_itp(it)

local make_enum_conv_tab = helpers.make_enum_conv_tab
local child_call_once = helpers.child_call_once
local conv_enum = helpers.conv_enum
local ptr2key = helpers.ptr2key
local cimport = helpers.cimport
local ffi = helpers.ffi
local eq = helpers.eq

local pline2lua = viml_helpers.pline2lua
local new_pstate = viml_helpers.new_pstate
local intchar2lua = viml_helpers.intchar2lua
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
  'kExprNodeRegister',
  'kExprNodeSubscript',
  'kExprNodeListLiteral',
  'kExprNodeUnaryPlus',
  'kExprNodeBinaryPlus',
  'kExprNodeNested',
  'kExprNodeCall',
  'kExprNodePlainIdentifier',
  'kExprNodeComplexIdentifier',
  'kExprNodeUnknownFigure',
  'kExprNodeLambda',
  'kExprNodeDictLiteral',
  'kExprNodeCurlyBracesIdentifier',
  'kExprNodeComma',
  'kExprNodeColon',
  'kExprNodeArrow',
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
  elseif (typ == 'UnknownFigure' or typ == 'DictLiteral'
          or typ == 'CurlyBracesIdentifier' or typ == 'Lambda') then
    typ = typ .. ('(%s)'):format(
      (eastnode.data.fig.type_guesses.allow_lambda and '\\' or '-')
      .. (eastnode.data.fig.type_guesses.allow_dict and 'd' or '-')
      .. (eastnode.data.fig.type_guesses.allow_ident and 'i' or '-'))
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
    err = (not east.correct) and {
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
  local function check_parsing(str, flags, exp_ast, exp_highlighting_fs,
                               print_exp)
    local pstate = new_pstate({str})
    local east = lib.viml_pexpr_parse(pstate, flags)
    local ast = east2lua(pstate, east)
    local hls = phl2lua(pstate)
    if print_exp then
      format_check(str, flags, ast, hls)
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
  end)
  -- FIXME: Test sequence of arrows inside and outside lambdas.
  -- FIXME: Test autoload character and scope in lambda arguments.
end)
