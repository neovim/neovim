--- @meta _
-- THIS FILE IS GENERATED
-- DO NOT EDIT
error('Cannot require a meta file')

--- @class vim.event.lspattach.data
--- @field client_id integer

--- @class vim.event.lspdetach.data
--- @field client_id integer

--- @class vim.event.lspnotify.data
--- @field client_id integer
--- @field method string
--- @field params table

--- @class vim.event.lspprogress.data
--- @field client_id integer
--- @field params lsp.ProgressParams

--- @class vim.event.lsprequest.data
--- @field client_id integer
--- @field request_id integer
--- @field request table

--- @class vim.event.lsptokenupdate.data
--- @field client_id integer
--- @field token table

--- @class vim.event.markset.data
--- @field name string
--- @field line integer
--- @field col integer

--- @class vim.event.packchanged.data
--- @field active boolean
--- @field kind string
--- @field spec vim.pack.Spec
--- @field path string

--- @class vim.event.packchangedpre.data
--- @field active boolean
--- @field kind string
--- @field spec vim.pack.Spec
--- @field path string

--- @class vim.event.progress.data
--- @field id any
--- @field text string[]
--- @field data? table
--- @field percent? integer
--- @field source? string
--- @field status? string
--- @field title? string

--- @class vim.event.termrequest.data
--- @field sequence string
--- @field terminator string
--- @field cursor integer[]

--- @class vim.event.termresponse.data
--- @field sequence string
