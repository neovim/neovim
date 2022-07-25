" Support for bitbake indenting, see runtime/indent/bitbake.vim

function s:is_bb_python_func_def(lnum)
    let stack = synstack(a:lnum, 1)
    if len(stack) == 0
        return 0
    endif

    return synIDattr(stack[0], "name") == "bbPyFuncDef"
endfunction

function bitbake#Indent(lnum)
    if !has('syntax_items')
        return -1
    endif

    let stack = synstack(a:lnum, 1)
    if len(stack) == 0
        return -1
    endif

    let name = synIDattr(stack[0], "name")

    " TODO: support different styles of indentation for assignments. For now,
    " we only support like this:
    " VAR = " \
    "     value1 \
    "     value2 \
    " "
    "
    " i.e. each value indented by shiftwidth(), with the final quote " completely unindented.
    if name == "bbVarValue"
        " Quote handling is tricky. kernel.bbclass has this line for instance:
        "     EXTRA_OEMAKE = " HOSTCC="${BUILD_CC} ${BUILD_CFLAGS} ${BUILD_LDFLAGS}" " HOSTCPP="${BUILD_CPP}""
        " Instead of trying to handle crazy cases like that, just assume that a
        " double-quote on a line by itself (following an assignment) means the
        " user is closing the assignment, and de-dent.
        if getline(a:lnum) =~ '^\s*"$'
            return 0
        endif

        let prevstack = synstack(a:lnum - 1, 1)
        if len(prevstack) == 0
            return -1
        endif

        let prevname = synIDattr(prevstack[0], "name")

        " Only indent if there was actually a continuation character on
        " the previous line, to avoid misleading indentation.
        let prevlinelastchar = synIDattr(synID(a:lnum - 1, col([a:lnum - 1, "$"]) - 1, 1), "name")
        let prev_continued = prevlinelastchar == "bbContinue"

        " Did the previous line introduce an assignment?
        if index(["bbVarDef", "bbVarFlagDef"], prevname) != -1
            if prev_continued
                return shiftwidth()
            endif
        endif

        if !prev_continued
            return 0
        endif

        " Autoindent can take it from here
        return -1
    endif

    if index(["bbPyDefRegion", "bbPyFuncRegion"], name) != -1
        let ret = python#GetIndent(a:lnum, function('s:is_bb_python_func_def'))
        " Should normally always be indented by at least one shiftwidth; but allow
        " return of -1 (defer to autoindent) or -2 (force indent to 0)
        if ret == 0
            return shiftwidth()
        elseif ret == -2
            return 0
        endif
        return ret
    endif

    " TODO: GetShIndent doesn't detect tasks prepended with 'fakeroot'
    " Need to submit a patch upstream to Vim to provide an extension point.
    " Unlike the Python indenter, the Sh indenter is way too large to copy and
    " modify here.
    if name == "bbShFuncRegion"
        return GetShIndent()
    endif

    " TODO:
    "   + heuristics for de-denting out of a bbPyDefRegion? e.g. when the user
    "       types an obvious BB keyword like addhandler or addtask, or starts
    "       writing a shell task. Maybe too hard to implement...

    return -1
endfunction
