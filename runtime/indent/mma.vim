" Vim indent file
" Language:     Mathematica
" Author:       steve layland <layland@wolfram.com>
" Last Change:  Sat May  10 18:56:22 CDT 2005
" Source:       http://vim.sourceforge.net/scripts/script.php?script_id=1274
"               http://members.wolfram.com/layland/vim/indent/mma.vim
"
" NOTE:
" Empty .m files will automatically be presumed to be Matlab files
" unless you have the following in your .vimrc:
"
"       let filetype_m="mma"
"
" Credits:
" o steve hacked this out of a random indent file in the Vim 6.1
"   distribution that he no longer remembers...sh.vim?  Thanks!

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
    finish
endif
let b:did_indent = 1

setlocal indentexpr=GetMmaIndent()
setlocal indentkeys+=0[,0],0(,0)
setlocal nosi "turn off smart indent so we don't over analyze } blocks

if exists("*GetMmaIndent")
    finish
endif

function GetMmaIndent()

    " Hit the start of the file, use zero indent.
    if v:lnum == 0
        return 0
    endif

     " Find a non-blank line above the current line.
    let lnum = prevnonblank(v:lnum - 1)

    " use indenting as a base
    let ind = indent(v:lnum)
    let lnum = v:lnum

    " if previous line has an unmatched bracket, or ( indent.
    " doesn't do multiple parens/blocks/etc...

    " also, indent only if this line if this line isn't starting a new
    " block... TODO - fix this with indentkeys?
    if getline(v:lnum-1) =~ '\\\@<!\%(\[[^\]]*\|([^)]*\|{[^}]*\)$' && getline(v:lnum) !~ '\s\+[\[({]'
        let ind = ind+&sw
    endif

    " if this line had unmatched closing block,
    " indent to the matching opening block
    if getline(v:lnum) =~ '[^[]*]\s*$'
        " move to the closing bracket
        call search(']','bW')
        " and find it's partner's indent
        let ind = indent(searchpair('\[','',']','bWn'))
    " same for ( blocks
    elseif getline(v:lnum) =~ '[^(]*)$'
        call search(')','bW')
        let ind = indent(searchpair('(','',')','bWn'))

    " and finally, close { blocks if si ain't already set
    elseif getline(v:lnum) =~ '[^{]*}'
        call search('}','bW')
        let ind = indent(searchpair('{','','}','bWn'))
    endif

    return ind
endfunction

