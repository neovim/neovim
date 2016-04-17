-- {{{1 Record existing globals for testing
local copy_table = function(tbl)
  local new_tbl = {}
  for k, v in pairs(tbl) do
    new_tbl[k] = v
  end
  return new_tbl
end

local globals_at_start = copy_table(_G)
local recorded_vim_global = nil

-- {{{1 Global declarations
local err
local op
local vim_type
local is_func, is_dict, is_list, is_float
local repr
local iter
local scalar, container
local number, string, list, dict, float, func
local bound_func
local scope, def_scope, b_scope, a_scope, v_scope, f_scope
local state, assign
local subscript
local scope_name_idx, length_idx, type_idx, locks_idx, val_idx
local BASE_TYPE_NUMBER, BASE_TYPE_STRING, BASE_TYPE_FUNCREF, BASE_TYPE_LIST
local BASE_TYPE_DICTIONARY, BASE_TYPE_FLOAT
local get_number, get_float, get_string, get_boolean
local get_cmp_t
-- {{{1 Utility functions
local unpack = unpack or table.unpack

local get_local_option = function(state, other, name)
  return other.options[name] or state.options[name]
end

local non_nil = function(wrapped)
  return function(state, ...)
    for i = 1,select('#', ...) do
      if select(i, ...) == nil then
        return nil
      end
    end
    return wrapped(state, ...)
  end
end

local join_tables = function(tbl1, tbl2)
  local ret = {}
  for k, v in pairs(tbl1) do
    ret[k] = v
  end
  for k, v in pairs(tbl2) do
    ret[k] = v
  end
  return ret
end

local print_table
print_table = function(tbl, indent, printed)
  for k, v in pairs(tbl) do
    print(('%s%-20s: %s'):format(indent, tostring(k), tostring(v)))
    if type(v) == 'table' and not printed[v] then
      printed[v] = true
      print_table(v, indent .. '  ', printed)
    end
  end
end

local compare_tables_recursive
compare_tables_recursive = function(tbl1, tbl2)
  for k, _ in pairs(tbl1) do
    if tbl2[k] == nil then
      return true, 'missing2', k
    end
  end
  for k, v in pairs(tbl2) do
    if tbl1[k] == nil then
      return true, 'missing1', k
    end
    if tbl1[k] ~= v then
      if type(v) == 'table' then
        if type(tbl1[k]) ~= 'table' then
          return true, 'differs', k
        else
          local differs, what, key, diff = compare_tables_recursive(tbl1[k], v)
          if differs then
            return true, what, tostring(k) .. '/' .. tostring(key), diff
          end
        end
      else
        return true, 'differs', k, (tostring(tbl1[k]) .. '~=' .. tostring(v))
      end
    end
  end
  return false, nil, nil
end

-- {{{1 State manipulations
local new_script_scope = function(state)
  return scope:new(state, 's')
end

local top

state = {
  new = function()
    local state = {
      -- values that need to be altered when entering/exiting some scopes
      is_trying = false,
      abort = false,
      is_silent = false,
      a = nil,
      l = nil,
      sid = nil,
      current_scope = nil,
      call_stack = {},
      exception = '',
      throwpoint = '',
      code = nil,
      fname = nil,
    }
    -- Values that do not need to be altered when exiting scope.
    state.global = {
      options = {},
      buffer = {b = b_scope:new(state), options = {}},
      window = {w = scope:new(state, 'w'), options = {}},
      tabpage = {t = scope:new(state, 't')},
      registers = {},
      v = v_scope:new(state),
      g = def_scope:new(state, 'g'),
      user_functions = f_scope:new(state),
      user_commands = {},
    }
    state.current_scope = state.global.g
    return state
  end,

  get_top = function()
    if top == nil then
      top = state:new()
    end
    return top
  end,

  enter_try = function(old_state)
    local state = copy_table(old_state)
    state.is_trying = true
    return state
  end,

  enter_catch = function(old_state, err)
    local state = copy_table(old_state)
    local etype, fname, lnr, exception = err:match('^%z(.-)%z(.-)%z(.-)%z(.*)$')
    assert(etype == 'exception')
    state.exception = exception
    if fname:sub(1, 1) == '<' then
      state.throwpoint = ''
    else
      state.throwpoint = fname .. ', line ' .. lnr
    end
    return state
  end,

  enter_function = function(old_state, self, fcall, abort)
    local state = copy_table(old_state)
    state.a = a_scope:new(state)
    state.l = def_scope:new(state, 'l')
    state.l.self = self
    state.current_scope = state.l
    state.call_stack = copy_table(state.call_stack)
    state.abort = abort
    table.insert(state.call_stack, fcall)
    return state
  end,

  enter_script = function(old_state, s, sid)
    local state = copy_table(old_state)
    state.s = s
    state.sid = sid
    return state
  end,

  enter_code = function(old_state, code, fname)
    local state = copy_table(old_state)
    state.code = code
    state.fname = fname
    return state
  end,
}

-- {{{1 Functions returning specific types
get_number = function(state, val, position)
  local t = vim_type(val)
  return t.as_number(state, val, position)
end

get_string = function(state, val, position)
  local t = vim_type(val)
  return t.as_string(state, val, position)
end

get_float = function(state, val, position)
  local t = vim_type(val)
  return (t.as_float or t.as_number)(state, val, position)
end

get_boolean = function(state, val, position)
  local num = get_number(state, val, position)
  return num and num ~= 0
end

repr = function(state, val, val_position, for_echo, refs)
  if not val then
    return nil
  end
  local t = vim_type(val)
  if t.container then
    if refs[val] then
      if for_echo then
        return t.already_represented_container
      else
        err.err(state, val_position, true,
                'E724: Recursive data type detected')
        -- Despite the error Vim string() still returns something
        return '{E724}'
      end
    else
      refs[val] = true
    end
  end
  return t.repr(state, val, val_position, for_echo, refs)
end

iter = function(state, lst, lst_position)
  local t = vim_type(lst)
  return t.next, t.new_it_state(state, lst, lst_position), lst
end

-- {{{1 Types
-- {{{2 Related constants
-- Special values that cannot be assigned from VimL
type_idx = true
locks_idx = false
val_idx = 0
scope_name_idx = -1
length_idx = -2

BASE_TYPE_NUMBER     = 0
BASE_TYPE_STRING     = 1
BASE_TYPE_FUNCREF    = 2
BASE_TYPE_LIST       = 3
BASE_TYPE_DICTIONARY = 4
BASE_TYPE_FLOAT      = 5

local VAR_LOCKED = 1
local VAR_FIXED = 2

local IDX_GET   = 0
local IDX_SLICE = 1
local IDX_UNLET = 2

-- {{{2 Utility functions
local add_type_table = function(func)
  return function(self, ...)
    local ret = func(...)
    if ret then
      ret[type_idx] = self
    end
    return ret
  end
end

local num_convert_2 = function(func, converter)
  return function(state, val1, val1_position, val2, val2_position)
    local n1 = converter(state, val1, val1_position)
    if n1 == nil then
      return nil
    end
    local n2 = converter(state, val2, val2_position)
    if n2 == nil then
      return nil
    end
    return func(n1, n2)
  end
end

-- From https://mail.python.org/pipermail/python-dev/2003-October/039445.html
local bisimilar_tables = function(ic, tbl1, tbl2, is_dict)
  local bisim = {}
  local pending_last = {}
  local consider = function(val1, val2, is_dict)
    if bisim[val1] then
      if bisim[val1][val2] then
        return nil
      else
        bisim[val1][val2] = true
      end
    else
      bisim[val1] = {[val2]=true}
    end
    pending_last.next = {val1=val1, val2=val2, is_dict=is_dict, next=nil}
    pending_last = pending_last.next
  end
  local consider_new = function(v1, v2)
    if v1 == v2 then
      -- Do not bother comparing same lists or dictionaries
      return true
    end
    local t1 = vim_type(v1)
    local t2 = vim_type(v2)
    if t1.type_number ~= t2.type_number then
      return false
    elseif t1.container then
      consider(v1, v2, t1.type_number == BASE_TYPE_DICTIONARY)
      return true
    else
      return get_cmp_t(t1, t2).raw_cmp(ic, v1, v2) == 0
    end
  end
  if tbl1 == tbl2 then
    -- Do not bother comparing same lists or dictionaries
    return true
  end
  consider(tbl1, tbl2, is_dict)
  local pending = pending_last
  while pending do
    local val1 = pending.val1
    local val2 = pending.val2
    if pending.is_dict then
      for k, _ in pairs(val2) do
        if type(k) == 'string' then
          if val1[k] == nil then
            return false
          end
        end
      end
      for k, v1 in pairs(val1) do
        if type(k) == 'string' then
          local v2 = val2[k]
          if v2 == nil then
            return false
          end
          if not consider_new(v1, v2) then
            return false
          end
        end
      end
    else
      if val1.length ~= val2.length then
        return false
      end
      for i = 1,val1.length do
        if not consider_new(val1[i], val2[i]) then
          return false
        end
      end
    end
    pending = pending.next
  end
  return true
end

local copymethods = {
  [type_idx] = function(v)
    return v
  end,
  [locks_idx] = function(v)
    return {}
  end,
}

local copy_value = function(val, copymethods)
  if type(val) ~= 'table' then
    return val
  end
  local ret = {}
  local copied = {[val]=ret}
  local tocopy = {table=val, ret=ret, next=nil}
  local tocopy_last = tocopy
  while tocopy do
    local cur_tbl = tocopy.table
    local cur_ret = tocopy.ret
    for k, v in pairs(cur_tbl) do
      if type(v) ~= 'table' then
        cur_ret[k] = v
      elseif copymethods[k] then
        cur_ret[k] = copymethods[k](v)
      elseif copied[v] then
        cur_ret[k] = copied[v]
      else
        local new_ret = {}
        cur_ret[k] = new_ret
        copied[v] = new_ret
        tocopy_last.next = {table=v, ret=new_ret, next=nil}
        tocopy_last = tocopy_last.next
      end
    end
    tocopy = tocopy.next
  end
  return ret
end

-- {{{2 Any type base
local type_base = {
-- {{{3 Support for iterations
  next = function(_, _)
    return nil
  end,
  new_it_state = function(state, lst, lst_position)
    return err.err(state, lst_position, true, 'E714: List required')
  end,
-- {{{3 Querying support
  call = function(state, fun, fun_position, ...)
    return err.err(state, fun_position, true, 'E15: Can only call a Funcref')
  end,
  get_slice_indicies = function(state, length, idx_type, get_index,
                                idx1, idx1_position,
                                idx2, idx2_position)
    idx1 = get_index(state, length, idx1, idx1_position, idx_type)
    if idx1 == nil then
      return nil, nil
    end
    idx2 = get_index(state, length, idx2, idx2_position, idx_type)
    if idx2 == nil then
      return nil, nil
    end
    if idx_type == IDX_UNLET then
      if idx1 > length then
        return err.err(state, idx1_position, true,
                       'E684: List index out of range: %i', idx1 - 1), nil
      end
      if idx2 < 1 then
        return err.err(state, idx2_position, true,
                       'E684: List index out of range: %i',
                       idx1 - length - 1), nil
      end
      if idx1 > idx2 then
        return err.err(state, idx1_position, true,
                       'E684: First index is greater than the second'), nil
      end
      if idx2 > length then
        idx2 = length
      end
      if idx1 < 1 then
        idx1 = 1
      end
    end
    return idx1, idx2
  end,
-- }}}3
}

-- {{{2 Scalar type base
scalar = join_tables(type_base, {
-- {{{3 Assignment support
  assign_subscript = function(state, val, val_position, ...)
    return err.err(state, val_position, true,
                   'E689: Can only index a List or Dictionary')
  end,
  assign_subscript_function = function(state, unique, val, val_position, ...)
    return scalar.assign_subscript(state, val, val_position, ...)
  end,
  assign_slice = function(state, val, val_position, ...)
    return scalar.assign_subscript(state, val, val_position, ...)
  end,
  delete_subscript = function(state, val, val_position, ...)
    return scalar.assign_subscript(state, val, val_position, ...)
  end,
  delete_slice = function(state, val, val_position, ...)
    return scalar.assign_subscript(state, val, val_position, ...)
  end,
-- {{{3 Querying support
  subscript = function(state, val, val_position, idx, idx_position)
    local str = get_string(state, val, val_position)
    if str == nil then
      return nil
    end
    local idx = scalar.get_index(state, #str, idx, idx_position, IDX_GET)
    if idx == nil then
      return nil
    end
    return str:sub(idx, idx)
  end,
  get_index = function(state, length, idx, idx_position, idx_type)
    local ret = get_number(state, idx, idx_position)
    if idx_type == IDX_GET then
      if ret < 0 then
        -- When string.sub receives (0, 0) as argument it returns empty string
        return 0
      else
        return ret + 1
      end
    else
      ret = ret < 0 and ret + length + 1 or ret + 1
      if ret <= 0 then
        return false
      end
      return ret
    end
  end,
  slice = function(state, val, val_position, ...)
    local str = get_string(state, val, val_position)
    if str == nil then
      return nil
    end
    local idx1, idx2 = scalar.get_slice_indicies(state, #str, IDX_SLICE,
                                                 scalar.get_index, ...)
    if idx1 == nil then
      return nil
    elseif idx1 == false or idx2 == false then
      return ''
    else
      return str:sub(idx1, idx2)
    end
  end,
-- {{{3 string()
  container = false,
-- {{{3 Locks support
  set_container_lock = function(...)
  end,
  set_key_lock = function(state, depth, t, val, val_position, key, key_position,
                          lock)
    return scalar.assign_subscript(state, val, val_position)
  end,
  set_slice_lock = function(state, depth, t, val, val_position,
                                             idx1, idx1_position,
                                             idx2, idx1_position)
    return scalar.assign_subscript(state, val, val_position)
  end,
-- {{{3 Operators support
  num_op_priority = 1,
  add = num_convert_2(function(n1, n2)
    return n1 + n2
  end, get_number),
  subtract = num_convert_2(function(n1, n2)
    return n1 - n2
  end, get_number),
  multiply = num_convert_2(function(n1, n2)
    return n1 * n2
  end, get_number),
  divide = num_convert_2(function(n1, n2)
    if n2 == 0 then
      -- According to :h expr-/
      if n1 == 0 then
        return -0x80000000
      elseif n1 > 0 then
        return  0x7fffffff
      else
        return -0x7fffffff
      end
    else
      local ret = n1 / n2
      return math.floor(math.abs(ret)) * ((ret >= 0) and 1 or -1)
    end
  end, get_number),
  modulo = num_convert_2(function(n1, n2)
    if n2 == 0 then
      return 0
    end
    return (n1 % n2) * ((n1 < 0 and -1 or 1) * (n2 < 0 and -1 or 1))
  end, get_number),
  negate = function(state, val, val_position)
    local n = get_number(state, val, val_position)
    return n and -n
  end,
  promote_integer = get_number,
-- }}}3
})

scalar.mod_add = scalar.add

-- {{{2 Container type base
local numop = function(state, val1, val1_position, val2, val2_position)
  -- One of the following calls must fail for container type
  return (get_float(state, val1, val1_position)
          and get_float(state, val2, val2_position))
end

container = join_tables(type_base, {
-- {{{3 string()
  container = true,
-- {{{3 Locks support
  check_container_lock = function(state, t, val, val_position, key)
    if val[locks_idx][locks_idx] then
      local message
      if val[locks_idx][locks_idx] == VAR_FIXED then
        -- Note: only scope dictionaries may have fixed keys or be fixed 
        -- themselves. Thus container does not have "fixed_message" or 
        -- "fixed_dict_message" keys.
        message = t.fixed_dict_message
      else
        message = 'E741: Value is locked: %s'
      end
      if type(key) == 'number' then
        key = key - 1
      end
      return  err.err(state, val_position, true, message, key)
    end
    return true
  end,
  check_key_lock = function(state, t, val, key, key_position)
    if val[locks_idx][key] then
      local message
      if val[locks_idx][key] == VAR_FIXED then
        message = t.fixed_message
      else
        message = 'E741: Value is locked: %s'
      end
      if type(key) == 'number' then
        key = key - 1
      end
      return err.err(state, key_position, true, message, key)
    end
    return true
  end,
  check_locks = function(state, t, val, val_position, key, key_position)
    local is_locked, new_key
    if val[key] then
      -- When trying to add a new key check whether container itself is locked.
      return t.check_key_lock(state, t, val, key, key_position), false
    else
      -- When trying to overwrite existing value check whether specific value is 
      -- locked.
      return t.check_container_lock(state, t, val, val_position, key), true
    end
  end,
  set_key_lock = function(state, depth, t, val, val_position, key, key_position,
                          lock)
    if not val[key] then
      return true
    end
    if val[locks_idx][key] ~= VAR_FIXED then
      val[locks_idx][key] = lock
    end
    vim_type(val[key]).set_container_lock(state, depth, val[key], lock, {})
    return true
  end,
-- {{{3 Copy support
  copy = function(val)
    local ret = copy_table(val)
    ret[locks_idx] = {}
    return ret
  end,
-- {{{3 Operators support
  num_op_priority = 10,
  add = numop,
  subtract = numop,
  multiply = numop,
  divide = numop,
  modulo = numop,
  negate = numop,
  promote_integer = numop,
-- }}}3
})

container.mod_add = container.add

-- {{{2 Basic types
-- {{{3 Number
number = join_tables(scalar, {
  type_number = BASE_TYPE_NUMBER,
-- {{{4 string()
  repr = function(state, num, num_position, for_echo, refs)
    return (('%i'):format(num))
  end,
-- {{{4 Type conversions
  as_number = function(state, num, num_position)
    return num
  end,
  as_string = function(state, num, num_position)
    return tostring(num)
  end,
  as_float = function(state, num, num_position)
    return num
  end,
-- {{{4 Operators support
  cmp_priority = 1,
  raw_cmp = function(ic, n1, n2)
    return (n1 > n2 and 1) or ((n1 == n2 and 0) or -1)
  end,
  cmp = function(state, ic, eq, val1, val1_position, val2, val2_position)
    local n1 = get_number(state, val1, val1_position)
    if n1 == nil then
      return nil
    end
    local n2 = get_number(state, val2, val2_position)
    if n2 == nil then
      return nil
    end
    return number.raw_cmp(ic, n1, n2)
  end,
  negate = function(state, num, num_position)
    return -num
  end,
  promote_integer = function(state, num, num_position)
    return num
  end,
-- }}}4
})

-- {{{3 String
string = join_tables(scalar, {
  type_number = BASE_TYPE_STRING,
-- {{{4 string()
  repr = function(state, str, str_position, for_echo, refs)
    if for_echo == true then
      return str
    else
      return "'" .. str:gsub("'", "''") .. "'"
    end
  end,
-- {{{4 Type conversions
  as_number = function(state, str, str_position)
    return tonumber(str:match('^%-?0[xX]%x+')) or
           tonumber(str:match('^%-?%d+')) or
           0
  end,
  as_string = function(state, str, str_position)
    return str
  end,
  as_float = function(state, num, num_position)
    return num
  end,
-- {{{4 Operators support
  cmp_priority = 0,
  raw_cmp = function(ic, s1, s2)
    if ic then
      return stricmp(s1, s2)
    else
      return (s1 > s2 and 1) or ((s1 == s2 and 0) or -1)
    end
  end,
  cmp = function(state, ic, eq, val1, val1_position, val2, val2_position)
    local s1 = get_string(state, val1, val1_position)
    if s1 == nil then
      return nil
    end
    local s2 = get_string(state, val2, val2_position)
    if s2 == nil then
      return nil
    end
    return string.raw_cmp(ic, s1, s2)
  end,
-- }}}4
})

-- {{{3 List
list = join_tables(container, {
-- {{{4 New
  type_number = BASE_TYPE_LIST,
  new = add_type_table(function(state, ...)
    return {[locks_idx]={}, length=select('#', ...), iterators={}, ...}
  end),
-- {{{4 Modification support
  insert = function(state, lst, lst_position, idx, idx_position,
                           val, val_position)
    local idx = list.get_index(state, lst.length, idx, idx_position, IDX_GET)
    if idx == nil then
      return nil
    end
    local t = vim_type(lst)
    if not t.check_container_lock(state, t, lst, lst_position, idx) then
      return nil
    end
    local locks = lst[locks_idx]
    for i = lst.length,idx,-1 do
      lst[i + 1] = lst[i]
      locks[i + 1] = locks[i]
    end
    lst[idx] = val
    locks[idx] = nil
  end,
  append = function(state, lst, lst_position, val, val_position)
    local t = vim_type(lst)
    if not t.check_container_lock(state, t, lst, lst_position, -1) then
      return nil
    end
    lst[lst.length + 1] = val
    lst.length = lst.length + 1
  end,
-- {{{4 Assignment support
  assign_subscript = function(state, lst, lst_position, idx, idx_position, val)
    local idx = list.get_index(state, lst.length, idx, idx_position, IDX_GET)
    if idx == nil then
      return nil
    end
    local t = vim_type(lst)
    -- When performing regular assignment lock on specific item is not ignored.
    if not t.check_locks(state, t, lst, lst_position, idx, idx_position) then
      return nil
    end
    lst[idx] = val
    return true
  end,
  assign_slice = function(state, lst,  lst_position,
                                 idx1, idx1_position,
                                 idx2, idx2_position,
                                 val)
    -- FIXME Use val position in error messages
    if not is_list(val) then
      if is_func(val) and lst_position:sub(-9) == ':function' then
        return err.err(state, lst_position, true,
                       'E475: Cannot assign function to a slice')
      else
        return err.err(state, lst_position, true,
                       'E709: [:] requires a List value')
      end
    end
    local idx1, idx2 = list.get_slice_indicies(
      state, lst.length, IDX_GET, list.get_index,
      idx1, idx1_position,
      idx2, idx2_position
    )
    if idx1 == nil then
      return nil
    end
    local t = vim_type(lst)
    if not t.check_container_lock(state, t, lst, lst_position, idx1) then
      return nil
    end
    local tgt_length = idx2 - idx1 + 1
    -- FIXME Use val position in error messages
    if val.length < tgt_length then
      return err.err(state, lst_position, true,
                     'E711: List value has not enough items')
    elseif val.length > tgt_length then
      return err.err(state, lst_position, true,
                     'E710: List value has too many items')
    end
    local locks = lst[locks_idx]
    for i = idx1,idx2 do
      lst[i] = val[i - idx1 + 1]
      -- When performing slice assignment locks on specific items are ignored 
      -- (may be a bug though). Lock on the whole list is not.
      locks[i] = nil
    end
    return true
  end,
  delete_slice = function(state, lst, lst_position, idx1, idx1_position,
                                                    idx2, idx2_position)
    local idx1, idx2 = list.get_slice_indicies(
      state, lst.length, IDX_UNLET, list.get_index,
      idx1, idx1_position,
      idx2, idx2_position
    )
    if idx1 == nil then
      return nil
    end
    local slicelen = idx2 - idx1 + 1
    local movelen = lst.length - idx2
    local locks = lst[locks_idx]
    for i = 1,movelen do
      lst[idx1 + i - 1] = lst[idx2 + i]
      locks[idx1 + i - 1] = locks[idx1 + i]
      lst[idx2 + i] = nil
      locks[idx2 + i] = nil
    end
    for i = idx1+movelen,idx2 do
      lst[i] = nil
      locks[i] = nil
    end
    lst.length = lst.length - slicelen
    return true
  end,
-- {{{4 Querying support
  get_index = function(state, length, idx, idx_position, idx_type)
    local ret = get_number(state, idx, idx_position)
    ret = ret < 0 and ret + length + 1 or ret + 1
    if idx_type == IDX_GET and (ret > length or ret <= 0) then
      return err.err(state, idx_position, true,
                     'E684: List index out of range: %i', idx)
    end
    return ret
  end,
  subscript = function(state, lst, lst_position, idx, idx_position)
    local length = lst.length
    local idx = list.get_index(state, length, idx, idx_position, IDX_GET)
    return lst[idx]
  end,
  slice = function(state, lst, lst_position, ...)
    local length = lst.length
    local idx1, idx2 = list.get_slice_indicies(state, length, IDX_SLICE,
                                               list.get_index, ...)
    if idx1 == nil then
      return nil
    end
    local ret = list:new(state)
    if idx1 > idx2 or idx1 > length or idx1 <= 0 then
      return ret
    elseif idx2 > length then
      idx2 = length
    end
    for i = idx1,idx2 do
      ret[i - idx1 + 1] = lst[i]
    end
    return ret
  end,
  raw_slice_to_end = function(lst, idx)
    local ret = list:new(state)
    for i = idx,lst.length do
      ret[i - idx + 1] = lst[i]
    end
    ret.length = lst.length - idx + 1
    return ret
  end,
-- {{{4 Support for iterations
  next = function(it_state, _)
    local i = it_state.i
    if i >= it_state.maxi then
      return nil
    end
    it_state.i = it_state.i + 1
    return i, it_state.lst[i + 1]
  end,
  new_it_state = function(state, lst, lst_position)
    local it_state = {
      i = 0,
      maxi = lst.length,
      lst = lst,
    }
    table.insert(lst.iterators, it_state)
    return it_state
  end,
-- {{{4 string()
  already_represented_container = '[...]',
  repr = function(state, lst, lst_position, for_echo, refs)
    local ret = '['
    local length = lst.length
    local add_comma = false
    for i = 1,length do
      if add_comma then
        ret = ret .. ', '
      else
        add_comma = true
      end
      local chunk = repr(state, lst[i], lst_position, for_echo and 'list', refs)
      if chunk == nil then
        return nil
      end
      ret = ret .. chunk
    end
    ret = ret .. ']'
    return ret
  end,
-- {{{4 Type conversions
  as_number = function(state, lst, lst_position)
    return err.err(state, lst_position, true, 'E745: Using List as a Number')
  end,
  as_string = function(state, lst, lst_position)
    return err.err(state, lst_position, true, 'E730: Using List as a String')
  end,
-- {{{4 Locks support
  set_container_lock = function(state, depth, lst, lock, already_set)
    -- lock may be either nil or VAR_LOCKED
    if already_set[lst] then
      return
    end
    already_set[lst] = true
    local locks = lst[locks_idx]
    if not depth or depth > 1 then
      for i = 1,lst.length do
        local v = lst[i]
        if locks[i] ~= VAR_FIXED then
          locks[i] = lock
        end
        local t = vim_type(v)
        t.set_container_lock(state, depth and depth - 1, v, lock, already_set)
      end
    end
    if locks[locks_idx] ~= VAR_FIXED then
      locks[locks_idx] = lock
    end
  end,
  set_slice_lock = function(state, depth, t, lst, lst_position,
                                             idx1, idx1_position,
                                             idx2, idx2_position, lock)
    local idx1, idx2 = list.get_slice_indicies(
      state, lst.length, IDX_UNLET, list.get_index,
      idx1, idx1_position,
      idx2, idx2_position
    )
    if idx1 == nil then
      return nil
    end
    local already_set = {}
    for i = idx1,idx2 do
      lst[locks_idx][i] = lock
      local v = lst[i]
      vim_type(v).set_container_lock(state, depth, v, lock, already_set)
    end
    return true
  end,
-- {{{4 Operators support
  cmp_priority = 10,
  cmp = function(state, ic, eq, val1, val1_position, val2, val2_position)
    if not (is_list(val1) and is_list(val2)) then
      return err.err(state, val2_position, true,
                     'E691: Can only compare List with List')
    elseif not eq then
      return err.err(state, val1_position, true,
                     'E692: Invalid operation for Lists')
    end
    return bisimilar_tables(ic, val1, val2, false) and 0 or 1
  end,
  num_op_priority = 3,
  do_add = function(state, copy_ret, val1, val1_position, val2, val2_position)
    if not (is_list(val1) and is_list(val2)) then
      -- Error out
      if is_list(val1) then
        return list.as_number(state, val1, val1_position)
      else
        return list.as_number(state, val2, val2_position)
      end
    end
    if not copy_ret then
      local t = vim_type(val1)
      if not list.check_container_lock(state, t, val1, val1_position, nil) then
        return nil
      end
    end
    local length1 = val1.length
    local ret = copy_ret and copy_table(val1) or val1
    for i, v in ipairs(val2) do
      ret[length1 + i] = v
    end
    ret.length = length1 + val2.length
    return ret
  end,
  add = function(state, ...)
    return list.do_add(state, true, ...)
  end,
  mod_add = function(state, ...)
    return list.do_add(state, false, ...)
  end,
-- }}}4
})

-- {{{3 Dictionary
dict = join_tables(container, {
-- {{{4 New
  type_number = BASE_TYPE_DICTIONARY,
  can_be_self = true,
  new = add_type_table(function(state, ...)
    if select('#', ...) % 2 ~= 0 then
      return err.err(state, position, true,
                     'Internal error: odd number of arguments to dict:new')
    end
    local ret = {[length_idx]=select('#', ...)/2, [locks_idx]={}}
    for i = 1,ret[length_idx] do
      local key = select(2*i - 1, ...)
      local val = select(2*i, ...)
      if not (key and val) then
        return nil
      end
      ret[get_string(state, key)] = val
    end
    return ret
  end),
-- {{{4 Modification support
-- {{{4 Assignment support
  assign_subscript = function(state, dct, dct_position, key, key_position, val)
    if key == '' then
      return err.err(state, key_position, true,
                     'E713: Cannot use empty key for dictionary')
    end
    local t = vim_type(dct)
    local can_edit, new_key = t.check_locks(state, t, dct, dct_position,
                                                      key, key_position)
    if not can_edit then
      return nil
    elseif new_key then
      dct[length_idx] = dct[length_idx] + 1
    end
    dct[key] = val
    return true
  end,
  delete_subscript = function(state, mustexist, dct, dct_position,
                                                key, key_position)
    local t = vim_type(dct)
    local old_key = dct[key]
    if old_key == nil then
      if mustexist then
        return err.err(
          state, key_position, true,
          ((t.missing_key_delete_message or t.missing_key_message) .. ": %s"),
          key
        )
      else
        return true
      end
    end
    if t.check_locks(state, t, dct, dct_position, key, key_position) then
      if old_key then
        dct[key] = nil
        dct[locks_idx][key] = nil
        dct[length_idx] = dct[length_idx] - 1
      end
      return old_key or true
    else
      return nil
    end
    return old_key or true
  end,
  non_unique_function_message = 'E717: Dictionary entry already exists: %s',
  assign_subscript_function = function(state, unique, dct, dct_position,
                                                      key, key_position,
                                                      val)
    if unique and dct[key] ~= nil then
      return err.err(state, key_position, true,
                     dct[type_idx].non_unique_function_message,
                     key)
    end
    return dict.assign_subscript(state, dct, dct_position, key, key_position,
                                        val)
  end,
  assign_slice = function(state, dct, dct_position, ...)
    return err.err(state, dct_position, true,
                   'E719: Cannot use [:] with a Dictionary')
  end,
  delete_slice = function(...)
    return dict.assign_slice(...)
  end,
-- {{{4 Querying support
  missing_key_message = 'E716: Key not present in Dictionary',
  subscript = function(state, dct, dct_position, key, key_position)
    key = get_string(state, key, key_position)
    if key == nil then
      return nil
    end
    local ret = dct[key]
    if (ret == nil) then
      local message
      message = dct[type_idx].missing_key_message
      return err.err(state, key_position, true, message .. ': %s', key)
    end
    return ret
  end,
  slice = function(...)
    return dict.assign_slice(...)
  end,
-- {{{4 string()
  already_represented_container = '{...}',
  repr = function(state, dct, dct_position, for_echo, refs)
    local ret = '{'
    local add_comma = false
    for k, v in pairs(dct) do
      if type(k) == 'string' then
        if add_comma then
          ret = ret .. ', '
        else
          add_comma = true
        end
        local chunk = repr(state, k, dct_position, false, refs)
        if chunk == nil then
          return nil
        end
        ret = ret .. chunk .. ': '
        local chunk = repr(state, v, dct_position, for_echo and 'dict', refs)
        if chunk == nil then
          return nil
        end
        ret = ret .. chunk
      end
    end
    ret = ret .. '}'
    return ret
  end,
-- {{{4 Type conversions
  as_number = function(state, dct, dct_position)
    return err.err(state, dct_position, true,
                   'E728: Using Dictionary as a Number')
  end,
  as_string = function(state, dct, dct_position)
    return err.err(state, dct_position, true,
                   'E731: Using Dictionary as a String')
  end,
-- {{{4 Locks support
  set_container_lock = function(state, depth, dct, lock, already_set)
    -- lock may be either nil or VAR_LOCKED
    if already_set[dct] then
      return
    end
    already_set[dct] = true
    local locks = dct[locks_idx]
    if not depth or depth > 1 then
      for k, v in pairs(dct) do
        if type(k) == 'string' then
          if locks[k] ~= VAR_FIXED then
            locks[k] = lock
          end
          local t = vim_type(v)
          t.set_container_lock(state, depth and depth - 1, v, lock, already_set)
        end
      end
    end
    if locks[locks_idx] ~= VAR_FIXED then
      locks[locks_idx] = lock
    end
  end,
  set_slice_lock = function(state, depth, t, dct, dct_position,
                                             idx1, idx1_position,
                                             idx2, idx1_position, lock)
    return scalar.assign_slice(state, dct, dct_position)
  end,
-- {{{4 Operators support
  cmp_priority = 10,
  cmp = function(state, ic, eq, val1, val1_position, val2, val2_position)
    if not (is_dict(val1) and is_dict(val2)) then
      return err.err(state, val2_position, true,
                     'E735: Can only compare Dictionary with Dictionary')
    elseif not eq then
      return err.err(state, val1_position, true,
                     'E736: Invalid operation for Dictionaries')
    end
    return bisimilar_tables(ic, val1, val2, true) and 0 or 1
  end,
-- }}}4
})

-- {{{3 Float
local return_float = function(func)
  return function(state, ...)
    local ret = func(state, ...)
    return float:new(state, ret)
  end
end

float = join_tables(scalar, {
-- {{{4 New
  type_number = BASE_TYPE_FLOAT,
  new = add_type_table(function(state, f)
    return {[val_idx] = f}
  end),
-- {{{4 string()
  repr = function(state, flt, flt_position, for_echo, refs)
    return ('%e'):format(flt[val_idx])
  end,
-- {{{4 Type conversions
  as_number = function(state, flt, flt_position)
    return err.err(state, flt_position, true, 'E805: Using Float as a Number')
  end,
  as_string = function(state, flt, flt_position)
    return err.err(state, flt_position, true, 'E806: Using Float as a String')
  end,
  as_float = function(state, flt, flt_position)
    return flt[val_idx]
  end,
-- {{{4 Operators support
  cmp_priority = 2,
  raw_cmp = function(ic, flt1, flt2)
    local f1 = flt1[val_idx]
    local f2 = flt2[val_idx]
    return (f1 > f2 and 1) or ((f1 == f2 and 0) or -1)
  end,
  cmp = function(state, ic, eq, val1, val1_position, val2, val2_position)
    local f1 = get_float(state, val1, val1_position)
    if f1 == nil then
      return nil
    end
    local f2 = get_float(state, val2, val2_position)
    if f2 == nil then
      return nil
    end
    return (f1 > f2 and 1) or ((f1 == f2 and 0) or -1)
  end,
  num_op_priority = 2,
  add = return_float(num_convert_2(function(f1, f2)
    return f1 + f2
  end, get_float)),
  subtract = return_float(num_convert_2(function(f1, f2)
    return f1 - f2
  end, get_float)),
  multiply = return_float(num_convert_2(function(f1, f2)
    return f1 * f2
  end, get_float)),
  divide = return_float(num_convert_2(function(f1, f2)
    return f1 / f2
  end, get_float)),
  modulo = function(state, flt1, flt1_position, ...)
    return err.err(state, flt1_position, true,
                   'E804: Cannot use \'%%\' with Float')
  end,
  negate = return_float(function(state, flt, flt_position)
    return -flt[val_idx]
  end),
  promote_integer = function(state, flt, flt_position)
    return flt
  end,
-- {{{4 Copy support
  copy = function(val)
    return copy_table(val)
  end,
-- }}}4
})

-- {{{3 Function reference
local funcs = {}
setmetatable(funcs, {__mode='k'})

func = join_tables(scalar, {
  type_number = BASE_TYPE_FUNCREF,
-- {{{4 New
  new = function(self, state, fun, first_node_position, funcname, args, props,
                              endfun_position)
    local start_lnr, start_col = err.unpack_position(first_node_position)
    local end_lnr, end_col = err.unpack_position(endfun_position)
    funcs[fun] = {
      start_lnr = start_lnr,
      start_col = start_col,
      end_lnr = end_lnr,
      end_col = end_col,
      code = state.code,
      fname = state.fname,
      funcname = funcname,
      user_funcname = '1',
      args = args,
      dict = props[1],
      abort = props[2],
      range = props[3],
    }
    return fun
  end,
-- {{{4 Querying support
  subscript = function(state, fun, fun_position, ...)
    return err.err(state, fun_position, true, 'E695: Cannot index a Funcref')
  end,
  slice = function(...)
    return func.subscript(...)
  end,
  call = function(state, fun, fun_position, ...)
    if funcs[fun] and funcs[fun].dict then
      return err.err(state, fun_position, true,
                     'E725: Calling dict function without a Dictionary: %s',
                     funcs[fun].funcname)
    end
    return fun(state, nil, fun_position, ...)
  end,
  fun_desc = function(fun)
    return funcs[fun]
  end,
-- {{{4 string()
  repr = function(state, fun, fun_position, for_echo, refs)
    local user_funcname = funcs[fun] and funcs[fun].user_funcname or '<nil>'
    return (for_echo == true
            and user_funcname
            or ('function(\'%s\')'):format(user_funcname))
  end,
-- {{{4 Type conversions
  as_number = function(state, fun, fun_position)
    return err.err(state, fun_position, true, 'E703: Using Funcref as a Number')
  end,
  as_string = function(state, fun, fun_position)
    return err.err(state, fun_position, true, 'E729: Using Funcref as a String')
  end,
  as_func = function(state, fun, fun_position)
    return fun
  end,
-- {{{4 Operators support
  cmp_priority = 10,
  raw_cmp = function(ic, fun1, fun2)
    return fun1 == fun2 and 0 or 1
  end,
  cmp = function(state, ic, eq, val1, val1_position, val2, val2_position)
    if not (is_func(val1) and is_func(val2)) then
      return err.err(state, val2_position, true,
                     'E693: Can only compare Funcref with Funcref')
    elseif not eq then
      return err.err(state, val1_position, true,
                     'E694: Invalid operation for Funcrefs')
    end
    local t1 = vim_type(val1)
    local t2 = vim_type(val2)
    return (t1.as_func(state, val1, val1_position) ==
            t2.as_func(state, val2, val2_position)) and 0 or 1
  end,
-- }}}4
})

-- {{{2 dict.func(): bound function
bound_func = join_tables(func, {
-- {{{3 New
  new = add_type_table(function(state, fun, self)
    return {
      func=fun,
      self=self,
    }
  end),
-- {{{3 Querying support
  call = function(state, fun, fun_position, ...)
    return fun.func(state, fun.self, fun_position, ...)
  end,
  fun_desc = function(fun)
    return funcs[fun.func]
  end,
-- {{{3 string()
  repr = function(state, fun, fun_position, for_echo, refs)
    return func.repr(state, fun.func, fun_position, for_echo, refs)
  end,
-- {{{3 Type conversions
  as_func = function(state, fun, fun_position)
    return fun and fun.func
  end,
-- }}}3
})
-- {{{2 Scopes
-- {{{3 Base type for scope dictionaries
scope = join_tables(dict, {
  new = add_type_table(function(state, scope_name, ...)
    local ret = dict:new(state, ...)
    ret[scope_name_idx] = scope_name
    return ret
  end),
  special_keys = {
    [''] = function(state, dct)
      return dct
    end
  },
  subscript = function(state, dct, dct_position, key, key_position)
    local special = dct[type_idx].special_keys[key]
    if special then
      return special(state, dct)
    else
      return dict.subscript(state, dct, dct_position, key, key_position)
    end
  end,
  missing_key_delete_message = 'E108: No such variable',
  missing_key_message = 'E121: Undefined variable',
  assign_subscript = function(state, dct, dct_position, key, key_position, val)
    if not key:match('^%a[%w_]*$') then
      return err.err(state, key_position, true,
                     'E461: Illegal variable name: %s', key)
    end
    return dict.assign_subscript(state, dct, dct_position, key, key_position,
                                        val)
  end,
  delete_subscript = function(state, mustexist, dct, dct_position,
                                                key, key_position)
    local t = vim_type(dct)
    local old_key = dct[key]
    if old_key == nil then
      if mustexist then
        return err.err(
          state, key_position, true,
          ((t.missing_key_delete_message or t.missing_key_message) .. ": %s"),
          key
        )
      else
        return true
      end
    end
    if old_key then
      dct[key] = nil
      dct[locks_idx][key] = nil
      dct[length_idx] = dct[length_idx] - 1
    end
    return old_key or true
  end,
  set_key_lock = function(state, depth, t, dct, dct_position, key, key_position,
                          lock)
    if key == '' then
      t.set_container_lock(state, depth, dct, lock, {})
      return true
    else
      return dict.set_key_lock(state, depth, t, dct, dct_position,
                                                key, key_position, lock)
    end
  end,
})

-- {{{3 g: and l: dictionaries
def_scope = join_tables(scope, {
  assign_subscript = function(state, dct, dct_position, key, key_position, val)
    if is_func(val) then
      if state.global.user_functions[key] then
        return err.err(
          state, key_position, true,
          'E705: Variable name conflicts with existing function: %s', key
        )
      end
    end
    return scope.assign_subscript(state, dct, dct_position, key, key_position,
                                         val)
  end
})

-- {{{3 b: scope dictionary
b_scope = join_tables(scope, {
  new = add_type_table(function(state, ...)
    return scope:new(state, 'b', ...)
  end),
})

-- {{{3 a: scope dictionary
a_scope = join_tables(scope, {
  new = add_type_table(function(state, ...)
    return scope:new(state, 'a', ...)
  end),
  fixed_message = 'E46: Cannot change read-only variable a:%s',
})

-- {{{3 v: scope dictionary
v_scope = join_tables(scope, {
  new = add_type_table(function(state, ...)
    return scope:new(state, 'v', ...)
  end),
  fixed_message = 'E46: Cannot change read-only variable v:%s',
  fixed_dict_message = 'E461: Illegal variable name: v:%s',
  special_keys = join_tables(scope.special_keys, {
    exception = function(state, dct)
      return state.exception
    end,
    throwpoint = function(state, dct)
      return state.throwpoint
    end,
  }),
})

-- {{{3 Functions dictionary
f_scope = join_tables(dict, {
  missing_key_message = 'E117: Unknown function',
  non_unique_function_message =
                        'E122: Function %s already exists, add ! to replace it',
  can_be_self = false,
  new = add_type_table(function(state, ...)
    return scope:new(state, nil, ...)
  end),
})

-- {{{1 Error manipulation
err = {
  matches = function(state, err, regex)
    if (err:match(regex)) then
      return true
    else
      return false
    end
  end,

  unpack_position = function(position)
    local lnr, col, cmd = position:match('(%d+):(%d+):(.*)')
    lnr = tonumber(lnr)
    col = tonumber(col)
    return lnr, col, cmd
  end,

  raise = function(fname, lnr, message)
    error('\0exception\0' .. fname .. '\0' .. lnr .. '\0' .. message, 0)
  end,

  err = function(state, position, vim_error, message, ...)
    local formatted_message
    -- TODO: Translate message if vim_error is true, but do not translate 
    --       message if state.abort is 'postproc'
    formatted_message = (message):format(...)
    local lnr, col, cmd = err.unpack_position(position)
    if state.is_trying then
      if vim_error then
        if cmd ~= '' then
          formatted_message = 'Vim(' .. cmd .. '):' .. formatted_message
        else
          formatted_message = 'Vim:' .. formatted_message
        end
      end
      err.raise(state.fname, lnr, formatted_message)
    -- state.abort may be either true, false or 'postproc'
    elseif state.abort == true then
      error('\0error' ..
            '\0' .. position ..
            '\0' .. tostring(vim_error) ..
            '\0' .. formatted_message, 0)
    else
      io.stderr:write(('line %u, column %u:\n'):format(lnr, col))
      io.stderr:write('> ' .. state.code[lnr] .. '\n')
      -- TODO Use strdisplaywidth() to calculate offset
      io.stderr:write('| ' .. (col > 1 and (' '):rep(col - 1) or '') .. '^\n')
      io.stderr:write(formatted_message .. '\n')
    end
    return nil
  end,

  throw = function(state, message, message_position)
    local vim_error = false
    if message:sub(1, 3) == 'Vim' then
      message = 'E608: Cannot :throw exceptions with \'Vim\' prefix'
      vim_error = true
    end
    err.err(state, message_position, vim_error, message)
    -- :throw always throws. If the above call did not raise the exception the 
    -- below lines will.
    local lnr, col, cmd = err.unpack_position(message_position)
    err.raise(state.fname, lnr, message)
  end,

  process_abort = function(state, abort_err)
    local etype, a2, a3, message = abort_err:match('^%z(.-)%z(.-)%z(.-)%z(.*)$')
    -- Depending on etype (a2, a3) may be either (fname, lnr) or (position, 
    -- vim_error)
    if etype == 'error' then
      state.abort = 'postproc'
      err.err(state, a2, a3 == 'true', message)
      -- XXX In Vim aborted function returns -1
      return -1
    else
      return error(abort_err, 0)
    end
  end,
}

-- {{{1 Built-in function implementations
local functions = f_scope:new(nil)
functions.type = function(state, self, callee_position, val, val_position)
  return vim_type(val)['type_number']
end

functions['function'] = function(state, self, callee_position,
                                              val, val_position)
  local s = val and get_string(state, val, val_position)
  if not s then
    return nil
  end
  local ret
  if s:match('^[a-z]') then
    ret = functions[s]
  elseif s:match('^%d') then
    return err.err(state, val_position, true,
                   'E475: Function name cannot start with a digit')
  else
    -- TODO Replace leading s: and <SID>
    ret = state.global.user_functions[s]
  end
  return ret or err.err(state, val_position, true,
                        'E700: Unknown function: %s', s)
end

functions.string = function(state, self, callee_position, val, val_position)
  return repr(state, val, val_position, false, {})
end

functions.call = function(state, self, callee_position, fun, fun_position,
                                                        lst, lst_position,
                                                        dct, dct_position)
  if dct then
    if not is_dict(dct) then
      return err.err(state, dct_position, true, 'E715: Dictionary required')
    end
    fun = bound_func:new(state, fun, dct)
  end
  if not is_list(lst) then
    return err.err(state, lst_position, true, 'E714: List required')
  end
  local args = {}
  for i, v in ipairs(lst) do
    args[i*2 - 1] = v
    args[i*2] = lst_position
  end
  return subscript.call(state, fun, fun_position, unpack(args))
end

functions.copy = function(state, self, callee_position, val, val_position)
  if type(val) == 'table' then
    return val[type_idx].copy(val)
  else
    return val
  end
end

functions.deepcopy = function(state, self, callee_position, val, val_position)
  return copy_value(val, copymethods)
end

local funcnames = {}

for k, v in pairs(functions) do
  if type(v) == 'function' then
    funcs[v] = {user_funcname = k}
  end
end

-- {{{1 Built-in commands implementations
local commands = {
  append = function(state, range, bang, lines)
  end,
  abclear = function(state, buffer)
  end,
  echo = function(state, ...)
    local mes = ''
    for i = 1,select('#', ...) do
      local str = select(i, ...)
      if str == nil then
        return nil
      end
      mes = mes .. ' '
      local chunk = repr(state, str, str_position, true, {})
      if chunk == nil then
        return nil
      end
      mes = mes .. chunk
    end
    print (mes:sub(2))
  end,
  call = function(state, range, callee, callee_position, ...)
    if not callee then
      return nil
    end
    if not is_func(callee) then
      return vim.err.err(state, callee_position, true,
                         'E117: Attempt to call a non-function')
    end
    if range then
      if vim_type(callee).fun_desc(callee).range then
        -- TODO: Record range in state
        local new_state = state
        return subscript.call(new_state, callee, callee_position, ...)
      else
        for line in range:iter() do
          -- TODO: Move cursor
          local ret = subscript.call(state, callee, callee_position, ...)
          if not ret then
            return ret
          end
        end
      end
    else
      return subscript.call(state, callee, callee_position, ...)
    end
  end,
}

-- {{{1 User commands implementation
local parse = function(state, command, range, bang, args)
  return args, nil
end

local run_user_command = function(state, command, range, bang, args)
  command = state.global.user_commands[command]
  if (command == nil) then
    -- TODO Record line number
    return err.err(state, position, true, 'E492: Not a editor command: %s',
                   command)
  end
  args, after = parse(state, command, range, bang, args)
  command.func(state, range, bang, args)
  if (after) then
    after(state)
  end
end

-- {{{1 Assign support
local set_dict_lock = function(lock, state, bang, depth, dct, dct_position,
                                                         key, key_position)
  if not (dct and key) then
    return nil
  end
  local t = vim_type(dct)
  if bang then
    depth = nil
  end
  return t.set_key_lock(state, depth, t, dct, dct_position, key, key_position,
                        lock)
end

local set_slice_lock = function(lock, state, bang, depth, lst, lst_position,
                                                          idx1, idx1_position,
                                                          idx2, idx2_position)
  if not (lst and idx1 and idx2) then
    return nil
  end
  local t = vim_type(lst)
  if bang then
    depth = nil
  end
  return t.set_slice_lock(state, depth, t, lst, lst_position,
                                           idx1, idx1_position,
                                           idx2, idx2_position,
                                           lock)
end

assign = {
  ass_dict = function(state, val, dct, dct_position,
                                  key, key_position)
    if not (val and dct and key) then
      return nil
    end
    local t = vim_type(dct)
    return t.assign_subscript(state, dct, dct_position, key, key_position, val)
  end,

  ass_dict_function = function(state, bang, val,
                                            dct, dct_position,
                                            key, key_position)
    if not (val and dct and key) then
      return nil
    end
    local t = vim_type(dct)
    if t.assign_subscript_function(state, not bang,
                                   dct, dct_position,
                                   key, key_position,
                                   val) then
      if funcs[val] then
        if dct == state.global.user_functions then
          funcs[val].user_funcname = key
        end
      end
      return true
    else
      return nil
    end
  end,

  ass_slice = function(state, val,
                              lst, lst_position,
                              idx1, idx1_position,
                              idx2, idx2_position)
    if not (val and lst and idx1 and idx2) then
      return nil
    end
    local t = vim_type(lst)
    return t.assign_slice(
      state,
      lst, lst_position,
      idx1, idx1_position,
      idx2, idx2_position,
      val
    )
  end,

  ass_slice_function = function(state, bang, ...)
    return assign.ass_slice(state, ...)
  end,

  del_dict = function(state, bang, dct, dct_position, key, key_position)
    if not (dct and key) then
      return nil
    end
    local t = vim_type(dct)
    return (t.delete_subscript(state, not bang, dct, dct_position,
                                                key, key_position)
            and true or nil)
  end,

  del_dict_function = function(state, bang, dct, dct_position,
                                            key, key_position)
    if not (dct and key) then
      return nil
    end
    local t = vim_type(dct)
    local ret = t.delete_subscript(state, not bang, dct, dct_position,
                                                    key, key_position)
    if not ret then
      return nil
    elseif ret == true then
      return true
    elseif not is_func(ret) then
      dct[key] = ret
      return err.err(state, key_position, true, 'E130: Unknown function')
    end
    -- TODO Delete global function
    return true
  end,

  del_slice = function(state, bang, lst, lst_position,
                                    idx1, idx1_position,
                                    idx2, idx2_position)
    if not (lst and idx1 and idx2) then
      return nil
    end
    local t = vim_type(lst)
    return t.delete_slice(state, lst, lst_position, idx1, idx1_position,
                                                    idx2, idx2_position)
  end,

  del_slice_function = function(state, bang, lst, lst_position,
                                             idx1, idx1_position,
                                             idx2, idx2_position)
    return err.err(state, lst_position, true,
                   'E475: Expecting function reference, not List')
  end,

  lock_dict = function(...)
    return set_dict_lock(VAR_LOCKED, ...)
  end,

  lock_slice = function(...)
    return set_slice_lock(VAR_LOCKED, ...)
  end,

  unlock_dict = function(...)
    return set_dict_lock(nil, ...)
  end,

  unlock_slice = function(...)
    return set_slice_lock(nil, ...)
  end,
}

-- {{{1 Range handling
local range
range = {
  compose = function(state, ...)
    local ret = {
      iter = range.iter,
    }
  end,
  apply_followup = function(state, followup_type, followup_data, lnr)
  end,

  iter = function(range)
  end,

  mark = function(state, mark)
  end,
  forward_search = function(state, regex)
  end,
  backward_search = function(state, regex)
  end,
  last = function(state)
  end,
  current = function(state)
  end,
  substitute_search = function(state)
  end,
  forward_previous_search = function(state)
  end,
  backward_previous_search = function(state)
  end,
}

-- {{{1 vim_type and is_* functions
local type_table = {
  ['string'] = string,
  ['number'] = number,
  ['function'] = func,
}

vim_type = function(val)
  return val and (type_table[type(val)] or val[type_idx])
end

local func_table = {
  [func] = true,
  [bound_func] = true,
}

is_func = function(val)
  return func_table[vim_type(val)]
end

is_dict = function(val)
  return (type(val) == 'table'
          and val[type_idx].type_number == BASE_TYPE_DICTIONARY)
end

is_list = function(val)
  return (type(val) == 'table' and val[type_idx] == list)
end

is_float = function(val)
  return (type(val) == 'table' and val[type_idx] == float)
end

-- {{{1 Operators
local iterop = function(state, op, ...)
  local result = select(1, ...)
  local result_position = select(2, ...)
  if result == nil then
    return nil
  end
  local tr = vim_type(result)
  for i = 2,select('#', ...)/2 do
    local v = select(i*2 - 1, ...)
    local v_position = select(i*2, ...)
    if v == nil then
      return nil
    end
    local ti = vim_type(v)
    if tr.num_op_priority >= ti.num_op_priority then
      result = tr[op](state, result, result_position, v, v_position)
    else
      result = ti[op](state, result, result_position, v, v_position)
    end
    result_position = v_position
    tr = vim_type(result)
  end
  return result
end

local vim_true = 1
local vim_false = 0

get_cmp_t = function(t1, t2)
  if t1.cmp_priority >= t2.cmp_priority then
    return t1
  else
    return t2
  end
end

local cmp = function(state, ic, eq, arg1, arg1_position, arg2, arg2_position)
  if not (arg1 and arg2) then
    return nil
  end
  local t1 = vim_type(arg1)
  local t2 = vim_type(arg2)
  local cmp = get_cmp_t(vim_type(arg1), vim_type(arg2)).cmp
  return cmp(state, ic, eq, arg1, arg1_position,
                            arg2, arg2_position)
end

local simple_identical = {
  [BASE_TYPE_LIST] = true,
  [BASE_TYPE_DICTIONARY] = true,
  [BASE_TYPE_FUNCREF] = true,
  [BASE_TYPE_NUMBER] = true,
}

op = {
  add = function(state, ...)
    return iterop(state, 'add', ...)
  end,

  mod_add = function(state, ...)
    return iterop(state, 'mod_add', ...)
  end,

  subtract = function(state, ...)
    return iterop(state, 'subtract', ...)
  end,

  multiply = function(state, ...)
    return iterop(state, 'multiply', ...)
  end,

  divide = function(state, ...)
    return iterop(state, 'divide', ...)
  end,

  modulo = function(state, ...)
    return iterop(state, 'modulo', ...)
  end,

  concat = function(state, ...)
    local result = select(1, ...)
    local result_position = select(2, ...)
    result = result and get_string(state, result, result_position)
    if result == nil then
      return nil
    end
    for i = 2,select('#', ...)/2 do
      local v = select(i * 2 - 1, ...)
      local v_position = select(i * 2, ...)
      v = v and get_string(state, v, v_position)
      if v == nil then
        return nil
      end
      result = result .. v
    end
    return result
  end,

  negate = function(state, val, val_position)
    local t = vim_type(val)
    return t.negate(state, val, val_position)
  end,

  negate_logical = function(state, val, val_position)
    return val and (get_number(state, val, val_position) == 0
                    and vim_true or vim_false)
  end,

  promote_integer = function(state, val, val_position)
    local t = vim_type(val)
    return t.promote_integer(state, val, val_position)
  end,

  identical = function(state, ic, arg1, arg1_position, arg2, arg2_position)
    if not (arg1 or arg2) then
      return nil
    end
    local t1 = vim_type(arg1)
    local t2 = vim_type(arg2)
    if (t1.type_number ~= t2.type_number) then
      return vim_false
    elseif simple_identical[t1.type_number] then
      return (arg1 == arg2) and vim_true or vim_false
    else
      return op.equals(state, ic, arg1, arg1_position, arg2, arg2_position)
    end
  end,

  matches = function(state, ic, arg1, arg1_position, arg2, arg2_position)
    if not (arg1 or arg2) then
      return nil
    end
    -- TODO
  end,

  less = function(state, ic, arg1, arg1_position, arg2, arg2_position)
    return (cmp(state, ic, false, arg1, arg1_position, arg2, arg2_position)
            == -1) and vim_true or vim_false
  end,

  greater = function(state, ic, arg1, arg1_position, arg2, arg2_position)
    return (cmp(state, ic, false, arg1, arg1_position, arg2, arg2_position)
            == 1) and vim_true or vim_false
  end,

  equals = function(state, ic, arg1, arg1_position, arg2, arg2_position)
    return (cmp(state, ic, true, arg1, arg1_position, arg2, arg2_position)
            == 0) and vim_true or vim_false
  end,
}

op.mod_concat = op.concat
op.mod_subtract = op.subtract

-- {{{1 Subscripting
subscript = {
  subscript = function(state, bind, val, val_position, idx, idx_position)
    if not (val and idx) then
      return nil
    end
    local t = vim_type(val)
    local ret = t.subscript(state, val, val_position, idx, idx_position)
    if bind and is_func(ret) and t.can_be_self then
      return bound_func:new(state, ret, val)
    else
      return ret
    end
  end,

  slice = function(state, val, val_position, idx1, idx1_position,
                                             idx2, idx2_position)
    if not (val and idx1 and idx2) then
      return nil
    end
    local t = vim_type(val)
    return t.slice(state, val, val_position, idx1 or  0, idx1_position,
                                             idx2 or -1, idx2_position)
  end,

  call = non_nil(function(state, callee, callee_position, ...)
    local t = vim_type(callee)
    return t.call(state, callee, callee_position, ...)
  end),
}

local concat_or_subscript = function(state, bind, dct, dct_position,
                                                  key, key_position)
  if is_dict(dct) then
    local t = dct[type_idx]
    local ret = t.subscript(state, dct, dct_position, key, key_position)
    if bind and t.can_be_self and is_func(ret) then
      return bound_func:new(state, ret, dct)
    else
      return ret
    end
  else
    return op.concat(state, dct, key)
  end
end

local scopes = {
  v = function(state) return state.global.v end,
  g = function(state) return state.global.g end,

  s = function(state) return state.s end,
  a = function(state) return state.a end,

  l = function(state) return state.l end,

  t = function(state) return state.global.tabpage.t end,
  w = function(state) return state.global.window.w end,
  b = function(state) return state.global.buffer.b end,
}

local get_scope_and_key = function(state, key, key_position)
  -- FIXME This function duplicates part of the functionality of 
  -- “translate_scope” function.
  if not key then
    return nil
  end
  if key:sub(2, 2) == ':' then
    if scopes[key:sub(1, 1)] then
      return scopes[key:sub(1, 1)](state), key_position, key:sub(3), key_position
    end
  end
  return state.current_scope, key_position, key, key_position
end

-- {{{1 Test helpers
local test_ret
-- WARNING: When type dictionary is copied luajit crashes
local test_copy_methods = {
  [type_idx] = function(v)
    return v
  end,
}
local test_echo = function(state, ...)
  test_ret[#test_ret + 1] = copy_value(select(1, ...), test_copy_methods)
end
local test_state
local test_state_copy
local test = {
  start = function()
    if not recorded_vim_global then
      globals_at_start.vim = vim
      recorded_vim_global = true
    end
    test_ret = list:new(nil)
    commands.echo = test_echo
    local old_enter_code = state.enter_code
    state.enter_code = function(...)
      local state = old_enter_code(...)
      if not test_state then
        test_state = state
        test_state_copy = copy_value(state, test_copy_methods)
      end
      return state
    end
  end,
  finish = function(state)
    if state ~= test_state then
      test_echo(nil, 'State table is different')
    else
      local differs, what, key, diff = compare_tables_recursive(
        test_state_copy,state)
      if differs then
        test_echo(nil, ({
          missing1='New key found: %s',
          missing2='Key not present in state: %s',
          differs='Value differs: %s (%s)',
        })[what]:format(key, diff))
      end
    end
    for k, v in pairs(globals_at_start) do
      if _G[k] ~= v then
        test_echo(nil, 'Found modified global: ' .. k)
      end
    end
    for k, _ in pairs(_G) do
      if globals_at_start[k] == nil then
        test_echo(nil, 'Found new global: ' .. k)
      end
    end
    local old_ret = test_ret
    test_ret = nil
    test_state = nil
    return old_ret
  end,
}

-- {{{1 return
local zero = 0
return {
  state = state,
  new_script_scope = new_script_scope,
  set_script_locals = set_script_locals,
  commands = commands,
  functions = functions,
  range = range,
  run_user_command = run_user_command,
  iter_start = iter_start,
  subscript = subscript,
  list = list,
  dict = dict,
  func = func,
  concat_or_subscript = concat_or_subscript,
  get_scope_and_key = get_scope_and_key,
  op = op,
  number = number,
  string = string,
  float = float,
  err = err,
  assign = assign,
  get_boolean = get_boolean,
  zero_ = zero,
  false_ = zero,
  true_ = 1,
  type = vim_type,
  iter = iter,
  types = {
    number = number,
    string = string,
    list = list,
    dict = dict,
    float = float,
  },
  is_func = is_func,
  is_dict = is_dict,
  is_list = is_list,
  is_float = is_float,
  get_local_option = get_local_option,
  test = test,
}
