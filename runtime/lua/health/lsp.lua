local protocol = vim.lsp.protocol
local M = {}

local report_error = vim.fn['health#report_error']
local report_info = vim.fn['health#report_info']
local report_ok = vim.fn['health#report_ok']


local function lsp_dump_active_client(client)
  local config = client.config
  vim.fn["health#report_start"]('State of ' .. config.name)
  report_info("Working directory: " .. config.root_dir)
  local i = 0
  for buf, diagnostics in pairs(vim.lsp.util.diagnostics_by_buf) do
    for _, diagnostic in pairs(diagnostics) do
      if diagnostic.severity == protocol.DiagnosticSeverity.Error then
        i = i + 1
        local fname = vim.fn.fnamemodify(
          vim.uri_to_fname(vim.uri_from_bufnr(buf)),
          ':.'
        )
        report_error(fname .. ': ' .. diagnostic.message)
        if i > 10 then
          return
        end
      end
    end
  end

  if client.notify('window/progress', {}) then
    report_ok('Language servers reported no errors via diagnostics')
  else
    report_error(
      'Language servers reported no errors via diagnostics, but has shutdown or is malfunctioning.')
  end
end

function M.check_health()
  local clients = vim.lsp.get_active_clients()
  report_info(#clients .. ' active clients')
  for _, client in pairs(clients) do
    lsp_dump_active_client(client)
  end
end

return M

