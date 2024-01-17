--- @meta _
-- THIS FILE IS GENERATED
-- DO NOT EDIT
error('Cannot require a meta file')

---filter lines or execute an external command
vim.cmd['!'] = function(...) end

---same as ":number"
vim.cmd['#'] = function(...) end

---repeat last ":substitute"
vim.cmd['&'] = function(...) end

---shift lines one 'shiftwidth' left
vim.cmd['<'] = function(...) end

---print the last line number
vim.cmd['='] = function(...) end

---shift lines one 'shiftwidth' right
vim.cmd['>'] = function(...) end

---execute contents of a register
vim.cmd['@'] = function(...) end

---|:Next|
---go to previous file in the argument list
function vim.cmd.N(...) end

---go to previous file in the argument list
function vim.cmd.Next(...) end

---|:abbreviate|
---enter abbreviation
function vim.cmd.ab(...) end

---enter abbreviation
function vim.cmd.abbreviate(...) end

---|:abclear|
---remove all abbreviations
function vim.cmd.abc(...) end

---remove all abbreviations
function vim.cmd.abclear(...) end

---|:aboveleft|
---make split window appear left or above
function vim.cmd.abo(...) end

---make split window appear left or above
function vim.cmd.aboveleft(...) end

---|:all|
---open a window for each file in the argument list
function vim.cmd.al(...) end

---open a window for each file in the argument list
function vim.cmd.all(...) end

---|:amenu|
---enter new menu item for all modes
function vim.cmd.am(...) end

---enter new menu item for all modes
function vim.cmd.amenu(...) end

---|:anoremenu|
---enter a new menu for all modes that will not be remapped
function vim.cmd.an(...) end

---enter a new menu for all modes that will not be remapped
function vim.cmd.anoremenu(...) end

---|:append|
---append text
function vim.cmd.a(...) end

---append text
function vim.cmd.append(...) end

---|:argadd|
---add items to the argument list
function vim.cmd.arga(...) end

---add items to the argument list
function vim.cmd.argadd(...) end

---|:argdedupe|
---remove duplicates from the argument list
function vim.cmd.argded(...) end

---remove duplicates from the argument list
function vim.cmd.argdedupe(...) end

---|:argdelete|
---delete items from the argument list
function vim.cmd.argd(...) end

---delete items from the argument list
function vim.cmd.argdelete(...) end

---do a command on all items in the argument list
function vim.cmd.argdo(...) end

---|:argedit|
---add item to the argument list and edit it
function vim.cmd.arge(...) end

---add item to the argument list and edit it
function vim.cmd.argedit(...) end

---|:argglobal|
---define the global argument list
function vim.cmd.argg(...) end

---define the global argument list
function vim.cmd.argglobal(...) end

---|:arglocal|
---define a local argument list
function vim.cmd.argl(...) end

---define a local argument list
function vim.cmd.arglocal(...) end

---|:args|
---print the argument list
function vim.cmd.ar(...) end

---print the argument list
function vim.cmd.args(...) end

---|:argument|
---go to specific file in the argument list
function vim.cmd.argu(...) end

---go to specific file in the argument list
function vim.cmd.argument(...) end

---|:ascii|
---print ascii value of character under the cursor
function vim.cmd.as(...) end

---print ascii value of character under the cursor
function vim.cmd.ascii(...) end

---|:augroup|
---select the autocommand group to use
function vim.cmd.aug(...) end

---select the autocommand group to use
function vim.cmd.augroup(...) end

---|:aunmenu|
---remove menu for all modes
function vim.cmd.aun(...) end

---remove menu for all modes
function vim.cmd.aunmenu(...) end

---|:autocmd|
---enter or show autocommands
function vim.cmd.au(...) end

---enter or show autocommands
function vim.cmd.autocmd(...) end

---|:bNext|
---go to previous buffer in the buffer list
function vim.cmd.bN(...) end

---go to previous buffer in the buffer list
function vim.cmd.bNext(...) end

---|:badd|
---add buffer to the buffer list
function vim.cmd.bad(...) end

---add buffer to the buffer list
function vim.cmd.badd(...) end

---|:ball|
---open a window for each buffer in the buffer list
function vim.cmd.ba(...) end

---open a window for each buffer in the buffer list
function vim.cmd.ball(...) end

---like ":badd" but also set the alternate file
function vim.cmd.balt(...) end

---|:bdelete|
---remove a buffer from the buffer list
function vim.cmd.bd(...) end

---remove a buffer from the buffer list
function vim.cmd.bdelete(...) end

---|:belowright|
---make split window appear right or below
function vim.cmd.bel(...) end

---make split window appear right or below
function vim.cmd.belowright(...) end

---|:bfirst|
---go to first buffer in the buffer list
function vim.cmd.bf(...) end

---go to first buffer in the buffer list
function vim.cmd.bfirst(...) end

---|:blast|
---go to last buffer in the buffer list
function vim.cmd.bl(...) end

---go to last buffer in the buffer list
function vim.cmd.blast(...) end

---|:bmodified|
---go to next buffer in the buffer list that has been modified
function vim.cmd.bm(...) end

---go to next buffer in the buffer list that has been modified
function vim.cmd.bmodified(...) end

---|:bnext|
---go to next buffer in the buffer list
function vim.cmd.bn(...) end

---go to next buffer in the buffer list
function vim.cmd.bnext(...) end

---|:botright|
---make split window appear at bottom or far right
function vim.cmd.bo(...) end

---make split window appear at bottom or far right
function vim.cmd.botright(...) end

---|:bprevious|
---go to previous buffer in the buffer list
function vim.cmd.bp(...) end

---go to previous buffer in the buffer list
function vim.cmd.bprevious(...) end

---|:break|
---break out of while loop
function vim.cmd.brea(...) end

---break out of while loop
vim.cmd['break'] = function(...) end

---|:breakadd|
---add a debugger breakpoint
function vim.cmd.breaka(...) end

---add a debugger breakpoint
function vim.cmd.breakadd(...) end

---|:breakdel|
---delete a debugger breakpoint
function vim.cmd.breakd(...) end

---delete a debugger breakpoint
function vim.cmd.breakdel(...) end

---|:breaklist|
---list debugger breakpoints
function vim.cmd.breakl(...) end

---list debugger breakpoints
function vim.cmd.breaklist(...) end

---|:brewind|
---go to first buffer in the buffer list
function vim.cmd.br(...) end

---go to first buffer in the buffer list
function vim.cmd.brewind(...) end

---|:browse|
---use file selection dialog
function vim.cmd.bro(...) end

---use file selection dialog
function vim.cmd.browse(...) end

---execute command in each listed buffer
function vim.cmd.bufdo(...) end

---|:buffer|
---go to specific buffer in the buffer list
function vim.cmd.b(...) end

---go to specific buffer in the buffer list
function vim.cmd.buffer(...) end

---list all files in the buffer list
function vim.cmd.buffers(...) end

---|:bunload|
---unload a specific buffer
function vim.cmd.bun(...) end

---unload a specific buffer
function vim.cmd.bunload(...) end

---|:bwipeout|
---really delete a buffer
function vim.cmd.bw(...) end

---really delete a buffer
function vim.cmd.bwipeout(...) end

---|:cNext|
---go to previous error
function vim.cmd.cN(...) end

---go to previous error
function vim.cmd.cNext(...) end

---|:cNfile|
---go to last error in previous file
function vim.cmd.cNf(...) end

---go to last error in previous file
function vim.cmd.cNfile(...) end

---|:cabbrev|
---like ":abbreviate" but for Command-line mode
function vim.cmd.ca(...) end

---like ":abbreviate" but for Command-line mode
function vim.cmd.cabbrev(...) end

---|:cabclear|
---clear all abbreviations for Command-line mode
function vim.cmd.cabc(...) end

---clear all abbreviations for Command-line mode
function vim.cmd.cabclear(...) end

---|:cabove|
---go to error above current line
function vim.cmd.cabo(...) end

---go to error above current line
function vim.cmd.cabove(...) end

---|:caddbuffer|
---add errors from buffer
function vim.cmd.cad(...) end

---add errors from buffer
function vim.cmd.caddbuffer(...) end

---|:caddexpr|
---add errors from expr
function vim.cmd.cadde(...) end

---add errors from expr
function vim.cmd.caddexpr(...) end

---|:caddfile|
---add error message to current quickfix list
function vim.cmd.caddf(...) end

---add error message to current quickfix list
function vim.cmd.caddfile(...) end

---|:cafter|
---go to error after current cursor
function vim.cmd.caf(...) end

---go to error after current cursor
function vim.cmd.cafter(...) end

---|:call|
---call a function
function vim.cmd.cal(...) end

---call a function
function vim.cmd.call(...) end

---|:catch|
---part of a :try command
function vim.cmd.cat(...) end

---part of a :try command
function vim.cmd.catch(...) end

---|:cbefore|
---go to error before current cursor
function vim.cmd.cbef(...) end

---go to error before current cursor
function vim.cmd.cbefore(...) end

---|:cbelow|
---go to error below current line
function vim.cmd.cbel(...) end

---go to error below current line
function vim.cmd.cbelow(...) end

---|:cbottom|
---scroll to the bottom of the quickfix window
function vim.cmd.cbo(...) end

---scroll to the bottom of the quickfix window
function vim.cmd.cbottom(...) end

---|:cbuffer|
---parse error messages and jump to first error
function vim.cmd.cb(...) end

---parse error messages and jump to first error
function vim.cmd.cbuffer(...) end

---go to specific error
function vim.cmd.cc(...) end

---|:cclose|
---close quickfix window
function vim.cmd.ccl(...) end

---close quickfix window
function vim.cmd.cclose(...) end

---change directory
function vim.cmd.cd(...) end

---execute command in each valid error list entry
function vim.cmd.cdo(...) end

---|:center|
---format lines at the center
function vim.cmd.ce(...) end

---format lines at the center
function vim.cmd.center(...) end

---|:cexpr|
---read errors from expr and jump to first
function vim.cmd.cex(...) end

---read errors from expr and jump to first
function vim.cmd.cexpr(...) end

---|:cfdo|
---execute command in each file in error list
function vim.cmd.cfd(...) end

---execute command in each file in error list
function vim.cmd.cfdo(...) end

---|:cfile|
---read file with error messages and jump to first
function vim.cmd.cf(...) end

---read file with error messages and jump to first
function vim.cmd.cfile(...) end

---|:cfirst|
---go to the specified error, default first one
function vim.cmd.cfir(...) end

---go to the specified error, default first one
function vim.cmd.cfirst(...) end

---|:cgetbuffer|
---get errors from buffer
function vim.cmd.cgetb(...) end

---get errors from buffer
function vim.cmd.cgetbuffer(...) end

---|:cgetexpr|
---get errors from expr
function vim.cmd.cgete(...) end

---get errors from expr
function vim.cmd.cgetexpr(...) end

---|:cgetfile|
---read file with error messages
function vim.cmd.cg(...) end

---read file with error messages
function vim.cmd.cgetfile(...) end

---|:change|
---replace a line or series of lines
function vim.cmd.c(...) end

---replace a line or series of lines
function vim.cmd.change(...) end

---print the change list
function vim.cmd.changes(...) end

---|:chdir|
---change directory
function vim.cmd.chd(...) end

---change directory
function vim.cmd.chdir(...) end

---|:checkhealth|
---run healthchecks
function vim.cmd.che(...) end

---run healthchecks
function vim.cmd.checkhealth(...) end

---|:checkpath|
---list included files
function vim.cmd.checkp(...) end

---list included files
function vim.cmd.checkpath(...) end

---|:checktime|
---check timestamp of loaded buffers
function vim.cmd.checkt(...) end

---check timestamp of loaded buffers
function vim.cmd.checktime(...) end

---|:chistory|
---list the error lists
function vim.cmd.chi(...) end

---list the error lists
function vim.cmd.chistory(...) end

---|:clast|
---go to the specified error, default last one
function vim.cmd.cla(...) end

---go to the specified error, default last one
function vim.cmd.clast(...) end

---|:clearjumps|
---clear the jump list
function vim.cmd.cle(...) end

---clear the jump list
function vim.cmd.clearjumps(...) end

---|:clist|
---list all errors
function vim.cmd.cl(...) end

---list all errors
function vim.cmd.clist(...) end

---|:close|
---close current window
function vim.cmd.clo(...) end

---close current window
function vim.cmd.close(...) end

---|:cmap|
---like ":map" but for Command-line mode
function vim.cmd.cm(...) end

---like ":map" but for Command-line mode
function vim.cmd.cmap(...) end

---|:cmapclear|
---clear all mappings for Command-line mode
function vim.cmd.cmapc(...) end

---clear all mappings for Command-line mode
function vim.cmd.cmapclear(...) end

---|:cmenu|
---add menu for Command-line mode
function vim.cmd.cme(...) end

---add menu for Command-line mode
function vim.cmd.cmenu(...) end

---|:cnewer|
---go to newer error list
function vim.cmd.cnew(...) end

---go to newer error list
function vim.cmd.cnewer(...) end

---|:cnext|
---go to next error
function vim.cmd.cn(...) end

---go to next error
function vim.cmd.cnext(...) end

---|:cnfile|
---go to first error in next file
function vim.cmd.cnf(...) end

---go to first error in next file
function vim.cmd.cnfile(...) end

---|:cnoreabbrev|
---like ":noreabbrev" but for Command-line mode
function vim.cmd.cnorea(...) end

---like ":noreabbrev" but for Command-line mode
function vim.cmd.cnoreabbrev(...) end

---|:cnoremap|
---like ":noremap" but for Command-line mode
function vim.cmd.cno(...) end

---like ":noremap" but for Command-line mode
function vim.cmd.cnoremap(...) end

---|:cnoremenu|
---like ":noremenu" but for Command-line mode
function vim.cmd.cnoreme(...) end

---like ":noremenu" but for Command-line mode
function vim.cmd.cnoremenu(...) end

---|:colder|
---go to older error list
function vim.cmd.col(...) end

---go to older error list
function vim.cmd.colder(...) end

---|:colorscheme|
---load a specific color scheme
function vim.cmd.colo(...) end

---load a specific color scheme
function vim.cmd.colorscheme(...) end

---|:comclear|
---clear all user-defined commands
function vim.cmd.comc(...) end

---clear all user-defined commands
function vim.cmd.comclear(...) end

---|:command|
---create user-defined command
function vim.cmd.com(...) end

---create user-defined command
function vim.cmd.command(...) end

---|:compiler|
---do settings for a specific compiler
function vim.cmd.comp(...) end

---do settings for a specific compiler
function vim.cmd.compiler(...) end

---|:confirm|
---prompt user when confirmation required
function vim.cmd.conf(...) end

---prompt user when confirmation required
function vim.cmd.confirm(...) end

---|:const|
---create a variable as a constant
function vim.cmd.cons(...) end

---create a variable as a constant
function vim.cmd.const(...) end

---|:continue|
---go back to :while
function vim.cmd.con(...) end

---go back to :while
function vim.cmd.continue(...) end

---|:copen|
---open quickfix window
function vim.cmd.cope(...) end

---open quickfix window
function vim.cmd.copen(...) end

---|:copy|
---copy lines
function vim.cmd.co(...) end

---copy lines
function vim.cmd.copy(...) end

---|:cpfile|
---go to last error in previous file
function vim.cmd.cpf(...) end

---go to last error in previous file
function vim.cmd.cpfile(...) end

---|:cprevious|
---go to previous error
function vim.cmd.cp(...) end

---go to previous error
function vim.cmd.cprevious(...) end

---|:cquit|
---quit Vim with an error code
function vim.cmd.cq(...) end

---quit Vim with an error code
function vim.cmd.cquit(...) end

---|:crewind|
---go to the specified error, default first one
function vim.cmd.cr(...) end

---go to the specified error, default first one
function vim.cmd.crewind(...) end

---|:cunabbrev|
---like ":unabbrev" but for Command-line mode
function vim.cmd.cuna(...) end

---like ":unabbrev" but for Command-line mode
function vim.cmd.cunabbrev(...) end

---|:cunmap|
---like ":unmap" but for Command-line mode
function vim.cmd.cu(...) end

---like ":unmap" but for Command-line mode
function vim.cmd.cunmap(...) end

---|:cunmenu|
---remove menu for Command-line mode
function vim.cmd.cunme(...) end

---remove menu for Command-line mode
function vim.cmd.cunmenu(...) end

---|:cwindow|
---open or close quickfix window
function vim.cmd.cw(...) end

---open or close quickfix window
function vim.cmd.cwindow(...) end

---|:debug|
---run a command in debugging mode
function vim.cmd.deb(...) end

---run a command in debugging mode
function vim.cmd.debug(...) end

---|:debuggreedy|
---read debug mode commands from normal input
function vim.cmd.debugg(...) end

---read debug mode commands from normal input
function vim.cmd.debuggreedy(...) end

---call function when current function is done
function vim.cmd.defer(...) end

---|:delcommand|
---delete user-defined command
function vim.cmd.delc(...) end

---delete user-defined command
function vim.cmd.delcommand(...) end

---|:delete|
---delete lines
function vim.cmd.d(...) end

---delete lines
function vim.cmd.delete(...) end

---|:delfunction|
---delete a user function
function vim.cmd.delf(...) end

---delete a user function
function vim.cmd.delfunction(...) end

---|:delmarks|
---delete marks
function vim.cmd.delm(...) end

---delete marks
function vim.cmd.delmarks(...) end

---|:diffget|
---remove differences in current buffer
function vim.cmd.diffg(...) end

---remove differences in current buffer
function vim.cmd.diffget(...) end

---|:diffoff|
---switch off diff mode
function vim.cmd.diffo(...) end

---switch off diff mode
function vim.cmd.diffoff(...) end

---|:diffpatch|
---apply a patch and show differences
function vim.cmd.diffp(...) end

---apply a patch and show differences
function vim.cmd.diffpatch(...) end

---|:diffput|
---remove differences in other buffer
function vim.cmd.diffpu(...) end

---remove differences in other buffer
function vim.cmd.diffput(...) end

---|:diffsplit|
---show differences with another file
function vim.cmd.diffs(...) end

---show differences with another file
function vim.cmd.diffsplit(...) end

---make current window a diff window
function vim.cmd.diffthis(...) end

---|:diffupdate|
---update 'diff' buffers
function vim.cmd.dif(...) end

---update 'diff' buffers
function vim.cmd.diffupdate(...) end

---|:digraphs|
---show or enter digraphs
function vim.cmd.dig(...) end

---show or enter digraphs
function vim.cmd.digraphs(...) end

---|:display|
---display registers
function vim.cmd.di(...) end

---display registers
function vim.cmd.display(...) end

---|:djump|
---jump to #define
function vim.cmd.dj(...) end

---jump to #define
function vim.cmd.djump(...) end

---|:dlist|
---list #defines
function vim.cmd.dli(...) end

---list #defines
function vim.cmd.dlist(...) end

---|:doautoall|
---apply autocommands for all loaded buffers
function vim.cmd.doautoa(...) end

---apply autocommands for all loaded buffers
function vim.cmd.doautoall(...) end

---|:doautocmd|
---apply autocommands to current buffer
vim.cmd['do'] = function(...) end

---apply autocommands to current buffer
function vim.cmd.doautocmd(...) end

---|:drop|
---jump to window editing file or edit file in current window
function vim.cmd.dr(...) end

---jump to window editing file or edit file in current window
function vim.cmd.drop(...) end

---|:dsearch|
---list one #define
function vim.cmd.ds(...) end

---list one #define
function vim.cmd.dsearch(...) end

---|:dsplit|
---split window and jump to #define
function vim.cmd.dsp(...) end

---split window and jump to #define
function vim.cmd.dsplit(...) end

---|:earlier|
---go to older change, undo
function vim.cmd.ea(...) end

---go to older change, undo
function vim.cmd.earlier(...) end

---|:echo|
---echoes the result of expressions
function vim.cmd.ec(...) end

---echoes the result of expressions
function vim.cmd.echo(...) end

---|:echoerr|
---like :echo, show like an error and use history
function vim.cmd.echoe(...) end

---like :echo, show like an error and use history
function vim.cmd.echoerr(...) end

---|:echohl|
---set highlighting for echo commands
function vim.cmd.echoh(...) end

---set highlighting for echo commands
function vim.cmd.echohl(...) end

---|:echomsg|
---same as :echo, put message in history
function vim.cmd.echom(...) end

---same as :echo, put message in history
function vim.cmd.echomsg(...) end

---same as :echo, but without <EOL>
function vim.cmd.echon(...) end

---|:edit|
---edit a file
function vim.cmd.e(...) end

---edit a file
function vim.cmd.edit(...) end

---|:else|
---part of an :if command
function vim.cmd.el(...) end

---part of an :if command
vim.cmd['else'] = function(...) end

---|:elseif|
---part of an :if command
function vim.cmd.elsei(...) end

---part of an :if command
vim.cmd['elseif'] = function(...) end

---|:emenu|
---execute a menu by name
function vim.cmd.em(...) end

---execute a menu by name
function vim.cmd.emenu(...) end

---|:endfor|
---end previous :for
function vim.cmd.endfo(...) end

---end previous :for
function vim.cmd.endfor(...) end

---|:endfunction|
---end of a user function started with :function
function vim.cmd.endf(...) end

---end of a user function started with :function
function vim.cmd.endfunction(...) end

---|:endif|
---end previous :if
function vim.cmd.en(...) end

---end previous :if
function vim.cmd.endif(...) end

---|:endtry|
---end previous :try
function vim.cmd.endt(...) end

---end previous :try
function vim.cmd.endtry(...) end

---|:endwhile|
---end previous :while
function vim.cmd.endw(...) end

---end previous :while
function vim.cmd.endwhile(...) end

---|:enew|
---edit a new, unnamed buffer
function vim.cmd.ene(...) end

---edit a new, unnamed buffer
function vim.cmd.enew(...) end

---|:eval|
---evaluate an expression and discard the result
function vim.cmd.ev(...) end

---evaluate an expression and discard the result
function vim.cmd.eval(...) end

---same as ":edit"
function vim.cmd.ex(...) end

---|:execute|
---execute result of expressions
function vim.cmd.exe(...) end

---execute result of expressions
function vim.cmd.execute(...) end

---|:exit|
---same as ":xit"
function vim.cmd.exi(...) end

---same as ":xit"
function vim.cmd.exit(...) end

---|:exusage|
---overview of Ex commands
function vim.cmd.exu(...) end

---overview of Ex commands
function vim.cmd.exusage(...) end

---|:fclose|
---close floating window
function vim.cmd.fc(...) end

---close floating window
function vim.cmd.fclose(...) end

---|:file|
---show or set the current file name
function vim.cmd.f(...) end

---show or set the current file name
function vim.cmd.file(...) end

---list all files in the buffer list
function vim.cmd.files(...) end

---|:filetype|
---switch file type detection on/off
function vim.cmd.filet(...) end

---switch file type detection on/off
function vim.cmd.filetype(...) end

---|:filter|
---filter output of following command
function vim.cmd.filt(...) end

---filter output of following command
function vim.cmd.filter(...) end

---|:finally|
---part of a :try command
function vim.cmd.fina(...) end

---part of a :try command
function vim.cmd.finally(...) end

---|:find|
---find file in 'path' and edit it
function vim.cmd.fin(...) end

---find file in 'path' and edit it
function vim.cmd.find(...) end

---|:finish|
---quit sourcing a Vim script
function vim.cmd.fini(...) end

---quit sourcing a Vim script
function vim.cmd.finish(...) end

---|:first|
---go to the first file in the argument list
function vim.cmd.fir(...) end

---go to the first file in the argument list
function vim.cmd.first(...) end

---|:fold|
---create a fold
function vim.cmd.fo(...) end

---create a fold
function vim.cmd.fold(...) end

---|:foldclose|
---close folds
function vim.cmd.foldc(...) end

---close folds
function vim.cmd.foldclose(...) end

---|:folddoclosed|
---execute command on lines in a closed fold
function vim.cmd.folddoc(...) end

---execute command on lines in a closed fold
function vim.cmd.folddoclosed(...) end

---|:folddoopen|
---execute command on lines not in a closed fold
function vim.cmd.foldd(...) end

---execute command on lines not in a closed fold
function vim.cmd.folddoopen(...) end

---|:foldopen|
---open folds
function vim.cmd.foldo(...) end

---open folds
function vim.cmd.foldopen(...) end

---for loop
vim.cmd['for'] = function(...) end

---|:function|
---define a user function
function vim.cmd.fu(...) end

---define a user function
vim.cmd['function'] = function(...) end

---|:global|
---execute commands for matching lines
function vim.cmd.g(...) end

---execute commands for matching lines
function vim.cmd.global(...) end

---|:goto|
---go to byte in the buffer
function vim.cmd.go(...) end

---go to byte in the buffer
function vim.cmd.goto(...) end

---|:grep|
---run 'grepprg' and jump to first match
function vim.cmd.gr(...) end

---run 'grepprg' and jump to first match
function vim.cmd.grep(...) end

---|:grepadd|
---like :grep, but append to current list
function vim.cmd.grepa(...) end

---like :grep, but append to current list
function vim.cmd.grepadd(...) end

---|:gui|
---start the GUI
function vim.cmd.gu(...) end

---start the GUI
function vim.cmd.gui(...) end

---|:gvim|
---start the GUI
function vim.cmd.gv(...) end

---start the GUI
function vim.cmd.gvim(...) end

---|:help|
---open a help window
function vim.cmd.h(...) end

---open a help window
function vim.cmd.help(...) end

---|:helpclose|
---close one help window
function vim.cmd.helpc(...) end

---close one help window
function vim.cmd.helpclose(...) end

---|:helpgrep|
---like ":grep" but searches help files
function vim.cmd.helpg(...) end

---like ":grep" but searches help files
function vim.cmd.helpgrep(...) end

---|:helptags|
---generate help tags for a directory
function vim.cmd.helpt(...) end

---generate help tags for a directory
function vim.cmd.helptags(...) end

---|:hide|
---hide current buffer for a command
function vim.cmd.hid(...) end

---hide current buffer for a command
function vim.cmd.hide(...) end

---|:highlight|
---specify highlighting methods
function vim.cmd.hi(...) end

---specify highlighting methods
function vim.cmd.highlight(...) end

---|:history|
---print a history list
function vim.cmd.his(...) end

---print a history list
function vim.cmd.history(...) end

---|:horizontal|
---following window command work horizontally
function vim.cmd.hor(...) end

---following window command work horizontally
function vim.cmd.horizontal(...) end

---|:iabbrev|
---like ":abbrev" but for Insert mode
function vim.cmd.ia(...) end

---like ":abbrev" but for Insert mode
function vim.cmd.iabbrev(...) end

---|:iabclear|
---like ":abclear" but for Insert mode
function vim.cmd.iabc(...) end

---like ":abclear" but for Insert mode
function vim.cmd.iabclear(...) end

---execute commands when condition met
vim.cmd['if'] = function(...) end

---|:ijump|
---jump to definition of identifier
function vim.cmd.ij(...) end

---jump to definition of identifier
function vim.cmd.ijump(...) end

---|:ilist|
---list lines where identifier matches
function vim.cmd.il(...) end

---list lines where identifier matches
function vim.cmd.ilist(...) end

---|:imap|
---like ":map" but for Insert mode
function vim.cmd.im(...) end

---like ":map" but for Insert mode
function vim.cmd.imap(...) end

---|:imapclear|
---like ":mapclear" but for Insert mode
function vim.cmd.imapc(...) end

---like ":mapclear" but for Insert mode
function vim.cmd.imapclear(...) end

---|:imenu|
---add menu for Insert mode
function vim.cmd.ime(...) end

---add menu for Insert mode
function vim.cmd.imenu(...) end

---|:inoreabbrev|
---like ":noreabbrev" but for Insert mode
function vim.cmd.inorea(...) end

---like ":noreabbrev" but for Insert mode
function vim.cmd.inoreabbrev(...) end

---|:inoremap|
---like ":noremap" but for Insert mode
function vim.cmd.ino(...) end

---like ":noremap" but for Insert mode
function vim.cmd.inoremap(...) end

---|:inoremenu|
---like ":noremenu" but for Insert mode
function vim.cmd.inoreme(...) end

---like ":noremenu" but for Insert mode
function vim.cmd.inoremenu(...) end

---|:insert|
---insert text
function vim.cmd.i(...) end

---insert text
function vim.cmd.insert(...) end

---|:intro|
---print the introductory message
function vim.cmd.int(...) end

---print the introductory message
function vim.cmd.intro(...) end

---|:isearch|
---list one line where identifier matches
function vim.cmd.is(...) end

---list one line where identifier matches
function vim.cmd.isearch(...) end

---|:isplit|
---split window and jump to definition of identifier
function vim.cmd.isp(...) end

---split window and jump to definition of identifier
function vim.cmd.isplit(...) end

---|:iunabbrev|
---like ":unabbrev" but for Insert mode
function vim.cmd.iuna(...) end

---like ":unabbrev" but for Insert mode
function vim.cmd.iunabbrev(...) end

---|:iunmap|
---like ":unmap" but for Insert mode
function vim.cmd.iu(...) end

---like ":unmap" but for Insert mode
function vim.cmd.iunmap(...) end

---|:iunmenu|
---remove menu for Insert mode
function vim.cmd.iunme(...) end

---remove menu for Insert mode
function vim.cmd.iunmenu(...) end

---|:join|
---join lines
function vim.cmd.j(...) end

---join lines
function vim.cmd.join(...) end

---|:jumps|
---print the jump list
function vim.cmd.ju(...) end

---print the jump list
function vim.cmd.jumps(...) end

---set a mark
function vim.cmd.k(...) end

---|:keepalt|
---following command keeps the alternate file
function vim.cmd.keepa(...) end

---following command keeps the alternate file
function vim.cmd.keepalt(...) end

---|:keepjumps|
---following command keeps jumplist and marks
function vim.cmd.keepj(...) end

---following command keeps jumplist and marks
function vim.cmd.keepjumps(...) end

---|:keepmarks|
---following command keeps marks where they are
function vim.cmd.kee(...) end

---following command keeps marks where they are
function vim.cmd.keepmarks(...) end

---|:keeppatterns|
---following command keeps search pattern history
function vim.cmd.keepp(...) end

---following command keeps search pattern history
function vim.cmd.keeppatterns(...) end

---|:lNext|
---go to previous entry in location list
function vim.cmd.lN(...) end

---go to previous entry in location list
function vim.cmd.lNext(...) end

---|:lNfile|
---go to last entry in previous file
function vim.cmd.lNf(...) end

---go to last entry in previous file
function vim.cmd.lNfile(...) end

---|:labove|
---go to location above current line
function vim.cmd.lab(...) end

---go to location above current line
function vim.cmd.labove(...) end

---|:laddbuffer|
---add locations from buffer
function vim.cmd.laddb(...) end

---add locations from buffer
function vim.cmd.laddbuffer(...) end

---|:laddexpr|
---add locations from expr
function vim.cmd.lad(...) end

---add locations from expr
function vim.cmd.laddexpr(...) end

---|:laddfile|
---add locations to current location list
function vim.cmd.laddf(...) end

---add locations to current location list
function vim.cmd.laddfile(...) end

---|:lafter|
---go to location after current cursor
function vim.cmd.laf(...) end

---go to location after current cursor
function vim.cmd.lafter(...) end

---|:language|
---set the language (locale)
function vim.cmd.lan(...) end

---set the language (locale)
function vim.cmd.language(...) end

---|:last|
---go to the last file in the argument list
function vim.cmd.la(...) end

---go to the last file in the argument list
function vim.cmd.last(...) end

---|:later|
---go to newer change, redo
function vim.cmd.lat(...) end

---go to newer change, redo
function vim.cmd.later(...) end

---|:lbefore|
---go to location before current cursor
function vim.cmd.lbef(...) end

---go to location before current cursor
function vim.cmd.lbefore(...) end

---|:lbelow|
---go to location below current line
function vim.cmd.lbel(...) end

---go to location below current line
function vim.cmd.lbelow(...) end

---|:lbottom|
---scroll to the bottom of the location window
function vim.cmd.lbo(...) end

---scroll to the bottom of the location window
function vim.cmd.lbottom(...) end

---|:lbuffer|
---parse locations and jump to first location
function vim.cmd.lb(...) end

---parse locations and jump to first location
function vim.cmd.lbuffer(...) end

---|:lcd|
---change directory locally
function vim.cmd.lc(...) end

---change directory locally
function vim.cmd.lcd(...) end

---|:lchdir|
---change directory locally
function vim.cmd.lch(...) end

---change directory locally
function vim.cmd.lchdir(...) end

---|:lclose|
---close location window
function vim.cmd.lcl(...) end

---close location window
function vim.cmd.lclose(...) end

---|:ldo|
---execute command in valid location list entries
function vim.cmd.ld(...) end

---execute command in valid location list entries
function vim.cmd.ldo(...) end

---|:left|
---left align lines
function vim.cmd.le(...) end

---left align lines
function vim.cmd.left(...) end

---|:leftabove|
---make split window appear left or above
function vim.cmd.lefta(...) end

---make split window appear left or above
function vim.cmd.leftabove(...) end

---assign a value to a variable or option
function vim.cmd.let(...) end

---|:lexpr|
---read locations from expr and jump to first
function vim.cmd.lex(...) end

---read locations from expr and jump to first
function vim.cmd.lexpr(...) end

---|:lfdo|
---execute command in each file in location list
function vim.cmd.lfd(...) end

---execute command in each file in location list
function vim.cmd.lfdo(...) end

---|:lfile|
---read file with locations and jump to first
function vim.cmd.lf(...) end

---read file with locations and jump to first
function vim.cmd.lfile(...) end

---|:lfirst|
---go to the specified location, default first one
function vim.cmd.lfir(...) end

---go to the specified location, default first one
function vim.cmd.lfirst(...) end

---|:lgetbuffer|
---get locations from buffer
function vim.cmd.lgetb(...) end

---get locations from buffer
function vim.cmd.lgetbuffer(...) end

---|:lgetexpr|
---get locations from expr
function vim.cmd.lgete(...) end

---get locations from expr
function vim.cmd.lgetexpr(...) end

---|:lgetfile|
---read file with locations
function vim.cmd.lg(...) end

---read file with locations
function vim.cmd.lgetfile(...) end

---|:lgrep|
---run 'grepprg' and jump to first match
function vim.cmd.lgr(...) end

---run 'grepprg' and jump to first match
function vim.cmd.lgrep(...) end

---|:lgrepadd|
---like :grep, but append to current list
function vim.cmd.lgrepa(...) end

---like :grep, but append to current list
function vim.cmd.lgrepadd(...) end

---|:lhelpgrep|
---like ":helpgrep" but uses location list
function vim.cmd.lh(...) end

---like ":helpgrep" but uses location list
function vim.cmd.lhelpgrep(...) end

---|:lhistory|
---list the location lists
function vim.cmd.lhi(...) end

---list the location lists
function vim.cmd.lhistory(...) end

---|:list|
---print lines
function vim.cmd.l(...) end

---print lines
function vim.cmd.list(...) end

---go to specific location
function vim.cmd.ll(...) end

---|:llast|
---go to the specified location, default last one
function vim.cmd.lla(...) end

---go to the specified location, default last one
function vim.cmd.llast(...) end

---|:llist|
---list all locations
function vim.cmd.lli(...) end

---list all locations
function vim.cmd.llist(...) end

---|:lmake|
---execute external command 'makeprg' and parse error messages
function vim.cmd.lmak(...) end

---execute external command 'makeprg' and parse error messages
function vim.cmd.lmake(...) end

---|:lmap|
---like ":map!" but includes Lang-Arg mode
function vim.cmd.lm(...) end

---like ":map!" but includes Lang-Arg mode
function vim.cmd.lmap(...) end

---|:lmapclear|
---like ":mapclear!" but includes Lang-Arg mode
function vim.cmd.lmapc(...) end

---like ":mapclear!" but includes Lang-Arg mode
function vim.cmd.lmapclear(...) end

---|:lnewer|
---go to newer location list
function vim.cmd.lnew(...) end

---go to newer location list
function vim.cmd.lnewer(...) end

---|:lnext|
---go to next location
function vim.cmd.lne(...) end

---go to next location
function vim.cmd.lnext(...) end

---|:lnfile|
---go to first location in next file
function vim.cmd.lnf(...) end

---go to first location in next file
function vim.cmd.lnfile(...) end

---|:lnoremap|
---like ":noremap!" but includes Lang-Arg mode
function vim.cmd.ln(...) end

---like ":noremap!" but includes Lang-Arg mode
function vim.cmd.lnoremap(...) end

---|:loadkeymap|
---load the following keymaps until EOF
function vim.cmd.loadk(...) end

---load the following keymaps until EOF
function vim.cmd.loadkeymap(...) end

---|:loadview|
---load view for current window from a file
function vim.cmd.lo(...) end

---load view for current window from a file
function vim.cmd.loadview(...) end

---|:lockmarks|
---following command keeps marks where they are
function vim.cmd.loc(...) end

---following command keeps marks where they are
function vim.cmd.lockmarks(...) end

---|:lockvar|
---lock variables
function vim.cmd.lockv(...) end

---lock variables
function vim.cmd.lockvar(...) end

---|:lolder|
---go to older location list
function vim.cmd.lol(...) end

---go to older location list
function vim.cmd.lolder(...) end

---|:lopen|
---open location window
function vim.cmd.lope(...) end

---open location window
function vim.cmd.lopen(...) end

---|:lpfile|
---go to last location in previous file
function vim.cmd.lpf(...) end

---go to last location in previous file
function vim.cmd.lpfile(...) end

---|:lprevious|
---go to previous location
function vim.cmd.lp(...) end

---go to previous location
function vim.cmd.lprevious(...) end

---|:lrewind|
---go to the specified location, default first one
function vim.cmd.lr(...) end

---go to the specified location, default first one
function vim.cmd.lrewind(...) end

---list all buffers
function vim.cmd.ls(...) end

---|:ltag|
---jump to tag and add matching tags to the location list
function vim.cmd.lt(...) end

---jump to tag and add matching tags to the location list
function vim.cmd.ltag(...) end

---execute |Lua| command
function vim.cmd.lua(...) end

---|:luado|
---execute Lua command for each line
function vim.cmd.luad(...) end

---execute Lua command for each line
function vim.cmd.luado(...) end

---|:luafile|
---execute |Lua| script file
function vim.cmd.luaf(...) end

---execute |Lua| script file
function vim.cmd.luafile(...) end

---|:lunmap|
---like ":unmap!" but includes Lang-Arg mode
function vim.cmd.lu(...) end

---like ":unmap!" but includes Lang-Arg mode
function vim.cmd.lunmap(...) end

---|:lvimgrep|
---search for pattern in files
function vim.cmd.lv(...) end

---search for pattern in files
function vim.cmd.lvimgrep(...) end

---|:lvimgrepadd|
---like :vimgrep, but append to current list
function vim.cmd.lvimgrepa(...) end

---like :vimgrep, but append to current list
function vim.cmd.lvimgrepadd(...) end

---|:lwindow|
---open or close location window
function vim.cmd.lw(...) end

---open or close location window
function vim.cmd.lwindow(...) end

---|:make|
---execute external command 'makeprg' and parse error messages
function vim.cmd.mak(...) end

---execute external command 'makeprg' and parse error messages
function vim.cmd.make(...) end

---show or enter a mapping
function vim.cmd.map(...) end

---|:mapclear|
---clear all mappings for Normal and Visual mode
function vim.cmd.mapc(...) end

---clear all mappings for Normal and Visual mode
function vim.cmd.mapclear(...) end

---|:mark|
---set a mark
function vim.cmd.ma(...) end

---set a mark
function vim.cmd.mark(...) end

---list all marks
function vim.cmd.marks(...) end

---|:match|
---define a match to highlight
function vim.cmd.mat(...) end

---define a match to highlight
function vim.cmd.match(...) end

---|:menu|
---enter a new menu item
function vim.cmd.me(...) end

---enter a new menu item
function vim.cmd.menu(...) end

---|:menutranslate|
---add a menu translation item
function vim.cmd.menut(...) end

---add a menu translation item
function vim.cmd.menutranslate(...) end

---|:messages|
---view previously displayed messages
function vim.cmd.mes(...) end

---view previously displayed messages
function vim.cmd.messages(...) end

---|:mkexrc|
---write current mappings and settings to a file
function vim.cmd.mk(...) end

---write current mappings and settings to a file
function vim.cmd.mkexrc(...) end

---|:mksession|
---write session info to a file
function vim.cmd.mks(...) end

---write session info to a file
function vim.cmd.mksession(...) end

---|:mkspell|
---produce .spl spell file
function vim.cmd.mksp(...) end

---produce .spl spell file
function vim.cmd.mkspell(...) end

---|:mkview|
---write view of current window to a file
function vim.cmd.mkvie(...) end

---write view of current window to a file
function vim.cmd.mkview(...) end

---|:mkvimrc|
---write current mappings and settings to a file
function vim.cmd.mkv(...) end

---write current mappings and settings to a file
function vim.cmd.mkvimrc(...) end

---|:mode|
---show or change the screen mode
function vim.cmd.mod(...) end

---show or change the screen mode
function vim.cmd.mode(...) end

---|:move|
---move lines
function vim.cmd.m(...) end

---move lines
function vim.cmd.move(...) end

---create a new empty window
function vim.cmd.new(...) end

---|:next|
---go to next file in the argument list
function vim.cmd.n(...) end

---go to next file in the argument list
function vim.cmd.next(...) end

---|:nmap|
---like ":map" but for Normal mode
function vim.cmd.nm(...) end

---like ":map" but for Normal mode
function vim.cmd.nmap(...) end

---|:nmapclear|
---clear all mappings for Normal mode
function vim.cmd.nmapc(...) end

---clear all mappings for Normal mode
function vim.cmd.nmapclear(...) end

---|:nmenu|
---add menu for Normal mode
function vim.cmd.nme(...) end

---add menu for Normal mode
function vim.cmd.nmenu(...) end

---|:nnoremap|
---like ":noremap" but for Normal mode
function vim.cmd.nn(...) end

---like ":noremap" but for Normal mode
function vim.cmd.nnoremap(...) end

---|:nnoremenu|
---like ":noremenu" but for Normal mode
function vim.cmd.nnoreme(...) end

---like ":noremenu" but for Normal mode
function vim.cmd.nnoremenu(...) end

---|:noautocmd|
---following commands don't trigger autocommands
function vim.cmd.noa(...) end

---following commands don't trigger autocommands
function vim.cmd.noautocmd(...) end

---|:nohlsearch|
---suspend 'hlsearch' highlighting
function vim.cmd.noh(...) end

---suspend 'hlsearch' highlighting
function vim.cmd.nohlsearch(...) end

---|:noreabbrev|
---enter an abbreviation that will not be remapped
function vim.cmd.norea(...) end

---enter an abbreviation that will not be remapped
function vim.cmd.noreabbrev(...) end

---|:noremap|
---enter a mapping that will not be remapped
function vim.cmd.no(...) end

---enter a mapping that will not be remapped
function vim.cmd.noremap(...) end

---|:noremenu|
---enter a menu that will not be remapped
function vim.cmd.noreme(...) end

---enter a menu that will not be remapped
function vim.cmd.noremenu(...) end

---|:normal|
---execute Normal mode commands
function vim.cmd.norm(...) end

---execute Normal mode commands
function vim.cmd.normal(...) end

---|:noswapfile|
---following commands don't create a swap file
function vim.cmd.nos(...) end

---following commands don't create a swap file
function vim.cmd.noswapfile(...) end

---|:number|
---print lines with line number
function vim.cmd.nu(...) end

---print lines with line number
function vim.cmd.number(...) end

---|:nunmap|
---like ":unmap" but for Normal mode
function vim.cmd.nun(...) end

---like ":unmap" but for Normal mode
function vim.cmd.nunmap(...) end

---|:nunmenu|
---remove menu for Normal mode
function vim.cmd.nunme(...) end

---remove menu for Normal mode
function vim.cmd.nunmenu(...) end

---|:oldfiles|
---list files that have marks in the |shada| file
function vim.cmd.ol(...) end

---list files that have marks in the |shada| file
function vim.cmd.oldfiles(...) end

---|:omap|
---like ":map" but for Operator-pending mode
function vim.cmd.om(...) end

---like ":map" but for Operator-pending mode
function vim.cmd.omap(...) end

---|:omapclear|
---remove all mappings for Operator-pending mode
function vim.cmd.omapc(...) end

---remove all mappings for Operator-pending mode
function vim.cmd.omapclear(...) end

---|:omenu|
---add menu for Operator-pending mode
function vim.cmd.ome(...) end

---add menu for Operator-pending mode
function vim.cmd.omenu(...) end

---|:only|
---close all windows except the current one
function vim.cmd.on(...) end

---close all windows except the current one
function vim.cmd.only(...) end

---|:onoremap|
---like ":noremap" but for Operator-pending mode
function vim.cmd.ono(...) end

---like ":noremap" but for Operator-pending mode
function vim.cmd.onoremap(...) end

---|:onoremenu|
---like ":noremenu" but for Operator-pending mode
function vim.cmd.onoreme(...) end

---like ":noremenu" but for Operator-pending mode
function vim.cmd.onoremenu(...) end

---|:options|
---open the options-window
function vim.cmd.opt(...) end

---open the options-window
function vim.cmd.options(...) end

---|:ounmap|
---like ":unmap" but for Operator-pending mode
function vim.cmd.ou(...) end

---like ":unmap" but for Operator-pending mode
function vim.cmd.ounmap(...) end

---|:ounmenu|
---remove menu for Operator-pending mode
function vim.cmd.ounme(...) end

---remove menu for Operator-pending mode
function vim.cmd.ounmenu(...) end

---|:ownsyntax|
---set new local syntax highlight for this window
function vim.cmd.ow(...) end

---set new local syntax highlight for this window
function vim.cmd.ownsyntax(...) end

---|:packadd|
---add a plugin from 'packpath'
function vim.cmd.pa(...) end

---add a plugin from 'packpath'
function vim.cmd.packadd(...) end

---|:packloadall|
---load all packages under 'packpath'
function vim.cmd.packl(...) end

---load all packages under 'packpath'
function vim.cmd.packloadall(...) end

---|:pclose|
---close preview window
function vim.cmd.pc(...) end

---close preview window
function vim.cmd.pclose(...) end

---|:pedit|
---edit file in the preview window
function vim.cmd.ped(...) end

---edit file in the preview window
function vim.cmd.pedit(...) end

---|:perl|
---execute perl command
function vim.cmd.pe(...) end

---execute perl command
function vim.cmd.perl(...) end

---|:perldo|
---execute perl command for each line
function vim.cmd.perld(...) end

---execute perl command for each line
function vim.cmd.perldo(...) end

---|:perlfile|
---execute perl script file
function vim.cmd.perlf(...) end

---execute perl script file
function vim.cmd.perlfile(...) end

---|:pop|
---jump to older entry in tag stack
function vim.cmd.po(...) end

---jump to older entry in tag stack
function vim.cmd.pop(...) end

---|:popup|
---popup a menu by name
function vim.cmd.popu(...) end

---popup a menu by name
function vim.cmd.popup(...) end

---|:ppop|
---":pop" in preview window
function vim.cmd.pp(...) end

---":pop" in preview window
function vim.cmd.ppop(...) end

---|:preserve|
---write all text to swap file
function vim.cmd.pre(...) end

---write all text to swap file
function vim.cmd.preserve(...) end

---|:previous|
---go to previous file in argument list
function vim.cmd.prev(...) end

---go to previous file in argument list
function vim.cmd.previous(...) end

---|:print|
---print lines
function vim.cmd.p(...) end

---print lines
function vim.cmd.print(...) end

---|:profdel|
---stop profiling a function or script
function vim.cmd.profd(...) end

---stop profiling a function or script
function vim.cmd.profdel(...) end

---|:profile|
---profiling functions and scripts
function vim.cmd.prof(...) end

---profiling functions and scripts
function vim.cmd.profile(...) end

---|:psearch|
---like ":ijump" but shows match in preview window
function vim.cmd.ps(...) end

---like ":ijump" but shows match in preview window
function vim.cmd.psearch(...) end

---|:ptNext|
---|:tNext| in preview window
function vim.cmd.ptN(...) end

---|:tNext| in preview window
function vim.cmd.ptNext(...) end

---|:ptag|
---show tag in preview window
function vim.cmd.pt(...) end

---show tag in preview window
function vim.cmd.ptag(...) end

---|:ptfirst|
---|:trewind| in preview window
function vim.cmd.ptf(...) end

---|:trewind| in preview window
function vim.cmd.ptfirst(...) end

---|:ptjump|
---|:tjump| and show tag in preview window
function vim.cmd.ptj(...) end

---|:tjump| and show tag in preview window
function vim.cmd.ptjump(...) end

---|:ptlast|
---|:tlast| in preview window
function vim.cmd.ptl(...) end

---|:tlast| in preview window
function vim.cmd.ptlast(...) end

---|:ptnext|
---|:tnext| in preview window
function vim.cmd.ptn(...) end

---|:tnext| in preview window
function vim.cmd.ptnext(...) end

---|:ptprevious|
---|:tprevious| in preview window
function vim.cmd.ptp(...) end

---|:tprevious| in preview window
function vim.cmd.ptprevious(...) end

---|:ptrewind|
---|:trewind| in preview window
function vim.cmd.ptr(...) end

---|:trewind| in preview window
function vim.cmd.ptrewind(...) end

---|:ptselect|
---|:tselect| and show tag in preview window
function vim.cmd.pts(...) end

---|:tselect| and show tag in preview window
function vim.cmd.ptselect(...) end

---|:put|
---insert contents of register in the text
function vim.cmd.pu(...) end

---insert contents of register in the text
function vim.cmd.put(...) end

---|:pwd|
---print current directory
function vim.cmd.pw(...) end

---print current directory
function vim.cmd.pwd(...) end

---execute Python 3 command
function vim.cmd.py3(...) end

---|:py3do|
---execute Python 3 command for each line
function vim.cmd.py3d(...) end

---execute Python 3 command for each line
function vim.cmd.py3do(...) end

---|:py3file|
---execute Python 3 script file
function vim.cmd.py3f(...) end

---execute Python 3 script file
function vim.cmd.py3file(...) end

---|:pydo|
---execute Python command for each line
function vim.cmd.pyd(...) end

---execute Python command for each line
function vim.cmd.pydo(...) end

---|:pyfile|
---execute Python script file
function vim.cmd.pyf(...) end

---execute Python script file
function vim.cmd.pyfile(...) end

---|:python|
---execute Python command
function vim.cmd.py(...) end

---execute Python command
function vim.cmd.python(...) end

---same as :py3
function vim.cmd.python3(...) end

---same as :pyx
function vim.cmd.pythonx(...) end

---execute |python_x| command
function vim.cmd.pyx(...) end

---|:pyxdo|
---execute |python_x| command for each line
function vim.cmd.pyxd(...) end

---execute |python_x| command for each line
function vim.cmd.pyxdo(...) end

---|:pyxfile|
---execute |python_x| script file
function vim.cmd.pyxf(...) end

---execute |python_x| script file
function vim.cmd.pyxfile(...) end

---|:qall|
---quit Vim
function vim.cmd.qa(...) end

---quit Vim
function vim.cmd.qall(...) end

---|:quit|
---quit current window (when one window quit Vim)
function vim.cmd.q(...) end

---quit current window (when one window quit Vim)
function vim.cmd.quit(...) end

---|:quitall|
---quit Vim
function vim.cmd.quita(...) end

---quit Vim
function vim.cmd.quitall(...) end

---|:read|
---read file into the text
function vim.cmd.r(...) end

---read file into the text
function vim.cmd.read(...) end

---|:recover|
---recover a file from a swap file
function vim.cmd.rec(...) end

---recover a file from a swap file
function vim.cmd.recover(...) end

---|:redir|
---redirect messages to a file or register
function vim.cmd.redi(...) end

---redirect messages to a file or register
function vim.cmd.redir(...) end

---|:redo|
---redo one undone change
function vim.cmd.red(...) end

---redo one undone change
function vim.cmd.redo(...) end

---|:redraw|
---force a redraw of the display
function vim.cmd.redr(...) end

---force a redraw of the display
function vim.cmd.redraw(...) end

---|:redrawstatus|
---force a redraw of the status line(s) and window bar(s)
function vim.cmd.redraws(...) end

---force a redraw of the status line(s) and window bar(s)
function vim.cmd.redrawstatus(...) end

---|:redrawtabline|
---force a redraw of the tabline
function vim.cmd.redrawt(...) end

---force a redraw of the tabline
function vim.cmd.redrawtabline(...) end

---|:registers|
---display the contents of registers
function vim.cmd.reg(...) end

---display the contents of registers
function vim.cmd.registers(...) end

---|:resize|
---change current window height
function vim.cmd.res(...) end

---change current window height
function vim.cmd.resize(...) end

---|:retab|
---change tab size
function vim.cmd.ret(...) end

---change tab size
function vim.cmd.retab(...) end

---|:return|
---return from a user function
function vim.cmd.retu(...) end

---return from a user function
vim.cmd['return'] = function(...) end

---|:rewind|
---go to the first file in the argument list
function vim.cmd.rew(...) end

---go to the first file in the argument list
function vim.cmd.rewind(...) end

---|:right|
---right align text
function vim.cmd.ri(...) end

---right align text
function vim.cmd.right(...) end

---|:rightbelow|
---make split window appear right or below
function vim.cmd.rightb(...) end

---make split window appear right or below
function vim.cmd.rightbelow(...) end

---|:rshada|
---read from |shada| file
function vim.cmd.rsh(...) end

---read from |shada| file
function vim.cmd.rshada(...) end

---|:ruby|
---execute Ruby command
function vim.cmd.rub(...) end

---execute Ruby command
function vim.cmd.ruby(...) end

---|:rubydo|
---execute Ruby command for each line
function vim.cmd.rubyd(...) end

---execute Ruby command for each line
function vim.cmd.rubydo(...) end

---|:rubyfile|
---execute Ruby script file
function vim.cmd.rubyf(...) end

---execute Ruby script file
function vim.cmd.rubyfile(...) end

---|:rundo|
---read undo information from a file
function vim.cmd.rund(...) end

---read undo information from a file
function vim.cmd.rundo(...) end

---|:runtime|
---source vim scripts in 'runtimepath'
function vim.cmd.ru(...) end

---source vim scripts in 'runtimepath'
function vim.cmd.runtime(...) end

---|:sNext|
---split window and go to previous file in argument list
function vim.cmd.sN(...) end

---split window and go to previous file in argument list
function vim.cmd.sNext(...) end

---|:sall|
---open a window for each file in argument list
function vim.cmd.sal(...) end

---open a window for each file in argument list
function vim.cmd.sall(...) end

---|:sandbox|
---execute a command in the sandbox
function vim.cmd.san(...) end

---execute a command in the sandbox
function vim.cmd.sandbox(...) end

---|:sargument|
---split window and go to specific file in argument list
function vim.cmd.sa(...) end

---split window and go to specific file in argument list
function vim.cmd.sargument(...) end

---|:saveas|
---save file under another name.
function vim.cmd.sav(...) end

---save file under another name.
function vim.cmd.saveas(...) end

---|:sbNext|
---split window and go to previous file in the buffer list
function vim.cmd.sbN(...) end

---split window and go to previous file in the buffer list
function vim.cmd.sbNext(...) end

---|:sball|
---open a window for each file in the buffer list
function vim.cmd.sba(...) end

---open a window for each file in the buffer list
function vim.cmd.sball(...) end

---|:sbfirst|
---split window and go to first file in the buffer list
function vim.cmd.sbf(...) end

---split window and go to first file in the buffer list
function vim.cmd.sbfirst(...) end

---|:sblast|
---split window and go to last file in buffer list
function vim.cmd.sbl(...) end

---split window and go to last file in buffer list
function vim.cmd.sblast(...) end

---|:sbmodified|
---split window and go to modified file in the buffer list
function vim.cmd.sbm(...) end

---split window and go to modified file in the buffer list
function vim.cmd.sbmodified(...) end

---|:sbnext|
---split window and go to next file in the buffer list
function vim.cmd.sbn(...) end

---split window and go to next file in the buffer list
function vim.cmd.sbnext(...) end

---|:sbprevious|
---split window and go to previous file in the buffer list
function vim.cmd.sbp(...) end

---split window and go to previous file in the buffer list
function vim.cmd.sbprevious(...) end

---|:sbrewind|
---split window and go to first file in the buffer list
function vim.cmd.sbr(...) end

---split window and go to first file in the buffer list
function vim.cmd.sbrewind(...) end

---|:sbuffer|
---split window and go to specific file in the buffer list
function vim.cmd.sb(...) end

---split window and go to specific file in the buffer list
function vim.cmd.sbuffer(...) end

---|:scriptencoding|
---encoding used in sourced Vim script
function vim.cmd.scripte(...) end

---encoding used in sourced Vim script
function vim.cmd.scriptencoding(...) end

---|:scriptnames|
---list names of all sourced Vim scripts
function vim.cmd.scr(...) end

---list names of all sourced Vim scripts
function vim.cmd.scriptnames(...) end

---|:set|
---show or set options
function vim.cmd.se(...) end

---show or set options
function vim.cmd.set(...) end

---|:setfiletype|
---set 'filetype', unless it was set already
function vim.cmd.setf(...) end

---set 'filetype', unless it was set already
function vim.cmd.setfiletype(...) end

---|:setglobal|
---show global values of options
function vim.cmd.setg(...) end

---show global values of options
function vim.cmd.setglobal(...) end

---|:setlocal|
---show or set options locally
function vim.cmd.setl(...) end

---show or set options locally
function vim.cmd.setlocal(...) end

---|:sfind|
---split current window and edit file in 'path'
function vim.cmd.sf(...) end

---split current window and edit file in 'path'
function vim.cmd.sfind(...) end

---|:sfirst|
---split window and go to first file in the argument list
function vim.cmd.sfir(...) end

---split window and go to first file in the argument list
function vim.cmd.sfirst(...) end

---|:sign|
---manipulate signs
function vim.cmd.sig(...) end

---manipulate signs
function vim.cmd.sign(...) end

---|:silent|
---run a command silently
function vim.cmd.sil(...) end

---run a command silently
function vim.cmd.silent(...) end

---|:slast|
---split window and go to last file in the argument list
function vim.cmd.sla(...) end

---split window and go to last file in the argument list
function vim.cmd.slast(...) end

---|:sleep|
---do nothing for a few seconds
function vim.cmd.sl(...) end

---do nothing for a few seconds
function vim.cmd.sleep(...) end

---|:smagic|
---:substitute with 'magic'
function vim.cmd.sm(...) end

---:substitute with 'magic'
function vim.cmd.smagic(...) end

---like ":map" but for Select mode
function vim.cmd.smap(...) end

---|:smapclear|
---remove all mappings for Select mode
function vim.cmd.smapc(...) end

---remove all mappings for Select mode
function vim.cmd.smapclear(...) end

---|:smenu|
---add menu for Select mode
function vim.cmd.sme(...) end

---add menu for Select mode
function vim.cmd.smenu(...) end

---|:snext|
---split window and go to next file in the argument list
function vim.cmd.sn(...) end

---split window and go to next file in the argument list
function vim.cmd.snext(...) end

---|:snomagic|
---:substitute with 'nomagic'
function vim.cmd.sno(...) end

---:substitute with 'nomagic'
function vim.cmd.snomagic(...) end

---|:snoremap|
---like ":noremap" but for Select mode
function vim.cmd.snor(...) end

---like ":noremap" but for Select mode
function vim.cmd.snoremap(...) end

---|:snoremenu|
---like ":noremenu" but for Select mode
function vim.cmd.snoreme(...) end

---like ":noremenu" but for Select mode
function vim.cmd.snoremenu(...) end

---|:sort|
---sort lines
function vim.cmd.sor(...) end

---sort lines
function vim.cmd.sort(...) end

---|:source|
---read Vim or Ex commands from a file
function vim.cmd.so(...) end

---read Vim or Ex commands from a file
function vim.cmd.source(...) end

---|:spelldump|
---split window and fill with all correct words
function vim.cmd.spelld(...) end

---split window and fill with all correct words
function vim.cmd.spelldump(...) end

---|:spellgood|
---add good word for spelling
function vim.cmd.spe(...) end

---add good word for spelling
function vim.cmd.spellgood(...) end

---|:spellinfo|
---show info about loaded spell files
function vim.cmd.spelli(...) end

---show info about loaded spell files
function vim.cmd.spellinfo(...) end

---|:spellrare|
---add rare word for spelling
function vim.cmd.spellra(...) end

---add rare word for spelling
function vim.cmd.spellrare(...) end

---|:spellrepall|
---replace all bad words like last |z=|
function vim.cmd.spellr(...) end

---replace all bad words like last |z=|
function vim.cmd.spellrepall(...) end

---|:spellundo|
---remove good or bad word
function vim.cmd.spellu(...) end

---remove good or bad word
function vim.cmd.spellundo(...) end

---|:spellwrong|
---add spelling mistake
function vim.cmd.spellw(...) end

---add spelling mistake
function vim.cmd.spellwrong(...) end

---|:split|
---split current window
function vim.cmd.sp(...) end

---split current window
function vim.cmd.split(...) end

---|:sprevious|
---split window and go to previous file in the argument list
function vim.cmd.spr(...) end

---split window and go to previous file in the argument list
function vim.cmd.sprevious(...) end

---|:srewind|
---split window and go to first file in the argument list
function vim.cmd.sre(...) end

---split window and go to first file in the argument list
function vim.cmd.srewind(...) end

---|:stag|
---split window and jump to a tag
function vim.cmd.sta(...) end

---split window and jump to a tag
function vim.cmd.stag(...) end

---|:startgreplace|
---start Virtual Replace mode
function vim.cmd.startg(...) end

---start Virtual Replace mode
function vim.cmd.startgreplace(...) end

---|:startinsert|
---start Insert mode
function vim.cmd.star(...) end

---start Insert mode
function vim.cmd.startinsert(...) end

---|:startreplace|
---start Replace mode
function vim.cmd.startr(...) end

---start Replace mode
function vim.cmd.startreplace(...) end

---|:stjump|
---do ":tjump" and split window
function vim.cmd.stj(...) end

---do ":tjump" and split window
function vim.cmd.stjump(...) end

---|:stop|
---suspend the editor or escape to a shell
function vim.cmd.st(...) end

---suspend the editor or escape to a shell
function vim.cmd.stop(...) end

---|:stopinsert|
---stop Insert mode
function vim.cmd.stopi(...) end

---stop Insert mode
function vim.cmd.stopinsert(...) end

---|:stselect|
---do ":tselect" and split window
function vim.cmd.sts(...) end

---do ":tselect" and split window
function vim.cmd.stselect(...) end

---|:substitute|
---find and replace text
function vim.cmd.s(...) end

---find and replace text
function vim.cmd.substitute(...) end

---|:sunhide|
---same as ":unhide"
function vim.cmd.sun(...) end

---same as ":unhide"
function vim.cmd.sunhide(...) end

---|:sunmap|
---like ":unmap" but for Select mode
function vim.cmd.sunm(...) end

---like ":unmap" but for Select mode
function vim.cmd.sunmap(...) end

---|:sunmenu|
---remove menu for Select mode
function vim.cmd.sunme(...) end

---remove menu for Select mode
function vim.cmd.sunmenu(...) end

---|:suspend|
---same as ":stop"
function vim.cmd.sus(...) end

---same as ":stop"
function vim.cmd.suspend(...) end

---|:sview|
---split window and edit file read-only
function vim.cmd.sv(...) end

---split window and edit file read-only
function vim.cmd.sview(...) end

---|:swapname|
---show the name of the current swap file
function vim.cmd.sw(...) end

---show the name of the current swap file
function vim.cmd.swapname(...) end

---|:syncbind|
---sync scroll binding
function vim.cmd.sync(...) end

---sync scroll binding
function vim.cmd.syncbind(...) end

---|:syntax|
---syntax highlighting
function vim.cmd.sy(...) end

---syntax highlighting
function vim.cmd.syntax(...) end

---|:syntime|
---measure syntax highlighting speed
function vim.cmd.synti(...) end

---measure syntax highlighting speed
function vim.cmd.syntime(...) end

---same as ":copy"
function vim.cmd.t(...) end

---|:tNext|
---jump to previous matching tag
function vim.cmd.tN(...) end

---jump to previous matching tag
function vim.cmd.tNext(...) end

---create new tab when opening new window
function vim.cmd.tab(...) end

---|:tabNext|
---go to previous tab page
function vim.cmd.tabN(...) end

---go to previous tab page
function vim.cmd.tabNext(...) end

---|:tabclose|
---close current tab page
function vim.cmd.tabc(...) end

---close current tab page
function vim.cmd.tabclose(...) end

---execute command in each tab page
function vim.cmd.tabdo(...) end

---|:tabedit|
---edit a file in a new tab page
function vim.cmd.tabe(...) end

---edit a file in a new tab page
function vim.cmd.tabedit(...) end

---|:tabfind|
---find file in 'path', edit it in a new tab page
function vim.cmd.tabf(...) end

---find file in 'path', edit it in a new tab page
function vim.cmd.tabfind(...) end

---|:tabfirst|
---go to first tab page
function vim.cmd.tabfir(...) end

---go to first tab page
function vim.cmd.tabfirst(...) end

---|:tablast|
---go to last tab page
function vim.cmd.tabl(...) end

---go to last tab page
function vim.cmd.tablast(...) end

---|:tabmove|
---move tab page to other position
function vim.cmd.tabm(...) end

---move tab page to other position
function vim.cmd.tabmove(...) end

---edit a file in a new tab page
function vim.cmd.tabnew(...) end

---|:tabnext|
---go to next tab page
function vim.cmd.tabn(...) end

---go to next tab page
function vim.cmd.tabnext(...) end

---|:tabonly|
---close all tab pages except the current one
function vim.cmd.tabo(...) end

---close all tab pages except the current one
function vim.cmd.tabonly(...) end

---|:tabprevious|
---go to previous tab page
function vim.cmd.tabp(...) end

---go to previous tab page
function vim.cmd.tabprevious(...) end

---|:tabrewind|
---go to first tab page
function vim.cmd.tabr(...) end

---go to first tab page
function vim.cmd.tabrewind(...) end

---list the tab pages and what they contain
function vim.cmd.tabs(...) end

---|:tag|
---jump to tag
function vim.cmd.ta(...) end

---jump to tag
function vim.cmd.tag(...) end

---show the contents of the tag stack
function vim.cmd.tags(...) end

---|:tcd|
---change directory for tab page
function vim.cmd.tc(...) end

---change directory for tab page
function vim.cmd.tcd(...) end

---|:tchdir|
---change directory for tab page
function vim.cmd.tch(...) end

---change directory for tab page
function vim.cmd.tchdir(...) end

---|:terminal|
---open a terminal buffer
function vim.cmd.te(...) end

---open a terminal buffer
function vim.cmd.terminal(...) end

---|:tfirst|
---jump to first matching tag
function vim.cmd.tf(...) end

---jump to first matching tag
function vim.cmd.tfirst(...) end

---|:throw|
---throw an exception
function vim.cmd.th(...) end

---throw an exception
function vim.cmd.throw(...) end

---|:tjump|
---like ":tselect", but jump directly when there is only one match
function vim.cmd.tj(...) end

---like ":tselect", but jump directly when there is only one match
function vim.cmd.tjump(...) end

---|:tlast|
---jump to last matching tag
function vim.cmd.tl(...) end

---jump to last matching tag
function vim.cmd.tlast(...) end

---|:tlmenu|
---add menu for |Terminal-mode|
function vim.cmd.tlm(...) end

---add menu for |Terminal-mode|
function vim.cmd.tlmenu(...) end

---|:tlnoremenu|
---like ":noremenu" but for |Terminal-mode|
function vim.cmd.tln(...) end

---like ":noremenu" but for |Terminal-mode|
function vim.cmd.tlnoremenu(...) end

---|:tlunmenu|
---remove menu for |Terminal-mode|
function vim.cmd.tlu(...) end

---remove menu for |Terminal-mode|
function vim.cmd.tlunmenu(...) end

---|:tmap|
---like ":map" but for |Terminal-mode|
function vim.cmd.tma(...) end

---like ":map" but for |Terminal-mode|
function vim.cmd.tmap(...) end

---|:tmapclear|
---remove all mappings for |Terminal-mode|
function vim.cmd.tmapc(...) end

---remove all mappings for |Terminal-mode|
function vim.cmd.tmapclear(...) end

---|:tmenu|
---define menu tooltip
function vim.cmd.tm(...) end

---define menu tooltip
function vim.cmd.tmenu(...) end

---|:tnext|
---jump to next matching tag
function vim.cmd.tn(...) end

---jump to next matching tag
function vim.cmd.tnext(...) end

---|:tnoremap|
---like ":noremap" but for |Terminal-mode|
function vim.cmd.tno(...) end

---like ":noremap" but for |Terminal-mode|
function vim.cmd.tnoremap(...) end

---|:topleft|
---make split window appear at top or far left
function vim.cmd.to(...) end

---make split window appear at top or far left
function vim.cmd.topleft(...) end

---|:tprevious|
---jump to previous matching tag
function vim.cmd.tp(...) end

---jump to previous matching tag
function vim.cmd.tprevious(...) end

---|:trewind|
---jump to first matching tag
function vim.cmd.tr(...) end

---jump to first matching tag
function vim.cmd.trewind(...) end

---add or remove file from trust database
function vim.cmd.trust(...) end

---execute commands, abort on error or exception
function vim.cmd.try(...) end

---|:tselect|
---list matching tags and select one
function vim.cmd.ts(...) end

---list matching tags and select one
function vim.cmd.tselect(...) end

---|:tunmap|
---like ":unmap" but for |Terminal-mode|
function vim.cmd.tunma(...) end

---like ":unmap" but for |Terminal-mode|
function vim.cmd.tunmap(...) end

---|:tunmenu|
---remove menu tooltip
function vim.cmd.tu(...) end

---remove menu tooltip
function vim.cmd.tunmenu(...) end

---|:unabbreviate|
---remove abbreviation
function vim.cmd.una(...) end

---remove abbreviation
function vim.cmd.unabbreviate(...) end

---|:undo|
---undo last change(s)
function vim.cmd.u(...) end

---undo last change(s)
function vim.cmd.undo(...) end

---|:undojoin|
---join next change with previous undo block
function vim.cmd.undoj(...) end

---join next change with previous undo block
function vim.cmd.undojoin(...) end

---|:undolist|
---list leafs of the undo tree
function vim.cmd.undol(...) end

---list leafs of the undo tree
function vim.cmd.undolist(...) end

---|:unhide|
---open a window for each loaded file in the buffer list
function vim.cmd.unh(...) end

---open a window for each loaded file in the buffer list
function vim.cmd.unhide(...) end

---|:unlet|
---delete variable
function vim.cmd.unl(...) end

---delete variable
function vim.cmd.unlet(...) end

---|:unlockvar|
---unlock variables
function vim.cmd.unlo(...) end

---unlock variables
function vim.cmd.unlockvar(...) end

---|:unmap|
---remove mapping
function vim.cmd.unm(...) end

---remove mapping
function vim.cmd.unmap(...) end

---|:unmenu|
---remove menu
function vim.cmd.unme(...) end

---remove menu
function vim.cmd.unmenu(...) end

---|:unsilent|
---run a command not silently
function vim.cmd.uns(...) end

---run a command not silently
function vim.cmd.unsilent(...) end

---|:update|
---write buffer if modified
function vim.cmd.up(...) end

---write buffer if modified
function vim.cmd.update(...) end

---|:verbose|
---execute command with 'verbose' set
function vim.cmd.verb(...) end

---execute command with 'verbose' set
function vim.cmd.verbose(...) end

---|:version|
---print version number and other info
function vim.cmd.ve(...) end

---print version number and other info
function vim.cmd.version(...) end

---|:vertical|
---make following command split vertically
function vim.cmd.vert(...) end

---make following command split vertically
function vim.cmd.vertical(...) end

---|:vglobal|
---execute commands for not matching lines
function vim.cmd.v(...) end

---execute commands for not matching lines
function vim.cmd.vglobal(...) end

---|:view|
---edit a file read-only
function vim.cmd.vie(...) end

---edit a file read-only
function vim.cmd.view(...) end

---|:vimgrep|
---search for pattern in files
function vim.cmd.vim(...) end

---search for pattern in files
function vim.cmd.vimgrep(...) end

---|:vimgrepadd|
---like :vimgrep, but append to current list
function vim.cmd.vimgrepa(...) end

---like :vimgrep, but append to current list
function vim.cmd.vimgrepadd(...) end

---|:visual|
---same as ":edit", but turns off "Ex" mode
function vim.cmd.vi(...) end

---same as ":edit", but turns off "Ex" mode
function vim.cmd.visual(...) end

---|:viusage|
---overview of Normal mode commands
function vim.cmd.viu(...) end

---overview of Normal mode commands
function vim.cmd.viusage(...) end

---|:vmap|
---like ":map" but for Visual+Select mode
function vim.cmd.vm(...) end

---like ":map" but for Visual+Select mode
function vim.cmd.vmap(...) end

---|:vmapclear|
---remove all mappings for Visual+Select mode
function vim.cmd.vmapc(...) end

---remove all mappings for Visual+Select mode
function vim.cmd.vmapclear(...) end

---|:vmenu|
---add menu for Visual+Select mode
function vim.cmd.vme(...) end

---add menu for Visual+Select mode
function vim.cmd.vmenu(...) end

---|:vnew|
---create a new empty window, vertically split
function vim.cmd.vne(...) end

---create a new empty window, vertically split
function vim.cmd.vnew(...) end

---|:vnoremap|
---like ":noremap" but for Visual+Select mode
function vim.cmd.vn(...) end

---like ":noremap" but for Visual+Select mode
function vim.cmd.vnoremap(...) end

---|:vnoremenu|
---like ":noremenu" but for Visual+Select mode
function vim.cmd.vnoreme(...) end

---like ":noremenu" but for Visual+Select mode
function vim.cmd.vnoremenu(...) end

---|:vsplit|
---split current window vertically
function vim.cmd.vs(...) end

---split current window vertically
function vim.cmd.vsplit(...) end

---|:vunmap|
---like ":unmap" but for Visual+Select mode
function vim.cmd.vu(...) end

---like ":unmap" but for Visual+Select mode
function vim.cmd.vunmap(...) end

---|:vunmenu|
---remove menu for Visual+Select mode
function vim.cmd.vunme(...) end

---remove menu for Visual+Select mode
function vim.cmd.vunmenu(...) end

---|:wNext|
---write to a file and go to previous file in argument list
function vim.cmd.wN(...) end

---write to a file and go to previous file in argument list
function vim.cmd.wNext(...) end

---|:wall|
---write all (changed) buffers
function vim.cmd.wa(...) end

---write all (changed) buffers
function vim.cmd.wall(...) end

---|:while|
---execute loop for as long as condition met
function vim.cmd.wh(...) end

---execute loop for as long as condition met
vim.cmd['while'] = function(...) end

---|:wincmd|
---execute a Window (CTRL-W) command
function vim.cmd.winc(...) end

---execute a Window (CTRL-W) command
function vim.cmd.wincmd(...) end

---execute command in each window
function vim.cmd.windo(...) end

---|:winpos|
---get or set window position
function vim.cmd.winp(...) end

---get or set window position
function vim.cmd.winpos(...) end

---|:winsize|
---get or set window size (obsolete)
function vim.cmd.wi(...) end

---get or set window size (obsolete)
function vim.cmd.winsize(...) end

---|:wnext|
---write to a file and go to next file in argument list
function vim.cmd.wn(...) end

---write to a file and go to next file in argument list
function vim.cmd.wnext(...) end

---|:wprevious|
---write to a file and go to previous file in argument list
function vim.cmd.wp(...) end

---write to a file and go to previous file in argument list
function vim.cmd.wprevious(...) end

---write to a file and quit window or Vim
function vim.cmd.wq(...) end

---|:wqall|
---write all changed buffers and quit Vim
function vim.cmd.wqa(...) end

---write all changed buffers and quit Vim
function vim.cmd.wqall(...) end

---|:write|
---write to a file
function vim.cmd.w(...) end

---write to a file
function vim.cmd.write(...) end

---|:wshada|
---write to ShaDa file
function vim.cmd.wsh(...) end

---write to ShaDa file
function vim.cmd.wshada(...) end

---|:wundo|
---write undo information to a file
function vim.cmd.wu(...) end

---write undo information to a file
function vim.cmd.wundo(...) end

---|:xall|
---same as ":wqall"
function vim.cmd.xa(...) end

---same as ":wqall"
function vim.cmd.xall(...) end

---|:xit|
---write if buffer changed and close window
function vim.cmd.x(...) end

---write if buffer changed and close window
function vim.cmd.xit(...) end

---|:xmap|
---like ":map" but for Visual mode
function vim.cmd.xm(...) end

---like ":map" but for Visual mode
function vim.cmd.xmap(...) end

---|:xmapclear|
---remove all mappings for Visual mode
function vim.cmd.xmapc(...) end

---remove all mappings for Visual mode
function vim.cmd.xmapclear(...) end

---|:xmenu|
---add menu for Visual mode
function vim.cmd.xme(...) end

---add menu for Visual mode
function vim.cmd.xmenu(...) end

---|:xnoremap|
---like ":noremap" but for Visual mode
function vim.cmd.xn(...) end

---like ":noremap" but for Visual mode
function vim.cmd.xnoremap(...) end

---|:xnoremenu|
---like ":noremenu" but for Visual mode
function vim.cmd.xnoreme(...) end

---like ":noremenu" but for Visual mode
function vim.cmd.xnoremenu(...) end

---|:xunmap|
---like ":unmap" but for Visual mode
function vim.cmd.xu(...) end

---like ":unmap" but for Visual mode
function vim.cmd.xunmap(...) end

---|:xunmenu|
---remove menu for Visual mode
function vim.cmd.xunme(...) end

---remove menu for Visual mode
function vim.cmd.xunmenu(...) end

---|:yank|
---yank lines into a register
function vim.cmd.y(...) end

---yank lines into a register
function vim.cmd.yank(...) end

---print some lines
function vim.cmd.z(...) end

---repeat last ":substitute"
vim.cmd['~'] = function(...) end
