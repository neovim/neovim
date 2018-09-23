-- File containing table with all functions.
--
-- Keys:
--
-- args  Number of arguments, list with maximum and minimum number of arguments
--       or list with a minimum number of arguments only. Defaults to zero
--       arguments.
-- func  Name of the C function which implements the VimL function. Defaults to
--       `f_{funcname}`.

local varargs = function(nr)
  return {nr}
end

return {
  funcs={
    abs={args=1},
    acos={args=1, func="float_op_wrapper", data="&acos"},  -- WJMc
    add={args=2},
    ['and']={args=2},
    api_info={},
    append={args=2},
    argc={},
    argidx={},
    arglistid={args={0, 2}},
    argv={args={0, 1}},
    asin={args=1, func="float_op_wrapper", data="&asin"},  -- WJMc
    assert_equal={args={2, 3}},
    assert_exception={args={1, 2}},
    assert_fails={args={1, 2}},
    assert_false={args={1, 2}},
    assert_inrange={args={3, 4}},
    assert_match={args={2, 3}},
    assert_notequal={args={2, 3}},
    assert_notmatch={args={2, 3}},
    assert_report={args=1},
    assert_true={args={1, 2}},
    atan={args=1, func="float_op_wrapper", data="&atan"},
    atan2={args=2},
    browse={args=4},
    browsedir={args=2},
    bufexists={args=1},
    buffer_exists={args=1, func='f_bufexists'},  -- obsolete
    buffer_name={args=1, func='f_bufname'},  -- obsolete
    buffer_number={args=1, func='f_bufnr'},  -- obsolete
    buflisted={args=1},
    bufloaded={args=1},
    bufname={args=1},
    bufnr={args={1, 2}},
    bufwinid={args=1},
    bufwinnr={args=1},
    byte2line={args=1},
    byteidx={args=2},
    byteidxcomp={args=2},
    call={args={2, 3}},
    ceil={args=1, func="float_op_wrapper", data="&ceil"},
    changenr={},
    chanclose={args={1, 2}},
    chansend={args=2},
    char2nr={args={1, 2}},
    cindent={args=1},
    clearmatches={},
    col={args=1},
    complete={args=2},
    complete_add={args=1},
    complete_check={},
    confirm={args={1, 4}},
    copy={args=1},
    cos={args=1, func="float_op_wrapper", data="&cos"},
    cosh={args=1, func="float_op_wrapper", data="&cosh"},
    count={args={2, 4}},
    cscope_connection={args={0, 3}},
    cursor={args={1, 3}},
    deepcopy={args={1, 2}},
    delete={args={1,2}},
    dictwatcheradd={args=3},
    dictwatcherdel={args=3},
    did_filetype={},
    diff_filler={args=1},
    diff_hlID={args=2},
    empty={args=1},
    escape={args=2},
    eval={args=1},
    eventhandler={},
    executable={args=1},
    execute={args={1, 2}},
    exepath={args=1},
    exists={args=1},
    exp={args=1, func="float_op_wrapper", data="&exp"},
    expand={args={1, 3}},
    extend={args={2, 3}},
    feedkeys={args={1, 2}},
    file_readable={args=1, func='f_filereadable'},  -- obsolete
    filereadable={args=1},
    filewritable={args=1},
    filter={args=2},
    finddir={args={1, 3}},
    findfile={args={1, 3}},
    float2nr={args=1},
    floor={args=1, func="float_op_wrapper", data="&floor"},
    fmod={args=2},
    fnameescape={args=1},
    fnamemodify={args=2},
    foldclosed={args=1},
    foldclosedend={args=1},
    foldlevel={args=1},
    foldtext={},
    foldtextresult={args=1},
    foreground={},
    funcref={args={1, 3}},
    ['function']={args={1, 3}},
    garbagecollect={args={0, 1}},
    get={args={2, 3}},
    getbufinfo={args={0, 1}},
    getbufline={args={2, 3}},
    getbufvar={args={2, 3}},
    getchar={args={0, 1}},
    getcharmod={},
    getcharsearch={},
    getcmdline={},
    getcmdpos={},
    getcmdtype={},
    getcmdwintype={},
    getcompletion={args={2, 3}},
    getcurpos={},
    getcwd={args={0,2}},
    getfontname={args={0, 1}},
    getfperm={args=1},
    getfsize={args=1},
    getftime={args=1},
    getftype={args=1},
    getline={args={1, 2}},
    getloclist={args={1, 2}},
    getmatches={},
    getpid={},
    getpos={args=1},
    getqflist={args={0, 1}},
    getreg={args={0, 3}},
    getregtype={args={0, 1}},
    gettabinfo={args={0, 1}},
    gettabvar={args={2, 3}},
    gettabwinvar={args={3, 4}},
    getwininfo={args={0, 1}},
    getwinposx={},
    getwinposy={},
    getwinvar={args={2, 3}},
    glob={args={1, 4}},
    glob2regpat={args=1},
    globpath={args={2, 5}},
    has={args=1},
    has_key={args=2},
    haslocaldir={args={0,2}},
    hasmapto={args={1, 3}},
    highlightID={args=1, func='f_hlID'},  -- obsolete
    highlight_exists={args=1, func='f_hlexists'},  -- obsolete
    histadd={args=2},
    histdel={args={1, 2}},
    histget={args={1, 2}},
    histnr={args=1},
    hlID={args=1},
    hlexists={args=1},
    hostname={},
    iconv={args=3},
    indent={args=1},
    index={args={2, 4}},
    input={args={1, 3}},
    inputdialog={args={1, 3}},
    inputlist={args=1},
    inputrestore={},
    inputsave={},
    inputsecret={args={1, 2}},
    insert={args={2, 3}},
    invert={args=1},
    isdirectory={args=1},
    islocked={args=1},
    id={args=1},
    items={args=1},
    jobclose={args={1, 2}, func="f_chanclose"},
    jobpid={args=1},
    jobresize={args=3},
    jobsend={args=2, func="f_chansend"},
    jobstart={args={1, 2}},
    jobstop={args=1},
    jobwait={args={1, 2}},
    join={args={1, 2}},
    json_decode={args=1},
    json_encode={args=1},
    keys={args=1},
    last_buffer_nr={},  -- obsolete
    len={args=1},
    libcall={args=3},
    libcallnr={args=3},
    line={args=1},
    line2byte={args=1},
    lispindent={args=1},
    localtime={},
    log={args=1, func="float_op_wrapper", data="&log"},
    log10={args=1, func="float_op_wrapper", data="&log10"},
    luaeval={args={1, 2}},
    map={args=2},
    maparg={args={1, 4}},
    mapcheck={args={1, 3}},
    match={args={2, 4}},
    matchadd={args={2, 5}},
    matchaddpos={args={2, 5}},
    matcharg={args=1},
    matchdelete={args=1},
    matchend={args={2, 4}},
    matchlist={args={2, 4}},
    matchstr={args={2, 4}},
    matchstrpos={args={2,4}},
    max={args=1},
    menu_get={args={1, 2}},
    min={args=1},
    mkdir={args={1, 3}},
    mode={args={0, 1}},
    msgpackdump={args=1},
    msgpackparse={args=1},
    nextnonblank={args=1},
    nr2char={args={1, 2}},
    ['or']={args=2},
    pathshorten={args=1},
    pow={args=2},
    prevnonblank={args=1},
    printf={args=varargs(1)},
    pumvisible={},
    py3eval={args=1},
    pyeval={args=1},
    range={args={1, 3}},
    readfile={args={1, 3}},
    reltime={args={0, 2}},
    reltimefloat={args=1},
    reltimestr={args=1},
    remove={args={2, 3}},
    rename={args=2},
    ['repeat']={args=2},
    resolve={args=1},
    reverse={args=1},
    round={args=1, func="float_op_wrapper", data="&round"},
    rpcnotify={args=varargs(2)},
    rpcrequest={args=varargs(2)},
    rpcstart={args={1, 2}},
    rpcstop={args=1},
    screenattr={args=2},
    screenchar={args=2},
    screencol={},
    screenrow={},
    search={args={1, 4}},
    searchdecl={args={1, 3}},
    searchpair={args={3, 7}},
    searchpairpos={args={3, 7}},
    searchpos={args={1, 4}},
    serverlist={},
    serverstart={args={0, 1}},
    serverstop={args=1},
    setbufvar={args=3},
    setcharsearch={args=1},
    setcmdpos={args=1},
    setfperm={args=2},
    setline={args=2},
    setloclist={args={2, 4}},
    setmatches={args=1},
    setpos={args=2},
    setqflist={args={1, 3}},
    setreg={args={2, 3}},
    settabvar={args=3},
    settabwinvar={args=4},
    setwinvar={args=3},
    sha256={args=1},
    shellescape={args={1, 2}},
    shiftwidth={},
    simplify={args=1},
    sin={args=1, func="float_op_wrapper", data="&sin"},
    sinh={args=1, func="float_op_wrapper", data="&sinh"},
    sockconnect={args={2,3}},
    sort={args={1, 3}},
    soundfold={args=1},
    stdioopen={args=1},
    spellbadword={args={0, 1}},
    spellsuggest={args={1, 3}},
    split={args={1, 3}},
    sqrt={args=1, func="float_op_wrapper", data="&sqrt"},
    stdpath={args=1},
    str2float={args=1},
    str2nr={args={1, 2}},
    strcharpart={args={2, 3}},
    strchars={args={1,2}},
    strdisplaywidth={args={1, 2}},
    strftime={args={1, 2}},
    strgetchar={args={2, 2}},
    stridx={args={2, 3}},
    string={args=1},
    strlen={args=1},
    strpart={args={2, 3}},
    strridx={args={2, 3}},
    strtrans={args=1},
    strwidth={args=1},
    submatch={args={1, 2}},
    substitute={args=4},
    synID={args=3},
    synIDattr={args={2, 3}},
    synIDtrans={args=1},
    synconcealed={args=2},
    synstack={args=2},
    system={args={1, 2}},
    systemlist={args={1, 3}},
    tabpagebuflist={args={0, 1}},
    tabpagenr={args={0, 1}},
    tabpagewinnr={args={1, 2}},
    tagfiles={},
    taglist={args={1, 2}},
    tan={args=1, func="float_op_wrapper", data="&tan"},
    tanh={args=1, func="float_op_wrapper", data="&tanh"},
    tempname={},
    termopen={args={1, 2}},
    test_garbagecollect_now={},
    test_write_list_log={args=1},
    timer_info={args={0,1}},
    timer_pause={args=2},
    timer_start={args={2,3}},
    timer_stop={args=1},
    timer_stopall={args=0},
    tolower={args=1},
    toupper={args=1},
    tr={args=3},
    trim={args={1,2}},
    trunc={args=1, func="float_op_wrapper", data="&trunc"},
    type={args=1},
    undofile={args=1},
    undotree={},
    uniq={args={1, 3}},
    values={args=1},
    virtcol={args=1},
    visualmode={args={0, 1}},
    wildmenumode={},
    win_findbuf={args=1},
    win_getid={args={0,2}},
    win_gotoid={args=1},
    win_id2tabwin={args=1},
    win_id2win={args=1},
    win_screenpos={args=1},
    winbufnr={args=1},
    wincol={},
    winheight={args=1},
    winline={},
    winnr={args={0, 1}},
    winrestcmd={},
    winrestview={args=1},
    winsaveview={},
    winwidth={args=1},
    wordcount={},
    writefile={args={2, 3}},
    xor={args=2},
  },
}
