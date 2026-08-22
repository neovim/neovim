--- @meta
-- This file is NOT generated, edit it directly.
--
-- See also `vim.api.keyset.events` in `api_keysets.gen.lua`.
error('Cannot require a meta file')

--- Data for the CmdAtom event.
--- @class vim.event.cmdatom.data
--- @field atoms? vim.event.cmdatom.data[] Subatoms of a composite (mapping, Visual sequence).
--- @field changed boolean Changed the buffer.
--- @field cmd? string Command/motion/object name ("w", "f", "iw", "gJ").
--- @field cmdarg? string Operand of `cmd` ("fx" => "x").
--- @field count? integer Effective count.
--- @field keys? string Resolved keysequence, raw bytes. Replay via `feedkeys(keys, 'n')`. Nil: lossy capture, replay via `feedkeys(lhs, 'm')` instead. Empty: unreplayable.
--- @field lhs string High-level user input: mapping LHS + any payload it read, or macro register ("gj", "ds'", "@q"). Raw bytes.
--- @field motionforce? 'v'|'V'|'<C-V>' forced-motion type.
--- @field moved? boolean Moved the cursor.
--- @field operator? string Operator name ("d", "g~", "g@"). key-notation.
--- @field pos? [integer,integer] Cursor before the action: 1-indexed row, 0-indexed column.
--- @field reg? string Register name.
--- @field text? string Inserted text, or the Ex/search cmdline.
--- @field type 'excmd'|'insert'|'jump'|'mapping'|'motion'|'mouse'|'normal'|'operator'|'scroll'|'visual'
--- @field undoseq? integer Undo state after the action (`undotree().seq_cur`). Decreases on undo.

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

--- @class vim.event.packchangedpre.data : vim.event.packchanged.data

--- @class vim.event.progress.data
--- @field id any
--- @field text string[]
--- @field data? table
--- @field percent? integer
--- @field source? string
--- @field status? string
--- @field title? string

--- @class vim.event.tabmoved.data
--- @field tabnr_old integer
--- @field tabnr_new integer

--- @class vim.event.termrequest.data
--- @field sequence string
--- @field terminator string
--- @field cursor integer[]

--- @class vim.event.termresponse.data
--- @field chan integer
--- @field sequence string
