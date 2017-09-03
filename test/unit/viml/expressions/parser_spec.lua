local helpers = require('test.unit.helpers')(after_each)
local viml_helpers = require('test.unit.viml.helpers')
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

local lib = cimport('./src/nvim/viml/parser/expressions.h')

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
      arg = ('%u:%s'):format(
        tonumber(east.err.arg_len),
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
  itp('works', function()
    local function check_parsing(str, flags, exp_ast, exp_highlighting_fs)
      local pstate = new_pstate({str})
      local east = lib.viml_pexpr_parse(pstate, flags)
      local ast = east2lua(pstate, east)
      eq(exp_ast, ast)
      if exp_highlighting_fs then
        local exp_highlighting = {}
        local next_col = 0
        for i, h in ipairs(exp_highlighting_fs) do
          exp_highlighting[i], next_col = h(next_col)
        end
        eq(exp_highlighting, phl2lua(pstate))
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
        arg = '2:@b',
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
        arg = '2:@b',
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
        arg = '0:',
        msg = 'E15: Expected value: %.*s',
      },
    }, {
      hl('UnaryPlus', '+'),
    })
    check_parsing(' +', 0, {
      ast = {
        'UnaryPlus:0:0: +',
      },
      err = {
        arg = '0:',
        msg = 'E15: Expected value: %.*s',
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
        arg = '0:',
        msg = 'E15: Expected value: %.*s',
      },
    }, {
      hl('Register', '@a'),
      hl('BinaryPlus', '+'),
    })
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
        arg = '1:)',
        msg = 'E15: Expected value: %.*s',
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
        arg = '1:)',
        msg = 'E15: Expected value: %.*s',
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
        arg = '1:)',
        msg = 'E15: Expected value: %.*s',
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
        arg = '2:()',
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
        arg = '1:)',
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
        arg = '3:(@a',
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
        arg = '3:(@b',
        msg = 'E116: Missing closing parenthesis for function call: %.*s',
      },
    }, {
      hl('Register', '@a'),
      hl('CallingParenthesis', '('),
      hl('Register', '@b'),
    })
  end)
end)
