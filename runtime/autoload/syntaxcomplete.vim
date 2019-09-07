" Vim completion script
" Language:    All languages, uses existing syntax highlighting rules
" Maintainer:  David Fishburn <dfishburn dot vim at gmail dot com>
" Version:     13.0
" Last Change: 2019 Aug 08
" Usage:       For detailed help, ":help ft-syntax-omni"

" History
"
" Version 13.0
"   - Extended the option omni_syntax_group_include_{filetype}
"     to accept a comma separated list of regex's rather than
"     string.  For example, for the javascript filetype you could
"     use:
"        let g:omni_syntax_group_include_javascript = 'javascript\w\+,jquery\w\+'
"   - Some syntax files (perl.vim) use the match // syntax as a mechanism
"     to identify keywords.  This update attempts to parse the
"     match syntax and pull out syntax items which are at least
"     3 words or more.
"
" Version 12.0
"   - It is possible to have '-' as part of iskeyword, when
"     checking for character ranges, tighten up the regex.
"     E688: More targets than List items.
"
" Version 11.0
"   - Corrected which characters required escaping during
"     substitution calls.
"
" Version 10.0
"   - Cycle through all the character ranges specified in the
"     iskeyword option and build a list of valid word separators.
"     Prior to this change, only actual characters were used,
"     where for example ASCII "45" == "-".  If "45" were used
"     in iskeyword the hyphen would not be picked up.
"     This introduces a new option, since the character ranges
"     specified could be multibyte:
"         let g:omni_syntax_use_single_byte = 1
"   - This by default will only allow single byte ASCII
"     characters to be added and an additional check to ensure
"     the charater is printable (see documentation for isprint).
"
" Version 9.0
"   - Add the check for cpo.
"
" Version 8.0
"   - Updated SyntaxCSyntaxGroupItems()
"         - Some additional syntax items were also allowed
"           on nextgroup= lines which were ignored by default.
"           Now these lines are processed independently.
"
" Version 7.0
"   - Updated syntaxcomplete#OmniSyntaxList()
"         - Looking up the syntax groups defined from a syntax file
"           looked for only 1 format of {filetype}GroupName, but some
"           syntax writers use this format as well:
"               {b:current_syntax}GroupName
"   -       OmniSyntaxList() will now check for both if the first
"           method does not find a match.
"
" Version 6.0
"   - Added syntaxcomplete#OmniSyntaxList()
"         - Allows other plugins to use this for their own
"           purposes.
"         - It will return a List of all syntax items for the
"           syntax group name passed in.
"         - XPTemplate for SQL will use this function via the
"           sqlcomplete plugin to populate a Choose box.
"
" Version 5.0
"   - Updated SyntaxCSyntaxGroupItems()
"         - When processing a list of syntax groups, the final group
"           was missed in function SyntaxCSyntaxGroupItems.
"
" Set completion with CTRL-X CTRL-O to autoloaded function.
" This check is in place in case this script is
" sourced directly instead of using the autoload feature.
if exists('+omnifunc')
    " Do not set the option if already set since this
    " results in an E117 warning.
    if &omnifunc == ""
        setlocal omnifunc=syntaxcomplete#Complete
    endif
endif

if exists('g:loaded_syntax_completion')
    finish
endif
let g:loaded_syntax_completion = 130

" Turn on support for line continuations when creating the script
let s:cpo_save = &cpo
set cpo&vim

" Set ignorecase to the ftplugin standard
" This is the default setting, but if you define a buffer local
" variable you can override this on a per filetype.
if !exists('g:omni_syntax_ignorecase')
    let g:omni_syntax_ignorecase = &ignorecase
endif

" Indicates whether we should use the iskeyword option to determine
" how to split words.
" This is the default setting, but if you define a buffer local
" variable you can override this on a per filetype.
if !exists('g:omni_syntax_use_iskeyword')
    let g:omni_syntax_use_iskeyword = 1
endif

" When using iskeyword, this setting controls whether the characters
" should be limited to single byte characters.
if !exists('g:omni_syntax_use_single_byte')
    let g:omni_syntax_use_single_byte = 1
endif

" When using iskeyword, this setting controls whether the characters
" should be limited to single byte characters.
if !exists('g:omni_syntax_use_iskeyword_numeric')
    let g:omni_syntax_use_iskeyword_numeric = 1
endif

" Only display items in the completion window that are at least
" this many characters in length.
" This is the default setting, but if you define a buffer local
" variable you can override this on a per filetype.
if !exists('g:omni_syntax_minimum_length')
    let g:omni_syntax_minimum_length = 0
endif

" This script will build a completion list based on the syntax
" elements defined by the files in $VIMRUNTIME/syntax.
" let s:syn_remove_words = 'match,matchgroup=,contains,'.
let s:syn_remove_words = 'matchgroup=,contains,'.
            \ 'links to,start=,end='
            " \ 'links to,start=,end=,nextgroup='

let s:cache_name = []
let s:cache_list = []
let s:prepended  = ''

" This function is used for the 'omnifunc' option.
function! syntaxcomplete#Complete(findstart, base)

    " Only display items in the completion window that are at least
    " this many characters in length
    if !exists('b:omni_syntax_ignorecase')
        if exists('g:omni_syntax_ignorecase')
            let b:omni_syntax_ignorecase = g:omni_syntax_ignorecase
        else
            let b:omni_syntax_ignorecase = &ignorecase
        endif
    endif

    if a:findstart
        " Locate the start of the item, including "."
        let line = getline('.')
        let start = col('.') - 1
        let lastword = -1
        while start > 0
            " if line[start - 1] =~ '\S'
            "     let start -= 1
            " elseif line[start - 1] =~ '\.'
            if line[start - 1] =~ '\k'
                let start -= 1
                let lastword = a:findstart
            else
                break
            endif
        endwhile

        " Return the column of the last word, which is going to be changed.
        " Remember the text that comes before it in s:prepended.
        if lastword == -1
            let s:prepended = ''
            return start
        endif
        let s:prepended = strpart(line, start, (col('.') - 1) - start)
        return start
    endif

    " let base = s:prepended . a:base
    let base = s:prepended

    let filetype = substitute(&filetype, '\.', '_', 'g')
    let list_idx = index(s:cache_name, filetype, 0, &ignorecase)
    if list_idx > -1
        let compl_list = s:cache_list[list_idx]
    else
        let compl_list   = OmniSyntaxList()
        let s:cache_name = add( s:cache_name,  filetype )
        let s:cache_list = add( s:cache_list,  compl_list )
    endif

    " Return list of matches.

    if base != ''
        " let compstr    = join(compl_list, ' ')
        " let expr       = (b:omni_syntax_ignorecase==0?'\C':'').'\<\%('.base.'\)\@!\w\+\s*'
        " let compstr    = substitute(compstr, expr, '', 'g')
        " let compl_list = split(compstr, '\s\+')

        " Filter the list based on the first few characters the user
        " entered
        let expr = 'v:val '.(g:omni_syntax_ignorecase==1?'=~?':'=~#')." '^".escape(base, '\\/.*$^~[]').".*'"
        let compl_list = filter(deepcopy(compl_list), expr)
    endif

    return compl_list
endfunc

function! syntaxcomplete#OmniSyntaxList(...)
    if a:0 > 0
        let parms = []
        if 3 == type(a:1)
            let parms = a:1
        elseif 1 == type(a:1)
            let parms = split(a:1, ',')
        endif
        return OmniSyntaxList( parms )
    else
        return OmniSyntaxList()
    endif
endfunc

function! OmniSyntaxList(...)
    let list_parms = []
    if a:0 > 0
        if 3 == type(a:1)
            let list_parms = a:1
        elseif 1 == type(a:1)
            let list_parms = split(a:1, ',')
        endif
    endif

    " Default to returning a dictionary, if use_dictionary is set to 0
    " a list will be returned.
    " let use_dictionary = 1
    " if a:0 > 0 && a:1 != ''
    "     let use_dictionary = a:1
    " endif

    " Only display items in the completion window that are at least
    " this many characters in length
    if !exists('b:omni_syntax_use_iskeyword')
        if exists('g:omni_syntax_use_iskeyword')
            let b:omni_syntax_use_iskeyword = g:omni_syntax_use_iskeyword
        else
            let b:omni_syntax_use_iskeyword = 1
        endif
    endif

    " Only display items in the completion window that are at least
    " this many characters in length
    if !exists('b:omni_syntax_minimum_length')
        if exists('g:omni_syntax_minimum_length')
            let b:omni_syntax_minimum_length = g:omni_syntax_minimum_length
        else
            let b:omni_syntax_minimum_length = 0
        endif
    endif

    let saveL = @l
    let filetype = substitute(&filetype, '\.', '_', 'g')

    if empty(list_parms)
        " Default the include group to include the requested syntax group
        let syntax_group_include_{filetype} = ''
        " Check if there are any overrides specified for this filetype
        if exists('g:omni_syntax_group_include_'.filetype)
            let syntax_group_include_{filetype} =
                        \ substitute( g:omni_syntax_group_include_{filetype},'\s\+','','g')
            let list_parms = split(g:omni_syntax_group_include_{filetype}, ',')
            if syntax_group_include_{filetype} =~ '\w'
                let syntax_group_include_{filetype} =
                            \ substitute( syntax_group_include_{filetype},
                            \ '\s*,\s*', '\\|', 'g'
                            \ )
            endif
        endif
    else
        " A specific list was provided, use it
    endif

    " Loop through all the syntax groupnames, and build a
    " syntax file which contains these names.  This can
    " work generically for any filetype that does not already
    " have a plugin defined.
    " This ASSUMES the syntax groupname BEGINS with the name
    " of the filetype.  From my casual viewing of the vim7\syntax
    " directory this is true for almost all syntax definitions.
    " As an example, the SQL syntax groups have this pattern:
    "     sqlType
    "     sqlOperators
    "     sqlKeyword ...
    if !empty(list_parms) && empty(substitute(join(list_parms), '[a-zA-Z ]', '', 'g'))
        " If list_parms only includes word characters, use it to limit
        " the syntax elements.
        " If using regex syntax list will fail to find those items, so
        " simply grab the who syntax list.
        redir @l
        silent! exec 'syntax list '.join(list_parms)
        redir END
    else
        redir @l
        silent! exec 'syntax list'
        redir END
    endif

    let syntax_full = "\n".@l
    let @l = saveL

    if syntax_full =~ 'E28'
                \ || syntax_full =~ 'E411'
                \ || syntax_full =~ 'E415'
                \ || syntax_full =~ 'No Syntax items'
        return []
    endif

    let filetype = substitute(&filetype, '\.', '_', 'g')

    let list_exclude_groups = []
    if a:0 > 0
        " Do nothing since we have specific a specific list of groups
    else
        " Default the exclude group to nothing
        let syntax_group_exclude_{filetype} = ''
        " Check if there are any overrides specified for this filetype
        if exists('g:omni_syntax_group_exclude_'.filetype)
            let syntax_group_exclude_{filetype} =
                        \ substitute( g:omni_syntax_group_exclude_{filetype},'\s\+','','g')
            let list_exclude_groups = split(g:omni_syntax_group_exclude_{filetype}, ',')
            if syntax_group_exclude_{filetype} =~ '\w'
                let syntax_group_exclude_{filetype} =
                            \ substitute( syntax_group_exclude_{filetype},
                            \ '\s*,\s*', '\\|', 'g'
                            \ )
            endif
        endif
    endif

    if empty(list_parms)
        let list_parms = [&filetype.'\w\+']
    endif

    let syn_list = ''
    let index    = 0
    for group_regex in list_parms
        " Sometimes filetypes can be composite names, like c.doxygen
        " Loop through each individual part looking for the syntax
        " items specific to each individual filetype.
        " let ftindex  = 0
        " let ftindex  = match(syntax_full, group_regex, ftindex)

        " while ftindex > -1
            " let ft_part_name = matchstr( syntax_full, '\w\+', ftindex )

            " Syntax rules can contain items for more than just the current
            " filetype.  They can contain additional items added by the user
            " via autocmds or their vimrc.
            " Some syntax files can be combined (html, php, jsp).
            " We want only items that begin with the filetype we are interested in.
            let next_group_regex = '\n' .
                        \ '\zs'.group_regex.'\ze'.
                        \ '\s\+xxx\s\+'
            let index    = match(syntax_full, next_group_regex, index)

            " For the matched group name, strip off any of the regex special
            " characters and see if we get a match with the current syntax
            if index == -1 && exists('b:current_syntax') && substitute(group_regex, '[^a-zA-Z ]\+.*', '', 'g') !~ '^'.b:current_syntax
                " There appears to be two standards when writing syntax files.
                " Either items begin as:
                "     syn keyword {filetype}Keyword         values ...
                "     let b:current_syntax = "sql"
                "     let b:current_syntax = "sqlanywhere"
                " Or
                "     syn keyword {syntax_filename}Keyword  values ...
                "     let b:current_syntax = "mysql"
                " So, we will make the format of finding the syntax group names
                " a bit more flexible and look for both if the first fails to
                " find a match.
                let next_group_regex = '\n' .
                            \ '\zs'.b:current_syntax.'\w\+\ze'.
                            \ '\s\+xxx\s\+'
                let index    = 0
                let index    = match(syntax_full, next_group_regex, index)
            endif

            while index > -1
                let group_name = matchstr( syntax_full, '\w\+', index )

                let get_syn_list = 1
                for exclude_group_name in list_exclude_groups
                    if '\<'.exclude_group_name.'\>' =~ '\<'.group_name.'\>'
                        let get_syn_list = 0
                    endif
                endfor

                " This code is no longer needed in version 6.0 since we have
                " augmented the syntax list command to only retrieve the syntax
                " groups we are interested in.
                "
                " if get_syn_list == 1
                "     if syntax_group_include_{filetype} != ''
                "         if '\<'.syntax_group_include_{filetype}.'\>' !~ '\<'.group_name.'\>'
                "             let get_syn_list = 0
                "         endif
                "     endif
                " endif

                if get_syn_list == 1
                    " Pass in the full syntax listing, plus the group name we
                    " are interested in.
                    let extra_syn_list = s:SyntaxCSyntaxGroupItems(group_name, syntax_full)
                    let syn_list = syn_list . extra_syn_list . "\n"
                endif

                let index = index + strlen(group_name)
                let index = match(syntax_full, next_group_regex, index)
            endwhile

            " let ftindex  = ftindex + len(ft_part_name)
            " let ftindex  = match( syntax_full, group_regex, ftindex )
        " endwhile
    endfor

"   " Sometimes filetypes can be composite names, like c.doxygen
"   " Loop through each individual part looking for the syntax
"   " items specific to each individual filetype.
"   let syn_list = ''
"   let ftindex  = 0
"   let ftindex  = match(&filetype, '\w\+', ftindex)

"   while ftindex > -1
"       let ft_part_name = matchstr( &filetype, '\w\+', ftindex )

"       " Syntax rules can contain items for more than just the current
"       " filetype.  They can contain additional items added by the user
"       " via autocmds or their vimrc.
"       " Some syntax files can be combined (html, php, jsp).
"       " We want only items that begin with the filetype we are interested in.
"       let next_group_regex = '\n' .
"                   \ '\zs'.ft_part_name.'\w\+\ze'.
"                   \ '\s\+xxx\s\+'
"       let index    = 0
"       let index    = match(syntax_full, next_group_regex, index)

"       if index == -1 && exists('b:current_syntax') && ft_part_name != b:current_syntax
"           " There appears to be two standards when writing syntax files.
"           " Either items begin as:
"           "     syn keyword {filetype}Keyword         values ...
"           "     let b:current_syntax = "sql"
"           "     let b:current_syntax = "sqlanywhere"
"           " Or
"           "     syn keyword {syntax_filename}Keyword  values ...
"           "     let b:current_syntax = "mysql"
"           " So, we will make the format of finding the syntax group names
"           " a bit more flexible and look for both if the first fails to
"           " find a match.
"           let next_group_regex = '\n' .
"                       \ '\zs'.b:current_syntax.'\w\+\ze'.
"                       \ '\s\+xxx\s\+'
"           let index    = 0
"           let index    = match(syntax_full, next_group_regex, index)
"       endif

"       while index > -1
"           let group_name = matchstr( syntax_full, '\w\+', index )

"           let get_syn_list = 1
"           for exclude_group_name in list_exclude_groups
"               if '\<'.exclude_group_name.'\>' =~ '\<'.group_name.'\>'
"                   let get_syn_list = 0
"               endif
"           endfor

"           " This code is no longer needed in version 6.0 since we have
"           " augmented the syntax list command to only retrieve the syntax
"           " groups we are interested in.
"           "
"           " if get_syn_list == 1
"           "     if syntax_group_include_{filetype} != ''
"           "         if '\<'.syntax_group_include_{filetype}.'\>' !~ '\<'.group_name.'\>'
"           "             let get_syn_list = 0
"           "         endif
"           "     endif
"           " endif

"           if get_syn_list == 1
"               " Pass in the full syntax listing, plus the group name we
"               " are interested in.
"               let extra_syn_list = s:SyntaxCSyntaxGroupItems(group_name, syntax_full)
"               let syn_list = syn_list . extra_syn_list . "\n"
"           endif

"           let index = index + strlen(group_name)
"           let index = match(syntax_full, next_group_regex, index)
"       endwhile

"       let ftindex  = ftindex + len(ft_part_name)
"       let ftindex  = match( &filetype, '\w\+', ftindex )
"   endwhile

    " Convert the string to a List and sort it.
    let compl_list = sort(split(syn_list))

    if &filetype == 'vim'
        let short_compl_list = []
        for i in range(len(compl_list))
            if i == len(compl_list)-1
                let next = i
            else
                let next = i + 1
            endif
            if  compl_list[next] !~ '^'.compl_list[i].'.$'
                let short_compl_list += [compl_list[i]]
            endif
        endfor

        return short_compl_list
    else
        return compl_list
    endif
endfunction

function! s:SyntaxCSyntaxGroupItems( group_name, syntax_full )

    let syn_list = ""

    " From the full syntax listing, strip out the portion for the
    " request group.
    " Query:
    "     \n           - must begin with a newline
    "     a:group_name - the group name we are interested in
    "     \s\+xxx\s\+  - group names are always followed by xxx
    "     \zs          - start the match
    "     .\{-}        - everything ...
    "     \ze          - end the match
    "     \(           - start a group or 2 potential matches
    "     \n\w         - at the first newline starting with a character
    "     \|           - 2nd potential match
    "     \%$          - matches end of the file or string
    "     \)           - end a group
    let syntax_group = matchstr(a:syntax_full,
                \ "\n".a:group_name.'\s\+xxx\s\+\zs.\{-}\ze\(\n\w\|\%$\)'
                \ )

    if syntax_group != ""
        " let syn_list = substitute( @l, '^.*xxx\s*\%(contained\s*\)\?', "", '' )
        " let syn_list = substitute( @l, '^.*xxx\s*', "", '' )

        " We only want the words for the lines beginning with
        " containedin, but there could be other items.

        " Tried to remove all lines that do not begin with contained
        " but this does not work in all cases since you can have
        "    contained nextgroup=...
        " So this will strip off the ending of lines with known
        " keywords.
        let syn_list = substitute(
                    \    syntax_group, '\<\('.
                    \    substitute(
                    \      escape(s:syn_remove_words, '\\/.*$^~[]')
                    \      , ',', '\\|', 'g'
                    \    ).
                    \    '\).\{-}\%($\|'."\n".'\)'
                    \    , "\n", 'g'
                    \  )

        " Attempt to deal with lines using the match syntax
        " javaScriptDocTags xxx match /@\(param\|argument\|requires\|file\)\>/
        " Though it can use any types of regex, so this plugin will attempt
        " to restrict it
        " 1.  Only use \( or \%( constructs remove all else
        " 2   Remove and []s
        " 3.  Account for match //constructs
        "                       \%(\%(ms\|me\|hs\|he\|rs\|re\|lc\)\S\+\)\?
        " 4.  Hope for the best
        "
        "
        let syn_list_old = syn_list
        while syn_list =~ '\<match\>\s\+\/'
            if syn_list =~ 'perlElseIfError'
                let syn_list = syn_list
            endif
            " Check if the match has words at least 3 characters long
            if syn_list =~ '\<match \/\zs.\{-}\<\w\{3,}\>.\{-}\ze\\\@<!\/\%(\%(ms\|me\|hs\|he\|rs\|re\|lc\)\S\+\)\?\s\+'
                " Remove everything after / and before the first \(
                let syn_list = substitute( syn_list, '\<match \/\zs.\{-}\ze\\%\?(.\{-}\\\@<!\/\%(\%(ms\|me\|hs\|he\|rs\|re\|lc\)\S\+\)\?\s\+', '', 'g' )
                " Remove everything after \) and up to the ending /
                let syn_list = substitute( syn_list, '\<match \/.\{-}\\)\zs.\{-}\ze\/\%(\%(ms\|me\|hs\|he\|rs\|re\|lc\)\S\+\)\?\s\+', '', 'g' )

                " Remove any character classes
                " let syn_list = substitute( syn_list, '\<match /\zs.\{-}\[[^]]*\].\{-}\ze\/ ', '', 'g' )
                let syn_list = substitute( syn_list, '\%(\<match \/[^/]\{-}\)\@<=\[[^]]*\]\ze.\{-}\\\@<!\/\%(\%(ms\|me\|hs\|he\|rs\|re\|lc\)\S\+\)\?', '', 'g' )
                " Remove any words < 3 characters
                let syn_list = substitute( syn_list, '\%(\<match \/[^/]\{-}\)\@<=\<\w\{1,2}\>\ze.\{-}\\\@<!\/\%(\%(ms\|me\|hs\|he\|rs\|re\|lc\)\S\+\)\?\s\+', '', 'g' )
                " Remove all non-word characters
                " let syn_list = substitute( syn_list, '\<match /\zs.\{-}\<\W\+\>.\{-}\ze\/ ', "", 'g' )
                " let syn_list = substitute( syn_list, '\%(\<match \/[^/]\{-}\)\@<=\W\+\ze.\{-}\/ ', ' ', 'g' )
                " Do this by using the outer substitute() call to gather all
                " text between the match /.../ tags.
                " The inner substitute() call operates on the text selected
                " and replaces all non-word characters.
                let syn_list = substitute( syn_list, '\<match \/\zs\(.\{-}\)\ze\\\@<!\/\%(\%(ms\|me\|hs\|he\|rs\|re\|lc\)\S\+\)\?\s\+'
                            \ , '\=substitute(submatch(1), "\\W\\+", " ", "g")'
                            \ , 'g' )
                " Remove the match / / syntax
                let syn_list = substitute( syn_list, '\<match \/\(.\{-}\)\/\%(\%(ms\|me\|hs\|he\|rs\|re\|lc\)\S\+\)\?\s\+', '\1', 'g' )
            else
                " No words long enough, remove the match
                " Remove the match syntax
                " let syn_list = substitute( syn_list, '\<match \/[^\/]*\/\%(\%(ms\|me\|hs\|he\|rs\|re\|lc\)\S\+\)\?\s\+', '', 'g' )
                let syn_list = substitute( syn_list, '\<match \/\%(.\{-}\)\?\/\%(\%(ms\|me\|hs\|he\|rs\|re\|lc\)\S\+\)\?\s\+', '', 'g' )
            endif
            if syn_list =~ '\<match\>\s\+\/'
                " Problem removing the match / / tags
                let syn_list = ''
            endif
        endwhile


        " Now strip off the newline + blank space + contained.
        " Also include lines with nextgroup=@someName skip_key_words syntax_element
                    " \    syn_list, '\%(^\|\n\)\@<=\s*\<\(contained\|nextgroup=\)'
                    " \    syn_list, '\%(^\|\n\)\@<=\s*\<\(contained\|nextgroup=[@a-zA-Z,]*\)'
        let syn_list = substitute(
                    \    syn_list, '\<\(contained\|nextgroup=[@a-zA-Z,]*\)'
                    \    , "", 'g'
                    \ )

        " This can leave lines like this
        "     =@vimMenuList  skipwhite onoremenu
        " Strip the special option keywords first
        "     :h :syn-skipwhite*
        let syn_list = substitute(
                    \    syn_list, '\<\(skipwhite\|skipnl\|skipempty\)\>'
                    \    , "", 'g'
                    \ )

        " Now remove the remainder of the nextgroup=@someName lines
        let syn_list = substitute(
                    \    syn_list, '\%(^\|\n\)\@<=\s*\(@\w\+\)'
                    \    , "", 'g'
                    \ )

        if b:omni_syntax_use_iskeyword == 0
            " There are a number of items which have non-word characters in
            " them, *'T_F1'*.  vim.vim is one such file.
            " This will replace non-word characters with spaces.
            let syn_list = substitute( syn_list, '[^0-9A-Za-z_ ]', ' ', 'g' )
        else
            if g:omni_syntax_use_iskeyword_numeric == 1
                " iskeyword can contain value like this
                " 38,42,43,45,47-58,60-62,64-90,97-122,_,+,-,*,/,%,<,=,>,:,$,?,!,@-@,94
                " Numeric values convert to their ASCII equivalent using the
                " nr2char() function.
                "     &       38
                "     *       42
                "     +       43
                "     -       45
                "     ^       94
                " Iterate through all numeric specifications and convert those
                " to their ascii equivalent ensuring the character is printable.
                " If so, add it to the list.
                let accepted_chars = ''
                for item in split(&iskeyword, ',')
                    if item =~ '\d-\d'
                        " This is a character range (ie 47-58),
                        " cycle through each character within the range
                        let [b:start, b:end] = split(item, '-')
                        for range_item in range( b:start, b:end )
                            if range_item <= 127 || g:omni_syntax_use_single_byte == 0
                                if nr2char(range_item) =~ '\p'
                                    let accepted_chars = accepted_chars . nr2char(range_item)
                                endif
                            endif
                        endfor
                    elseif item =~ '^\d\+$'
                        " Only numeric, translate to a character
                        if item < 127 || g:omni_syntax_use_single_byte == 0
                            if nr2char(item) =~ '\p'
                                let accepted_chars = accepted_chars . nr2char(item)
                            endif
                        endif
                    else
                        if char2nr(item) < 127 || g:omni_syntax_use_single_byte == 0
                            if item =~ '\p'
                                let accepted_chars = accepted_chars . item
                            endif
                        endif
                    endif
                endfor
                " Escape special regex characters
                " Looks like the wrong chars are escaped.  In a collection,
                "      :h /[]
                "      only `]', `\', `-' and `^' are special:
                " let accepted_chars = escape(accepted_chars, '\\/.*$^~[]' )
                let accepted_chars = escape(accepted_chars, ']\-^' )
                " Remove all characters that are not acceptable
                let syn_list = substitute( syn_list, '[^A-Za-z'.accepted_chars.']', ' ', 'g' )
            else
                let accept_chars = ','.&iskeyword.','
                " Remove all character ranges
                " let accept_chars = substitute(accept_chars, ',[^,]\+-[^,]\+,', ',', 'g')
                let accept_chars = substitute(accept_chars, ',\@<=[^,]\+-[^,]\+,', '', 'g')
                " Remove all numeric specifications
                " let accept_chars = substitute(accept_chars, ',\d\{-},', ',', 'g')
                let accept_chars = substitute(accept_chars, ',\@<=\d\{-},', '', 'g')
                " Remove all commas
                let accept_chars = substitute(accept_chars, ',', '', 'g')
                " Escape special regex characters
                " Looks like the wrong chars are escaped.  In a collection,
                "      :h /[]
                "      only `]', `\', `-' and `^' are special:
                " let accept_chars = escape(accept_chars, '\\/.*$^~[]' )
                let accept_chars = escape(accept_chars, ']\-^' )
                " Remove all characters that are not acceptable
                let syn_list = substitute( syn_list, '[^0-9A-Za-z_'.accept_chars.']', ' ', 'g' )
            endif
        endif

        if b:omni_syntax_minimum_length > 0
            " If the user specified a minimum length, enforce it
            let syn_list = substitute(' '.syn_list.' ', ' \S\{,'.b:omni_syntax_minimum_length.'}\ze ', ' ', 'g')
        endif
    else
        let syn_list = ''
    endif

    return syn_list
endfunction

function! OmniSyntaxShowChars(spec)
  let result = []
  for item in split(a:spec, ',')
    if len(item) > 1
      if item == '@-@'
        call add(result, char2nr(item))
      else
        call extend(result, call('range', split(item, '-')))
      endif
    else
      if item == '@'  " assume this is [A-Za-z]
        for [c1, c2] in [['A', 'Z'], ['a', 'z']]
          call extend(result, range(char2nr(c1), char2nr(c2)))
        endfor
      else
        call add(result, char2nr(item))
      endif
    endif
  endfor
  return join(map(result, 'nr2char(v:val)'), ', ')
endfunction
let &cpo = s:cpo_save
unlet s:cpo_save
