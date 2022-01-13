local function dump_bin_array(output, name, data)
  output:write([[
  static const uint8_t ]] .. name .. [[[] = {
]])

  for i = 1, #data do
    output:write(string.byte(data, i) .. ', ')
    if i % 10 == 0 then
      output:write('\n  ')
    end
  end
  output:write([[
};
]])
end

return dump_bin_array
