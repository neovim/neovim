" Replace word under cursor (which should be a GitHub username)
" with some user info ("Full Name <email@address>").
" If info cout not be found, "Not found" is inserted.
function! <SID>InsertGitHubUserInfo()
    let l:user = expand('<cWORD>')
    " final slice is to remove ending newline
    let l:info = system('github_user_info ' . l:user . ' 2> /dev/null')[:-2]
    if v:shell_error
        let l:info = 'Not found'
    endif
    execute "normal! diWa" . l:info . "\<esc>"
endfunction

nnoremap <silent> <leader>gu :call <SID>InsertGitHubUserInfo()<cr>
