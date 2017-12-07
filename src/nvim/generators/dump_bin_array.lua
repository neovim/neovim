MAX_NUM_BYTES = 15  -- 78 / 5: maximum number of bytes on one line

local function dump_bin_array(output, name, data)
  output:write(('static const uint8_t %s[] = {\n '):format(name))

  for i = 1, #data do
    byte = data:byte(i)
    output:write((' %3u,'):format(byte))
    if i % MAX_NUM_BYTES == 0 and i ~= #data then
      output:write('\n ')
    end
  end

  output:write('\n};\n')
end

return dump_bin_array
