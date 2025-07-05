describe('vim.pack', function()
  describe('add()', function()
    pending('works', function()
      -- TODO
    end)

    pending('reports errors after loading', function()
      -- TODO
      -- Should handle (not let it terminate the function) and report errors from pack_add()
    end)

    pending('respects after/', function()
      -- TODO
      -- Should source 'after/plugin/' directory (even nested files) after
      -- all 'plugin/' files are sourced in all plugins from input.
      --
      -- Should add 'after/' directory (if present) to 'runtimepath'
    end)

    pending('normalizes each spec', function()
      -- TODO

      -- TODO: Should properly infer `name` from `src` (as its basename
      -- minus '.git' suffix) but allow '.git' suffix in explicit `name`
    end)

    pending('normalizes spec array', function()
      -- TODO
      -- Should silently ignore full duplicates (same `src`+`version`)
      -- and error on conflicts.
    end)

    pending('installs', function()
      -- TODO

      -- TODO: Should block code flow until all plugins are available on disk
      -- and `:packadd` all of them (even just now installed) as a result.
    end)
  end)

  describe('update()', function()
    pending('works', function()
      -- TODO

      -- TODO: Should work with both added and not added plugins
    end)

    pending('suggests newer tags if there are no updates', function()
      -- TODO

      -- TODO: Should not suggest tags that point to the current state.
      -- Even if there is one/several and located at start/middle/end.
    end)
  end)

  describe('get()', function()
    pending('works', function()
      -- TODO
    end)

    pending('works after `del()`', function()
      -- TODO: Should not include removed plugins and still return list

      -- TODO: Should return corrent list inside `PackChanged` "delete" event
    end)
  end)

  describe('del()', function()
    pending('works', function()
      -- TODO
    end)
  end)
end)
