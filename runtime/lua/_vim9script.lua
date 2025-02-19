-------------------------------------------------------------------------------
-- This file is auto generated by vim9jit. Do not edit by hand.
--  All content is in the source repository.
--  Bugs should be reported to: github.com/tjdevries/vim9jit
--
-- In addition, this file is considered "private" by neovim. You should
-- not expect any of the APIs, functions, etc to be stable. They are subject
-- to change at any time.
-------------------------------------------------------------------------------

local vim9 = (function()
  local M = {}

  M.ternary = function(cond, if_true, if_false)
    if cond then
      if type(if_true) == 'function' then
        return if_true()
      else
        return if_true
      end
    else
      if type(if_false) == 'function' then
        return if_false()
      else
        return if_false
      end
    end
  end

  M.fn_ref = function(module, name, copied, ...)
    for _, val in ipairs({ ... }) do
      table.insert(copied, val)
    end

    local funcref = name
    if type(funcref) == 'function' then
      return funcref(unpack(copied))
    elseif type(funcref) == 'string' then
      if vim.fn.exists('*' .. funcref) == 1 then
        return vim.fn[funcref](unpack(copied))
      end

      if module[funcref] then
        module[funcref](unpack(copied))
      end

      error('unknown function: ' .. funcref)
    else
      error(string.format('unable to call funcref: %s', funcref))
    end
  end

  M.fn_mut = function(name, args, info)
    local result = vim.fn._Vim9ScriptFn(name, args)
    for idx, val in pairs(result[2]) do
      M.replace(args[idx], val)
    end

    -- Substitute returning the reference to the
    -- returned value
    if info.replace then
      return args[info.replace + 1]
    end

    return result[1]
  end

  M.replace = function(orig, new)
    if type(orig) == 'table' and type(new) == 'table' then
      for k in pairs(orig) do
        orig[k] = nil
      end

      for k, v in pairs(new) do
        orig[k] = v
      end

      return orig
    end

    return new
  end

  M.index = function(obj, idx)
    if vim.islist(obj) then
      if idx < 0 then
        return obj[#obj + idx + 1]
      else
        return obj[idx + 1]
      end
    elseif type(obj) == 'table' then
      return obj[idx]
    elseif type(obj) == 'string' then
      return string.sub(obj, idx + 1, idx + 1)
    end

    error('invalid type for indexing: ' .. vim.inspect(obj))
  end

  M.index_expr = function(idx)
    if type(idx) == 'string' then
      return idx
    elseif type(idx) == 'number' then
      return idx + 1
    else
      error(string.format('not yet handled: %s', vim.inspect(idx)))
    end
  end

  M.slice = function(obj, start, finish)
    if start == nil then
      start = 0
    end

    if start < 0 then
      start = #obj + start
    end
    assert(type(start) == 'number')

    if finish == nil then
      finish = #obj
    end

    if finish < 0 then
      finish = #obj + finish
    end
    assert(type(finish) == 'number')

    local slicer
    if vim.islist(obj) then
      slicer = vim.list_slice
    elseif type(obj) == 'string' then
      slicer = string.sub
    else
      error('invalid type for slicing: ' .. vim.inspect(obj))
    end

    return slicer(obj, start + 1, finish + 1)
  end

  -- Currently unused, but this could be used to embed vim9jit within a
  -- running nvim application and transpile "on the fly" as files are
  -- sourced. There would still need to be some work done to make that
  -- work correctly with imports and what not, but overall it could
  -- work well for calling ":source X" from within a vimscript/vim9script
  -- function
  M.make_source_cmd = function()
    local group = vim.api.nvim_create_augroup('nvim.vim9script_source', {})
    vim.api.nvim_create_autocmd('SourceCmd', {
      pattern = '*.vim',
      group = group,
      callback = function(a)
        local file = vim.fn.readfile(a.file)
        for _, line in ipairs(file) do
          -- TODO: Or starts with def <something>
          --  You can use def in legacy vim files
          if vim.startswith(line, 'vim9script') then
            -- TODO: Use the rust lib to actually
            -- generate the corresponding lua code and then
            -- execute that (instead of sourcing it directly)
            return
          end
        end

        vim.api.nvim_exec2(table.concat(file, '\n'), { output = false })
      end,
    })
  end

  M.iter = function(expr)
    if vim.islist(expr) then
      return ipairs(expr)
    else
      return pairs(expr)
    end
  end

  M.ITER_DEFAULT = 0
  M.ITER_CONTINUE = 1
  M.ITER_BREAK = 2
  M.ITER_RETURN = 3

  return M
end)()

vim.cmd([[
function! _Vim9ScriptFn(name, args) abort
  try
    let ret = function(a:name, a:args)()
  catch
    echo "Failed..."
    echo a:name
    echo a:args

    throw v:errmsg
  endtry

  return [ret, a:args]
endfunction
]])

vim9['autoload'] = (function()
  return function(path)
    return loadfile(path)()
  end
end)()
vim9['bool'] = (function()
  return function(...)
    return vim9.convert.to_vim_bool(...)
  end
end)()
vim9['convert'] = (function()
  local M = {}

  M.decl_bool = function(val)
    if type(val) == 'boolean' then
      return val
    elseif type(val) == 'number' then
      if val == 0 then
        return false
      elseif val == 1 then
        return true
      else
        error(string.format('bad number passed to bool declaration: %s', val))
      end
    end

    error(string.format('invalid bool declaration: %s', vim.inspect(val)))
  end

  M.decl_dict = function(val)
    if type(val) == 'nil' then
      return vim.empty_dict()
    elseif type(val) == 'table' then
      if vim.tbl_isempty(val) then
        return vim.empty_dict()
      elseif vim.islist(val) then
        error(string.format('Cannot pass list to dictionary? %s', vim.inspect(val)))
      else
        return val
      end
    end

    error(string.format('invalid dict declaration: %s', vim.inspect(val)))
  end

  M.to_vim_bool = function(val)
    if type(val) == 'boolean' then
      return val
    elseif type(val) == 'number' then
      return val ~= 0
    elseif type(val) == 'string' then
      return string.len(val) ~= 0
    elseif type(val) == 'table' then
      return not vim.tbl_isempty(val)
    elseif val == nil then
      return false
    end

    error('unhandled type: ' .. vim.inspect(val))
  end

  return M
end)()
vim9['fn'] = (function()
  local M = {}

  M.insert = function(list, item, idx)
    if idx == nil then
      idx = 1
    end

    table.insert(list, idx + 1, item)

    return list
  end

  M.extend = function(left, right, expr3)
    if expr3 ~= nil then
      error("haven't written this code yet")
    end

    if vim.islist(right) then
      vim.list_extend(left, right)
      return left
    else
      -- local result = vim.tbl_extend(left, right)
      for k, v in pairs(right) do
        left[k] = v
      end

      return left
    end
  end

  M.add = function(list, item)
    table.insert(list, item)
    return list
  end

  M.has_key = function(obj, key)
    return not not obj[key]
  end

  M.prop_type_add = function(...)
    local args = { ... }
    print('[prop_type_add]', vim.inspect(args))
  end

  do
    local has_overrides = {
      -- We do have vim9script ;) that's this plugin
      ['vim9script'] = true,

      -- Include some vim patches that are sometimes required by various vim9script plugins
      -- that we implement via vim9jit
      [ [[patch-8.2.2261]] ] = true,
      [ [[patch-8.2.4257]] ] = true,
    }

    M.has = function(patch)
      if has_overrides[patch] then
        return true
      end

      return vim.fn.has(patch)
    end
  end

  --[=[
Currently missing patch, can be removed in the future.

readdirex({directory} [, {expr} [, {dict}]])			*readdirex()*
		Extended version of |readdir()|.
		Return a list of Dictionaries with file and directory
		information in {directory}.
		This is useful if you want to get the attributes of file and
		directory at the same time as getting a list of a directory.
		This is much faster than calling |readdir()| then calling
		|getfperm()|, |getfsize()|, |getftime()| and |getftype()| for
		each file and directory especially on MS-Windows.
		The list will by default be sorted by name (case sensitive),
		the sorting can be changed by using the optional {dict}
		argument, see |readdir()|.

		The Dictionary for file and directory information has the
		following items:
			group	Group name of the entry. (Only on Unix)
			name	Name of the entry.
			perm	Permissions of the entry. See |getfperm()|.
			size	Size of the entry. See |getfsize()|.
			time	Timestamp of the entry. See |getftime()|.
			type	Type of the entry.
				On Unix, almost same as |getftype()| except:
				    Symlink to a dir	"linkd"
				    Other symlink	"link"
				On MS-Windows:
				    Normal file		"file"
				    Directory		"dir"
				    Junction		"junction"
				    Symlink to a dir	"linkd"
				    Other symlink	"link"
				    Other reparse point	"reparse"
			user	User name of the entry's owner. (Only on Unix)
		On Unix, if the entry is a symlink, the Dictionary includes
		the information of the target (except the "type" item).
		On MS-Windows, it includes the information of the symlink
		itself because of performance reasons.
--]=]
  M.readdirex = function(dir)
    local files = vim.fn.readdir(dir)
    local direx = {}
    for _, f in ipairs(files) do
      table.insert(direx, {
        name = f,
        type = vim.fn.getftype(f),
      })
    end

    return direx
  end

  M.mapnew = function(tbl, expr)
    return vim.fn.map(tbl, expr)
  end

  M.typename = function(val)
    local ty = type(val)
    if ty == 'string' then
      return 'string'
    elseif ty == 'boolean' then
      return 'bool'
    elseif ty == 'number' then
      return 'number'
    else
      error(string.format('typename: %s', val))
    end
  end

  -- Popup menu stuff: Could be rolled into other plugin later
  -- but currently is here for testing purposes (and implements
  -- some very simple compat layers at the moment)
  do
    local pos_map = {
      topleft = 'NW',
      topright = 'NE',
      botleft = 'SW',
      botright = 'SE',
    }

    M.popup_menu = function(_, options)
      -- print "OPTIONS:"

      local buf = vim.api.nvim_create_buf(false, true)
      local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        style = 'minimal',
        anchor = pos_map[options.pos],
        height = options.maxheight or options.minheight,
        width = options.maxwidth or options.minwidth,
        row = options.line,
        col = options.col,
      })

      if options.filter then
        local loop
        loop = function()
          vim.cmd([[redraw!]])
          local ok, ch = pcall(vim.fn.getcharstr)
          if not ok then
            return
          end -- interrupted

          if ch == '<C-C>' then
            return
          end

          if not require('vim9script').bool(options.filter(nil, ch)) then
            vim.cmd.normal(ch)
          end

          vim.schedule(loop)
        end

        vim.schedule(loop)
      end

      return win
    end

    M.popup_settext = function(id, text)
      if type(text) == 'string' then
        -- text = vim.split(text, "\n")
        error("Haven't handled string yet")
      end

      local lines = {}
      for _, obj in ipairs(text) do
        table.insert(lines, obj.text)
      end

      vim.api.nvim_buf_set_lines(vim.api.nvim_win_get_buf(id), 0, -1, false, lines)
    end

    M.popup_filter_menu = function()
      print('ok, just pretend we filtered the menu')
    end

    M.popup_setoptions = function(id, _)
      print('setting options...', id)
    end
  end

  M = setmetatable(M, {
    __index = vim.fn,
  })

  return M
end)()
vim9['heredoc'] = (function()
  local M = {}

  M.trim = function(lines)
    local min_whitespace = 9999
    for _, line in ipairs(lines) do
      local _, finish = string.find(line, '^%s*')
      min_whitespace = math.min(min_whitespace, finish)
    end

    local trimmed_lines = {}
    for _, line in ipairs(lines) do
      table.insert(trimmed_lines, string.sub(line, min_whitespace + 1))
    end

    return trimmed_lines
  end

  return M
end)()
vim9['import'] = (function()
  local imported = {}
  imported.autoload = setmetatable({}, {
    __index = function(_, name)
      local luaname = 'autoload/' .. string.gsub(name, '%.vim$', '.lua')
      local runtime_file = vim.api.nvim_get_runtime_file(luaname, false)[1]
      if not runtime_file then
        error('unable to find autoload file:' .. name)
      end

      return imported.absolute[vim.fn.fnamemodify(runtime_file, ':p')]
    end,
  })

  imported.absolute = setmetatable({}, {
    __index = function(self, name)
      if vim.uv.fs_stat(name) then
        local result = loadfile(name)()
        rawset(self, name, result)

        return result
      end

      error(string.format('unabled to find absolute file: %s', name))
    end,
  })

  return function(info)
    local name = info.name

    if info.autoload then
      return imported.autoload[info.name]
    end

    local debug_info = debug.getinfo(2, 'S')
    local sourcing_path = vim.fn.fnamemodify(string.sub(debug_info.source, 2), ':p')

    -- Relative paths
    if vim.startswith(name, '../') or vim.startswith(name, './') then
      local luaname = string.gsub(name, '%.vim$', '.lua')
      local directory = vim.fn.fnamemodify(sourcing_path, ':h')
      local search = directory .. '/' .. luaname
      return imported.absolute[search]
    end

    if vim.startswith(name, '/') then
      error('absolute path')
      -- local luaname = string.gsub(name, "%.vim", ".lua")
      -- local runtime_file = vim.api.nvim_get_runtime_file(luaname, false)[1]
      -- if runtime_file then
      --   runtime_file = vim.fn.fnamemodify(runtime_file, ":p")
      --   return loadfile(runtime_file)()
      -- end
    end

    error('Unhandled case' .. vim.inspect(info) .. vim.inspect(debug_info))
  end
end)()
vim9['ops'] = (function()
  local lib = vim9

  local M = {}

  M['And'] = function(left, right)
    return lib.bool(left) and lib.bool(right)
  end

  M['Or'] = function(left, right)
    return lib.bool(left) or lib.bool(right)
  end

  M['Plus'] = function(left, right)
    return left + right
  end

  M['Multiply'] = function(left, right)
    return left * right
  end

  M['Divide'] = function(left, right)
    return left / right
  end

  M['StringConcat'] = function(left, right)
    return left .. right
  end

  M['EqualTo'] = function(left, right)
    return left == right
  end

  M['NotEqualTo'] = function(left, right)
    return not M['EqualTo'](left, right)
  end

  M['LessThan'] = function(left, right)
    return left < right
  end

  M['LessThanOrEqual'] = function(left, right)
    return left <= right
  end

  M['GreaterThan'] = function(left, right)
    return left > right
  end

  M['GreaterThanOrEqual'] = function(left, right)
    return left >= right
  end

  M['RegexpMatches'] = function(left, right)
    return not not vim.regex(right):match_str(left)
  end

  M['RegexpMatchesIns'] = function(left, right)
    return not not vim.regex('\\c' .. right):match_str(left)
  end

  M['NotRegexpMatches'] = function(left, right)
    return not M['RegexpMatches'](left, right)
  end

  M['Modulo'] = function(left, right)
    return left % right
  end

  M['Minus'] = function(left, right)
    -- TODO: This is not right :)
    return left - right
  end

  return M
end)()
vim9['prefix'] = (function()
  local lib = vim9

  local M = {}

  M['Minus'] = function(right)
    return -right
  end

  M['Bang'] = function(right)
    return not lib.bool(right)
  end

  return M
end)()

return vim9
