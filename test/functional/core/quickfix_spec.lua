local helpers = require('test.functional.helpers')(after_each)

describe('quickfix functionality', function()
  before_each(function()
    helpers.clear()
  end)
  it('Location list correctly updated when buffer modified', function()
    helpers.source([[
        new
        setl bt=nofile
        let lines = ['Line 1', 'Line 2', 'Line 3', 'Line 4', 'Line 5']
        call append(0, lines)
        new
        setl bt=nofile
        call append(0, lines)
        let qf_item = {
          \ 'lnum': 4,
          \ 'text': "This is the error line.",
          \ }
        let qf_item['bufnr'] = bufnr('%')
        call setloclist(0, [qf_item])
        wincmd p
        let qf_item['bufnr'] = bufnr('%')
        call setloclist(0, [qf_item])
        1del _
        call append(0, ['New line 1', 'New line 2', 'New line 3'])
        silent ll
    ]])
    helpers.eq({0, 6, 1, 0, 1}, helpers.funcs.getcurpos())
  end)
end)
