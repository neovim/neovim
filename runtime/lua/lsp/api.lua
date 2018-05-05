
return {
  server = {
    add = require('lsp.server').add,
  },

  configure = {
    callbacks = require('lsp.configure.callbacks'),
    request = require('lsp.configure.request'),
  },

}
