if exists('g:loaded_shada_autoload')
  finish
endif
let g:loaded_shada_autoload = 1

""
" If true keep the old header entry when editing existing ShaDa file.
"
" Old header entry will be kept only if it is listed in the opened file. To 
" remove old header entry despite of the setting just remove it from the 
" listing. Setting it to false makes plugin ignore all header entries. Defaults 
" to 1.
let g:shada#keep_old_header = get(g:, 'shada#keep_old_header', 1)

""
" If true then first entry will be plugin’s own header entry.
let g:shada#add_own_header = get(g:, 'shada#add_own_header', 1)

""
" Dictionary that maps ShaDa types to their names.
let s:SHADA_ENTRY_NAMES = {
  \1: 'header',
  \2: 'search_pattern',
  \3: 'replacement_string',
  \4: 'history_entry',
  \5: 'register',
  \6: 'variable',
  \7: 'global_mark',
  \8: 'jump',
  \9: 'buffer_list',
  \10: 'local_mark',
  \11: 'change',
\}

""
" Dictionary that maps ShaDa names to corresponding types
let s:SHADA_ENTRY_TYPES = {}
call map(copy(s:SHADA_ENTRY_NAMES),
        \'extend(s:SHADA_ENTRY_TYPES, {v:val : +v:key})')

""
" Map that maps entry names to lists of keys that can be used by this entry. 
" Only contains data for entries which are represented as mappings, except for 
" the header.
let s:SHADA_MAP_ENTRIES = {
  \'search_pattern': ['sp', 'sh', 'ss', 'sb', 'sm', 'sc', 'sl', 'se', 'so',
  \                   'su'],
  \'register': ['n', 'rc', 'rw', 'rt', 'ru'],
  \'global_mark': ['n', 'f', 'l', 'c'],
  \'local_mark': ['f', 'n', 'l', 'c'],
  \'jump': ['f', 'l', 'c'],
  \'change': ['f', 'l', 'c'],
  \'header': [],
\}

""
" Like one of the values from s:SHADA_MAP_ENTRIES, but for a single buffer in 
" buffer list entry.
let s:SHADA_BUFFER_LIST_KEYS = ['f', 'l', 'c']

""
" List of possible history types. Maps integer values that represent history 
" types to human-readable names.
let s:SHADA_HISTORY_TYPES = ['command', 'search', 'expression', 'input', 'debug']

""
" Map that maps entry names to their descriptions. Only for entries which have 
" list as a data type. Description is a list of lists where each entry has item 
" description and item type.
let s:SHADA_FIXED_ARRAY_ENTRIES = {
  \'replacement_string': [[':s replacement string', 'bin']],
  \'history_entry': [
    \['history type', 'histtype'],
    \['contents', 'bin'],
    \['separator', 'intchar'],
  \],
  \'variable': [['name', 'bin'], ['value', 'any']],
\}

""
" Dictionary that maps enum names to dictionary with enum values. Dictionary 
" with enum values maps enum human-readable names to corresponding values. Enums 
" are used as type names in s:SHADA_FIXED_ARRAY_ENTRIES and 
" s:SHADA_STANDARD_KEYS.
let s:SHADA_ENUMS = {
  \'histtype': {
    \'CMD': 0,
    \'SEARCH': 1,
    \'EXPR': 2,
    \'INPUT': 3,
    \'DEBUG': 4,
  \},
  \'regtype': {
    \'CHARACTERWISE': 0,
    \'LINEWISE': 1,
    \'BLOCKWISE': 2,
  \}
\}

""
" Second argument to msgpack#eval.
let s:SHADA_SPECIAL_OBJS = {}
call map(values(s:SHADA_ENUMS),
        \'extend(s:SHADA_SPECIAL_OBJS, map(copy(v:val), "string(v:val)"))')

""
" Like s:SHADA_ENUMS, but inner dictionary maps values to names and not names to 
" values.
let s:SHADA_REV_ENUMS = map(copy(s:SHADA_ENUMS), '{}')
call map(copy(s:SHADA_ENUMS),
        \'map(copy(v:val), '
          \. '"extend(s:SHADA_REV_ENUMS[" . string(v:key) . "], '
                  \. '{v:val : v:key})")')

""
" Maximum length of ShaDa entry name. Used to arrange entries to the table.
let s:SHADA_MAX_ENTRY_LENGTH = max(
      \map(values(s:SHADA_ENTRY_NAMES), 'len(v:val)')
      \+ [len('unknown (0x)') + 16])

""
" Object that marks required value.
let s:SHADA_REQUIRED = []

""
" Dictionary that maps default key names to their description. Description is 
" a list that contains human-readable hint, key type and default value.
let s:SHADA_STANDARD_KEYS = {
  \'sm': ['magic value', 'boolean', g:msgpack#true],
  \'sc': ['smartcase value', 'boolean', g:msgpack#false],
  \'sl': ['has line offset', 'boolean', g:msgpack#false],
  \'se': ['place cursor at end', 'boolean', g:msgpack#false],
  \'so': ['offset value', 'integer', 0],
  \'su': ['is last used', 'boolean', g:msgpack#true],
  \'ss': ['is :s pattern', 'boolean', g:msgpack#false],
  \'sh': ['v:hlsearch value', 'boolean', g:msgpack#false],
  \'sp': ['pattern', 'bin', s:SHADA_REQUIRED],
  \'sb': ['search backward', 'boolean', g:msgpack#false],
  \'rt': ['type', 'regtype', s:SHADA_ENUMS.regtype.CHARACTERWISE],
  \'rw': ['block width', 'uint', 0],
  \'rc': ['contents', 'binarray', s:SHADA_REQUIRED],
  \'ru': ['is_unnamed', 'boolean', g:msgpack#false],
  \'n':  ['name', 'intchar', char2nr('"')],
  \'l':  ['line number', 'uint', 1],
  \'c':  ['column', 'uint', 0],
  \'f':  ['file name', 'bin', s:SHADA_REQUIRED],
\}

""
" Set of entry types containing entries which require `n` key.
let s:SHADA_REQUIRES_NAME = {'local_mark': 1, 'global_mark': 1, 'register': 1}

""
" Maximum width of human-readable hint. Used to arrange data in table.
let s:SHADA_MAX_HINT_WIDTH = max(map(values(s:SHADA_STANDARD_KEYS),
                                    \'len(v:val[0])'))

""
" Default mark name for the cases when it makes sense (i.e. for local marks).
let s:SHADA_DEFAULT_MARK_NAME = '"'

""
" Mapping that maps timestamps represented using msgpack#string to strftime 
" output. Used by s:shada_strftime.
let s:shada_strftime_cache = {}

""
" Mapping that maps strftime output from s:shada_strftime to timestamps.
let s:shada_strptime_cache = {}

""
" Time format used for displaying ShaDa files.
let s:SHADA_TIME_FORMAT = '%Y-%m-%dT%H:%M:%S'

""
" Wrapper around msgpack#strftime that caches its output.
"
" Format is hardcoded to s:SHADA_TIME_FORMAT.
function s:shada_strftime(timestamp) abort
  let key = msgpack#string(a:timestamp)
  if has_key(s:shada_strftime_cache, key)
    return s:shada_strftime_cache[key]
  endif
  let val = msgpack#strftime(s:SHADA_TIME_FORMAT, a:timestamp)
  let s:shada_strftime_cache[key] = val
  let s:shada_strptime_cache[val] = a:timestamp
  return val
endfunction

""
" Wrapper around msgpack#strftime that uses cache created by s:shada_strftime().
"
" Also caches its own results. Format is hardcoded to s:SHADA_TIME_FORMAT.
function s:shada_strptime(string) abort
  if has_key(s:shada_strptime_cache, a:string)
    return s:shada_strptime_cache[a:string]
  endif
  let ts = msgpack#strptime(s:SHADA_TIME_FORMAT, a:string)
  let s:shada_strptime_cache[a:string] = ts
  return ts
endfunction

""
" Check whether given value matches given type.
"
" @return Zero if value matches, error message string if it does not.
function s:shada_check_type(type, val) abort
  let type = msgpack#type(a:val)
  if type is# a:type
    return 0
  endif
  if has_key(s:SHADA_ENUMS, a:type)
    let msg = s:shada_check_type('uint', a:val)
    if msg isnot 0
      return msg
    endif
    if !has_key(s:SHADA_REV_ENUMS[a:type], a:val)
      let evals_msg = join(map(sort(items(s:SHADA_REV_ENUMS[a:type])),
                              \'v:val[0] . " (" . v:val[1] . ")"'), ', ')
      return 'Unexpected enum value: expected one of ' . evals_msg
    endif
    return 0
  elseif a:type is# 'uint'
    if type isnot# 'integer'
      return 'Expected integer'
    endif
    if !(type(a:val) == type({}) ? a:val._VAL[0] == 1 : a:val >= 0)
      return 'Value is negative'
    endif
    return 0
  elseif a:type is# 'bin'
    " Binary string without zero bytes
    if type isnot# 'binary'
      return 'Expected binary string'
    elseif (type(a:val) == type({})
           \&& !empty(filter(copy(a:val._VAL), 'stridx(v:val, "\n") != -1')))
      return 'Expected no NUL bytes'
    endif
    return 0
  elseif a:type is# 'intchar'
    let msg = s:shada_check_type('uint', a:val)
    if msg isnot# 0
      return msg
    endif
    return 0
  elseif a:type is# 'binarray'
    if type isnot# 'array'
      return 'Expected array value'
    elseif !empty(filter(copy(type(a:val) == type({}) ? a:val._VAL : a:val),
                        \'msgpack#type(v:val) isnot# "binary"'))
      return 'Expected array of binary strings'
    else
      for element in (type(a:val) == type({}) ? a:val._VAL : a:val)
        if (type(element) == type({})
           \&& !empty(filter(copy(element._VAL), 'stridx(v:val, "\n") != -1')))
          return 'Expected no NUL bytes'
        endif
        unlet element
      endfor
    endif
    return 0
  elseif a:type is# 'boolean'
    return 'Expected boolean'
  elseif a:type is# 'integer'
    return 'Expected integer'
  elseif a:type is# 'any'
    return 0
  endif
  return 'Internal error: unknown type ' . a:type
endfunction

""
" Convert msgpack mapping object to a list of strings for 
" s:shada_convert_entry().
"
" @param[in]  map           Mapping to convert.
" @param[in]  default_keys  List of keys which have default value in this 
"                           mapping.
" @param[in]  name          Name of the converted entry.
function s:shada_convert_map(map, default_keys, name) abort
  let ret = []
  let keys = copy(a:default_keys)
  call map(sort(keys(a:map)), 'index(keys, v:val) == -1 ? add(keys, v:val) : 0')
  let descriptions = map(copy(keys),
                        \'get(s:SHADA_STANDARD_KEYS, v:val, ["", 0, 0])')
  let max_key_len = max(map(copy(keys), 'len(v:val)'))
  let max_desc_len = max(map(copy(descriptions),
                            \'v:val[0] is 0 ? 0 : len(v:val[0])'))
  if max_key_len < len('Key')
    let max_key_len = len('Key')
  endif
  let key_header = 'Key' . repeat('_', max_key_len - len('Key'))
  if max_desc_len == 0
    call add(ret, printf('  %% %s  %s', key_header, 'Value'))
  else
    if max_desc_len < len('Description')
      let max_desc_len = len('Description')
    endif
    let desc_header = ('Description'
                      \. repeat('_', max_desc_len - len('Description')))
    call add(ret, printf('  %% %s  %s  %s', key_header, desc_header, 'Value'))
  endif
  let i = 0
  for key in keys
    let [description, type, default] = descriptions[i]
    if a:name isnot# 'local_mark' && key is# 'n'
      unlet default
      let default = s:SHADA_REQUIRED
    endif
    let value = get(a:map, key, default)
    if (key is# 'n' && !has_key(s:SHADA_REQUIRES_NAME, a:name)
       \&& value is# s:SHADA_REQUIRED)
      " Do nothing
    elseif value is s:SHADA_REQUIRED
      call add(ret, '  # Required key missing: ' . key)
    elseif max_desc_len == 0
      call add(ret, printf('  + %-*s  %s',
                          \max_key_len, key,
                          \msgpack#string(value)))
    else
      if type isnot 0 && value isnot# default
        let msg = s:shada_check_type(type, value)
        if msg isnot 0
          call add(ret, '  # ' . msg)
        endif
      endif
      let strval = s:shada_string(type, value)
      if msgpack#type(value) is# 'array' && msg is 0
        let shift = 2 + 2 + max_key_len + 2 + max_desc_len + 2
        " Value:    1   2   3             4   5              6:
        " "  + Key  Description  Value"
        "  1122333445555555555566
        if shift + strdisplaywidth(strval, shift) > 80
          let strval = '@'
        endif
      endif
      call add(ret, printf('  + %-*s  %-*s  %s',
                          \max_key_len, key,
                          \max_desc_len, description,
                          \strval))
      if strval is '@'
        for v in value
          call add(ret, printf('  | - %s', msgpack#string(v)))
          unlet v
        endfor
      endif
    endif
    let i += 1
    unlet value
    unlet default
  endfor
  return ret
endfunction

""
" Wrapper around msgpack#string() which may return string from s:SHADA_REV_ENUMS
function s:shada_string(type, v) abort
  if (has_key(s:SHADA_ENUMS, a:type) && type(a:v) == type(0)
     \&& has_key(s:SHADA_REV_ENUMS[a:type], a:v))
    return s:SHADA_REV_ENUMS[a:type][a:v]
  " Restricting a:v to be <= 127 is not necessary, but intchar constants are
  " normally expected to be either ASCII printable characters or NUL.
  elseif a:type is# 'intchar' && type(a:v) == type(0) && a:v >= 0 && a:v <= 127
    if a:v > 0 && strtrans(nr2char(a:v)) is# nr2char(a:v)
      return "'" . nr2char(a:v) . "'"
    else
      return "'\\" . a:v . "'"
    endif
  else
    return msgpack#string(a:v)
  endif
endfunction

""
" Evaluate string obtained by s:shada_string().
function s:shada_eval(s) abort
  return msgpack#eval(a:s, s:SHADA_SPECIAL_OBJS)
endfunction

""
" Convert one ShaDa entry to a list of strings suitable for setline().
"
" Returned format looks like this:
"
"     TODO
function s:shada_convert_entry(entry) abort
  if type(a:entry.type) == type({})
    " |msgpack-special-dict| may only be used if value does not fit into the 
    " default integer type. All known entry types do fit, so it is definitely 
    " unknown entry.
    let name = 'unknown_(' . msgpack#int_dict_to_str(a:entry.type) . ')'
  else
    let name = get(s:SHADA_ENTRY_NAMES, a:entry.type, 0)
    if name is 0
      let name = printf('unknown_(0x%x)', a:entry.type)
    endif
  endif
  let title = toupper(name[0]) . tr(name[1:], '_', ' ')
  let header = printf('%s with timestamp %s:', title,
                     \s:shada_strftime(a:entry.timestamp))
  let ret = [header]
  if name[:8] is# 'unknown_(' && name[-1:] is# ')'
    call add(ret, '  = ' . msgpack#string(a:entry.data))
  elseif has_key(s:SHADA_FIXED_ARRAY_ENTRIES, name)
    if type(a:entry.data) != type([])
      call add(ret, printf('  # Unexpected type: %s instead of array',
                          \msgpack#type(a:entry.data)))
      call add(ret, '  = ' . msgpack#string(a:entry.data))
      return ret
    endif
    let i = 0
    let max_desc_len = max(map(copy(s:SHADA_FIXED_ARRAY_ENTRIES[name]),
                              \'len(v:val[0])'))
    if max_desc_len < len('Description')
      let max_desc_len = len('Description')
    endif
    let desc_header = ('Description'
                      \. repeat('_', max_desc_len - len('Description')))
    call add(ret, printf('  @ %s  %s', desc_header, 'Value'))
    for value in a:entry.data
      let [desc, type] = get(s:SHADA_FIXED_ARRAY_ENTRIES[name], i, ['', 0])
      if (i == 2 && name is# 'history_entry'
         \&& a:entry.data[0] isnot# s:SHADA_ENUMS.histtype.SEARCH)
        let [desc, type] = ['', 0]
      endif
      if type isnot 0
        let msg = s:shada_check_type(type, value)
        if msg isnot 0
          call add(ret, '  # ' . msg)
        endif
      endif
      call add(ret, printf('  - %-*s  %s', max_desc_len, desc,
                          \s:shada_string(type, value)))
      let i += 1
      unlet value
    endfor
    if (len(a:entry.data) < len(s:SHADA_FIXED_ARRAY_ENTRIES[name])
       \&& !(name is# 'history_entry'
            \&& len(a:entry.data) == 2
            \&& a:entry.data[0] isnot# s:SHADA_ENUMS.histtype.SEARCH))
      call add(ret, '  # Expected more elements in list')
    endif
  elseif has_key(s:SHADA_MAP_ENTRIES, name)
    if type(a:entry.data) != type({})
      call add(ret, printf('  # Unexpected type: %s instead of map',
                          \msgpack#type(a:entry.data)))
      call add(ret, '  = ' . msgpack#string(a:entry.data))
      return ret
    endif
    if msgpack#special_type(a:entry.data) isnot 0
      call add(ret, '  # Entry is a special dict which is unexpected')
      call add(ret, '  = ' . msgpack#string(a:entry.data))
      return ret
    endif
    let ret += s:shada_convert_map(a:entry.data, s:SHADA_MAP_ENTRIES[name],
                                  \name)
  elseif name is# 'buffer_list'
    if type(a:entry.data) != type([])
      call add(ret, printf('  # Unexpected type: %s instead of array',
                          \msgpack#type(a:entry.data)))
      call add(ret, '  = ' . msgpack#string(a:entry.data))
      return ret
    elseif !empty(filter(copy(a:entry.data),
                        \'type(v:val) != type({}) '
                      \. '|| msgpack#special_type(v:val) isnot 0'))
      call add(ret, '  # Expected array of maps')
      call add(ret, '  = ' . msgpack#string(a:entry.data))
      return ret
    endif
    for bufdef in a:entry.data
      if bufdef isnot a:entry.data[0]
        call add(ret, '')
      endif
      let ret += s:shada_convert_map(bufdef, s:SHADA_BUFFER_LIST_KEYS, name)
    endfor
  else
    throw 'internal-unknown-type:Internal error: unknown type name: ' . name
  endif
  return ret
endfunction

""
" Order of msgpack objects in one ShaDa entry. Each item in the list is name of 
" the key in dictionaries returned by shada#read().
let s:SHADA_ENTRY_OBJECT_SEQUENCE = ['type', 'timestamp', 'length', 'data']

""
" Convert list returned by msgpackparse() to a list of ShaDa objects
"
" @param[in]  mpack  List of VimL objects returned by msgpackparse().
"
" @return List of dictionaries with keys type, timestamp, length and data. Each 
"         dictionary describes one ShaDa entry.
function shada#mpack_to_sd(mpack) abort
  let ret = []
  let i = 0
  for element in a:mpack
    let key = s:SHADA_ENTRY_OBJECT_SEQUENCE[
          \i % len(s:SHADA_ENTRY_OBJECT_SEQUENCE)]
    if key is# 'type'
      call add(ret, {})
    endif
    let ret[-1][key] = element
    if key isnot# 'data'
      if !msgpack#is_uint(element)
        throw printf('not-uint:Entry %i has %s element '.
                    \'which is not an unsigned integer',
                    \len(ret), key)
      endif
      if key is# 'type' && msgpack#equal(element, 0)
        throw printf('zero-uint:Entry %i has %s element '.
                    \'which is zero',
                    \len(ret), key)
      endif
    endif
    let i += 1
    unlet element
  endfor
  return ret
endfunction

""
" Convert read ShaDa file to a list of lines suitable for setline()
"
" @param[in]  shada  List of ShaDa entries like returned by shada#mpack_to_sd().
"
" @return List of strings suitable for setline()-like functions.
function shada#sd_to_strings(shada) abort
  let ret = []
  for entry in a:shada
    let ret += s:shada_convert_entry(entry)
  endfor
  return ret
endfunction

""
" Convert a readfile()-like list of strings to a list of lines suitable for 
" setline().
"
" @param[in]  binstrings  List of strings to convert.
"
" @return List of lines.
function shada#get_strings(binstrings) abort
  return shada#sd_to_strings(shada#mpack_to_sd(msgpackparse(a:binstrings)))
endfunction

""
" Convert s:shada_convert_entry() output to original entry.
function s:shada_convert_strings(strings) abort
  let strings = copy(a:strings)
  let match = matchlist(
        \strings[0],
        \'\v\C^(.{-})\m with timestamp \(\d\{4}-\d\d-\d\dT\d\d:\d\d:\d\d\):$')
  if empty(match)
    throw 'invalid-header:Header has invalid format: ' . strings[0]
  endif
  call remove(strings, 0)
  let title = match[1]
  let name = tolower(title[0]) . tr(title[1:], ' ', '_')
  let ret = {}
  let empty_default = g:msgpack#nil
  if name[:8] is# 'unknown_(' && name[-1:] is# ')'
    let ret.type = +name[9:-2]
  elseif has_key(s:SHADA_ENTRY_TYPES, name)
    let ret.type = s:SHADA_ENTRY_TYPES[name]
    if has_key(s:SHADA_MAP_ENTRIES, name)
      unlet empty_default
      let empty_default = {}
    elseif has_key(s:SHADA_FIXED_ARRAY_ENTRIES, name) || name is# 'buffer_list'
      unlet empty_default
      let empty_default = []
    endif
  else
    throw 'invalid-type:Unknown type ' . name
  endif
  let ret.timestamp = s:shada_strptime(match[2])
  if empty(strings)
    let ret.data = empty_default
  else
    while !empty(strings)
      if strings[0][2] is# '='
        let data = s:shada_eval(strings[0][4:])
        call remove(strings, 0)
      elseif strings[0][2] is# '%'
        if name is# 'buffer_list' && !has_key(ret, 'data')
          let ret.data = []
        endif
        let match = matchlist(
              \strings[0],
              \'\m\C^  % \(Key_*\)\(  Description_*\)\?  Value')
        if empty(match)
          throw 'invalid-map-header:Invalid mapping header: ' . strings[0]
        endif
        call remove(strings, 0)
        let key_len = len(match[1])
        let desc_skip_len = len(match[2])
        let data = {'_TYPE': v:msgpack_types.map, '_VAL': []}
        while !empty(strings) && strings[0][2] is# '+'
          let line = remove(strings, 0)[4:]
          let key = substitute(line[:key_len - 1], '\v\C\ *$', '', '')
          let strval = line[key_len + desc_skip_len + 2:]
          if strval is# '@'
            let val = []
            while !empty(strings) && strings[0][2] is# '|'
              if strings[0][4] isnot# '-'
                throw ('invalid-array:Expected hyphen-minus at column 5: '
                      \. strings)
              endif
              call add(val, s:shada_eval(remove(strings, 0)[5:]))
            endwhile
          else
            let val = s:shada_eval(strval)
          endif
          if (has_key(s:SHADA_STANDARD_KEYS, key)
             \&& s:SHADA_STANDARD_KEYS[key][2] isnot# s:SHADA_REQUIRED
             \&& msgpack#equal(s:SHADA_STANDARD_KEYS[key][2], val))
            unlet val
            continue
          endif
          call add(data._VAL, [{'_TYPE': v:msgpack_types.string, '_VAL': [key]},
                              \val])
          unlet val
        endwhile
      elseif strings[0][2] is# '@'
        let match = matchlist(
              \strings[0],
              \'\m\C^  @ \(Description_*  \)\?Value')
        if empty(match)
          throw 'invalid-array-header:Invalid array header: ' . strings[0]
        endif
        call remove(strings, 0)
        let desc_skip_len = len(match[1])
        let data = []
        while !empty(strings) && strings[0][2] is# '-'
          let val = remove(strings, 0)[4 + desc_skip_len :]
          call add(data, s:shada_eval(val))
        endwhile
      else
        throw 'invalid-line:Unrecognized line: ' . strings[0]
      endif
      if !has_key(ret, 'data')
        let ret.data = data
      elseif type(ret.data) == type([])
        call add(ret.data, data)
      else
        let ret.data = [ret.data, data]
      endif
      unlet data
    endwhile
  endif
  let ret._data = msgpackdump([ret.data])
  let ret.length = len(ret._data) - 1
  for s in ret._data
    let ret.length += len(s)
  endfor
  return ret
endfunction

""
" Convert s:shada_sd_to_strings() output to a list of original entries.
function shada#strings_to_sd(strings) abort
  let strings = filter(copy(a:strings), 'v:val !~# ''\v^\s*%(\#|$)''')
  let stringss = []
  for string in strings
    if string[0] isnot# ' '
      call add(stringss, [])
    endif
    call add(stringss[-1], string)
  endfor
  return map(copy(stringss), 's:shada_convert_strings(v:val)')
endfunction

""
" Convert a list of strings to list of strings suitable for writefile().
function shada#get_binstrings(strings) abort
  let entries = shada#strings_to_sd(a:strings)
  if !g:shada#keep_old_header
    call filter(entries, 'v:val.type != ' . s:SHADA_ENTRY_TYPES.header)
  endif
  if g:shada#add_own_header
    let data = {'version': v:version, 'generator': 'shada.vim'}
    let dumped_data = msgpackdump([data])
    let length = len(dumped_data) - 1
    for s in dumped_data
      let length += len(s)
    endfor
    call insert(entries, {
            \'type': s:SHADA_ENTRY_TYPES.header,
            \'timestamp': localtime(),
            \'length': length,
            \'data': data,
            \'_data': dumped_data,
          \})
  endif
  let mpack = []
  for entry in entries
    let mpack += map(copy(s:SHADA_ENTRY_OBJECT_SEQUENCE), 'entry[v:val]')
  endfor
  return msgpackdump(mpack)
endfunction
