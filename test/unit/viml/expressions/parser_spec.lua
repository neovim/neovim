local helpers = require('test.unit.helpers')(after_each)
local global_helpers = require('test.helpers')
local itp = helpers.gen_itp(it)
local viml_helpers = require('test.unit.viml.helpers')

local make_enum_conv_tab = helpers.make_enum_conv_tab
local child_call_once = helpers.child_call_once
local alloc_log_new = helpers.alloc_log_new
local kvi_destroy = helpers.kvi_destroy
local conv_enum = helpers.conv_enum
local debug_log = helpers.debug_log
local ptr2key = helpers.ptr2key
local cimport = helpers.cimport
local ffi = helpers.ffi
local neq = helpers.neq
local eq = helpers.eq

local conv_ccs = viml_helpers.conv_ccs
local new_pstate = viml_helpers.new_pstate
local conv_cmp_type = viml_helpers.conv_cmp_type
local pstate_set_str = viml_helpers.pstate_set_str
local conv_expr_asgn_type = viml_helpers.conv_expr_asgn_type

local mergedicts_copy = global_helpers.mergedicts_copy
local format_string = global_helpers.format_string
local format_luav = global_helpers.format_luav
local intchar2lua = global_helpers.intchar2lua
local dictdiff = global_helpers.dictdiff

local lib = cimport('./src/nvim/viml/parser/expressions.h',
                    './src/nvim/syntax.h')

local alloc_log = alloc_log_new()

local predefined_hl_defs = {
  -- From highlight_init_both
  Conceal=true,
  Cursor=true,
  lCursor=true,
  DiffText=true,
  ErrorMsg=true,
  IncSearch=true,
  ModeMsg=true,
  NonText=true,
  PmenuSbar=true,
  StatusLine=true,
  StatusLineNC=true,
  TabLineFill=true,
  TabLineSel=true,
  TermCursor=true,
  VertSplit=true,
  WildMenu=true,
  EndOfBuffer=true,
  QuickFixLine=true,
  Substitute=true,
  Whitespace=true,

  -- From highlight_init_(dark|light)
  ColorColumn=true,
  CursorColumn=true,
  CursorLine=true,
  CursorLineNr=true,
  DiffAdd=true,
  DiffChange=true,
  DiffDelete=true,
  Directory=true,
  FoldColumn=true,
  Folded=true,
  LineNr=true,
  MatchParen=true,
  MoreMsg=true,
  Pmenu=true,
  PmenuSel=true,
  PmenuThumb=true,
  Question=true,
  Search=true,
  SignColumn=true,
  SpecialKey=true,
  SpellBad=true,
  SpellCap=true,
  SpellLocal=true,
  SpellRare=true,
  TabLine=true,
  Title=true,
  Visual=true,
  WarningMsg=true,
  Normal=true,

  -- From syncolor.vim, if &background
  Comment=true,
  Constant=true,
  Special=true,
  Identifier=true,
  Statement=true,
  PreProc=true,
  Type=true,
  Underlined=true,
  Ignore=true,

  -- From syncolor.vim, below if &background
  Error=true,
  Todo=true,

  -- From syncolor.vim, links at the bottom
  String=true,
  Character=true,
  Number=true,
  Boolean=true,
  Float=true,
  Function=true,
  Conditional=true,
  Repeat=true,
  Label=true,
  Operator=true,
  Keyword=true,
  Exception=true,
  Include=true,
  Define=true,
  Macro=true,
  PreCondit=true,
  StorageClass=true,
  Structure=true,
  Typedef=true,
  Tag=true,
  SpecialChar=true,
  Delimiter=true,
  SpecialComment=true,
  Debug=true,
}

local nvim_hl_defs = {}

child_call_once(function()
  local i = 0
  while lib.highlight_init_cmdline[i] ~= nil do
    local hl_args = lib.highlight_init_cmdline[i]
    local s = ffi.string(hl_args)
    local err, msg = pcall(function()
      if s:sub(1, 13) == 'default link ' then
        local new_grp, grp_link = s:match('^default link (%w+) (%w+)$')
        neq(nil, new_grp)
        -- Note: group to link to must be already defined at the time of
        --       linking, otherwise it will be created as cleared. So existence
        --       of the group is checked here and not in the next pass over
        --       nvim_hl_defs.
        eq(true, not not (nvim_hl_defs[grp_link]
                          or predefined_hl_defs[grp_link]))
        eq(false, not not (nvim_hl_defs[new_grp]
                           or predefined_hl_defs[new_grp]))
        nvim_hl_defs[new_grp] = {'link', grp_link}
      else
        local new_grp, grp_args = s:match('^(%w+) (.*)')
        neq(nil, new_grp)
        eq(false, not not (nvim_hl_defs[new_grp]
                           or predefined_hl_defs[new_grp]))
        nvim_hl_defs[new_grp] = {'definition', grp_args}
      end
    end)
    if not err then
      msg = format_string(
        'Error while processing string %s at position %u:\n%s', s, i, msg)
      error(msg)
    end
    i = i + 1
  end
  for k, _ in ipairs(nvim_hl_defs) do
    eq('Nvim', k:sub(1, 4))
    -- NvimInvalid
    -- 12345678901
    local err, msg = pcall(function()
      if k:sub(5, 11) == 'Invalid' then
        neq(nil, nvim_hl_defs['Nvim' .. k:sub(12)])
      else
        neq(nil, nvim_hl_defs['NvimInvalid' .. k:sub(5)])
      end
    end)
    if not err then
      msg = format_string('Error while processing group %s:\n%s', k, msg)
      error(msg)
    end
  end
end)

local function hls_to_hl_fs(hls)
  local ret = {}
  local next_col = 0
  for i, v in ipairs(hls) do
    local group, line, col, str = v:match('^Nvim([a-zA-Z]+):(%d+):(%d+):(.*)$')
    col = tonumber(col)
    line = tonumber(line)
    assert(line == 0)
    local col_shift = col - next_col
    assert(col_shift >= 0)
    next_col = col + #str
    ret[i] = format_string('hl(%r, %r%s)',
                           group,
                           str,
                           (col_shift == 0
                            and ''
                            or (', %u'):format(col_shift)))
  end
  return ret
end

local function format_check(expr, format_check_data, opts)
  -- That forces specific order.
  local zflags = opts.flags[1]
  local zdata = format_check_data[zflags]
  local dig_len
  if opts.funcname then
    print(format_string('\n%s(%r, {', opts.funcname, expr))
    dig_len = #opts.funcname + 2
  else
    print(format_string('\n_check_parsing(%r, %r, {', opts, expr))
    dig_len = #('_check_parsing(, \'') + #(format_string('%r', opts))
  end
  local digits = '  --' .. (' '):rep(dig_len - #('  --'))
  local digits2 = digits:sub(1, -10)
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
  if zdata.ast.len then
    print(('  len = %u,'):format(zdata.ast.len))
  end
  print('  ast = ' .. format_luav(zdata.ast.ast, '  ') .. ',')
  if zdata.ast.err then
    print('  err = {')
    print('    arg = ' .. format_luav(zdata.ast.err.arg) .. ',')
    print('    msg = ' .. format_luav(zdata.ast.err.msg) .. ',')
    print('  },')
  end
  print('}, {')
  for _, v in ipairs(zdata.hl_fs) do
    print('  ' .. v .. ',')
  end
  local diffs = {}
  local diffs_num = 0
  for flags, v in pairs(format_check_data) do
    if flags ~= zflags then
      diffs[flags] = dictdiff(zdata, v)
      if diffs[flags] then
        if flags == 3 + zflags then
          if (dictdiff(format_check_data[1 + zflags],
                       format_check_data[3 + zflags]) == nil
              or dictdiff(format_check_data[2 + zflags],
                          format_check_data[3 + zflags]) == nil)
          then
            diffs[flags] = nil
          else
            diffs_num = diffs_num + 1
          end
        else
          diffs_num = diffs_num + 1
        end
      end
    end
  end
  if diffs_num ~= 0 then
    print('}, {')
    local flags = 1
    while diffs_num ~= 0 do
      if diffs[flags] then
        diffs_num = diffs_num - 1
        local diff = diffs[flags]
        print(('  [%u] = {'):format(flags))
        if diff.ast then
          print('    ast = ' .. format_luav(diff.ast, '    ') .. ',')
        end
        if diff.hl_fs then
          print('    hl_fs = ' .. format_luav(diff.hl_fs, '    ', {
            literal_strings=true
          }) .. ',')
        end
        print('  },')
      end
      flags = flags + 1
    end
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
  'kExprNodeAssignment',
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
    typ = typ .. format_string('(val=%e)', tonumber(eastnode.data.flt.value))
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
  elseif typ == 'Assignment' then
    typ = ('%s(%s)'):format(typ, conv_expr_asgn_type(eastnode.data.ass.type))
  end
  ret_str = typ .. ':' .. ret_str
  local can_simplify = not ret.children
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

local function east2lua(str, pstate, east)
  local checked_nodes = {}
  local len = tonumber(pstate.pos.col)
  if pstate.pos.line == 1 then
    len = tonumber(pstate.reader.lines.items[0].size)
  end
  if type(str) == 'string' and len == #str then
    len = nil
  end
  return {
    err = east.err.msg ~= nil and {
      msg = ffi.string(east.err.msg),
      arg = ffi.string(east.err.arg, east.err.arg_len),
    } or nil,
    len = len,
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
    ret[i + 1] = ('%s:%u:%u:%s'):format(
      chunk_tbl.group,
      chunk_tbl.start.line,
      chunk_tbl.start.col,
      chunk_tbl.str)
  end
  return ret
end

child_call_once(function()
  assert:set_parameter('TableFormatLevel', 1000000)
end)

describe('Expressions parser', function()
  local function _check_parsing(opts, str, exp_ast, exp_highlighting_fs,
                                nz_flags_exps)
    local zflags = opts.flags[1]
    nz_flags_exps = nz_flags_exps or {}
    local format_check_data = {}
    for _, flags in ipairs(opts.flags) do
      debug_log(('Running test case (%s, %u)'):format(str, flags))
      local err, msg = pcall(function()
        if os.getenv('NVIM_TEST_PARSER_SPEC_PRINT_TEST_CASE') == '1' then
          print(str, flags)
        end
        alloc_log:check({})

        local pstate = new_pstate({str})
        local east = lib.viml_pexpr_parse(pstate, flags)
        local ast = east2lua(str, pstate, east)
        local hls = phl2lua(pstate)
        if exp_ast == nil then
          format_check_data[flags] = {ast=ast, hl_fs=hls_to_hl_fs(hls)}
        else
          local exps = {
            ast = exp_ast,
            hl_fs = exp_highlighting_fs,
          }
          local add_exps = nz_flags_exps[flags]
          if not add_exps and flags == 3 + zflags then
            add_exps = nz_flags_exps[1 + zflags] or nz_flags_exps[2 + zflags]
          end
          if add_exps then
            if add_exps.ast then
              exps.ast = mergedicts_copy(exps.ast, add_exps.ast)
            end
            if add_exps.hl_fs then
              exps.hl_fs = mergedicts_copy(exps.hl_fs, add_exps.hl_fs)
            end
          end
          eq(exps.ast, ast)
          if exp_highlighting_fs then
            local exp_highlighting = {}
            local next_col = 0
            for i, h in ipairs(exps.hl_fs) do
              exp_highlighting[i], next_col = h(next_col)
            end
            eq(exp_highlighting, hls)
          end
        end
        lib.viml_pexpr_free_ast(east)
        kvi_destroy(pstate.colors)
        alloc_log:clear_tmp_allocs(true)
        alloc_log:check({})
      end)
      if not err then
        msg = format_string('Error while processing test (%r, %u):\n%s',
                            str, flags, msg)
        error(msg)
      end
    end
    if exp_ast == nil then
      format_check(str, format_check_data, opts)
    end
  end
  local function hl(group, str, shift)
    return function(next_col)
      if nvim_hl_defs['Nvim' .. group] == nil then
        error(('Unknown group: Nvim%s'):format(group))
      end
      local col = next_col + (shift or 0)
      return (('%s:%u:%u:%s'):format(
        'Nvim' .. group,
        0,
        col,
        str)), (col + #str)
    end
  end
  local function fmtn(typ, args, rest)
    return ('%s(%s)%s'):format(typ, args, rest)
  end
  require('test.unit.viml.expressions.parser_tests')(
      itp, _check_parsing, hl, fmtn)
end)
