-- {
--  {
--    full_name='aleph', abbreviation='al',
--    short_desc="ASCII code of the letter Aleph (Hebrew)",
--    varname='p_aleph', pv_name=nil,
--    type='number', list=nil, scope={'global'},
--    deny_duplicates=nil,
--    enable_if=nil,
--    defaults={condition=nil, if_true={vi=224, vim=0}, if_false=nil},
--    secure=nil, gettext=nil, noglob=nil, normal_fname_chars=nil,
--    pri_mkrc=nil, deny_in_modelines=nil, normal_dname_chars=nil,
--    modelineexpr=nil,
--    expand=nil, nodefault=nil, no_mkrc=nil, vi_def=true, vim=true,
--    alloced=nil,
--    save_pv_indir=nil,
--    redraw={'curswant'},
--  }
-- }
-- types: bool, number, string
-- lists: (nil), comma, onecomma, flags, flagscomma
-- scopes: global, buffer, window
-- redraw options: statuslines, current_window, curent_window_only,
--                 current_buffer, all_windows, everything, curswant
-- default: {vi=…[, vim=…]}
-- defaults: {condition=#if condition, if_true=default, if_false=default}
-- #if condition:
--    string: #ifdef string
--    !string: #ifndef string
--    {string, string}: #if defined(string) && defined(string)
--    {!string, !string}: #if !defined(string) && !defined(string)
local cstr = function(s)
  return '"' .. s:gsub('["\\]', '\\%0'):gsub('\t', '\\t') .. '"'
end
local macros=function(s)
  return function()
    return s
  end
end
local imacros=function(s)
  return function()
    return '(intptr_t)' .. s
  end
end
local N_=function(s) -- luacheck: ignore 211 (currently unused)
  return function()
    return 'N_(' .. cstr(s) .. ')'
  end
end
-- used for 'cinkeys' and 'indentkeys'
local indentkeys_default = '0{,0},0),0],:,0#,!^F,o,O,e';
return {
  cstr=cstr,
  options={
    {
      full_name='aleph', abbreviation='al',
      short_desc=N_("ASCII code of the letter Aleph (Hebrew)"),
      type='number', scope={'global'},
      vi_def=true,
      redraw={'curswant'},
      varname='p_aleph',
      defaults={if_true={vi=224}}
    },
    {
      full_name='arabic', abbreviation='arab',
      short_desc=N_("Arabic as a default second language"),
      type='bool', scope={'window'},
      vi_def=true,
      vim=true,
      redraw={'curswant'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='arabicshape', abbreviation='arshape',
      short_desc=N_("do shaping for Arabic characters"),
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      redraw={'all_windows', 'ui_option'},

      varname='p_arshape',
      defaults={if_true={vi=true}}
    },
    {
      full_name='allowrevins', abbreviation='ari',
      short_desc=N_("allow CTRL-_ in Insert and Command-line mode"),
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_ari',
      defaults={if_true={vi=false}}
    },
    {
      full_name='ambiwidth', abbreviation='ambw',
      short_desc=N_("what to do with Unicode chars of ambiguous width"),
      type='string', scope={'global'},
      vi_def=true,
      redraw={'all_windows', 'ui_option'},
      varname='p_ambw',
      defaults={if_true={vi="single"}}
    },
    {
      full_name='autochdir', abbreviation='acd',
      short_desc=N_("change directory to the file in the current window"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_acd',
      defaults={if_true={vi=false}}
    },
    {
      full_name='autoindent', abbreviation='ai',
      short_desc=N_("take indent for new line from previous line"),
      type='bool', scope={'buffer'},
      varname='p_ai',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='autoread', abbreviation='ar',
      short_desc=N_("autom. read file when changed outside of Vim"),
      type='bool', scope={'global', 'buffer'},
      varname='p_ar',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='autowrite', abbreviation='aw',
      short_desc=N_("automatically write file if changed"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_aw',
      defaults={if_true={vi=false}}
    },
    {
      full_name='autowriteall', abbreviation='awa',
      short_desc=N_("as 'autowrite', but works with more commands"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_awa',
      defaults={if_true={vi=false}}
    },
    {
      full_name='background', abbreviation='bg',
      short_desc=N_("\"dark\" or \"light\", used for highlight colors"),
      type='string', scope={'global'},
      vim=true,
      redraw={'all_windows'},
      varname='p_bg',
      defaults={if_true={vi="light",vim="dark"}}
    },
    {
      full_name='backspace', abbreviation='bs',
      short_desc=N_("how backspace works at start of line"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vim=true,
      varname='p_bs',
      defaults={if_true={vi="", vim="indent,eol,start"}}
    },
    {
      full_name='backup', abbreviation='bk',
      short_desc=N_("keep backup file after overwriting a file"),
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_bk',
      defaults={if_true={vi=false}}
    },
    {
      full_name='backupcopy', abbreviation='bkc',
      short_desc=N_("make backup as a copy, don't rename the file"),
      type='string', list='onecomma', scope={'global', 'buffer'},
      deny_duplicates=true,
      vim=true,
      varname='p_bkc',
      defaults={
        condition='UNIX',
        if_true={vi="yes", vim="auto"},
        if_false={vi="auto", vim="auto"}
      },
    },
    {
      full_name='backupdir', abbreviation='bdir',
      short_desc=N_("list of directories for the backup file"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      secure=true,
      vi_def=true,
      expand='nodefault',
      varname='p_bdir',
      defaults={if_true={vi=''}}
    },
    {
      full_name='backupext', abbreviation='bex',
      short_desc=N_("extension used for the backup file"),
      type='string', scope={'global'},
      normal_fname_chars=true,
      vi_def=true,
      varname='p_bex',
      defaults={if_true={vi="~"}}
    },
    {
      full_name='backupskip', abbreviation='bsk',
      short_desc=N_("no backup for files that match these patterns"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_bsk',
      defaults={if_true={vi=""}}
    },
    {
      full_name='belloff', abbreviation='bo',
      short_desc=N_("do not ring the bell for these reasons"),
      type='string', list='comma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_bo',
      defaults={if_true={vi="all"}}
    },
    {
      full_name='binary', abbreviation='bin',
      short_desc=N_("read/write/edit file in binary mode"),
      type='bool', scope={'buffer'},
      vi_def=true,
      redraw={'statuslines'},
      varname='p_bin',
      defaults={if_true={vi=false}}
    },
    {
      full_name='bomb',
      short_desc=N_("a Byte Order Mark to the file"),
      type='bool', scope={'buffer'},
      no_mkrc=true,
      vi_def=true,
      redraw={'statuslines'},
      varname='p_bomb',
      defaults={if_true={vi=false}}
    },
    {
      full_name='breakat', abbreviation='brk',
      short_desc=N_("characters that may cause a line break"),
      type='string', list='flags', scope={'global'},
      vi_def=true,
      redraw={'all_windows'},
      varname='p_breakat',
      defaults={if_true={vi=" \t!@*-+;:,./?"}}
    },
    {
      full_name='breakindent', abbreviation='bri',
      short_desc=N_("wrapped line repeats indent"),
      type='bool', scope={'window'},
      vi_def=true,
      vim=true,
      redraw={'current_window'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='breakindentopt', abbreviation='briopt',
      short_desc=N_("settings for 'breakindent'"),
      type='string', list='onecomma', scope={'window'},
      deny_duplicates=true,
      vi_def=true,
      alloced=true,
      redraw={'current_buffer'},
      defaults={if_true={vi=""}},
    },
    {
      full_name='browsedir', abbreviation='bsdir',
      short_desc=N_("which directory to start browsing in"),
      type='string', scope={'global'},
      vi_def=true,
      enable_if=false,
    },
    {
      full_name='bufhidden', abbreviation='bh',
      short_desc=N_("what to do when buffer is no longer in window"),
      type='string', scope={'buffer'},
      noglob=true,
      vi_def=true,
      alloced=true,
      varname='p_bh',
      defaults={if_true={vi=""}}
    },
    {
      full_name='buflisted', abbreviation='bl',
      short_desc=N_("whether the buffer shows up in the buffer list"),
      type='bool', scope={'buffer'},
      noglob=true,
      vi_def=true,
      varname='p_bl',
      defaults={if_true={vi=1}}
    },
    {
      full_name='buftype', abbreviation='bt',
      short_desc=N_("special type of buffer"),
      type='string', scope={'buffer'},
      noglob=true,
      vi_def=true,
      alloced=true,
      varname='p_bt',
      defaults={if_true={vi=""}}
    },
    {
      full_name='casemap', abbreviation='cmp',
      short_desc=N_("specifies how case of letters is changed"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_cmp',
      defaults={if_true={vi="internal,keepascii"}}
    },
    {
      full_name='cdpath', abbreviation='cd',
      short_desc=N_("list of directories searched with \":cd\""),
      type='string', list='comma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      expand=true,
      secure=true,
      varname='p_cdpath',
      defaults={if_true={vi=",,"}}
    },
    {
      full_name='cedit',
      short_desc=N_("used to open the command-line window"),
      type='string', scope={'global'},
      varname='p_cedit',
      defaults={if_true={vi="", vim=macros('CTRL_F_STR')}}
    },
    {
      full_name='channel',
      short_desc=N_("Channel connected to the buffer"),
      type='number', scope={'buffer'},
      no_mkrc=true,
      nodefault=true,
      varname='p_channel',
      defaults={if_true={vi=0}}
    },
    {
      full_name='charconvert', abbreviation='ccv',
      short_desc=N_("expression for character encoding conversion"),
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_ccv',
      defaults={if_true={vi=""}}
    },
    {
      full_name='cindent', abbreviation='cin',
      short_desc=N_("do C program indenting"),
      type='bool', scope={'buffer'},
      vi_def=true,
      vim=true,
      varname='p_cin',
      defaults={if_true={vi=false}}
    },
    {
      full_name='cinkeys', abbreviation='cink',
      short_desc=N_("keys that trigger indent when 'cindent' is set"),
      type='string', list='onecomma', scope={'buffer'},
      deny_duplicates=true,
      vi_def=true,
      alloced=true,
      varname='p_cink',
      defaults={if_true={vi=indentkeys_default}}
    },
    {
      full_name='cinoptions', abbreviation='cino',
      short_desc=N_("how to do indenting when 'cindent' is set"),
      type='string', list='onecomma', scope={'buffer'},
      deny_duplicates=true,
      vi_def=true,
      alloced=true,
      varname='p_cino',
      defaults={if_true={vi=""}}
    },
    {
      full_name='cinwords', abbreviation='cinw',
      short_desc=N_("words where 'si' and 'cin' add an indent"),
      type='string', list='onecomma', scope={'buffer'},
      deny_duplicates=true,
      vi_def=true,
      alloced=true,
      varname='p_cinw',
      defaults={if_true={vi="if,else,while,do,for,switch"}}
    },
    {
      full_name='clipboard', abbreviation='cb',
      short_desc=N_("use the clipboard as the unnamed register"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_cb',
      defaults={if_true={vi=""}}
    },
    {
      full_name='cmdheight', abbreviation='ch',
      short_desc=N_("number of lines to use for the command-line"),
      type='number', scope={'global'},
      vi_def=true,
      redraw={'all_windows'},
      varname='p_ch',
      defaults={if_true={vi=1}}
    },
    {
      full_name='cmdwinheight', abbreviation='cwh',
      short_desc=N_("height of the command-line window"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_cwh',
      defaults={if_true={vi=7}}
    },
    {
      full_name='colorcolumn', abbreviation='cc',
      short_desc=N_("columns to highlight"),
      type='string', list='onecomma', scope={'window'},
      deny_duplicates=true,
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=""}}
    },
    {
      full_name='columns', abbreviation='co',
      short_desc=N_("number of columns in the display"),
      type='number', scope={'global'},
      no_mkrc=true,
      vi_def=true,
      redraw={'everything'},
      varname='p_columns',
      defaults={if_true={vi=macros('DFLT_COLS')}}
    },
    {
      full_name='comments', abbreviation='com',
      short_desc=N_("patterns that can start a comment line"),
      type='string', list='onecomma', scope={'buffer'},
      deny_duplicates=true,
      vi_def=true,
      alloced=true,
      redraw={'curswant'},
      varname='p_com',
      defaults={if_true={vi="s1:/*,mb:*,ex:*/,://,b:#,:%,:XCOMM,n:>,fb:-"}}
    },
    {
      full_name='commentstring', abbreviation='cms',
      short_desc=N_("template for comments; used for fold marker"),
      type='string', scope={'buffer'},
      vi_def=true,
      alloced=true,
      redraw={'curswant'},
      varname='p_cms',
      defaults={if_true={vi="/*%s*/"}}
    },
    {
      full_name='compatible', abbreviation='cp',
	  short_desc=N_("No description"),
      type='bool', scope={'global'},
      redraw={'all_windows'},
      varname='p_force_off',
      -- pri_mkrc isn't needed here, optval_default()
      -- always returns TRUE for 'compatible'
      defaults={if_true={vi=true, vim=false}}
    },
    {
      full_name='complete', abbreviation='cpt',
      short_desc=N_("specify how Insert mode completion works"),
      type='string', list='onecomma', scope={'buffer'},
      deny_duplicates=true,
      alloced=true,
      varname='p_cpt',
      defaults={if_true={vi=".,w,b,u,t,i", vim=".,w,b,u,t"}}
    },
    {
      full_name='concealcursor', abbreviation='cocu',
      short_desc=N_("whether concealable text is hidden in cursor line"),
      type='string', scope={'window'},
      vi_def=true,
      alloced=true,
      redraw={'current_window'},
      defaults={if_true={vi=""}}
    },
    {
      full_name='conceallevel', abbreviation='cole',
      short_desc=N_("whether concealable text is shown or hidden"),
      type='number', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=0}}
    },
    {
      full_name='completefunc', abbreviation='cfu',
      short_desc=N_("function to be used for Insert mode completion"),
      type='string', scope={'buffer'},
      secure=true,
      vi_def=true,
      alloced=true,
      varname='p_cfu',
      defaults={if_true={vi=""}}
    },
    {
      full_name='completeopt', abbreviation='cot',
      short_desc=N_("options for Insert mode completion"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_cot',
      defaults={if_true={vi="menu,preview"}}
    },
    {
      full_name='completeslash', abbreviation='csl',
      type='string', scope={'buffer'},
      vi_def=true,
      vim=true,
      varname='p_csl',
      enable_if='BACKSLASH_IN_FILENAME',
      defaults={if_true={vi=""}}
    },
    {
      full_name='confirm', abbreviation='cf',
      short_desc=N_("ask what to do about unsaved/read-only files"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_confirm',
      defaults={if_true={vi=false}}
    },
    {
      full_name='copyindent', abbreviation='ci',
      short_desc=N_("make 'autoindent' use existing indent structure"),
      type='bool', scope={'buffer'},
      vi_def=true,
      vim=true,
      varname='p_ci',
      defaults={if_true={vi=false}}
    },
    {
      full_name='cpoptions', abbreviation='cpo',
      short_desc=N_("flags for Vi-compatible behavior"),
      type='string', list='flags', scope={'global'},
      vim=true,
      redraw={'all_windows'},
      varname='p_cpo',
      defaults={if_true={vi=macros('CPO_VI'), vim=macros('CPO_VIM')}}
    },
    {
      full_name='cscopepathcomp', abbreviation='cspc',
      short_desc=N_("how many components of the path to show"),
      type='number', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_cspc',
      defaults={if_true={vi=0}}
    },
    {
      full_name='cscopeprg', abbreviation='csprg',
      short_desc=N_("command to execute cscope"),
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      expand=true,
      varname='p_csprg',
      defaults={if_true={vi="cscope"}}
    },
    {
      full_name='cscopequickfix', abbreviation='csqf',
      short_desc=N_("use quickfix window for cscope results"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_csqf',
      defaults={if_true={vi=""}}
    },
    {
      full_name='cscoperelative', abbreviation='csre',
      short_desc=N_("Use cscope.out path basename as prefix"),
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_csre',
      defaults={if_true={vi=0}}
    },
    {
      full_name='cscopetag', abbreviation='cst',
      short_desc=N_("use cscope for tag commands"),
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_cst',
      defaults={if_true={vi=0}}
    },
    {
      full_name='cscopetagorder', abbreviation='csto',
      short_desc=N_("determines \":cstag\" search order"),
      type='number', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_csto',
      defaults={if_true={vi=0}}
    },
    {
      full_name='cscopeverbose', abbreviation='csverb',
      short_desc=N_("give messages when adding a cscope database"),
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_csverbose',
      defaults={if_true={vi=1}}
    },
    {
      full_name='cursorbind', abbreviation='crb',
      short_desc=N_("move cursor in window as it moves in other windows"),
      type='bool', scope={'window'},
      vi_def=true,
      pv_name='p_crbind',
      defaults={if_true={vi=false}}
    },
    {
      full_name='cursorcolumn', abbreviation='cuc',
      short_desc=N_("highlight the screen column of the cursor"),
      type='bool', scope={'window'},
      vi_def=true,
      redraw={'current_window_only'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='cursorline', abbreviation='cul',
      short_desc=N_("highlight the screen line of the cursor"),
      type='bool', scope={'window'},
      vi_def=true,
      redraw={'current_window_only'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='debug',
      short_desc=N_("to \"msg\" to see all error messages"),
      type='string', scope={'global'},
      vi_def=true,
      varname='p_debug',
      defaults={if_true={vi=""}}
    },
    {
      full_name='define', abbreviation='def',
      short_desc=N_("pattern to be used to find a macro definition"),
      type='string', scope={'global', 'buffer'},
      vi_def=true,
      alloced=true,
      redraw={'curswant'},
      varname='p_def',
      defaults={if_true={vi="^\\s*#\\s*define"}}
    },
    {
      full_name='delcombine', abbreviation='deco',
      short_desc=N_("delete combining characters on their own"),
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_deco',
      defaults={if_true={vi=false}}
    },
    {
      full_name='dictionary', abbreviation='dict',
      short_desc=N_("list of file names used for keyword completion"),
      type='string', list='onecomma', scope={'global', 'buffer'},
      deny_duplicates=true,
      normal_dname_chars=true,
      vi_def=true,
      expand=true,
      varname='p_dict',
      defaults={if_true={vi=""}}
    },
    {
      full_name='diff',
      short_desc=N_("diff mode for the current window"),
      type='bool', scope={'window'},
      noglob=true,
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='diffexpr', abbreviation='dex',
      short_desc=N_("expression used to obtain a diff file"),
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      redraw={'curswant'},
      varname='p_dex',
      defaults={if_true={vi=""}}
    },
    {
      full_name='diffopt', abbreviation='dip',
      short_desc=N_("options for using diff mode"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      alloced=true,
      redraw={'current_window'},
      varname='p_dip',
      defaults={if_true={vi="internal,filler,closeoff"}}
    },
    {
      full_name='digraph', abbreviation='dg',
      short_desc=N_("enable the entering of digraphs in Insert mode"),
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_dg',
      defaults={if_true={vi=false}}
    },
    {
      full_name='directory', abbreviation='dir',
      short_desc=N_("list of directory names for the swap file"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      secure=true,
      vi_def=true,
      expand='nodefault',
      varname='p_dir',
      defaults={if_true={vi=''}}
    },
    {
      full_name='display', abbreviation='dy',
      short_desc=N_("list of flags for how to display text"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vim=true,
      redraw={'all_windows'},
      varname='p_dy',
      defaults={if_true={vi="", vim="lastline,msgsep"}}
    },
    {
      full_name='eadirection', abbreviation='ead',
      short_desc=N_("in which direction 'equalalways' works"),
      type='string', scope={'global'},
      vi_def=true,
      varname='p_ead',
      defaults={if_true={vi="both"}}
    },
    {
      full_name='edcompatible', abbreviation='ed',
	  short_desc=N_("No description"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_force_off',
      defaults={if_true={vi=false}}
    },
    {
      full_name='emoji', abbreviation='emo',
	  short_desc=N_("No description"),
      type='bool', scope={'global'},
      vi_def=true,
      redraw={'all_windows', 'ui_option'},
      varname='p_emoji',
      defaults={if_true={vi=true}}
    },
    {
      full_name='encoding', abbreviation='enc',
      short_desc=N_("encoding used internally"),
      type='string', scope={'global'},
      deny_in_modelines=true,
      vi_def=true,
      varname='p_enc',
      defaults={if_true={vi=macros('ENC_DFLT')}}
    },
    {
      full_name='endofline', abbreviation='eol',
      short_desc=N_("write <EOL> for last line in file"),
      type='bool', scope={'buffer'},
      no_mkrc=true,
      vi_def=true,
      redraw={'statuslines'},
      varname='p_eol',
      defaults={if_true={vi=true}}
    },
    {
      full_name='equalalways', abbreviation='ea',
      short_desc=N_("windows are automatically made the same size"),
      type='bool', scope={'global'},
      vi_def=true,
      redraw={'all_windows'},
      varname='p_ea',
      defaults={if_true={vi=true}}
    },
    {
      full_name='equalprg', abbreviation='ep',
      short_desc=N_("external program to use for \"=\" command"),
      type='string', scope={'global', 'buffer'},
      secure=true,
      vi_def=true,
      expand=true,
      varname='p_ep',
      defaults={if_true={vi=""}}
    },
    {
      full_name='errorbells', abbreviation='eb',
      short_desc=N_("ring the bell for error messages"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_eb',
      defaults={if_true={vi=false}}
    },
    {
      full_name='errorfile', abbreviation='ef',
      short_desc=N_("name of the errorfile for the QuickFix mode"),
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      expand=true,
      varname='p_ef',
      defaults={if_true={vi=macros('DFLT_ERRORFILE')}}
    },
    {
      full_name='errorformat', abbreviation='efm',
      short_desc=N_("description of the lines in the error file"),
      type='string', list='onecomma', scope={'global', 'buffer'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_efm',
      defaults={if_true={vi=macros('DFLT_EFM')}}
    },
    {
      full_name='eventignore', abbreviation='ei',
      short_desc=N_("autocommand events that are ignored"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_ei',
      defaults={if_true={vi=""}}
    },
    {
      full_name='expandtab', abbreviation='et',
      short_desc=N_("use spaces when <Tab> is inserted"),
      type='bool', scope={'buffer'},
      vi_def=true,
      vim=true,
      varname='p_et',
      defaults={if_true={vi=false}}
    },
    {
      full_name='exrc', abbreviation='ex',
      short_desc=N_("read .nvimrc and .exrc in the current directory"),
      type='bool', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_exrc',
      defaults={if_true={vi=false}}
    },
    {
      full_name='fileencoding', abbreviation='fenc',
      short_desc=N_("file encoding for multi-byte text"),
      type='string', scope={'buffer'},
      no_mkrc=true,
      vi_def=true,
      alloced=true,
      redraw={'statuslines', 'current_buffer'},
      varname='p_fenc',
      defaults={if_true={vi=""}}
    },
    {
      full_name='fileencodings', abbreviation='fencs',
      short_desc=N_("automatically detected character encodings"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_fencs',
      defaults={if_true={vi="ucs-bom,utf-8,default,latin1"}}
    },
    {
      full_name='fileformat', abbreviation='ff',
      short_desc=N_("file format used for file I/O"),
      type='string', scope={'buffer'},
      no_mkrc=true,
      vi_def=true,
      alloced=true,
      redraw={'curswant', 'statuslines'},
      varname='p_ff',
      defaults={if_true={vi=macros('DFLT_FF')}}
    },
    {
      full_name='fileformats', abbreviation='ffs',
      short_desc=N_("automatically detected values for 'fileformat'"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vim=true,
      varname='p_ffs',
      defaults={if_true={vi=macros('DFLT_FFS_VI'), vim=macros('DFLT_FFS_VIM')}}
    },
    {
      full_name='fileignorecase', abbreviation='fic',
      short_desc=N_("ignore case when using file names"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_fic',
      defaults={
        condition='CASE_INSENSITIVE_FILENAME',
        if_true={vi=true},
        if_false={vi=false},
      }
    },
    {
      full_name='filetype', abbreviation='ft',
      short_desc=N_("type of file, used for autocommands"),
      type='string', scope={'buffer'},
      noglob=true,
      normal_fname_chars=true,
      vi_def=true,
      alloced=true,
      expand=true,
      varname='p_ft',
      defaults={if_true={vi=""}}
    },
    {
      full_name='fillchars', abbreviation='fcs',
      short_desc=N_("characters to use for displaying special items"),
      type='string', list='onecomma', scope={'global', 'window'},
      deny_duplicates=true,
      vi_def=true,
      alloced=true,
      redraw={'current_window'},
      varname='p_fcs',
      defaults={if_true={vi=''}}
    },
    {
      full_name='fixendofline', abbreviation='fixeol',
      short_desc=N_("make sure last line in file has <EOL>"),
      type='bool', scope={'buffer'},
      vi_def=true,
      redraw={'statuslines'},
      varname='p_fixeol',
      defaults={if_true={vi=true}}
    },
    {
      full_name='foldclose', abbreviation='fcl',
      short_desc=N_("close a fold when the cursor leaves it"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      redraw={'current_window'},
      varname='p_fcl',
      defaults={if_true={vi=""}}
    },
    {
      full_name='foldcolumn', abbreviation='fdc',
      short_desc=N_("width of the column used to indicate folds"),
      type='string', scope={'window'},
      vi_def=true,
      alloced=true,
      redraw={'current_window'},
      defaults={if_true={vi="0"}}
    },
    {
      full_name='foldenable', abbreviation='fen',
      short_desc=N_("set to display all folds open"),
      type='bool', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=true}}
    },
    {
      full_name='foldexpr', abbreviation='fde',
      short_desc=N_("expression used when 'foldmethod' is \"expr\""),
      type='string', scope={'window'},
      vi_def=true,
      vim=true,
      modelineexpr=true,
      alloced=true,
      redraw={'current_window'},
      defaults={if_true={vi="0"}}
    },
    {
      full_name='foldignore', abbreviation='fdi',
      short_desc=N_("ignore lines when 'foldmethod' is \"indent\""),
      type='string', scope={'window'},
      vi_def=true,
      vim=true,
      alloced=true,
      redraw={'current_window'},
      defaults={if_true={vi="#"}}
    },
    {
      full_name='foldlevel', abbreviation='fdl',
      short_desc=N_("close folds with a level higher than this"),
      type='number', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=0}}
    },
    {
      full_name='foldlevelstart', abbreviation='fdls',
      short_desc=N_("'foldlevel' when starting to edit a file"),
      type='number', scope={'global'},
      vi_def=true,
      redraw={'curswant'},
      varname='p_fdls',
      defaults={if_true={vi=-1}}
    },
    {
      full_name='foldmarker', abbreviation='fmr',
      short_desc=N_("markers used when 'foldmethod' is \"marker\""),
      type='string', list='onecomma', scope={'window'},
      deny_duplicates=true,
      vi_def=true,
      vim=true,
      alloced=true,
      redraw={'current_window'},
      defaults={if_true={vi="{{{,}}}"}}
    },
    {
      full_name='foldmethod', abbreviation='fdm',
      short_desc=N_("folding type"),
      type='string', scope={'window'},
      vi_def=true,
      vim=true,
      alloced=true,
      redraw={'current_window'},
      defaults={if_true={vi="manual"}}
    },
    {
      full_name='foldminlines', abbreviation='fml',
      short_desc=N_("minimum number of lines for a fold to be closed"),
      type='number', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=1}}
    },
    {
      full_name='foldnestmax', abbreviation='fdn',
      short_desc=N_("maximum fold depth"),
      type='number', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=20}}
    },
    {
      full_name='foldopen', abbreviation='fdo',
      short_desc=N_("for which commands a fold will be opened"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      redraw={'curswant'},
      varname='p_fdo',
      defaults={if_true={vi="block,hor,mark,percent,quickfix,search,tag,undo"}}
    },
    {
      full_name='foldtext', abbreviation='fdt',
      short_desc=N_("expression used to display for a closed fold"),
      type='string', scope={'window'},
      vi_def=true,
      vim=true,
      modelineexpr=true,
      alloced=true,
      redraw={'current_window'},
      defaults={if_true={vi="foldtext()"}}
    },
    {
      full_name='formatexpr', abbreviation='fex',
      short_desc=N_("expression used with \"gq\" command"),
      type='string', scope={'buffer'},
      vi_def=true,
      vim=true,
      modelineexpr=true,
      alloced=true,
      varname='p_fex',
      defaults={if_true={vi=""}}
    },
    {
      full_name='formatoptions', abbreviation='fo',
      short_desc=N_("how automatic formatting is to be done"),
      type='string', list='flags', scope={'buffer'},
      vim=true,
      alloced=true,
      varname='p_fo',
      defaults={if_true={vi=macros('DFLT_FO_VI'), vim=macros('DFLT_FO_VIM')}}
    },
    {
      full_name='formatlistpat', abbreviation='flp',
      short_desc=N_("pattern used to recognize a list header"),
      type='string', scope={'buffer'},
      vi_def=true,
      alloced=true,
      varname='p_flp',
      defaults={if_true={vi="^\\s*\\d\\+[\\]:.)}\\t ]\\s*"}}
    },
    {
      full_name='formatprg', abbreviation='fp',
      short_desc=N_("name of external program used with \"gq\" command"),
      type='string', scope={'global', 'buffer'},
      secure=true,
      vi_def=true,
      expand=true,
      varname='p_fp',
      defaults={if_true={vi=""}}
    },
    {
      full_name='fsync', abbreviation='fs',
      short_desc=N_("whether to invoke fsync() after file write"),
      type='bool', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_fs',
      defaults={if_true={vi=false}}
    },
    {
      full_name='gdefault', abbreviation='gd',
      short_desc=N_("the \":substitute\" flag 'g' is default on"),
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_gd',
      defaults={if_true={vi=false}}
    },
    {
      full_name='grepformat', abbreviation='gfm',
      short_desc=N_("format of 'grepprg' output"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_gefm',
      defaults={if_true={vi=macros('DFLT_GREPFORMAT')}}
    },
    {
      full_name='grepprg', abbreviation='gp',
      short_desc=N_("program to use for \":grep\""),
      type='string', scope={'global', 'buffer'},
      secure=true,
      vi_def=true,
      expand=true,
      varname='p_gp',
      defaults={
        condition='WIN32',
        -- Add an extra file name so that grep will always
        -- insert a file name in the match line. */
        if_true={vi="findstr /n $* nul"},
        if_false={vi="grep -n $* /dev/null"}
      }
    },
    {
      full_name='guicursor', abbreviation='gcr',
      short_desc=N_("GUI: settings for cursor shape and blinking"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_guicursor',
      defaults={if_true={vi="n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20"}}
    },
    {
      full_name='guifont', abbreviation='gfn',
      short_desc=N_("GUI: Name(s) of font(s) to be used"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_guifont',
      redraw={'ui_option'},
      defaults={if_true={vi=""}}
    },
    {
      full_name='guifontwide', abbreviation='gfw',
      short_desc=N_("list of font names for double-wide characters"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      redraw={'ui_option'},
      varname='p_guifontwide',
      defaults={if_true={vi=""}}
    },
    {
      full_name='guioptions', abbreviation='go',
      short_desc=N_("GUI: Which components and options are used"),
      type='string', list='flags', scope={'global'},
      vi_def=true,
      redraw={'all_windows'},
      enable_if=false,
    },
    {
      full_name='guitablabel', abbreviation='gtl',
      short_desc=N_("GUI: custom label for a tab page"),
      type='string', scope={'global'},
      vi_def=true,
      modelineexpr=true,
      redraw={'current_window'},
      enable_if=false,
    },
    {
      full_name='guitabtooltip', abbreviation='gtt',
      short_desc=N_("GUI: custom tooltip for a tab page"),
      type='string', scope={'global'},
      vi_def=true,
      redraw={'current_window'},
      enable_if=false,
    },
    {
      full_name='helpfile', abbreviation='hf',
      short_desc=N_("full path name of the main help file"),
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      expand=true,
      varname='p_hf',
      defaults={if_true={vi=macros('DFLT_HELPFILE')}}
    },
    {
      full_name='helpheight', abbreviation='hh',
      short_desc=N_("minimum height of a new help window"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_hh',
      defaults={if_true={vi=20}}
    },
    {
      full_name='helplang', abbreviation='hlg',
      short_desc=N_("preferred help languages"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_hlg',
      defaults={if_true={vi=""}}
    },
    {
      full_name='hidden', abbreviation='hid',
      short_desc=N_("don't unload buffer when it is |abandon|ed"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_hid',
      defaults={if_true={vi=false}}
    },
    {
      full_name='highlight', abbreviation='hl',
      short_desc=N_("sets highlighting mode for various occasions"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_hl',
      defaults={if_true={vi=macros('HIGHLIGHT_INIT')}}
    },
    {
      full_name='history', abbreviation='hi',
      short_desc=N_("number of command-lines that are remembered"),
      type='number', scope={'global'},
      vim=true,
      varname='p_hi',
      defaults={if_true={vi=0, vim=10000}}
    },
    {
      full_name='hkmap', abbreviation='hk',
      short_desc=N_("Hebrew keyboard mapping"),
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_hkmap',
      defaults={if_true={vi=false}}
    },
    {
      full_name='hkmapp', abbreviation='hkp',
      short_desc=N_("phonetic Hebrew keyboard mapping"),
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_hkmapp',
      defaults={if_true={vi=false}}
    },
    {
      full_name='hlsearch', abbreviation='hls',
      short_desc=N_("highlight matches with last search pattern"),
      type='bool', scope={'global'},
      vim=true,
      redraw={'all_windows'},
      varname='p_hls',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='icon',
      short_desc=N_("Vim set the text of the window icon"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_icon',
      defaults={if_true={vi=false}}
    },
    {
      full_name='iconstring',
      short_desc=N_("to use for the Vim icon text"),
      type='string', scope={'global'},
      vi_def=true,
      modelineexpr=true,
      varname='p_iconstring',
      defaults={if_true={vi=""}}
    },
    {
      full_name='ignorecase', abbreviation='ic',
      short_desc=N_("ignore case in search patterns"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_ic',
      defaults={if_true={vi=false}}
    },
    {
      full_name='imcmdline', abbreviation='imc',
      short_desc=N_("use IM when starting to edit a command line"),
      type='bool', scope={'global'},
      vi_def=true,
      enable_if=false,
      defaults={if_true={vi=false}}
    },
    {
      full_name='imdisable', abbreviation='imd',
      short_desc=N_("do not use the IM in any mode"),
      type='bool', scope={'global'},
      vi_def=true,
      enable_if=false,
      defaults={if_true={vi=false}}
    },
    {
      full_name='iminsert', abbreviation='imi',
      short_desc=N_("use :lmap or IM in Insert mode"),
      type='number', scope={'buffer'},
      vi_def=true,
      varname='p_iminsert', pv_name='p_imi',
      defaults={
        if_true={vi=macros('B_IMODE_NONE')},
      }
    },
    {
      full_name='imsearch', abbreviation='ims',
      short_desc=N_("use :lmap or IM when typing a search pattern"),
      type='number', scope={'buffer'},
      vi_def=true,
      varname='p_imsearch', pv_name='p_ims',
      defaults={
        if_true={vi=macros('B_IMODE_USE_INSERT')},
      }
    },
    {
      full_name='inccommand', abbreviation='icm',
	  short_desc=N_("Live preview of substitution"),
      type='string', scope={'global'},
      vi_def=true,
      redraw={'all_windows'},
      varname='p_icm',
      defaults={if_true={vi=""}}
    },
    {
      full_name='include', abbreviation='inc',
      short_desc=N_("pattern to be used to find an include file"),
      type='string', scope={'global', 'buffer'},
      vi_def=true,
      alloced=true,
      varname='p_inc',
      defaults={if_true={vi="^\\s*#\\s*include"}}
    },
    {
      full_name='includeexpr', abbreviation='inex',
      short_desc=N_("expression used to process an include line"),
      type='string', scope={'buffer'},
      vi_def=true,
      modelineexpr=true,
      alloced=true,
      varname='p_inex',
      defaults={if_true={vi=""}}
    },
    {
      full_name='incsearch', abbreviation='is',
      short_desc=N_("highlight match while typing search pattern"),
      type='bool', scope={'global'},
      vim=true,
      varname='p_is',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='indentexpr', abbreviation='inde',
      short_desc=N_("expression used to obtain the indent of a line"),
      type='string', scope={'buffer'},
      vi_def=true,
      vim=true,
      modelineexpr=true,
      alloced=true,
      varname='p_inde',
      defaults={if_true={vi=""}}
    },
    {
      full_name='indentkeys', abbreviation='indk',
      short_desc=N_("keys that trigger indenting with 'indentexpr'"),
      type='string', list='onecomma', scope={'buffer'},
      deny_duplicates=true,
      vi_def=true,
      alloced=true,
      varname='p_indk',
      defaults={if_true={vi=indentkeys_default}}
    },
    {
      full_name='infercase', abbreviation='inf',
      short_desc=N_("adjust case of match for keyword completion"),
      type='bool', scope={'buffer'},
      vi_def=true,
      varname='p_inf',
      defaults={if_true={vi=false}}
    },
    {
      full_name='insertmode', abbreviation='im',
      short_desc=N_("start the edit of a file in Insert mode"),
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_im',
      defaults={if_true={vi=false}}
    },
    {
      full_name='isfname', abbreviation='isf',
      short_desc=N_("characters included in file names and pathnames"),
      type='string', list='comma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_isf',
      defaults={
        condition='BACKSLASH_IN_FILENAME',
        -- Excluded are: & and ^ are special in cmd.exe
        -- ( and ) are used in text separating fnames */
        if_true={vi="@,48-57,/,\\,.,-,_,+,,,#,$,%,{,},[,],:,@-@,!,~,="},
        if_false={vi="@,48-57,/,.,-,_,+,,,#,$,%,~,="}
      }
    },
    {
      full_name='isident', abbreviation='isi',
      short_desc=N_("characters included in identifiers"),
      type='string', list='comma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_isi',
      defaults={
        condition='WIN32',
        if_true={vi="@,48-57,_,128-167,224-235"},
        if_false={vi="@,48-57,_,192-255"}
      }
    },
    {
      full_name='iskeyword', abbreviation='isk',
      short_desc=N_("characters included in keywords"),
      type='string', list='comma', scope={'buffer'},
      deny_duplicates=true,
      vim=true,
      alloced=true,
      varname='p_isk',
      defaults={if_true={vi="@,48-57,_", vim="@,48-57,_,192-255"}}
    },
    {
      full_name='isprint', abbreviation='isp',
      short_desc=N_("printable characters"),
      type='string', list='comma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      redraw={'all_windows'},
      varname='p_isp',
      defaults={if_true={vi="@,161-255"}
      }
    },
    {
      full_name='joinspaces', abbreviation='js',
      short_desc=N_("two spaces after a period with a join command"),
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_js',
      defaults={if_true={vi=true}}
    },
    {
      full_name='jumpoptions', abbreviation='jop',
      short_desc=N_("Controls the behavior of the jumplist"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      varname='p_jop',
      vim=true,
      defaults={if_true={vim=''}}
    },
    {
      full_name='keymap', abbreviation='kmp',
      short_desc=N_("name of a keyboard mapping"),
      type='string', scope={'buffer'},
      normal_fname_chars=true,
      pri_mkrc=true,
      vi_def=true,
      alloced=true,
      redraw={'statuslines', 'current_buffer'},
      varname='p_keymap', pv_name='p_kmap',
      defaults={if_true={vi=""}}
    },
    {
      full_name='keymodel', abbreviation='km',
      short_desc=N_("enable starting/stopping selection with keys"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_km',
      defaults={if_true={vi=""}}
    },
    {
      full_name='keywordprg', abbreviation='kp',
      short_desc=N_("program to use for the \"K\" command"),
      type='string', scope={'global', 'buffer'},
      secure=true,
      vi_def=true,
      expand=true,
      varname='p_kp',
      defaults={
        if_true={vi=":Man"},
      }
    },
    {
      full_name='langmap', abbreviation='lmap',
      short_desc=N_("alphabetic characters for other language mode"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      secure=true,
      vi_def=true,
      varname='p_langmap',
      defaults={if_true={vi=""}}
    },
    {
      full_name='langmenu', abbreviation='lm',
      short_desc=N_("language to be used for the menus"),
      type='string', scope={'global'},
      normal_fname_chars=true,
      vi_def=true,
      varname='p_lm',
      defaults={if_true={vi=""}}
    },
    {
      full_name='langnoremap', abbreviation='lnr',
      short_desc=N_("do not apply 'langmap' to mapped characters"),
      type='bool', scope={'global'},
      varname='p_lnr',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='langremap', abbreviation='lrm',
      short_desc=N_('No description'),
      type='bool', scope={'global'},
      varname='p_lrm',
      defaults={if_true={vi=true, vim=false}}
    },
    {
      full_name='laststatus', abbreviation='ls',
      short_desc=N_("tells when last window has status lines"),
      type='number', scope={'global'},
      vim=true,
      redraw={'all_windows'},
      varname='p_ls',
      defaults={if_true={vi=1,vim=2}}
    },
    {
      full_name='lazyredraw', abbreviation='lz',
      short_desc=N_("don't redraw while executing macros"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_lz',
      defaults={if_true={vi=false}}
    },
    {
      full_name='linebreak', abbreviation='lbr',
      short_desc=N_("wrap long lines at a blank"),
      type='bool', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='lines',
      short_desc=N_("of lines in the display"),
      type='number', scope={'global'},
      no_mkrc=true,
      vi_def=true,
      redraw={'everything'},
      varname='p_lines',
      defaults={if_true={vi=macros('DFLT_ROWS')}}
    },
    {
      full_name='linespace', abbreviation='lsp',
      short_desc=N_("number of pixel lines to use between characters"),
      type='number', scope={'global'},
      vi_def=true,
      redraw={'ui_option'},
      varname='p_linespace',
      defaults={if_true={vi=0}}
    },
    {
      full_name='lisp',
      short_desc=N_("indenting for Lisp"),
      type='bool', scope={'buffer'},
      vi_def=true,
      varname='p_lisp',
      defaults={if_true={vi=false}}
    },
    {
      full_name='lispwords', abbreviation='lw',
      short_desc=N_("words that change how lisp indenting works"),
      type='string', list='onecomma', scope={'global', 'buffer'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_lispwords', pv_name='p_lw',
      defaults={if_true={vi=macros('LISPWORD_VALUE')}}
    },
    {
      full_name='list',
      short_desc=N_("<Tab> and <EOL>"),
      type='bool', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='listchars', abbreviation='lcs',
      short_desc=N_("characters for displaying in list mode"),
      type='string', list='onecomma', scope={'global', 'window'},
      deny_duplicates=true,
      vim=true,
      alloced=true,
      redraw={'current_window'},
      varname='p_lcs',
      defaults={if_true={vi="eol:$", vim="tab:> ,trail:-,nbsp:+"}}
    },
    {
      full_name='loadplugins', abbreviation='lpl',
      short_desc=N_("load plugin scripts when starting up"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_lpl',
      defaults={if_true={vi=true}}
    },
    {
      full_name='magic',
      short_desc=N_("special characters in search patterns"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_magic',
      defaults={if_true={vi=true}}
    },
    {
      full_name='makeef', abbreviation='mef',
      short_desc=N_("name of the errorfile for \":make\""),
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      expand=true,
      varname='p_mef',
      defaults={if_true={vi=""}}
    },
    {
      full_name='makeencoding', abbreviation='menc',
      short_desc=N_("Converts the output of external commands"),
      type='string', scope={'global', 'buffer'},
      vi_def=true,
      varname='p_menc',
      defaults={if_true={vi=""}}
    },
    {
      full_name='makeprg', abbreviation='mp',
      short_desc=N_("program to use for the \":make\" command"),
      type='string', scope={'global', 'buffer'},
      secure=true,
      vi_def=true,
      expand=true,
      varname='p_mp',
      defaults={if_true={vi="make"}}
    },
    {
      full_name='matchpairs', abbreviation='mps',
      short_desc=N_("pairs of characters that \"%\" can match"),
      type='string', list='onecomma', scope={'buffer'},
      deny_duplicates=true,
      vi_def=true,
      alloced=true,
      varname='p_mps',
      defaults={if_true={vi="(:),{:},[:]"}}
    },
    {
      full_name='matchtime', abbreviation='mat',
      short_desc=N_("tenths of a second to show matching paren"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_mat',
      defaults={if_true={vi=5}}
    },
    {
      full_name='maxcombine', abbreviation='mco',
      short_desc=N_("maximum nr of combining characters displayed"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_mco',
      defaults={if_true={vi=6}}
    },
    {
      full_name='maxfuncdepth', abbreviation='mfd',
      short_desc=N_("maximum recursive depth for user functions"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_mfd',
      defaults={if_true={vi=100}}
    },
    {
      full_name='maxmapdepth', abbreviation='mmd',
      short_desc=N_("maximum recursive depth for mapping"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_mmd',
      defaults={if_true={vi=1000}}
    },
    {
      full_name='maxmempattern', abbreviation='mmp',
      short_desc=N_("maximum memory (in Kbyte) used for pattern search"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_mmp',
      defaults={if_true={vi=1000}}
    },
    {
      full_name='menuitems', abbreviation='mis',
      short_desc=N_("maximum number of items in a menu"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_mis',
      defaults={if_true={vi=25}}
    },
    {
      full_name='mkspellmem', abbreviation='msm',
      short_desc=N_("memory used before |:mkspell| compresses the tree"),
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      expand=true,
      varname='p_msm',
      defaults={if_true={vi="460000,2000,500"}}
    },
    {
      full_name='modeline', abbreviation='ml',
      short_desc=N_("recognize modelines at start or end of file"),
      type='bool', scope={'buffer'},
      vim=true,
      varname='p_ml',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='modelineexpr', abbreviation='mle',
      short_desc=N_("allow some options to be set in modeline"),
      type='bool', scope={'global'},
      vi_def=true,
      secure=true,
      varname='p_mle',
      defaults={if_true={vi=false}}
    },
    {
      full_name='modelines', abbreviation='mls',
      short_desc=N_("number of lines checked for modelines"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_mls',
      defaults={if_true={vi=5}}
    },
    {
      full_name='modifiable', abbreviation='ma',
      short_desc=N_("changes to the text are not possible"),
      type='bool', scope={'buffer'},
      noglob=true,
      vi_def=true,
      varname='p_ma',
      defaults={if_true={vi=true}}
    },
    {
      full_name='modified', abbreviation='mod',
      short_desc=N_("buffer has been modified"),
      type='bool', scope={'buffer'},
      no_mkrc=true,
      vi_def=true,
      redraw={'statuslines'},
      varname='p_mod',
      defaults={if_true={vi=false}}
    },
    {
      full_name='more',
      short_desc=N_("listings when the whole screen is filled"),
      type='bool', scope={'global'},
      vim=true,
      varname='p_more',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='mouse',
      short_desc=N_("the use of mouse clicks"),
      type='string', list='flags', scope={'global'},
      varname='p_mouse',
      defaults={if_true={vi="", vim=""}}
    },
    {
      full_name='mousefocus', abbreviation='mousef',
      short_desc=N_("keyboard focus follows the mouse"),
      type='bool', scope={'global'},
      vi_def=true,
      redraw={'ui_option'},
      varname='p_mousef',
      defaults={if_true={vi=false}}
    },
    {
      full_name='mousehide', abbreviation='mh',
      short_desc=N_("hide mouse pointer while typing"),
      type='bool', scope={'global'},
      vi_def=true,
      enable_if=false,
      defaults={if_true={vi=true}}
    },
    {
      full_name='mousemodel', abbreviation='mousem',
      short_desc=N_("changes meaning of mouse buttons"),
      type='string', scope={'global'},
      vi_def=true,
      varname='p_mousem',
      defaults={if_true={vi="extend"}}
    },
    {
      full_name='mouseshape', abbreviation='mouses',
      short_desc=N_("shape of the mouse pointer in different modes"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      enable_if=false,
    },
    {
      full_name='mousetime', abbreviation='mouset',
      short_desc=N_("max time between mouse double-click"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_mouset',
      defaults={if_true={vi=500}}
    },
    {
      full_name='nrformats', abbreviation='nf',
      short_desc=N_("number formats recognized for CTRL-A command"),
      type='string', list='onecomma', scope={'buffer'},
      deny_duplicates=true,
      alloced=true,
      varname='p_nf',
      defaults={if_true={vi="bin,octal,hex", vim="bin,hex"}}
    },
    {
      full_name='number', abbreviation='nu',
      short_desc=N_("print the line number in front of each line"),
      type='bool', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='numberwidth', abbreviation='nuw',
      short_desc=N_("number of columns used for the line number"),
      type='number', scope={'window'},
      vim=true,
      redraw={'current_window'},
      defaults={if_true={vi=8, vim=4}}
    },
    {
      full_name='omnifunc', abbreviation='ofu',
      short_desc=N_("function for filetype-specific completion"),
      type='string', scope={'buffer'},
      secure=true,
      vi_def=true,
      alloced=true,
      varname='p_ofu',
      defaults={if_true={vi=""}}
    },
    {
      full_name='opendevice', abbreviation='odev',
      short_desc=N_("allow reading/writing devices on MS-Windows"),
      type='bool', scope={'global'},
      vi_def=true,
      enable_if=false,
      defaults={if_true={vi=false, vim=false}}
    },
    {
      full_name='operatorfunc', abbreviation='opfunc',
      short_desc=N_("function to be called for |g@| operator"),
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_opfunc',
      defaults={if_true={vi=""}}
    },
    {
      full_name='packpath', abbreviation='pp',
      short_desc=N_("list of directories used for packages"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      secure=true,
      vi_def=true,
      expand=true,
      varname='p_pp',
      defaults={if_true={vi=''}}
    },
    {
      full_name='paragraphs', abbreviation='para',
      short_desc=N_("nroff macros that separate paragraphs"),
      type='string', scope={'global'},
      vi_def=true,
      varname='p_para',
      defaults={if_true={vi="IPLPPPQPP TPHPLIPpLpItpplpipbp"}}
    },
    {
      full_name='paste',
      short_desc=N_("pasting text"),
      type='bool', scope={'global'},
      pri_mkrc=true,
      vi_def=true,
      varname='p_paste',
      defaults={if_true={vi=false}}
    },
    {
      full_name='pastetoggle', abbreviation='pt',
      short_desc=N_("key code that causes 'paste' to toggle"),
      type='string', scope={'global'},
      vi_def=true,
      varname='p_pt',
      defaults={if_true={vi=""}}
    },
    {
      full_name='patchexpr', abbreviation='pex',
      short_desc=N_("expression used to patch a file"),
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_pex',
      defaults={if_true={vi=""}}
    },
    {
      full_name='patchmode', abbreviation='pm',
      short_desc=N_("keep the oldest version of a file"),
      type='string', scope={'global'},
      normal_fname_chars=true,
      vi_def=true,
      varname='p_pm',
      defaults={if_true={vi=""}}
    },
    {
      full_name='path', abbreviation='pa',
      short_desc=N_("list of directories searched with \"gf\" et.al."),
      type='string', list='comma', scope={'global', 'buffer'},
      deny_duplicates=true,
      vi_def=true,
      expand=true,
      varname='p_path',
      defaults={if_true={vi=".,/usr/include,,"}}
    },
    {
      full_name='preserveindent', abbreviation='pi',
      short_desc=N_("preserve the indent structure when reindenting"),
      type='bool', scope={'buffer'},
      vi_def=true,
      vim=true,
      varname='p_pi',
      defaults={if_true={vi=false}}
    },
    {
      full_name='previewheight', abbreviation='pvh',
      short_desc=N_("height of the preview window"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_pvh',
      defaults={if_true={vi=12}}
    },
    {
      full_name='previewwindow', abbreviation='pvw',
      short_desc=N_("identifies the preview window"),
      type='bool', scope={'window'},
      noglob=true,
      vi_def=true,
      redraw={'statuslines'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='printdevice', abbreviation='pdev',
      short_desc=N_("name of the printer to be used for :hardcopy"),
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_pdev',
      defaults={if_true={vi=""}}
    },
    {
      full_name='printencoding', abbreviation='penc',
      short_desc=N_("encoding to be used for printing"),
      type='string', scope={'global'},
      vi_def=true,
      varname='p_penc',
      defaults={if_true={vi=""}}
    },
    {
      full_name='printexpr', abbreviation='pexpr',
      short_desc=N_("expression used to print PostScript for :hardcopy"),
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_pexpr',
      defaults={if_true={vi=""}}
    },
    {
      full_name='printfont', abbreviation='pfn',
      short_desc=N_("name of the font to be used for :hardcopy"),
      type='string', scope={'global'},
      vi_def=true,
      varname='p_pfn',
      defaults={if_true={vi="courier"}}
    },
    {
      full_name='printheader', abbreviation='pheader',
      short_desc=N_("format of the header used for :hardcopy"),
      type='string', scope={'global'},
      vi_def=true,
      varname='p_header',
      defaults={if_true={vi="%<%f%h%m%=Page %N"}}
    },
    {
      full_name='printmbcharset', abbreviation='pmbcs',
      short_desc=N_("CJK character set to be used for :hardcopy"),
      type='string', scope={'global'},
      vi_def=true,
      varname='p_pmcs',
      defaults={if_true={vi=""}}
    },
    {
      full_name='printmbfont', abbreviation='pmbfn',
      short_desc=N_("font names to be used for CJK output of :hardcopy"),
      type='string', scope={'global'},
      vi_def=true,
      varname='p_pmfn',
      defaults={if_true={vi=""}}
    },
    {
      full_name='printoptions', abbreviation='popt',
      short_desc=N_("controls the format of :hardcopy output"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_popt',
      defaults={if_true={vi=""}}
    },
    {
      full_name='prompt',
      short_desc=N_("enable prompt in Ex mode"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_prompt',
      defaults={if_true={vi=true}}
    },
    {
      full_name='pumblend', abbreviation='pb',
      short_desc=N_("Controls transparency level of popup menu"),
      type='number', scope={'global'},
      vi_def=true,
      redraw={'ui_option'},
      varname='p_pb',
      defaults={if_true={vi=0}}
    },
    {
      full_name='pumheight', abbreviation='ph',
      short_desc=N_("maximum height of the popup menu"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_ph',
      defaults={if_true={vi=0}}
    },
    {
      full_name='pumwidth', abbreviation='pw',
      short_desc=N_("minimum width of the popup menu"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_pw',
      defaults={if_true={vi=15}}
    },
    {
      full_name='pyxversion', abbreviation='pyx',
      short_desc=N_("selects default python version to use"),
      type='number', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_pyx',
      defaults={if_true={vi=0}}
    },
    {
      full_name='quoteescape', abbreviation='qe',
      short_desc=N_("escape characters used in a string"),
      type='string', scope={'buffer'},
      vi_def=true,
      alloced=true,
      varname='p_qe',
      defaults={if_true={vi="\\"}}
    },
    {
      full_name='readonly', abbreviation='ro',
      short_desc=N_("disallow writing the buffer"),
      type='bool', scope={'buffer'},
      noglob=true,
      vi_def=true,
      redraw={'statuslines'},
      varname='p_ro',
      defaults={if_true={vi=false}}
    },
    {
      full_name='redrawdebug', abbreviation='rdb',
      short_desc=N_("Changes the way redrawing works (debug)"),
      type='string', list='onecomma', scope={'global'},
      vi_def=true,
      varname='p_rdb',
      defaults={if_true={vi=''}}
    },
    {
      full_name='redrawtime', abbreviation='rdt',
      short_desc=N_("timeout for 'hlsearch' and |:match| highlighting"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_rdt',
      defaults={if_true={vi=2000}}
    },
    {
      full_name='regexpengine', abbreviation='re',
      short_desc=N_("default regexp engine to use"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_re',
      defaults={if_true={vi=0}}
    },
    {
      full_name='relativenumber', abbreviation='rnu',
      short_desc=N_("show relative line number in front of each line"),
      type='bool', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='remap',
      short_desc=N_("mappings to work recursively"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_remap',
      defaults={if_true={vi=true}}
    },
    {
      full_name='report',
      short_desc=N_("for reporting nr. of lines changed"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_report',
      defaults={if_true={vi=2}}
    },
    {
      full_name='revins', abbreviation='ri',
      short_desc=N_("inserting characters will work backwards"),
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_ri',
      defaults={if_true={vi=false}}
    },
    {
      full_name='rightleft', abbreviation='rl',
      short_desc=N_("window is right-to-left oriented"),
      type='bool', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='rightleftcmd', abbreviation='rlc',
      short_desc=N_("commands for which editing works right-to-left"),
      type='string', scope={'window'},
      vi_def=true,
      alloced=true,
      redraw={'current_window'},
      defaults={if_true={vi="search"}}
    },
    {
      full_name='ruler', abbreviation='ru',
      short_desc=N_("show cursor line and column in the status line"),
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      redraw={'statuslines'},
      varname='p_ru',
      defaults={if_true={vi=true}}
    },
    {
      full_name='rulerformat', abbreviation='ruf',
      short_desc=N_("custom format for the ruler"),
      type='string', scope={'global'},
      vi_def=true,
      alloced=true,
      modelineexpr=true,
      redraw={'statuslines'},
      varname='p_ruf',
      defaults={if_true={vi=""}}
    },
    {
      full_name='runtimepath', abbreviation='rtp',
      short_desc=N_("list of directories used for runtime files"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      secure=true,
      vi_def=true,
      expand='nodefault',
      varname='p_rtp',
      defaults={if_true={vi=''}}
    },
    {
      full_name='scroll', abbreviation='scr',
      short_desc=N_("lines to scroll with CTRL-U and CTRL-D"),
      type='number', scope={'window'},
      no_mkrc=true,
      vi_def=true,
      pv_name='p_scroll',
      defaults={if_true={vi=0}}
    },
    {
      full_name='scrollback', abbreviation='scbk',
      short_desc=N_("lines to scroll with CTRL-U and CTRL-D"),
      type='number', scope={'buffer'},
      vi_def=true,
      varname='p_scbk',
      redraw={'current_buffer'},
      defaults={if_true={vi=-1}}
    },
    {
      full_name='scrollbind', abbreviation='scb',
      short_desc=N_("scroll in window as other windows scroll"),
      type='bool', scope={'window'},
      vi_def=true,
      pv_name='p_scbind',
      defaults={if_true={vi=false}}
    },
    {
      full_name='scrolljump', abbreviation='sj',
      short_desc=N_("minimum number of lines to scroll"),
      type='number', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_sj',
      defaults={if_true={vi=1}}
    },
    {
      full_name='scrolloff', abbreviation='so',
      short_desc=N_("minimum nr. of lines above and below cursor"),
      type='number', scope={'global', 'window'},
      vi_def=true,
      vim=true,
      redraw={'all_windows'},
      varname='p_so',
      defaults={if_true={vi=0}}
    },
    {
      full_name='scrollopt', abbreviation='sbo',
      short_desc=N_("how 'scrollbind' should behave"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_sbo',
      defaults={if_true={vi="ver,jump"}}
    },
    {
      full_name='sections', abbreviation='sect',
      short_desc=N_("nroff macros that separate sections"),
      type='string', scope={'global'},
      vi_def=true,
      varname='p_sections',
      defaults={if_true={vi="SHNHH HUnhsh"}}
    },
    {
      full_name='secure',
      short_desc=N_("mode for reading .vimrc in current dir"),
      type='bool', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_secure',
      defaults={if_true={vi=false}}
    },
    {
      full_name='selection', abbreviation='sel',
      short_desc=N_("what type of selection to use"),
      type='string', scope={'global'},
      vi_def=true,
      varname='p_sel',
      defaults={if_true={vi="inclusive"}}
    },
    {
      full_name='selectmode', abbreviation='slm',
      short_desc=N_("when to use Select mode instead of Visual mode"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_slm',
      defaults={if_true={vi=""}}
    },
    {
      full_name='sessionoptions', abbreviation='ssop',
      short_desc=N_("options for |:mksession|"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vim=true,
      varname='p_ssop',
      defaults={if_true={
        vi="blank,buffers,curdir,folds,help,options,tabpages,winsize",
        vim="blank,buffers,curdir,folds,help,tabpages,winsize"
      }}
    },
    {
      full_name='shada', abbreviation='sd',
      short_desc=N_("use .shada file upon startup and exiting"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      secure=true,
      varname='p_shada',
      defaults={if_true={vi="", vim="!,'100,<50,s10,h"}}
    },
    {
      full_name='shadafile', abbreviation='sdf',
      short_desc=N_("overrides the filename used for shada"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      secure=true,
      expand=true,
      varname='p_shadafile',
      defaults={if_true={vi=""}}
    },
    {
      full_name='shell', abbreviation='sh',
      short_desc=N_("name of shell to use for external commands"),
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      expand=true,
      varname='p_sh',
      defaults={
        condition='WIN32',
        if_true={vi="cmd.exe"},
        if_false={vi="sh"}
      }
    },
    {
      full_name='shellcmdflag', abbreviation='shcf',
      short_desc=N_("flag to shell to execute one command"),
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_shcf',
      defaults={
        condition='WIN32',
        if_true={vi="/s /c"},
        if_false={vi="-c"}
      }
    },
    {
      full_name='shellpipe', abbreviation='sp',
      short_desc=N_("string to put output of \":make\" in error file"),
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_sp',
      defaults={
        condition='WIN32',
        if_true={vi=">%s 2>&1"},
        if_false={vi="| tee"},
      }
    },
    {
      full_name='shellquote', abbreviation='shq',
      short_desc=N_("quote character(s) for around shell command"),
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_shq',
      defaults={if_true={vi=""}}
    },
    {
      full_name='shellredir', abbreviation='srr',
      short_desc=N_("string to put output of filter in a temp file"),
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_srr',
      defaults={
        condition='WIN32',
        if_true={vi=">%s 2>&1"},
        if_false={vi=">"}
      }
    },
    {
      full_name='shellslash', abbreviation='ssl',
      short_desc=N_("use forward slash for shell file names"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_ssl',
      enable_if='BACKSLASH_IN_FILENAME',
      defaults={if_true={vi=false}}
    },
    {
      full_name='shelltemp', abbreviation='stmp',
      short_desc=N_("whether to use a temp file for shell commands"),
      type='bool', scope={'global'},
      varname='p_stmp',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='shellxquote', abbreviation='sxq',
      short_desc=N_("like 'shellquote', but include redirection"),
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_sxq',
      defaults={
        condition='WIN32',
        if_true={vi="\""},
        if_false={vi=""},
      }
    },
    {
      full_name='shellxescape', abbreviation='sxe',
      short_desc=N_("characters to escape when 'shellxquote' is ("),
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_sxe',
      defaults={if_true={vi=""}}
    },
    {
      full_name='shiftround', abbreviation='sr',
      short_desc=N_("round indent to multiple of shiftwidth"),
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_sr',
      defaults={if_true={vi=false}}
    },
    {
      full_name='shiftwidth', abbreviation='sw',
      short_desc=N_("number of spaces to use for (auto)indent step"),
      type='number', scope={'buffer'},
      vi_def=true,
      varname='p_sw',
      defaults={if_true={vi=8}}
    },
    {
      full_name='shortmess', abbreviation='shm',
      short_desc=N_("list of flags, reduce length of messages"),
      type='string', list='flags', scope={'global'},
      vim=true,
      varname='p_shm',
      defaults={if_true={vi="S", vim="filnxtToOF"}}
    },
    {
      full_name='showbreak', abbreviation='sbr',
      short_desc=N_("string to use at the start of wrapped lines"),
      type='string', scope={'global'},
      vi_def=true,
      redraw={'all_windows'},
      varname='p_sbr',
      defaults={if_true={vi=""}}
    },
    {
      full_name='showcmd', abbreviation='sc',
      short_desc=N_("show (partial) command in status line"),
      type='bool', scope={'global'},
      vim=true,
      varname='p_sc',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='showfulltag', abbreviation='sft',
      short_desc=N_("show full tag pattern when completing tag"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_sft',
      defaults={if_true={vi=false}}
    },
    {
      full_name='showmatch', abbreviation='sm',
      short_desc=N_("briefly jump to matching bracket if insert one"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_sm',
      defaults={if_true={vi=false}}
    },
    {
      full_name='showmode', abbreviation='smd',
      short_desc=N_("message on status line to show current mode"),
      type='bool', scope={'global'},
      vim=true,
      varname='p_smd',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='showtabline', abbreviation='stal',
      short_desc=N_("tells when the tab pages line is displayed"),
      type='number', scope={'global'},
      vi_def=true,
      redraw={'all_windows', 'ui_option'},
      varname='p_stal',
      defaults={if_true={vi=1}}
    },
    {
      full_name='sidescroll', abbreviation='ss',
      short_desc=N_("minimum number of columns to scroll horizontal"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_ss',
      defaults={if_true={vi=1}}
    },
    {
      full_name='sidescrolloff', abbreviation='siso',
      short_desc=N_("min. nr. of columns to left and right of cursor"),
      type='number', scope={'global', 'window'},
      vi_def=true,
      vim=true,
      redraw={'all_windows'},
      varname='p_siso',
      defaults={if_true={vi=0}}
    },
    {
      full_name='signcolumn', abbreviation='scl',
      short_desc=N_("when to display the sign column"),
      type='string', scope={'window'},
      vi_def=true,
      alloced=true,
      redraw={'current_window'},
      defaults={if_true={vi="auto"}}
    },
    {
      full_name='smartcase', abbreviation='scs',
      short_desc=N_("no ignore case when pattern has uppercase"),
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_scs',
      defaults={if_true={vi=false}}
    },
    {
      full_name='smartindent', abbreviation='si',
      short_desc=N_("smart autoindenting for C programs"),
      type='bool', scope={'buffer'},
      vi_def=true,
      vim=true,
      varname='p_si',
      defaults={if_true={vi=false}}
    },
    {
      full_name='smarttab', abbreviation='sta',
      short_desc=N_("use 'shiftwidth' when inserting <Tab>"),
      type='bool', scope={'global'},
      vim=true,
      varname='p_sta',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='softtabstop', abbreviation='sts',
      short_desc=N_("number of spaces that <Tab> uses while editing"),
      type='number', scope={'buffer'},
      vi_def=true,
      vim=true,
      varname='p_sts',
      defaults={if_true={vi=0}}
    },
    {
      full_name='spell',
      short_desc=N_("spell checking"),
      type='bool', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='spellcapcheck', abbreviation='spc',
      short_desc=N_("pattern to locate end of a sentence"),
      type='string', scope={'buffer'},
      vi_def=true,
      alloced=true,
      redraw={'current_buffer'},
      varname='p_spc',
      defaults={if_true={vi="[.?!]\\_[\\])'\"	 ]\\+"}}
    },
    {
      full_name='spellfile', abbreviation='spf',
      short_desc=N_("files where |zg| and |zw| store words"),
      type='string', list='onecomma', scope={'buffer'},
      deny_duplicates=true,
      secure=true,
      vi_def=true,
      alloced=true,
      expand=true,
      varname='p_spf',
      defaults={if_true={vi=""}}
    },
    {
      full_name='spelllang', abbreviation='spl',
      short_desc=N_("language(s) to do spell checking for"),
      type='string', list='onecomma', scope={'buffer'},
      deny_duplicates=true,
      vi_def=true,
      alloced=true,
      expand=true,
      redraw={'current_buffer'},
      varname='p_spl',
      defaults={if_true={vi="en"}}
    },
    {
      full_name='spellsuggest', abbreviation='sps',
      short_desc=N_("method(s) used to suggest spelling corrections"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      secure=true,
      vi_def=true,
      expand=true,
      varname='p_sps',
      defaults={if_true={vi="best"}}
    },
    {
      full_name='spelloptions', abbreviation='spo',
      type='string', list='onecomma', scope={'buffer'},
      deny_duplicates=true,
      secure=true,
      vi_def=true,
      expand=true,
      varname='p_spo',
      defaults={if_true={vi="", vim=""}}
    },
    {
      full_name='splitbelow', abbreviation='sb',
      short_desc=N_("new window from split is below the current one"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_sb',
      defaults={if_true={vi=false}}
    },
    {
      full_name='splitright', abbreviation='spr',
      short_desc=N_("new window is put right of the current one"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_spr',
      defaults={if_true={vi=false}}
    },
    {
      full_name='startofline', abbreviation='sol',
      short_desc=N_("commands move cursor to first non-blank in line"),
      type='bool', scope={'global'},
      vi_def=true,
      vim=false,
      varname='p_sol',
      defaults={if_true={vi=false}}
    },
    {
      full_name='statusline', abbreviation='stl',
      short_desc=N_("custom format for the status line"),
      type='string', scope={'global', 'window'},
      vi_def=true,
      alloced=true,
      modelineexpr=true,
      redraw={'statuslines'},
      varname='p_stl',
      defaults={if_true={vi=""}}
    },
    {
      full_name='suffixes', abbreviation='su',
      short_desc=N_("suffixes that are ignored with multiple match"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_su',
      defaults={if_true={vi=".bak,~,.o,.h,.info,.swp,.obj"}}
    },
    {
      full_name='suffixesadd', abbreviation='sua',
      short_desc=N_("suffixes added when searching for a file"),
      type='string', list='onecomma', scope={'buffer'},
      deny_duplicates=true,
      vi_def=true,
      alloced=true,
      varname='p_sua',
      defaults={if_true={vi=""}}
    },
    {
      full_name='swapfile', abbreviation='swf',
      short_desc=N_("whether to use a swapfile for a buffer"),
      type='bool', scope={'buffer'},
      vi_def=true,
      redraw={'statuslines'},
      varname='p_swf',
      defaults={if_true={vi=true}}
    },
    {
      full_name='switchbuf', abbreviation='swb',
      short_desc=N_("sets behavior when switching to another buffer"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_swb',
      defaults={if_true={vi=""}}
    },
    {
      full_name='synmaxcol', abbreviation='smc',
      short_desc=N_("maximum column to find syntax items"),
      type='number', scope={'buffer'},
      vi_def=true,
      redraw={'current_buffer'},
      varname='p_smc',
      defaults={if_true={vi=3000}}
    },
    {
      full_name='syntax', abbreviation='syn',
      short_desc=N_("syntax to be loaded for current buffer"),
      type='string', scope={'buffer'},
      noglob=true,
      normal_fname_chars=true,
      vi_def=true,
      alloced=true,
      varname='p_syn',
      defaults={if_true={vi=""}}
    },
    {
      full_name='tagfunc', abbreviation='tfu',
      short_desc=N_("function used to perform tag searches"),
      type='string', scope={'buffer'},
      vim=true,
      vi_def=true,
      varname='p_tfu',
      defaults={if_true={vi=""}}
    },
    {
      full_name='tabline', abbreviation='tal',
      short_desc=N_("custom format for the console tab pages line"),
      type='string', scope={'global'},
      vi_def=true,
      modelineexpr=true,
      redraw={'all_windows'},
      varname='p_tal',
      defaults={if_true={vi=""}}
    },
    {
      full_name='tabpagemax', abbreviation='tpm',
      short_desc=N_("maximum number of tab pages for |-p| and \"tab all\""),
      type='number', scope={'global'},
      vim=true,
      varname='p_tpm',
      defaults={if_true={vi=10, vim=50}}
    },
    {
      full_name='tabstop', abbreviation='ts',
      short_desc=N_("number of spaces that <Tab> in file uses"),
      type='number', scope={'buffer'},
      vi_def=true,
      redraw={'current_buffer'},
      varname='p_ts',
      defaults={if_true={vi=8}}
    },
    {
      full_name='tagbsearch', abbreviation='tbs',
      short_desc=N_("use binary searching in tags files"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_tbs',
      defaults={if_true={vi=true}}
    },
    {
      full_name='tagcase', abbreviation='tc',
      short_desc=N_("how to handle case when searching in tags files"),
      type='string', scope={'global', 'buffer'},
      vim=true,
      varname='p_tc',
      defaults={if_true={vi="followic", vim="followic"}}
    },
    {
      full_name='taglength', abbreviation='tl',
      short_desc=N_("number of significant characters for a tag"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_tl',
      defaults={if_true={vi=0}}
    },
    {
      full_name='tagrelative', abbreviation='tr',
      short_desc=N_("file names in tag file are relative"),
      type='bool', scope={'global'},
      vim=true,
      varname='p_tr',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='tags', abbreviation='tag',
      short_desc=N_("list of file names used by the tag command"),
      type='string', list='onecomma', scope={'global', 'buffer'},
      deny_duplicates=true,
      vi_def=true,
      expand=true,
      varname='p_tags',
      defaults={if_true={vi="./tags;,tags"}}
    },
    {
      full_name='tagstack', abbreviation='tgst',
      short_desc=N_("push tags onto the tag stack"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_tgst',
      defaults={if_true={vi=true}}
    },
    {
      full_name='termbidi', abbreviation='tbidi',
      short_desc=N_("terminal takes care of bi-directionality"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_tbidi',
      defaults={if_true={vi=false}}
    },
    {
      full_name='termencoding', abbreviation='tenc',
      short_desc=N_("Terminal encodig"),
      type='string', scope={'global'},
      vi_def=true,
      defaults={if_true={vi=""}}
    },
    {
      full_name='termguicolors', abbreviation='tgc',
      short_desc=N_("Terminal true color support"),
      type='bool', scope={'global'},
      vi_def=false,
      redraw={'ui_option'},
      varname='p_tgc',
      defaults={if_true={vi=false}}
    },
    {
      full_name='termpastefilter', abbreviation='tpf',
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vim=true,
      varname='p_tpf',
      defaults={if_true={vi="", vim="BS,HT,ESC,DEL"}}
    },
    {
      full_name='terse',
      short_desc=N_("hides notification of search wrap"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_terse',
      defaults={if_true={vi=false}}
    },
    {
      full_name='textwidth', abbreviation='tw',
      short_desc=N_("maximum width of text that is being inserted"),
      type='number', scope={'buffer'},
      vi_def=true,
      vim=true,
      redraw={'current_buffer'},
      varname='p_tw',
      defaults={if_true={vi=0}}
    },
    {
      full_name='thesaurus', abbreviation='tsr',
      short_desc=N_("list of thesaurus files for keyword completion"),
      type='string', list='onecomma', scope={'global', 'buffer'},
      deny_duplicates=true,
      normal_dname_chars=true,
      vi_def=true,
      expand=true,
      varname='p_tsr',
      defaults={if_true={vi=""}}
    },
    {
      full_name='tildeop', abbreviation='top',
      short_desc=N_("tilde command \"~\" behaves like an operator"),
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_to',
      defaults={if_true={vi=false}}
    },
    {
      full_name='timeout', abbreviation='to',
      short_desc=N_("time out on mappings and key codes"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_timeout',
      defaults={if_true={vi=true}}
    },
    {
      full_name='timeoutlen', abbreviation='tm',
      short_desc=N_("time out time in milliseconds"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_tm',
      defaults={if_true={vi=1000}}
    },
    {
      full_name='title',
      short_desc=N_("Vim set the title of the window"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_title',
      defaults={if_true={vi=false}}
    },
    {
      full_name='titlelen',
      short_desc=N_("of 'columns' used for window title"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_titlelen',
      defaults={if_true={vi=85}}
    },
    {
      full_name='titleold',
      short_desc=N_("title, restored when exiting"),
      type='string', scope={'global'},
      secure=true,
      no_mkrc=true,
      vi_def=true,
      varname='p_titleold',
      defaults={if_true={vi=""}}
    },
    {
      full_name='titlestring',
      short_desc=N_("to use for the Vim window title"),
      type='string', scope={'global'},
      vi_def=true,
      modelineexpr=true,
      varname='p_titlestring',
      defaults={if_true={vi=""}}
    },
    {
      full_name='ttimeout',
      short_desc=N_("out on mappings"),
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      redraw={'ui_option'},
      varname='p_ttimeout',
      defaults={if_true={vi=true}}
    },
    {
      full_name='ttimeoutlen', abbreviation='ttm',
      short_desc=N_("time out time for key codes in milliseconds"),
      type='number', scope={'global'},
      vi_def=true,
      redraw={'ui_option'},
      varname='p_ttm',
      defaults={if_true={vi=50}}
    },
    {
      full_name='ttyfast', abbreviation='tf',
	  short_desc=N_("No description"),
      type='bool', scope={'global'},
      no_mkrc=true,
      vi_def=true,
      varname='p_force_on',
      defaults={if_true={vi=true}}
    },
    {
      full_name='undodir', abbreviation='udir',
      short_desc=N_("where to store undo files"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      secure=true,
      vi_def=true,
      expand='nodefault',
      varname='p_udir',
      defaults={if_true={vi=''}}
    },
    {
      full_name='undofile', abbreviation='udf',
      short_desc=N_("save undo information in a file"),
      type='bool', scope={'buffer'},
      vi_def=true,
      vim=true,
      varname='p_udf',
      defaults={if_true={vi=false}}
    },
    {
      full_name='undolevels', abbreviation='ul',
      short_desc=N_("maximum number of changes that can be undone"),
      type='number', scope={'global', 'buffer'},
      vi_def=true,
      varname='p_ul',
      defaults={if_true={vi=1000}}
    },
    {
      full_name='undoreload', abbreviation='ur',
      short_desc=N_("max nr of lines to save for undo on a buffer reload"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_ur',
      defaults={if_true={vi=10000}}
    },
    {
      full_name='updatecount', abbreviation='uc',
      short_desc=N_("after this many characters flush swap file"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_uc',
      defaults={if_true={vi=200}}
    },
    {
      full_name='updatetime', abbreviation='ut',
      short_desc=N_("after this many milliseconds flush swap file"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_ut',
      defaults={if_true={vi=4000}}
    },
    {
      full_name='verbose', abbreviation='vbs',
      short_desc=N_("give informative messages"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_verbose',
      defaults={if_true={vi=0}}
    },
    {
      full_name='verbosefile', abbreviation='vfile',
      short_desc=N_("file to write messages in"),
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      expand=true,
      varname='p_vfile',
      defaults={if_true={vi=""}}
    },
    {
      full_name='viewdir', abbreviation='vdir',
      short_desc=N_("directory where to store files with :mkview"),
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      expand='nodefault',
      varname='p_vdir',
      defaults={if_true={vi=''}}
    },
    {
      full_name='viewoptions', abbreviation='vop',
      short_desc=N_("specifies what to save for :mkview"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_vop',
      defaults={if_true={vi="folds,options,cursor,curdir"}}
    },
    {
      -- Alias for "shada".
      full_name='viminfo', abbreviation='vi',
      short_desc=N_("Alias for shada"),
      type='string', scope={'global'}, nodefault=true,
    },
    {
      -- Alias for "shadafile".
      full_name='viminfofile', abbreviation='vif',
      short_desc=N_("Alias for shadafile instead"),
      type='string', scope={'global'}, nodefault=true,
    },
    {
      full_name='virtualedit', abbreviation='ve',
      short_desc=N_("when to use virtual editing"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      vim=true,
      redraw={'curswant'},
      varname='p_ve',
      defaults={if_true={vi="", vim=""}}
    },
    {
      full_name='visualbell', abbreviation='vb',
      short_desc=N_("use visual bell instead of beeping"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_vb',
      defaults={if_true={vi=false}}
    },
    {
      full_name='warn',
      short_desc=N_("for shell command when buffer was changed"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_warn',
      defaults={if_true={vi=true}}
    },
    {
      full_name='whichwrap', abbreviation='ww',
      short_desc=N_("allow specified keys to cross line boundaries"),
      type='string', list='flagscomma', scope={'global'},
      vim=true,
      varname='p_ww',
      defaults={if_true={vi="", vim="b,s"}}
    },
    {
      full_name='wildchar', abbreviation='wc',
      short_desc=N_("command-line character for wildcard expansion"),
      type='number', scope={'global'},
      vim=true,
      varname='p_wc',
      defaults={if_true={vi=imacros('Ctrl_E'), vim=imacros('TAB')}}
    },
    {
      full_name='wildcharm', abbreviation='wcm',
      short_desc=N_("like 'wildchar' but also works when mapped"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_wcm',
      defaults={if_true={vi=0}}
    },
    {
      full_name='wildignore', abbreviation='wig',
      short_desc=N_("files matching these patterns are not completed"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_wig',
      defaults={if_true={vi=""}}
    },
    {
      full_name='wildignorecase', abbreviation='wic',
      short_desc=N_("ignore case when completing file names"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_wic',
      defaults={if_true={vi=false}}
    },
    {
      full_name='wildmenu', abbreviation='wmnu',
      short_desc=N_("use menu for command line completion"),
      type='bool', scope={'global'},
      vim=true,
      varname='p_wmnu',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='wildmode', abbreviation='wim',
      short_desc=N_("mode for 'wildchar' command-line expansion"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vim=true,
      varname='p_wim',
      defaults={if_true={vi="", vim="full"}}
    },
    {
      full_name='wildoptions', abbreviation='wop',
      short_desc=N_("specifies how command line completion is done"),
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vim=true,
      varname='p_wop',
      defaults={if_true={vi='', vim='pum,tagfile'}}
    },
    {
      full_name='winaltkeys', abbreviation='wak',
      short_desc=N_("when the windows system handles ALT keys"),
      type='string', scope={'global'},
      vi_def=true,
      varname='p_wak',
      defaults={if_true={vi="menu"}}
    },
    {
      full_name='winblend', abbreviation='winbl',
      short_desc=N_("Controls transparency level for floating windows"),
      type='number', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=0}}
    },
    {
      full_name='winhighlight', abbreviation='winhl',
      short_desc=N_("Setup window-local highlights");
      type='string', scope={'window'},
      vi_def=true,
      alloced=true,
      redraw={'current_window'},
      defaults={if_true={vi=""}}
    },
    {
      full_name='window', abbreviation='wi',
      short_desc=N_("nr of lines to scroll for CTRL-F and CTRL-B"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_window',
      defaults={if_true={vi=0}}
    },
    {
      full_name='winheight', abbreviation='wh',
      short_desc=N_("minimum number of lines for the current window"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_wh',
      defaults={if_true={vi=1}}
    },
    {
      full_name='winfixheight', abbreviation='wfh',
      short_desc=N_("keep window height when opening/closing windows"),
      type='bool', scope={'window'},
      vi_def=true,
      redraw={'statuslines'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='winfixwidth', abbreviation='wfw',
      short_desc=N_("keep window width when opening/closing windows"),
      type='bool', scope={'window'},
      vi_def=true,
      redraw={'statuslines'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='winminheight', abbreviation='wmh',
      short_desc=N_("minimum number of lines for any window"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_wmh',
      defaults={if_true={vi=1}}
    },
    {
      full_name='winminwidth', abbreviation='wmw',
      short_desc=N_("minimal number of columns for any window"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_wmw',
      defaults={if_true={vi=1}}
    },
    {
      full_name='winwidth', abbreviation='wiw',
      short_desc=N_("minimal number of columns for current window"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_wiw',
      defaults={if_true={vi=20}}
    },
    {
      full_name='wrap',
      short_desc=N_("lines wrap and continue on the next line"),
      type='bool', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=true}}
    },
    {
      full_name='wrapmargin', abbreviation='wm',
      short_desc=N_("chars from the right where wrapping starts"),
      type='number', scope={'buffer'},
      vi_def=true,
      varname='p_wm',
      defaults={if_true={vi=0}}
    },
    {
      full_name='wrapscan', abbreviation='ws',
      short_desc=N_("searches wrap around the end of the file"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_ws',
      defaults={if_true={vi=true}}
    },
    {
      full_name='write',
      short_desc=N_("to a file is allowed"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_write',
      defaults={if_true={vi=true}}
    },
    {
      full_name='writeany', abbreviation='wa',
      short_desc=N_("write to file with no need for \"!\" override"),
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_wa',
      defaults={if_true={vi=false}}
    },
    {
      full_name='writebackup', abbreviation='wb',
      short_desc=N_("make a backup before overwriting a file"),
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_wb',
      defaults={if_true={vi=true}}
    },
    {
      full_name='writedelay', abbreviation='wd',
      short_desc=N_("delay this many msec for each char (for debug)"),
      type='number', scope={'global'},
      vi_def=true,
      varname='p_wd',
      defaults={if_true={vi=0}}
    },
  }
}
