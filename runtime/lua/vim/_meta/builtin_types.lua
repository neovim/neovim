--- @class vim.fn.sign
--- @field group string
--- @field id integer
--- @field lnum integer
--- @field name string
--- @field priority integer

--- @class vim.fn.getbufinfo.dict
--- @field buflisted? 0|1
--- @field bufloaded? 0|1
--- @field bufmodified? 0|1

--- @class vim.fn.getbufinfo.ret.item
--- @field bufnr integer
--- @field changed 0|1
--- @field changedtick integer
--- @field hidden 0|1
--- @field lastused integer
--- @field linecount integer
--- @field listed 0|1
--- @field lnum integer
--- @field loaded 0|1
--- @field name string
--- @field signs vim.fn.sign[]
--- @field variables table<string,any>
--- @field windows integer[]

--- @alias vim.fn.getjumplist.ret [vim.fn.getjumplist.ret.item[], integer]

--- @class vim.fn.getjumplist.ret.item
--- @field bufnr integer
--- @field col integer
--- @field coladd integer
--- @field filename? string
--- @field lnum integer

--- @class vim.fn.getmousepos.ret
--- @field screenrow integer
--- @field screencol integer
--- @field winid integer
--- @field winrow integer
--- @field wincol integer
--- @field line integer
--- @field column integer

--- @class vim.fn.getwininfo.ret.item
--- @field botline integer
--- @field bufnr integer
--- @field height integer
--- @field loclist integer
--- @field quickfix integer
--- @field tabnr integer
--- @field terminal integer
--- @field textoff integer
--- @field topline integer
--- @field variables table<string,any>
--- @field width integer
--- @field winbar integer
--- @field wincol integer
--- @field winid integer
--- @field winnr integer
--- @field winrow integer

--- @class vim.fn.sign_define.dict
--- @field text string
--- @field icon? string
--- @field linehl? string
--- @field numhl? string
--- @field texthl? string
--- @field culhl? string

--- @class vim.fn.sign_getdefined.ret.item
--- @field name string
--- @field text string
--- @field icon? string
--- @field texthl? string
--- @field culhl? string
--- @field numhl? string
--- @field linehl? string

--- @class vim.fn.sign_getplaced.dict
--- @field group? string
--- @field id? integer
--- @field lnum? string|integer

--- @class vim.fn.sign_getplaced.ret.item
--- @field bufnr integer
--- @field signs vim.fn.sign[]

--- @class vim.fn.sign_place.dict
--- @field lnum? integer
--- @field priority? integer

--- @class vim.fn.sign_placelist.list.item
--- @field buffer integer|string
--- @field group? string
--- @field id? integer
--- @field lnum integer
--- @field name string
--- @field priority? integer

--- @class vim.fn.sign_unplace.dict
--- @field buffer? integer|string
--- @field id? integer

--- @class vim.fn.sign_unplacelist.list.item
--- @field buffer? integer|string
--- @field group? string
--- @field id? integer

--- @class vim.fn.winrestview.dict
--- @field col? integer
--- @field coladd? integer
--- @field curswant? integer
--- @field leftcol? integer
--- @field lnum? integer
--- @field skipcol? integer
--- @field topfill? integer
--- @field topline? integer

--- @class vim.fn.winsaveview.ret: vim.fn.winrestview.dict
--- @field col integer
--- @field coladd integer
--- @field curswant integer
--- @field leftcol integer
--- @field lnum integer
--- @field skipcol integer
--- @field topfill integer
--- @field topline integer

--- @class vim.fn.getscriptinfo.ret
--- @field autoload false
--- @field functions? string[]
--- @field name string
--- @field sid string
--- @field variables? table<string, any>
--- @field version 1
