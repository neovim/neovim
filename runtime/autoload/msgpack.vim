if exists('g:loaded_msgpack_autoload')
  finish
endif
let g:loaded_msgpack_autoload = 1

""
" Check that given value is an integer. Respects |msgpack-special-dict|.
function msgpack#is_int(v) abort
  return type(a:v) == type(0) || (
        \type(a:v) == type({}) && get(a:v, '_TYPE') is# v:msgpack_types.integer)
endfunction

""
" Check that given value is an unsigned integer. Respects 
" |msgpack-special-dict|.
function msgpack#is_uint(v) abort
  return msgpack#is_int(a:v) && (type(a:v) == type(0)
                                \? a:v >= 0
                                \: a:v._VAL[0] > 0)
endfunction

""
" True if s:msgpack_init_python() function was already run.
let s:msgpack_python_initialized = 0

""
" Cached return of s:msgpack_init_python() used when 
" s:msgpack_python_initialized is true.
let s:msgpack_python_type = 0

""
" Create Python functions that are necessary for work. Also defines functions 
" s:msgpack_dict_strftime(format, timestamp) and s:msgpack_dict_strptime(format, 
" string).
"
" @return Zero in case no Python is available, empty string if Python-2 is 
"         available and string `"3"` if Python-3 is available.
function s:msgpack_init_python() abort
  if s:msgpack_python_initialized
    return s:msgpack_python_type
  endif
  let s:msgpack_python_initialized = 1
  for suf in (has('win32') ? ['3'] : ['', '3'])
    try
      execute 'python' . suf
              \. "\n"
              \. "def shada_dict_strftime():\n"
              \. "  import datetime\n"
              \. "  import vim\n"
              \. "  fmt = vim.eval('a:format')\n"
              \. "  timestamp = vim.eval('a:timestamp')\n"
              \. "  timestamp = [int(v) for v in timestamp['_VAL']]\n"
              \. "  timestamp = timestamp[0] * (timestamp[1] << 62\n"
              \. "                              | timestamp[2] << 31\n"
              \. "                              | timestamp[3])\n"
              \. "  time = datetime.datetime.fromtimestamp(timestamp)\n"
              \. "  return time.strftime(fmt)\n"
              \. "def shada_dict_strptime():\n"
              \. "  import calendar\n"
              \. "  import datetime\n"
              \. "  import vim\n"
              \. "  fmt = vim.eval('a:format')\n"
              \. "  timestr = vim.eval('a:string')\n"
              \. "  timestamp = datetime.datetime.strptime(timestr, fmt)\n"
              \. "  try:\n"
              \. "    timestamp = int(timestamp.timestamp())\n"
              \. "  except:\n"
              \. "    try:\n"
              \. "      timestamp = int(timestamp.strftime('%s'))\n"
              \. "    except:\n"
              \. "      timestamp = calendar.timegm(timestamp.utctimetuple())\n"
              \. "  if timestamp > 2 ** 31:\n"
              \. "    tsabs = abs(timestamp)\n"
              \. "    return ('{\"_TYPE\": v:msgpack_types.integer,'\n"
              \. "            + '\"_VAL\": [{sign},{v1},{v2},{v3}]}').format(\n"
              \. "              sign=(1 if timestamp >= 0 else -1),\n"
              \. "              v1=((tsabs >> 62) & 0x3),\n"
              \. "              v2=((tsabs >> 31) & (2 ** 31 - 1)),\n"
              \. "              v3=(tsabs & (2 ** 31 - 1)))\n"
              \. "  else:\n"
              \. "    return str(timestamp)\n"
      execute  "function s:msgpack_dict_strftime(format, timestamp) abort\n"
            \. "  return py" . suf . "eval('shada_dict_strftime()')\n"
            \. "endfunction\n"
            \. "function s:msgpack_dict_strptime(format, string)\n"
            \. "  return eval(py" . suf . "eval('shada_dict_strptime()'))\n"
            \. "endfunction\n"
      let s:msgpack_python_type = suf
      return suf
    catch
      continue
    endtry
  endfor

  ""
  " strftime() function for |msgpack-special-dict| values.
  "
  " @param[in]  format     String according to which time should be formatted.
  " @param[in]  timestamp  Timestamp (seconds since epoch) to format.
  "
  " @return Formatted timestamp.
  "
  " @warning Without +python or +python3 this function does not work correctly. 
  "          The VimL code contains “reference” implementation which does not 
  "          really work because of precision loss.
  function s:msgpack_dict_strftime(format, timestamp)
    return msgpack#strftime(a:format, +msgpack#int_dict_to_str(a:timestamp))
  endfunction

  ""
  " Function that parses given string according to given format.
  "
  " @param[in]  format  String according to which string was formatted.
  " @param[in]  string  Time formatted according to format.
  "
  " @return Timestamp.
  "
  " @warning Without +python or +python3 this function is able to work only with 
  "          31-bit (32-bit signed) timestamps that have format 
  "          `%Y-%m-%dT%H:%M:%S`.
  function s:msgpack_dict_strptime(format, string)
    let fmt = '%Y-%m-%dT%H:%M:%S'
    if a:format isnot# fmt
      throw 'notimplemented-format:Only ' . fmt . ' format is supported'
    endif
    let match = matchlist(a:string,
                         \'\v\C^(\d+)\-(\d+)\-(\d+)T(\d+)\:(\d+)\:(\d+)$')
    if empty(match)
      throw 'invalid-string:Given string does not match format ' . a:format
    endif
    call map(match, 'str2nr(v:val, 10)')
    let [year, month, day, hour, minute, second] = match[1:6]
    " Bisection start and end:
    "
    " Start: 365 days in year, 28 days in month, -12 hours tz offset.
    let bisect_ts_start = (((((year - 1970) * 365
                             \+ (month - 1) * 28
                             \+ (day - 1)) * 24
                            \+ hour - 12) * 60
                           \+ minute) * 60
                          \+ second)
    if bisect_ts_start < 0
      let bisect_ts_start = 0
    endif
    let start_string = strftime(fmt, bisect_ts_start)
    if start_string is# a:string
      return bisect_ts_start
    endif
    " End: 366 days in year, 31 day in month, +14 hours tz offset.
    let bisect_ts_end = (((((year - 1970) * 366
                           \+ (month - 1) * 31
                           \+ (day - 1)) * 24
                          \+ hour + 14) * 60
                         \+ minute) * 60
                        \+ second)
    let end_string = strftime(fmt, bisect_ts_end)
    if end_string is# a:string
      return bisect_ts_end
    endif
    if start_string ># end_string
      throw 'internal-start-gt:Internal error: start > end'
    endif
    if start_string is# end_string
      throw printf('internal-start-eq:Internal error: '
                  \. 'start(%u)==end(%u), but start(%s)!=string(%s)',
                  \bisect_ts_start, bisect_ts_end,
                  \string(start_string), string(a:string))
    endif
    if start_string ># a:string
      throw 'internal-start-string:Internal error: start > string'
    endif
    if end_string <# a:string
      throw 'internal-end-string:Internal error: end < string'
    endif
    while 1
      let bisect_ts_middle = (bisect_ts_start/2) + (bisect_ts_end/2)
      let middle_string = strftime(fmt, bisect_ts_middle)
      if a:string is# middle_string
        return bisect_ts_middle
      elseif a:string ># middle_string
        if bisect_ts_middle == bisect_ts_start
          let bisect_ts_start += 1
        else
          let bisect_ts_start = bisect_ts_middle
        endif
      else
        if bisect_ts_middle == bisect_ts_end
          let bisect_ts_end -= 1
        else
          let bisect_ts_end = bisect_ts_middle
        endif
      endif
      if bisect_ts_start >= bisect_ts_end
        throw 'not-found:Unable to find timestamp'
      endif
    endwhile
  endfunction

  return 0
endfunction

""
" Wrapper for strftime() that respects |msgpack-special-dict|. May actually use 
" non-standard strftime() implementations for |msgpack-special-dict| values.
"
" @param[in]  format     Format string.
" @param[in]  timestamp  Formatted timestamp.
function msgpack#strftime(format, timestamp) abort
  if type(a:timestamp) == type({})
    call s:msgpack_init_python()
    return s:msgpack_dict_strftime(a:format, a:timestamp)
  else
    return strftime(a:format, a:timestamp)
  endif
endfunction

""
" Parse string according to the format.
"
" Requires +python available. If it is not then only supported format is 
" `%Y-%m-%dT%H:%M:%S` because this is the format used by ShaDa plugin. Also in 
" this case bisection will be used (timestamps tried with strftime() up until 
" result matches the string) and only 31-bit (signed 32-bit: with negative 
" timestamps being useless this leaves 31 bits) timestamps will be supported.
"
" @param[in]  format  Time format.
" @param[in]  string  Parsed time string. Must match given format.
"
" @return Timestamp. Possibly as |msgpack-special-dict|.
function msgpack#strptime(format, string) abort
  call s:msgpack_init_python()
  return s:msgpack_dict_strptime(a:format, a:string)
endfunction

let s:MSGPACK_HIGHEST_BIT = 1
let s:MSGPACK_HIGHEST_BIT_NR = 0
while s:MSGPACK_HIGHEST_BIT * 2 > 0
  let s:MSGPACK_HIGHEST_BIT = s:MSGPACK_HIGHEST_BIT * 2
  let s:MSGPACK_HIGHEST_BIT_NR += 1
endwhile

""
" Shift given number by given amount of bits
function s:shift(n, s) abort
  if a:s == 0
    return a:n
  elseif a:s < 0
    let ret = a:n
    for _ in range(-a:s)
      let ret = ret / 2
    endfor
    return ret
  else
    let ret = a:n
    for i in range(a:s)
      let new_ret = ret * 2
      if new_ret < ret
        " Overflow: remove highest bit
        let ret = xor(s:MSGPACK_HIGHEST_BIT, ret) * 2
      endif
      let ret = new_ret
    endfor
    return ret
  endif
endfunction

let s:msgpack_mask_cache = {
      \s:MSGPACK_HIGHEST_BIT_NR : s:MSGPACK_HIGHEST_BIT - 1}

""
" Apply a mask where first m bits are ones and other are zeroes to a given 
" number
function s:mask1(n, m) abort
  if a:m > s:MSGPACK_HIGHEST_BIT_NR + 1
    let m = s:MSGPACK_HIGHEST_BIT_NR + 1
  else
    let m = a:m
  endif
  if !has_key(s:msgpack_mask_cache, m)
    let p = 0
    for _ in range(m)
      let p = p * 2 + 1
    endfor
    let s:msgpack_mask_cache[m] = p
  endif
  return and(a:n, s:msgpack_mask_cache[m])
endfunction

""
" Convert |msgpack-special-dict| that represents integer value to a string. Uses 
" hexadecimal representation starting with 0x because it is the easiest to 
" convert to.
function msgpack#int_dict_to_str(v) abort
  let v = a:v._VAL
  " 64-bit number:
  " 0000000001111111111222222222233333333334444444444555555555566666
  " 1234567890123456789012345678901234567890123456789012345678901234
  " Split in _VAL:
  " 0000000001111111111222222222233 3333333344444444445555555555666 66
  " 1234567890123456789012345678901 2345678901234567890123456789012 34
  " Split by hex digits:
  " 0000 0000 0111 1111 1112 2222 2222 2333 3333 3334 4444 4444 4555 5555 5556 6666
  " 1234 5678 9012 3456 7890 1234 5678 9012 3456 7890 1234 5678 9012 3456 7890 1234
  "
  " Total split:
  "                _VAL[3]                              _VAL[2]                      _VAL[1]
  " ______________________________________  _______________________________________  __
  " 0000 0000 0111 1111 1112 2222 2222 233  3 3333 3334 4444 4444 4555 5555 5556 66  66
  " 1234 5678 9012 3456 7890 1234 5678 901  2 3456 7890 1234 5678 9012 3456 7890 12  34
  " ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ^^^^^^ ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ^^^^^^
  "                g4                    g3                  g2                    g1
  " ********************************** ***  * ********************************** **  **
  "                1                    2   3                4                   5   6
  " 1: s:mask1(v[3], 28): first 28 bits of _VAL[3]
  " 2: s:shift(v[3], -28): last 3 bits of _VAL[3]
  " 3: s:mask1(v[2], 1): first bit of _VAL[2]
  " 4: s:mask1(s:shift(v[2], -1), 28): bits 2 .. 29 of _VAL[2]
  " 5: s:shift(v[2], -29): last 2 bits of _VAL[2]
  " 6: s:shift(v[1], 2): _VAL[1]
  let g4 = printf('%07x', s:mask1(v[3], 28))
  let g3 = printf('%01x', or(s:shift(v[3], -28), s:shift(s:mask1(v[2], 1), 3)))
  let g2 = printf('%07x', s:mask1(s:shift(v[2], -1), 28))
  let g1 = printf('%01x', or(s:shift(v[2], -29), s:shift(v[1], 2)))
  return ((v[0] < 0 ? '-' : '') . '0x' . g1 . g2 . g3 . g4)
endfunction

""
" True boolean value.
let g:msgpack#true = {'_TYPE': v:msgpack_types.boolean, '_VAL': 1}
lockvar! g:msgpack#true

""
" False boolean value.
let g:msgpack#false = {'_TYPE': v:msgpack_types.boolean, '_VAL': 0}
lockvar! g:msgpack#false

""
" NIL value.
let g:msgpack#nil = {'_TYPE': v:msgpack_types.nil, '_VAL': 0}
lockvar! g:msgpack#nil

""
" Deduce type of |msgpack-special-dict|.
"
" @return zero if given dictionary is not special or name of the key in 
"         v:msgpack_types dictionary.
function msgpack#special_type(v) abort
  if type(a:v) != type({}) || !has_key(a:v, '_TYPE')
    return 0
  endif
  for [k, v] in items(v:msgpack_types)
    if a:v._TYPE is v
      return k
    endif
  endfor
  return 0
endfunction

""
" Mapping that maps type() output to type names.
let s:MSGPACK_STANDARD_TYPES = {
  \type(0): 'integer',
  \type(0.0): 'float',
  \type(''): 'binary',
  \type([]): 'array',
  \type({}): 'map',
  \type(v:true): 'boolean',
  \type(v:null): 'nil',
\}

""
" Deduce type of one of items returned by msgpackparse().
"
" @return Name of a key in v:msgpack_types.
function msgpack#type(v) abort
  let special_type = msgpack#special_type(a:v)
  if special_type is 0
    return s:MSGPACK_STANDARD_TYPES[type(a:v)]
  endif
  return special_type
endfunction

""
" Dump nil value.
function s:msgpack_dump_nil(v) abort
  return 'NIL'
endfunction

""
" Dump boolean value.
function s:msgpack_dump_boolean(v) abort
  return (a:v is v:true || (a:v isnot v:false && a:v._VAL)) ? 'TRUE' : 'FALSE'
endfunction

""
" Dump integer msgpack value.
function s:msgpack_dump_integer(v) abort
  if type(a:v) == type({})
    return msgpack#int_dict_to_str(a:v)
  else
    return string(a:v)
  endif
endfunction

""
" Dump floating-point value.
function s:msgpack_dump_float(v) abort
  return substitute(string(type(a:v) == type({}) ? a:v._VAL : a:v),
                   \'\V\^\(-\)\?str2float(''\(inf\|nan\)'')\$', '\1\2', '')
endfunction

""
" Dump |msgpack-special-dict| that represents a string. If any additional 
" parameter is given then it dumps binary string.
function s:msgpack_dump_string(v, ...) abort
  let ret = [a:0 ? '"' : '="']
  for v in a:v._VAL
    call add(
          \ret,
          \substitute(
            \substitute(v, '["\\]', '\\\0', 'g'),
            \'\n', '\\0', 'g'))
    call add(ret, '\n')
  endfor
  let ret[-1] = '"'
  return join(ret, '')
endfunction

""
" Dump binary string.
function s:msgpack_dump_binary(v) abort
  if type(a:v) == type({})
    return s:msgpack_dump_string(a:v, 1)
  else
    return s:msgpack_dump_string({'_VAL': split(a:v, "\n", 1)}, 1)
  endif
endfunction

""
" Dump array value.
function s:msgpack_dump_array(v) abort
  let val = type(a:v) == type({}) ? a:v._VAL : a:v
  return '[' . join(map(val[:], 'msgpack#string(v:val)'), ', ') . ']'
endfunction

""
" Dump dictionary value.
function s:msgpack_dump_map(v) abort
  let ret = ['{']
  if msgpack#special_type(a:v) is 0
    for [k, v] in items(a:v)
      let ret += [s:msgpack_dump_string({'_VAL': split(k, "\n", 1)}),
                 \': ',
                 \msgpack#string(v),
                 \', ']
      unlet v
    endfor
    if !empty(a:v)
      call remove(ret, -1)
    endif
  else
    for [k, v] in sort(copy(a:v._VAL))
      let ret += [msgpack#string(k),
                 \': ',
                 \msgpack#string(v),
                 \', ']
      unlet k
      unlet v
    endfor
    if !empty(a:v._VAL)
      call remove(ret, -1)
    endif
  endif
  let ret += ['}']
  return join(ret, '')
endfunction

""
" Dump extension value.
function s:msgpack_dump_ext(v) abort
  return printf('+(%i)%s', a:v._VAL[0],
               \s:msgpack_dump_string({'_VAL': a:v._VAL[1]}, 1))
endfunction

""
" Convert msgpack object to a string, like string() function does. Result of the 
" conversion may be passed to msgpack#eval().
function msgpack#string(v) abort
  if type(a:v) == type({})
    let type = msgpack#special_type(a:v)
    if type is 0
      let type = 'map'
    endif
  else
    let type = get(s:MSGPACK_STANDARD_TYPES, type(a:v), 0)
    if type is 0
      throw printf('msgpack:invtype: Unable to convert value %s', string(a:v))
    endif
  endif
  return s:msgpack_dump_{type}(a:v)
endfunction

""
" Copy msgpack object like deepcopy() does, but leave types intact
function msgpack#deepcopy(obj) abort
  if type(a:obj) == type([])
    return map(copy(a:obj), 'msgpack#deepcopy(v:val)')
  elseif type(a:obj) == type({})
    let special_type = msgpack#special_type(a:obj)
    if special_type is 0
      return map(copy(a:obj), 'msgpack#deepcopy(v:val)')
    else
      return {
        \'_TYPE': v:msgpack_types[special_type],
        \'_VAL': msgpack#deepcopy(a:obj._VAL)
      \}
    endif
  else
    return copy(a:obj)
  endif
endfunction

""
" Convert an escaped character to needed value
function s:msgpack_eval_str_sub(ch) abort
  if a:ch is# 'n'
    return '", "'
  elseif a:ch is# '0'
    return '\n'
  else
    return '\' . a:ch
  endif
endfunction

let s:MSGPACK_SPECIAL_OBJECTS = {
  \'NIL': '{''_TYPE'': v:msgpack_types.nil, ''_VAL'': 0}',
  \'TRUE': '{''_TYPE'': v:msgpack_types.boolean, ''_VAL'': 1}',
  \'FALSE': '{''_TYPE'': v:msgpack_types.boolean, ''_VAL'': 0}',
  \'nan': '(-(1.0/0.0-1.0/0.0))',
  \'inf': '(1.0/0.0)',
\}

""
" Convert msgpack object dumped by msgpack#string() to a VimL object suitable 
" for msgpackdump().
"
" @param[in]  s             String to evaluate.
" @param[in]  special_objs  Additional special objects, in the same format as 
"                           s:MSGPACK_SPECIAL_OBJECTS.
"
" @return Any value that msgpackparse() may return.
function msgpack#eval(s, special_objs) abort
  let s = a:s
  let expr = []
  let context = []
  while !empty(s)
    let s = substitute(s, '^\s*', '', '')
    if s[0] =~# '\v^\h$'
      let name = matchstr(s, '\v\C^\w+')
      if has_key(s:MSGPACK_SPECIAL_OBJECTS, name)
        call add(expr, s:MSGPACK_SPECIAL_OBJECTS[name])
      elseif has_key(a:special_objs, name)
        call add(expr, a:special_objs[name])
      else
        throw 'name-unknown:Unknown name ' . name . ': ' . s
      endif
      let s = s[len(name):]
    elseif (s[0] is# '-' && s[1] =~# '\v^\d$') || s[0] =~# '\v^\d$'
      let sign = 1
      if s[0] is# '-'
        let s = s[1:]
        let sign = -1
      endif
      if s[0:1] is# '0x'
        " See comment in msgpack#int_dict_to_str().
        let s = s[2:]
        let hexnum = matchstr(s, '\v\C^\x+')
        if empty(hexnum)
          throw '0x-empty:Must have number after 0x: ' . s
        elseif len(hexnum) > 16
          throw '0x-long:Must have at most 16 hex digits: ' . s
        endif
        let s = s[len(hexnum):]
        let hexnum = repeat('0', 16 - len(hexnum)) . hexnum
        let g1 = str2nr(hexnum[0], 16)
        let g2 = str2nr(hexnum[1:7], 16)
        let g3 = str2nr(hexnum[8], 16)
        let g4 = str2nr(hexnum[9:15], 16)
        let v1 = s:shift(g1, -2)
        let v2 = or(or(s:shift(s:mask1(g1, 2), 29), s:shift(g2, 1)),
                   \s:mask1(s:shift(g3, -3), 1))
        let v3 = or(s:shift(s:mask1(g3, 3), 28), g4)
        call add(expr, printf('{''_TYPE'': v:msgpack_types.integer, '.
                             \'''_VAL'': [%i, %u, %u, %u]}',
                             \sign, v1, v2, v3))
      else
        let num = matchstr(s, '\v\C^\d+')
        let s = s[len(num):]
        if sign == -1
          call add(expr, '-')
        endif
        call add(expr, num)
        if s[0] is# '.'
          let dec = matchstr(s, '\v\C^\.\d+%(e[+-]?\d+)?')
          if empty(dec)
            throw '0.-nodigits:Decimal dot must be followed by digit(s): ' . s
          endif
          let s = s[len(dec):]
          call add(expr, dec)
        endif
      endif
    elseif s =~# '\v^\-%(inf|nan)'
      call add(expr, '-')
      call add(expr, s:MSGPACK_SPECIAL_OBJECTS[s[1:3]])
      let s = s[4:]
    elseif stridx('="+', s[0]) != -1
      let match = matchlist(s, '\v\C^(\=|\+\((\-?\d+)\)|)(\"%(\\.|[^\\"]+)*\")')
      if empty(match)
        throw '"-invalid:Invalid string: ' . s
      endif
      call add(expr, '{''_TYPE'': v:msgpack_types.')
      if empty(match[1])
        call add(expr, 'binary')
      elseif match[1] is# '='
        call add(expr, 'string')
      else
        call add(expr, 'ext')
      endif
      call add(expr, ', ''_VAL'': [')
      if match[1][0] is# '+'
        call add(expr, match[2] . ', [')
      endif
      call add(expr, substitute(match[3], '\v\C\\(.)',
                               \'\=s:msgpack_eval_str_sub(submatch(1))', 'g'))
      if match[1][0] is# '+'
        call add(expr, ']')
      endif
      call add(expr, ']}')
      let s = s[len(match[0]):]
    elseif s[0] is# '{'
      call add(context, 'map')
      call add(expr, '{''_TYPE'': v:msgpack_types.map, ''_VAL'': [')
      call add(expr, '[')
      let s = s[1:]
    elseif s[0] is# '['
      call add(context, 'array')
      call add(expr, '[')
      let s = s[1:]
    elseif s[0] is# ':'
      call add(expr, ',')
      let s = s[1:]
    elseif s[0] is# ','
      if context[-1] is# 'array'
        call add(expr, ',')
      else
        call add(expr, '], [')
      endif
      let s = s[1:]
    elseif s[0] is# ']'
      call remove(context, -1)
      call add(expr, ']')
      let s = s[1:]
    elseif s[0] is# '}'
      call remove(context, -1)
      if expr[-1] is# "\x5B"
        call remove(expr, -1)
      else
        call add(expr, ']')
      endif
      call add(expr, ']}')
      let s = s[1:]
    elseif s[0] is# ''''
      let char = matchstr(s, '\v\C^\''\zs%(\\\d+|.)\ze\''')
      if empty(char)
        throw 'char-invalid:Invalid integer character literal format: ' . s
      endif
      if char[0] is# '\'
        call add(expr, +char[1:])
      else
        call add(expr, char2nr(char))
      endif
      let s = s[len(char) + 2:]
    else
      throw 'unknown:Invalid non-space character: ' . s
    endif
  endwhile
  if empty(expr)
    throw 'empty:Parsed string is empty'
  endif
  return eval(join(expr, ''))
endfunction

""
" Check whether two msgpack values are equal
function msgpack#equal(a, b)
  let atype = msgpack#type(a:a)
  let btype = msgpack#type(a:b)
  if atype isnot# btype
    return 0
  endif
  let aspecial = msgpack#special_type(a:a)
  let bspecial = msgpack#special_type(a:b)
  if aspecial is# bspecial
    if aspecial is# 0
      if type(a:a) == type({})
        if len(a:a) != len(a:b)
          return 0
        endif
        if !empty(filter(keys(a:a), '!has_key(a:b, v:val)'))
          return 0
        endif
        for [k, v] in items(a:a)
          if !msgpack#equal(v, a:b[k])
            return 0
          endif
          unlet v
        endfor
        return 1
      elseif type(a:a) == type([])
        if len(a:a) != len(a:b)
          return 0
        endif
        let i = 0
        for asubval in a:a
          if !msgpack#equal(asubval, a:b[i])
            return 0
          endif
          let i += 1
          unlet asubval
        endfor
        return 1
      elseif type(a:a) == type(0.0)
        return (a:a == a:a ? a:a == a:b : string(a:a) ==# string(a:b))
      else
        return a:a ==# a:b
      endif
    elseif aspecial is# 'map' || aspecial is# 'array'
      if len(a:a._VAL) != len(a:b._VAL)
        return 0
      endif
      let alist = aspecial is# 'map' ? sort(copy(a:a._VAL)) : a:a._VAL
      let blist = bspecial is# 'map' ? sort(copy(a:b._VAL)) : a:b._VAL
      let i = 0
      for asubval in alist
        let bsubval = blist[i]
        if aspecial is# 'map'
          if !(msgpack#equal(asubval[0], bsubval[0])
              \&& msgpack#equal(asubval[1], bsubval[1]))
            return 0
          endif
        else
          if !msgpack#equal(asubval, bsubval)
            return 0
          endif
        endif
        let i += 1
        unlet asubval
        unlet bsubval
      endfor
      return 1
    elseif aspecial is# 'nil'
      return 1
    elseif aspecial is# 'float'
      return (a:a._VAL == a:a._VAL
             \? (a:a._VAL == a:b._VAL)
             \: (string(a:a._VAL) ==# string(a:b._VAL)))
    else
      return a:a._VAL ==# a:b._VAL
    endif
  else
    if atype is# 'array'
      let a = aspecial is 0 ? a:a : a:a._VAL
      let b = bspecial is 0 ? a:b : a:b._VAL
      return msgpack#equal(a, b)
    elseif atype is# 'binary'
      let a = (aspecial is 0 ? split(a:a, "\n", 1) : a:a._VAL)
      let b = (bspecial is 0 ? split(a:b, "\n", 1) : a:b._VAL)
      return a ==# b
    elseif atype is# 'map'
      if aspecial is 0
        let akeys = copy(a:a)
        if len(a:b._VAL) != len(akeys)
          return 0
        endif
        for [k, v] in a:b._VAL
          if msgpack#type(k) isnot# 'string'
            " Non-special mapping cannot have non-string keys
            return 0
          endif
          if (empty(k._VAL)
             \|| k._VAL ==# [""]
             \|| !empty(filter(copy(k._VAL), 'stridx(v:val, "\n") != -1')))
            " Non-special mapping cannot have zero byte in key or an empty key
            return 0
          endif
          let kstr = join(k._VAL, "\n")
          if !has_key(akeys, kstr)
            " Protects from both missing and duplicate keys
            return 0
          endif
          if !msgpack#equal(akeys[kstr], v)
            return 0
          endif
          call remove(akeys, kstr)
          unlet k
          unlet v
        endfor
        return 1
      else
        return msgpack#equal(a:b, a:a)
      endif
    elseif atype is# 'float'
      let a = aspecial is 0 ? a:a : a:a._VAL
      let b = bspecial is 0 ? a:b : a:b._VAL
      return (a == a ? a == b : string(a) ==# string(b))
    elseif atype is# 'integer'
      if aspecial is 0
        let sign = a:a >= 0 ? 1 : -1
        let a = sign * a:a
        let v1 = s:mask1(s:shift(a, -62), 2)
        let v2 = s:mask1(s:shift(a, -31), 31)
        let v3 = s:mask1(a, 31)
        return [sign, v1, v2, v3] == a:b._VAL
      else
        return msgpack#equal(a:b, a:a)
      endif
    else
      throw printf('internal-invalid-type: %s == %s, but special %s /= %s',
                  \atype, btype, aspecial, bspecial)
    endif
  endif
endfunction
