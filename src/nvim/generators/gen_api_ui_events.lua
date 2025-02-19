local mpack = vim.mpack

assert(#arg == 5)
local input = io.open(arg[1], 'rb')
local call_output = io.open(arg[2], 'wb')
local remote_output = io.open(arg[3], 'wb')
local metadata_output = io.open(arg[4], 'wb')
local client_output = io.open(arg[5], 'wb')

local c_grammar = require('generators.c_grammar')
local events = c_grammar.grammar:match(input:read('*all'))

local hashy = require 'generators.hashy'

local function write_signature(output, ev, prefix, notype)
  output:write('(' .. prefix)
  if prefix == '' and #ev.parameters == 0 then
    output:write('void')
  end
  for j = 1, #ev.parameters do
    if j > 1 or prefix ~= '' then
      output:write(', ')
    end
    local param = ev.parameters[j]
    if not notype then
      output:write(param[1] .. ' ')
    end
    output:write(param[2])
  end
  output:write(')')
end

local function write_arglist(output, ev)
  if #ev.parameters == 0 then
    return
  end
  output:write('  MAXSIZE_TEMP_ARRAY(args, ' .. #ev.parameters .. ');\n')
  for j = 1, #ev.parameters do
    local param = ev.parameters[j]
    local kind = string.upper(param[1])
    output:write('  ADD_C(args, ')
    output:write(kind .. '_OBJ(' .. param[2] .. ')')
    output:write(');\n')
  end
end

local function call_ui_event_method(output, ev)
  output:write('void ui_client_event_' .. ev.name .. '(Array args)\n{\n')

  local hlattrs_args_count = 0
  if #ev.parameters > 0 then
    output:write('  if (args.size < ' .. #ev.parameters)
    for j = 1, #ev.parameters do
      local kind = ev.parameters[j][1]
      if kind ~= 'Object' then
        if kind == 'HlAttrs' then
          kind = 'Dict'
        end
        output:write('\n      || args.items[' .. (j - 1) .. '].type != kObjectType' .. kind .. '')
      end
    end
    output:write(') {\n')
    output:write('    ELOG("Error handling ui event \'' .. ev.name .. '\'");\n')
    output:write('    return;\n')
    output:write('  }\n')
  end

  for j = 1, #ev.parameters do
    local param = ev.parameters[j]
    local kind = param[1]
    output:write('  ' .. kind .. ' arg_' .. j .. ' = ')
    if kind == 'HlAttrs' then
      -- The first HlAttrs argument is rgb_attrs and second is cterm_attrs
      output:write(
        'ui_client_dict2hlattrs(args.items['
          .. (j - 1)
          .. '].data.dict, '
          .. (hlattrs_args_count == 0 and 'true' or 'false')
          .. ');\n'
      )
      hlattrs_args_count = hlattrs_args_count + 1
    elseif kind == 'Object' then
      output:write('args.items[' .. (j - 1) .. '];\n')
    elseif kind == 'Window' then
      output:write('(Window)args.items[' .. (j - 1) .. '].data.integer;\n')
    else
      output:write('args.items[' .. (j - 1) .. '].data.' .. string.lower(kind) .. ';\n')
    end
  end

  output:write('  tui_' .. ev.name .. '(tui')
  for j = 1, #ev.parameters do
    output:write(', arg_' .. j)
  end
  output:write(');\n')

  output:write('}\n\n')
end

events = vim.tbl_filter(function(ev)
  return ev[1] ~= 'empty' and ev[1] ~= 'preproc'
end, events)

for i = 1, #events do
  local ev = events[i]
  assert(ev.return_type == 'void')

  if ev.since == nil and not ev.noexport then
    print('Ui event ' .. ev.name .. ' lacks since field.\n')
    os.exit(1)
  end
  ev.since = tonumber(ev.since)

  local args = #ev.parameters > 0 and 'args' or 'noargs'
  if not ev.remote_only then
    if not ev.remote_impl and not ev.noexport then
      remote_output:write('void remote_ui_' .. ev.name)
      write_signature(remote_output, ev, 'RemoteUI *ui')
      remote_output:write('\n{\n')
      write_arglist(remote_output, ev)
      remote_output:write('  push_call(ui, "' .. ev.name .. '", ' .. args .. ');\n')
      remote_output:write('}\n\n')
    end
  end

  if not (ev.remote_only and ev.remote_impl) then
    call_output:write('void ui_call_' .. ev.name)
    write_signature(call_output, ev, '')
    call_output:write('\n{\n')
    if ev.remote_only then
      -- Lua callbacks may emit other events or the same event again. Avoid the latter
      -- by adding a recursion guard to each generated function that may call a Lua callback.
      call_output:write('  static bool entered = false;\n')
      call_output:write('  if (entered) {\n')
      call_output:write('    return;\n')
      call_output:write('  }\n')
      call_output:write('  entered = true;\n')
      write_arglist(call_output, ev)
      call_output:write(('  ui_call_event("%s", %s, %s)'):format(ev.name, tostring(ev.fast), args))
      call_output:write(';\n  entered = false;\n')
    elseif ev.compositor_impl then
      call_output:write('  ui_comp_' .. ev.name)
      write_signature(call_output, ev, '', true)
      call_output:write(';\n')
      call_output:write('  UI_CALL')
      write_signature(call_output, ev, '!ui->composed, ' .. ev.name .. ', ui', true)
      call_output:write(';\n')
    else
      call_output:write('  UI_CALL')
      write_signature(call_output, ev, 'true, ' .. ev.name .. ', ui', true)
      call_output:write(';\n')
    end
    call_output:write('}\n\n')
  end

  if ev.compositor_impl then
    call_output:write('void ui_composed_call_' .. ev.name)
    write_signature(call_output, ev, '')
    call_output:write('\n{\n')
    call_output:write('  UI_CALL')
    write_signature(call_output, ev, 'ui->composed, ' .. ev.name .. ', ui', true)
    call_output:write(';\n')
    call_output:write('}\n\n')
  end

  if (not ev.remote_only) and not ev.noexport and not ev.client_impl and not ev.client_ignore then
    call_ui_event_method(client_output, ev)
  end
end

local client_events = {}
for _, ev in ipairs(events) do
  if (not ev.noexport) and ((not ev.remote_only) or ev.client_impl) and not ev.client_ignore then
    client_events[ev.name] = ev
  end
end

local hashorder, hashfun = hashy.hashy_hash(
  'ui_client_handler',
  vim.tbl_keys(client_events),
  function(idx)
    return 'event_handlers[' .. idx .. '].name'
  end
)

client_output:write('static const UIClientHandler event_handlers[] = {\n')

for _, name in ipairs(hashorder) do
  client_output:write('  { .name = "' .. name .. '", .fn = ui_client_event_' .. name .. '},\n')
end

client_output:write('\n};\n\n')
client_output:write(hashfun)

call_output:close()
remote_output:close()
client_output:close()

-- don't expose internal attributes like "impl_name" in public metadata
local exported_attributes = { 'name', 'parameters', 'since', 'deprecated_since' }
local exported_events = {}
for _, ev in ipairs(events) do
  local ev_exported = {}
  for _, attr in ipairs(exported_attributes) do
    ev_exported[attr] = ev[attr]
  end
  for _, p in ipairs(ev_exported.parameters) do
    if p[1] == 'HlAttrs' or p[1] == 'Dict' then
      -- TODO(justinmk): for back-compat, but do clients actually look at this?
      p[1] = 'Dictionary'
    end
  end
  if not ev.noexport then
    exported_events[#exported_events + 1] = ev_exported
  end
end

metadata_output:write(mpack.encode(exported_events))
metadata_output:close()
