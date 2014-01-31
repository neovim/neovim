" Vim script for exists() function test
" Script-local variables are checked here

" Existing script-local variable
let s:script_var = 1
echo 's:script_var: 1'
if exists('s:script_var')
    echo "OK"
else
    echo "FAILED"
endif

" Non-existing script-local variable
unlet s:script_var
echo 's:script_var: 0'
if !exists('s:script_var')
    echo "OK"
else
    echo "FAILED"
endif

" Existing script-local list
let s:script_list = ["blue", "orange"]
echo 's:script_list: 1'
if exists('s:script_list')
    echo "OK"
else
    echo "FAILED"
endif

" Non-existing script-local list
unlet s:script_list
echo 's:script_list: 0'
if !exists('s:script_list')
    echo "OK"
else
    echo "FAILED"
endif

" Existing script-local dictionary
let s:script_dict = {"xcord":100, "ycord":2}
echo 's:script_dict: 1'
if exists('s:script_dict')
    echo "OK"
else
    echo "FAILED"
endif

" Non-existing script-local dictionary
unlet s:script_dict
echo 's:script_dict: 0'
if !exists('s:script_dict')
    echo "OK"
else
    echo "FAILED"
endif

" Existing script curly-brace variable
let str = "script"
let s:curly_{str}_var = 1
echo 's:curly_' . str . '_var: 1'
if exists('s:curly_{str}_var')
    echo "OK"
else
    echo "FAILED"
endif

" Non-existing script-local curly-brace variable
unlet s:curly_{str}_var
echo 's:curly_' . str . '_var: 0'
if !exists('s:curly_{str}_var')
    echo "OK"
else
    echo "FAILED"
endif

" Existing script-local function
function! s:my_script_func()
endfunction

echo '*s:my_script_func: 1'
if exists('*s:my_script_func')
    echo "OK"
else
    echo "FAILED"
endif

" Non-existing script-local function
delfunction s:my_script_func

echo '*s:my_script_func: 0'
if !exists('*s:my_script_func')
    echo "OK"
else
    echo "FAILED"
endif
unlet str

