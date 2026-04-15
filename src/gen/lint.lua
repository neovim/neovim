local fmt = string.format

local M = {}

--- Banned nouns. See `:help dev-name-common`.
--- Apply to parameter names, keyset keys, and function name parts.
local banned_nouns = {
  buffer = 'buf',
  -- channel = 'chan',
  command = 'cmd',
  directory = 'dir',
  highlight = 'hl',
  position = 'pos',
  process = 'proc',
  window = 'win',
}

--- Banned verbs. See `:help dev-name-common`.
--- Apply to function name parts.
local banned_verbs = {
  contains = 'has',
  delete = 'del',
  disable = 'enable',
  exit = 'cancel', -- or "stop"
  list = 'get',
  notify = 'print', -- or "echo"
  remove = 'del',
  toggle = 'enable',
}

--- Whitelist of legacy function names that violate the naming conventions.
--- Do not add new entries here. New functions must follow `:help dev-naming`.
---
--- @type table<string, table<string, true>>
local legacy_names = {
  ['src/nvim/api/buffer.c'] = {
    nvim_buf_delete = true,
  },
  ['src/nvim/api/window.c'] = {
    nvim_win_get_position = true,
  },
  ['src/nvim/api/tabpage.c'] = {
    nvim_tabpage_list_wins = true,
  },
  ['src/nvim/api/ui.c'] = {
    remote_ui_highlight_set = true,
  },
  ['src/nvim/api/vim.c'] = {
    nvim_list_bufs = true,
    nvim_list_chans = true,
    nvim_list_runtime_paths = true,
    nvim_list_tabpages = true,
    nvim_list_uis = true,
    nvim_list_wins = true,
  },
  ['runtime/lua/vim/_core/shared.lua'] = {
    _ensure_list = true,
    _list_insert = true,
    _list_remove = true,
    list_contains = true,
    tbl_contains = true,
  },
  ['runtime/lua/vim/lsp.lua'] = {
    buf_notify = true,
  },
  ['runtime/lua/vim/lsp/client.lua'] = {
    _on_exit = true,
    _process_request = true,
    _process_static_registrations = true,
    _remove_workspace_folder = true,
  },
  ['runtime/lua/vim/lsp/util.lua'] = {
    buf_highlight_references = true,
    make_position_params = true,
  },
  ['runtime/lua/vim/lsp/rpc.lua'] = {
    _notify = true,
  },
  ['runtime/lua/vim/treesitter.lua'] = {
    node_contains = true,
  },
  ['runtime/lua/vim/treesitter/highlighter.lua'] = {
    for_each_highlight_state = true,
    prepare_highlight_states = true,
  },
  ['runtime/lua/vim/treesitter/query.lua'] = {
    _process_patterns = true,
  },
  ['src/nvim/api/command.c'] = {
    create_user_command = true,
    nvim_buf_create_user_command = true,
    nvim_buf_del_user_command = true,
    nvim_create_user_command = true,
    nvim_del_user_command = true,
  },
  ['src/nvim/api/vimscript.c'] = {
    nvim_command = true,
  },
}

--- Whitelist of legacy Lua class fields that violate the naming conventions.
--- Do not add new entries here. New classes must follow `:help dev-naming`.
---
--- @type table<string, table<string, true>>
local legacy_fields = {
  ['vim.treesitter.dev.inspect_tree.Opts'] = {
    command = true,
  },
  ['vim.undotree.opts'] = {
    command = true,
  },
}

--- Whitelist of legacy keyset keys that violate the naming conventions.
--- Do not add new entries here. New keysets must follow `:help dev-naming`.
---
--- @type table<string, table<string, true>>
local legacy_keys = {
  create_autocmd = {
    command = true,
  },
}

--- Enforces naming conventions (`:help dev-naming`).
---
--- - For API functions:
---   - Checks positional parameter names of non-deprecated functions.
---     The `legacy_names` whitelist does NOT apply to params: misnamed positional
---     parameters are never allowed.
---   - Checks function name parts (split by `_`) for banned nouns/verbs.
--- - For `keysets_defs.h` keys:
---   - Checks key names. Because we don't (currently) have a way to mark keyset names as
---     "deprecated", a banned key is allowed (only) if its replacement also exists.
--- - For Lua classes (opts dicts, etc.):
---   - Checks field names. A banned field is allowed only if its replacement also exists
---     (same compat rule as keysets).
---
--- @param source string Source filename or module name.
--- @param api_funs {name:string, params:{name:string}[], deprecated?:true, deprecated_since?:integer}[]? Parsed API functions.
--- @param keysets {name: string, keys: string[], types: table<string,string>}[]? API keyset metadata.
--- @param classes table<string, {name:string, fields:{name:string, access?:string}[], nodoc?:true, access?:string}>? Parsed Lua classes.
function M.lint_names(source, api_funs, keysets, classes)
  local errors = {} --- @type string[]

  if api_funs then
    local src_legacy = legacy_names[source] or {}
    for _, fun in ipairs(api_funs) do
      if fun.name and fun.params and not fun.deprecated and not fun.deprecated_since then
        -- Positional parameter names: always checked (no "legacy" allowed).
        for _, p in ipairs(fun.params) do
          local want_name = banned_nouns[p.name]
          if want_name then
            local msg = '%s: %s(): param "%s" should be renamed to "%s"'
            errors[#errors + 1] = fmt(msg, source, fun.name, p.name, want_name)
          end
        end

        -- Function name parts: check for banned nouns/verbs.
        -- Skip the `nvim_` prefix; start from the second part.
        -- Legacy-whitelisted names are skipped.
        if not src_legacy[fun.name] then
          local parts = vim.split(fun.name, '_', { plain = true })
          for i = 2, #parts do
            local part = parts[i]
            local want_noun = banned_nouns[part]
            if want_noun then
              local msg = '%s: %s(): name contains banned noun "%s", use "%s"'
              errors[#errors + 1] = fmt(msg, source, fun.name, part, want_noun)
            end
            local want_verb = banned_verbs[part]
            if want_verb then
              local msg = '%s: %s(): name contains banned verb "%s", use "%s"'
              errors[#errors + 1] = fmt(msg, source, fun.name, part, want_verb)
            end
          end
        end
      end
    end
  end

  if keysets then
    for _, k in ipairs(keysets) do
      local keyset = {} --- @type table<string, true>
      for _, key in ipairs(k.keys) do
        keyset[key] = true
      end
      local ks_legacy = legacy_keys[k.name] or {}
      for _, key in ipairs(k.keys) do
        local want_name = banned_nouns[key]
        if want_name and not keyset[want_name] and not ks_legacy[key] then
          -- Banned key without its replacement: not a compat key, just stale.
          local msg = '%s: keyset "%s": key "%s" should be renamed to "%s"'
          errors[#errors + 1] = fmt(msg, source, k.name, key, want_name)
        end
      end
    end
  end

  if classes then
    for cls_name, cls in pairs(classes) do
      if cls.fields and not cls.nodoc and not cls.access then
        local field_set = {} --- @type table<string, true>
        for _, f in ipairs(cls.fields) do
          field_set[f.name] = true
        end
        local cls_legacy = legacy_fields[cls_name] or {}
        for _, f in ipairs(cls.fields) do
          if not f.access then
            local want_name = banned_nouns[f.name]
            if want_name and not field_set[want_name] and not cls_legacy[f.name] then
              -- Banned field without its replacement: not a compat field, just stale.
              local msg = '%s: class "%s": field "%s" should be renamed to "%s"'
              errors[#errors + 1] = fmt(msg, source, cls_name, f.name, want_name)
            end
          end
        end
      end
    end
  end

  if #errors > 0 then
    table.sort(errors)
    error('lint_names(): found banned parameter/key names:\n  ' .. table.concat(errors, '\n  '))
  end
end

return M
