--- Generate input for gperf
---
--- Does not generate the perfect hash itself, only input file.
---
--- Parameters to function are stored in an `opts` table, following keys are
--- possible:
---
--- @param  outputf_base  Required, base output file name. The result will be
---                       written to `outputf_base .. '.gperf'`.
--- @param  initializer_suffix  Required, value of `initalizer-suffix` define.
--- @param  word_array_name  Name of the word array, defaults to `gperf_{base}`
---                          where `{base}` is the leading alphanumeric sequence
---                          of `outputf_base` basename.
--- @param  hash_function_name  Name of the hash function, defaults to
---                             `gperf_{base}_hash`.
--- @param  lookup_function_name  Name of the lookup function, defaults to
---                               `gperf_{base}_find`.
--- @param  struct_type  Required, type of the structure stored in the hash.
--- @param  data  Required, data to store in the hash. Must be a table.
--- @param  item_callback  Callback used to transform items from `data` to
---                        strings for gperf. Defaults to function which just
---                        returns its first argument (key from data table)
---                        followed by a comma followed by its second argument
---                        (value from data table) filtered by value_callback.
---
---                        @note Callback also accepts `self` (i.e. `opts`).
--- @param  value_callback  Callback used to transform values from data.
---                         Defaults to just returning nothing.
---
---                         @note Callback also accepts `self` (i.e. `opts`).
local function generate(opts)
  local gperfpipe = io.open(opts.outputf_base .. '.gperf', 'wb')
  local base = (
    opts.outputf_base:gsub('^.*[\\/:]', ''):gsub('[^a-zA-Z0-9].*', ''))
  opts.word_array_name = opts.word_array_name or 'gperf_' .. base
  opts.hash_function_name = (
    opts.hash_function_name or 'gperf_' .. base .. '_hash')
  opts.lookup_function_name = (
    opts.lookup_function_name or 'gperf_' .. base .. '_find')
  opts.item_callback = opts.item_callback or function(self, k, v)
    return k .. ', ' .. opts:value_callback(v)
  end
  opts.value_callback = opts.value_callback or function(self, v)
    return v
  end
  gperfpipe:write((''
    .. '%language=ANSI-C\n'
    .. '%global-table\n'
    .. '%readonly-tables\n'
    .. '%define initializer-suffix ' .. opts.initializer_suffix .. '\n'
    .. '%define word-array-name ' .. opts.word_array_name .. '\n'
    .. '%define hash-function-name ' .. opts.hash_function_name .. '\n'
    .. '%define lookup-function-name ' .. opts.lookup_function_name .. '\n'
    .. '%omit-struct-type\n'
    .. '%struct-type\n'
    .. opts.struct_type .. '\n'
    .. '%%\n'))
  for k, v in pairs(opts.data) do
    gperfpipe:write(opts:item_callback(k, v) .. '\n')
  end
  gperfpipe:close()
end

return {
  generate=generate,
}
