-- {
--  {
--    full_name='aleph', abbreviation='al',
--    varname='p_aleph', pv_name=nil,
--    type='number', list=nil, scope={'global'},
--    deny_duplicates=nil,
--    enable_if=nil,
--    defaults={condition=nil, if_true={vi=224, vim=0}, if_false=nil},
--    secure=nil, gettext=nil, noglob=nil, normal_fname_chars=nil,
--    pri_mkrc=nil, deny_in_modelines=nil, normal_dname_chars=nil,
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
local N_=function(s)
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
      type='number', scope={'global'},
      vi_def=true,
      redraw={'curswant'},
      varname='p_aleph',
      defaults={if_true={vi=224}}
    },
    {
      full_name='arabic', abbreviation='arab',
      type='bool', scope={'window'},
      vi_def=true,
      vim=true,
      redraw={'curswant'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='arabicshape', abbreviation='arshape',
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      redraw={'all_windows', 'ui_option'},

      varname='p_arshape',
      defaults={if_true={vi=true}}
    },
    {
      full_name='allowrevins', abbreviation='ari',
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_ari',
      defaults={if_true={vi=false}}
    },
    {
      full_name='ambiwidth', abbreviation='ambw',
      type='string', scope={'global'},
      vi_def=true,
      redraw={'all_windows', 'ui_option'},
      varname='p_ambw',
      defaults={if_true={vi="single"}}
    },
    {
      full_name='autochdir', abbreviation='acd',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_acd',
      defaults={if_true={vi=false}}
    },
    {
      full_name='autoindent', abbreviation='ai',
      type='bool', scope={'buffer'},
      varname='p_ai',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='autoread', abbreviation='ar',
      type='bool', scope={'global', 'buffer'},
      varname='p_ar',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='autowrite', abbreviation='aw',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_aw',
      defaults={if_true={vi=false}}
    },
    {
      full_name='autowriteall', abbreviation='awa',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_awa',
      defaults={if_true={vi=false}}
    },
    {
      full_name='background', abbreviation='bg',
      type='string', scope={'global'},
      vim=true,
      redraw={'all_windows'},
      varname='p_bg',
      defaults={if_true={vi="light",vim="dark"}}
    },
    {
      full_name='backspace', abbreviation='bs',
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vim=true,
      varname='p_bs',
      defaults={if_true={vi="", vim="indent,eol,start"}}
    },
    {
      full_name='backup', abbreviation='bk',
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_bk',
      defaults={if_true={vi=false}}
    },
    {
      full_name='backupcopy', abbreviation='bkc',
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
      type='string', scope={'global'},
      normal_fname_chars=true,
      vi_def=true,
      varname='p_bex',
      defaults={if_true={vi="~"}}
    },
    {
      full_name='backupskip', abbreviation='bsk',
      type='string', list='onecomma', scope={'global'},
      vi_def=true,
      varname='p_bsk',
      defaults={if_true={vi=""}}
    },
    {
      full_name='belloff', abbreviation='bo',
      deny_duplicates=true,
      type='string', list='comma', scope={'global'},
      vi_def=true,
      varname='p_bo',
      defaults={if_true={vi="all"}}
    },
    {
      full_name='binary', abbreviation='bin',
      type='bool', scope={'buffer'},
      vi_def=true,
      redraw={'statuslines'},
      varname='p_bin',
      defaults={if_true={vi=false}}
    },
    {
      full_name='bomb',
      type='bool', scope={'buffer'},
      no_mkrc=true,
      vi_def=true,
      redraw={'statuslines'},
      varname='p_bomb',
      defaults={if_true={vi=false}}
    },
    {
      full_name='breakat', abbreviation='brk',
      type='string', list='flags', scope={'global'},
      vi_def=true,
      redraw={'all_windows'},
      varname='p_breakat',
      defaults={if_true={vi=" \t!@*-+;:,./?"}}
    },
    {
      full_name='breakindent', abbreviation='bri',
      type='bool', scope={'window'},
      vi_def=true,
      vim=true,
      redraw={'current_window'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='breakindentopt', abbreviation='briopt',
      type='string', list='onecomma', scope={'window'},
      deny_duplicates=true,
      vi_def=true,
      alloced=true,
      redraw={'current_buffer'},
      defaults={if_true={vi=""}},
    },
    {
      full_name='browsedir', abbreviation='bsdir',
      type='string', scope={'global'},
      vi_def=true,
      enable_if=false,
    },
    {
      full_name='bufhidden', abbreviation='bh',
      type='string', scope={'buffer'},
      noglob=true,
      vi_def=true,
      alloced=true,
      varname='p_bh',
      defaults={if_true={vi=""}}
    },
    {
      full_name='buflisted', abbreviation='bl',
      type='bool', scope={'buffer'},
      noglob=true,
      vi_def=true,
      varname='p_bl',
      defaults={if_true={vi=1}}
    },
    {
      full_name='buftype', abbreviation='bt',
      type='string', scope={'buffer'},
      noglob=true,
      vi_def=true,
      alloced=true,
      varname='p_bt',
      defaults={if_true={vi=""}}
    },
    {
      full_name='casemap', abbreviation='cmp',
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_cmp',
      defaults={if_true={vi="internal,keepascii"}}
    },
    {
      full_name='cdpath', abbreviation='cd',
      type='string', list='comma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      expand=true,
      varname='p_cdpath',
      defaults={if_true={vi=",,"}}
    },
    {
      full_name='cedit',
      type='string', scope={'global'},
      varname='p_cedit',
      defaults={if_true={vi="", vim=macros('CTRL_F_STR')}}
    },
    {
      full_name='channel',
      type='number', scope={'buffer'},
      no_mkrc=true,
      nodefault=true,
      varname='p_channel',
      defaults={if_true={vi=0}}
    },
    {
      full_name='charconvert', abbreviation='ccv',
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_ccv',
      defaults={if_true={vi=""}}
    },
    {
      full_name='cindent', abbreviation='cin',
      type='bool', scope={'buffer'},
      vi_def=true,
      vim=true,
      varname='p_cin',
      defaults={if_true={vi=false}}
    },
    {
      full_name='cinkeys', abbreviation='cink',
      type='string', list='onecomma', scope={'buffer'},
      deny_duplicates=true,
      vi_def=true,
      alloced=true,
      varname='p_cink',
      defaults={if_true={vi=indentkeys_default}}
    },
    {
      full_name='cinoptions', abbreviation='cino',
      type='string', list='onecomma', scope={'buffer'},
      deny_duplicates=true,
      vi_def=true,
      alloced=true,
      varname='p_cino',
      defaults={if_true={vi=""}}
    },
    {
      full_name='cinwords', abbreviation='cinw',
      type='string', list='onecomma', scope={'buffer'},
      deny_duplicates=true,
      vi_def=true,
      alloced=true,
      varname='p_cinw',
      defaults={if_true={vi="if,else,while,do,for,switch"}}
    },
    {
      full_name='clipboard', abbreviation='cb',
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_cb',
      defaults={if_true={vi=""}}
    },
    {
      full_name='cmdheight', abbreviation='ch',
      type='number', scope={'global'},
      vi_def=true,
      redraw={'all_windows'},
      varname='p_ch',
      defaults={if_true={vi=1}}
    },
    {
      full_name='cmdwinheight', abbreviation='cwh',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_cwh',
      defaults={if_true={vi=7}}
    },
    {
      full_name='colorcolumn', abbreviation='cc',
      type='string', list='onecomma', scope={'window'},
      deny_duplicates=true,
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=""}}
    },
    {
      full_name='columns', abbreviation='co',
      type='number', scope={'global'},
      no_mkrc=true,
      nodefault=true,
      vi_def=true,
      redraw={'everything'},
      varname='Columns',
      defaults={if_true={vi=macros('DFLT_COLS')}}
    },
    {
      full_name='comments', abbreviation='com',
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
      type='string', scope={'buffer'},
      vi_def=true,
      alloced=true,
      redraw={'curswant'},
      varname='p_cms',
      defaults={if_true={vi="/*%s*/"}}
    },
    {
      full_name='compatible', abbreviation='cp',
      type='bool', scope={'global'},
      redraw={'all_windows'},
      varname='p_force_off',
      -- pri_mkrc isn't needed here, optval_default()
      -- always returns TRUE for 'compatible'
      defaults={if_true={vi=true, vim=false}}
    },
    {
      full_name='complete', abbreviation='cpt',
      type='string', list='onecomma', scope={'buffer'},
      deny_duplicates=true,
      alloced=true,
      varname='p_cpt',
      defaults={if_true={vi=".,w,b,u,t,i", vim=".,w,b,u,t"}}
    },
    {
      full_name='concealcursor', abbreviation='cocu',
      type='string', scope={'window'},
      vi_def=true,
      alloced=true,
      redraw={'current_window'},
      defaults={if_true={vi=""}}
    },
    {
      full_name='conceallevel', abbreviation='cole',
      type='number', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=0}}
    },
    {
      full_name='completefunc', abbreviation='cfu',
      type='string', scope={'buffer'},
      secure=true,
      vi_def=true,
      alloced=true,
      varname='p_cfu',
      defaults={if_true={vi=""}}
    },
    {
      full_name='completeopt', abbreviation='cot',
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_cot',
      defaults={if_true={vi="menu,preview"}}
    },
    {
      full_name='confirm', abbreviation='cf',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_confirm',
      defaults={if_true={vi=false}}
    },
    {
      full_name='copyindent', abbreviation='ci',
      type='bool', scope={'buffer'},
      vi_def=true,
      vim=true,
      varname='p_ci',
      defaults={if_true={vi=false}}
    },
    {
      full_name='cpoptions', abbreviation='cpo',
      type='string', list='flags', scope={'global'},
      vim=true,
      redraw={'all_windows'},
      varname='p_cpo',
      defaults={if_true={vi=macros('CPO_VI'), vim=macros('CPO_VIM')}}
    },
    {
      full_name='cscopepathcomp', abbreviation='cspc',
      type='number', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_cspc',
      defaults={if_true={vi=0}}
    },
    {
      full_name='cscopeprg', abbreviation='csprg',
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      expand=true,
      varname='p_csprg',
      defaults={if_true={vi="cscope"}}
    },
    {
      full_name='cscopequickfix', abbreviation='csqf',
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_csqf',
      defaults={if_true={vi=""}}
    },
    {
      full_name='cscoperelative', abbreviation='csre',
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_csre',
      defaults={if_true={vi=0}}
    },
    {
      full_name='cscopetag', abbreviation='cst',
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_cst',
      defaults={if_true={vi=0}}
    },
    {
      full_name='cscopetagorder', abbreviation='csto',
      type='number', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_csto',
      defaults={if_true={vi=0}}
    },
    {
      full_name='cscopeverbose', abbreviation='csverb',
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_csverbose',
      defaults={if_true={vi=1}}
    },
    {
      full_name='cursorbind', abbreviation='crb',
      type='bool', scope={'window'},
      vi_def=true,
      pv_name='p_crbind',
      defaults={if_true={vi=false}}
    },
    {
      full_name='cursorcolumn', abbreviation='cuc',
      type='bool', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='cursorline', abbreviation='cul',
      type='bool', scope={'window'},
      vi_def=true,
      redraw={'current_window_only'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='debug',
      type='string', scope={'global'},
      vi_def=true,
      varname='p_debug',
      defaults={if_true={vi=""}}
    },
    {
      full_name='define', abbreviation='def',
      type='string', scope={'global', 'buffer'},
      vi_def=true,
      alloced=true,
      redraw={'curswant'},
      varname='p_def',
      defaults={if_true={vi="^\\s*#\\s*define"}}
    },
    {
      full_name='delcombine', abbreviation='deco',
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_deco',
      defaults={if_true={vi=false}}
    },
    {
      full_name='dictionary', abbreviation='dict',
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
      type='bool', scope={'window'},
      noglob=true,
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='diffexpr', abbreviation='dex',
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      redraw={'curswant'},
      varname='p_dex',
      defaults={if_true={vi=""}}
    },
    {
      full_name='diffopt', abbreviation='dip',
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      alloced=true,
      redraw={'current_window'},
      varname='p_dip',
      defaults={if_true={vi="internal,filler"}}
    },
    {
      full_name='digraph', abbreviation='dg',
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_dg',
      defaults={if_true={vi=false}}
    },
    {
      full_name='directory', abbreviation='dir',
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
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vim=true,
      redraw={'all_windows'},
      varname='p_dy',
      defaults={if_true={vi="", vim="lastline,msgsep"}}
    },
    {
      full_name='eadirection', abbreviation='ead',
      type='string', scope={'global'},
      vi_def=true,
      varname='p_ead',
      defaults={if_true={vi="both"}}
    },
    {
      full_name='edcompatible', abbreviation='ed',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_force_off',
      defaults={if_true={vi=false}}
    },
    {
      full_name='emoji', abbreviation='emo',
      type='bool', scope={'global'},
      vi_def=true,
      redraw={'all_windows', 'ui_option'},
      varname='p_emoji',
      defaults={if_true={vi=true}}
    },
    {
      full_name='encoding', abbreviation='enc',
      type='string', scope={'global'},
      deny_in_modelines=true,
      vi_def=true,
      varname='p_enc',
      defaults={if_true={vi=macros('ENC_DFLT')}}
    },
    {
      full_name='endofline', abbreviation='eol',
      type='bool', scope={'buffer'},
      no_mkrc=true,
      vi_def=true,
      redraw={'statuslines'},
      varname='p_eol',
      defaults={if_true={vi=true}}
    },
    {
      full_name='equalalways', abbreviation='ea',
      type='bool', scope={'global'},
      vi_def=true,
      redraw={'all_windows'},
      varname='p_ea',
      defaults={if_true={vi=true}}
    },
    {
      full_name='equalprg', abbreviation='ep',
      type='string', scope={'global', 'buffer'},
      secure=true,
      vi_def=true,
      expand=true,
      varname='p_ep',
      defaults={if_true={vi=""}}
    },
    {
      full_name='errorbells', abbreviation='eb',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_eb',
      defaults={if_true={vi=false}}
    },
    {
      full_name='errorfile', abbreviation='ef',
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      expand=true,
      varname='p_ef',
      defaults={if_true={vi=macros('DFLT_ERRORFILE')}}
    },
    {
      full_name='errorformat', abbreviation='efm',
      type='string', list='onecomma', scope={'global', 'buffer'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_efm',
      defaults={if_true={vi=macros('DFLT_EFM')}}
    },
    {
      full_name='eventignore', abbreviation='ei',
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_ei',
      defaults={if_true={vi=""}}
    },
    {
      full_name='expandtab', abbreviation='et',
      type='bool', scope={'buffer'},
      vi_def=true,
      vim=true,
      varname='p_et',
      defaults={if_true={vi=false}}
    },
    {
      full_name='exrc', abbreviation='ex',
      type='bool', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_exrc',
      defaults={if_true={vi=false}}
    },
    {
      full_name='fileencoding', abbreviation='fenc',
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
      type='string', list='onecomma', scope={'global'},
      vi_def=true,
      varname='p_fencs',
      defaults={if_true={vi="ucs-bom,utf-8,default,latin1"}}
    },
    {
      full_name='fileformat', abbreviation='ff',
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
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vim=true,
      varname='p_ffs',
      defaults={if_true={vi=macros('DFLT_FFS_VI'), vim=macros('DFLT_FFS_VIM')}}
    },
    {
      full_name='fileignorecase', abbreviation='fic',
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
      type='string', scope={'buffer'},
      noglob=true,
      normal_fname_chars=true,
      vi_def=true,
      alloced=true,
      varname='p_ft',
      defaults={if_true={vi=""}}
    },
    {
      full_name='fillchars', abbreviation='fcs',
      type='string', list='onecomma', scope={'window'},
      deny_duplicates=true,
      vi_def=true,
      alloced=true,
      redraw={'current_window'},
      defaults={if_true={vi=''}}
    },
    {
      full_name='fixendofline', abbreviation='fixeol',
      type='bool', scope={'buffer'},
      vi_def=true,
      redraw={'statuslines'},
      varname='p_fixeol',
      defaults={if_true={vi=true}}
    },
    {
      full_name='foldclose', abbreviation='fcl',
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      redraw={'current_window'},
      varname='p_fcl',
      defaults={if_true={vi=""}}
    },
    {
      full_name='foldcolumn', abbreviation='fdc',
      type='number', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='foldenable', abbreviation='fen',
      type='bool', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=true}}
    },
    {
      full_name='foldexpr', abbreviation='fde',
      type='string', scope={'window'},
      vi_def=true,
      vim=true,
      alloced=true,
      redraw={'current_window'},
      defaults={if_true={vi="0"}}
    },
    {
      full_name='foldignore', abbreviation='fdi',
      type='string', scope={'window'},
      vi_def=true,
      vim=true,
      alloced=true,
      redraw={'current_window'},
      defaults={if_true={vi="#"}}
    },
    {
      full_name='foldlevel', abbreviation='fdl',
      type='number', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=0}}
    },
    {
      full_name='foldlevelstart', abbreviation='fdls',
      type='number', scope={'global'},
      vi_def=true,
      redraw={'curswant'},
      varname='p_fdls',
      defaults={if_true={vi=-1}}
    },
    {
      full_name='foldmarker', abbreviation='fmr',
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
      type='string', scope={'window'},
      vi_def=true,
      vim=true,
      alloced=true,
      redraw={'current_window'},
      defaults={if_true={vi="manual"}}
    },
    {
      full_name='foldminlines', abbreviation='fml',
      type='number', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=1}}
    },
    {
      full_name='foldnestmax', abbreviation='fdn',
      type='number', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=20}}
    },
    {
      full_name='foldopen', abbreviation='fdo',
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      redraw={'curswant'},
      varname='p_fdo',
      defaults={if_true={vi="block,hor,mark,percent,quickfix,search,tag,undo"}}
    },
    {
      full_name='foldtext', abbreviation='fdt',
      type='string', scope={'window'},
      vi_def=true,
      vim=true,
      alloced=true,
      redraw={'current_window'},
      defaults={if_true={vi="foldtext()"}}
    },
    {
      full_name='formatexpr', abbreviation='fex',
      type='string', scope={'buffer'},
      vi_def=true,
      vim=true,
      alloced=true,
      varname='p_fex',
      defaults={if_true={vi=""}}
    },
    {
      full_name='formatoptions', abbreviation='fo',
      type='string', list='flags', scope={'buffer'},
      vim=true,
      alloced=true,
      varname='p_fo',
      defaults={if_true={vi=macros('DFLT_FO_VI'), vim=macros('DFLT_FO_VIM')}}
    },
    {
      full_name='formatlistpat', abbreviation='flp',
      type='string', scope={'buffer'},
      vi_def=true,
      alloced=true,
      varname='p_flp',
      defaults={if_true={vi="^\\s*\\d\\+[\\]:.)}\\t ]\\s*"}}
    },
    {
      full_name='formatprg', abbreviation='fp',
      type='string', scope={'global', 'buffer'},
      secure=true,
      vi_def=true,
      expand=true,
      varname='p_fp',
      defaults={if_true={vi=""}}
    },
    {
      full_name='fsync', abbreviation='fs',
      type='bool', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_fs',
      defaults={if_true={vi=false}}
    },
    {
      full_name='gdefault', abbreviation='gd',
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_gd',
      defaults={if_true={vi=false}}
    },
    {
      full_name='grepformat', abbreviation='gfm',
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_gefm',
      defaults={if_true={vi=macros('DFLT_GREPFORMAT')}}
    },
    {
      full_name='grepprg', abbreviation='gp',
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
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_guicursor',
      defaults={if_true={vi="n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20"}}
    },
    {
      full_name='guifont', abbreviation='gfn',
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_guifont',
      redraw={'ui_option'},
      defaults={if_true={vi=""}}
    },
    {
      full_name='guifontset', abbreviation='gfs',
      type='string', list='onecomma', scope={'global'},
      vi_def=true,
      varname='p_guifontset',
      redraw={'ui_option'},
      defaults={if_true={vi=""}}
    },
    {
      full_name='guifontwide', abbreviation='gfw',
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      redraw={'ui_option'},
      varname='p_guifontwide',
      defaults={if_true={vi=""}}
    },
    {
      full_name='guioptions', abbreviation='go',
      type='string', list='flags', scope={'global'},
      vi_def=true,
      redraw={'all_windows'},
      enable_if=false,
    },
    {
      full_name='guitablabel', abbreviation='gtl',
      type='string', scope={'global'},
      vi_def=true,
      redraw={'current_window'},
      enable_if=false,
    },
    {
      full_name='guitabtooltip', abbreviation='gtt',
      type='string', scope={'global'},
      vi_def=true,
      redraw={'current_window'},
      enable_if=false,
    },
    {
      full_name='helpfile', abbreviation='hf',
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      expand=true,
      varname='p_hf',
      defaults={if_true={vi=macros('DFLT_HELPFILE')}}
    },
    {
      full_name='helpheight', abbreviation='hh',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_hh',
      defaults={if_true={vi=20}}
    },
    {
      full_name='helplang', abbreviation='hlg',
      type='string', list='onecomma', scope={'global'},
      vi_def=true,
      varname='p_hlg',
      defaults={if_true={vi=""}}
    },
    {
      full_name='hidden', abbreviation='hid',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_hid',
      defaults={if_true={vi=false}}
    },
    {
      full_name='highlight', abbreviation='hl',
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_hl',
      defaults={if_true={vi=macros('HIGHLIGHT_INIT')}}
    },
    {
      full_name='history', abbreviation='hi',
      type='number', scope={'global'},
      vim=true,
      varname='p_hi',
      defaults={if_true={vi=0, vim=10000}}
    },
    {
      full_name='hkmap', abbreviation='hk',
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_hkmap',
      defaults={if_true={vi=false}}
    },
    {
      full_name='hkmapp', abbreviation='hkp',
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_hkmapp',
      defaults={if_true={vi=false}}
    },
    {
      full_name='hlsearch', abbreviation='hls',
      type='bool', scope={'global'},
      vim=true,
      redraw={'all_windows'},
      varname='p_hls',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='icon',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_icon',
      defaults={if_true={vi=false}}
    },
    {
      full_name='iconstring',
      type='string', scope={'global'},
      vi_def=true,
      varname='p_iconstring',
      defaults={if_true={vi=""}}
    },
    {
      full_name='ignorecase', abbreviation='ic',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_ic',
      defaults={if_true={vi=false}}
    },
    {
      full_name='imcmdline', abbreviation='imc',
      type='bool', scope={'global'},
      vi_def=true,
      enable_if=false,
      defaults={if_true={vi=false}}
    },
    {
      full_name='imdisable', abbreviation='imd',
      type='bool', scope={'global'},
      vi_def=true,
      enable_if=false,
      defaults={if_true={vi=false}}
    },
    {
      full_name='iminsert', abbreviation='imi',
      type='number', scope={'buffer'},
      vi_def=true,
      varname='p_iminsert', pv_name='p_imi',
      defaults={
        if_true={vi=macros('B_IMODE_NONE')},
      }
    },
    {
      full_name='imsearch', abbreviation='ims',
      type='number', scope={'buffer'},
      vi_def=true,
      varname='p_imsearch', pv_name='p_ims',
      defaults={
        if_true={vi=macros('B_IMODE_USE_INSERT')},
      }
    },
    {
      full_name='inccommand', abbreviation='icm',
      type='string', scope={'global'},
      vi_def=true,
      redraw={'all_windows'},
      varname='p_icm',
      defaults={if_true={vi=""}}
    },
    {
      full_name='include', abbreviation='inc',
      type='string', scope={'global', 'buffer'},
      vi_def=true,
      alloced=true,
      varname='p_inc',
      defaults={if_true={vi="^\\s*#\\s*include"}}
    },
    {
      full_name='includeexpr', abbreviation='inex',
      type='string', scope={'buffer'},
      vi_def=true,
      alloced=true,
      varname='p_inex',
      defaults={if_true={vi=""}}
    },
    {
      full_name='incsearch', abbreviation='is',
      type='bool', scope={'global'},
      vim=true,
      varname='p_is',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='indentexpr', abbreviation='inde',
      type='string', scope={'buffer'},
      vi_def=true,
      vim=true,
      alloced=true,
      varname='p_inde',
      defaults={if_true={vi=""}}
    },
    {
      full_name='indentkeys', abbreviation='indk',
      type='string', list='onecomma', scope={'buffer'},
      deny_duplicates=true,
      vi_def=true,
      alloced=true,
      varname='p_indk',
      defaults={if_true={vi=indentkeys_default}}
    },
    {
      full_name='infercase', abbreviation='inf',
      type='bool', scope={'buffer'},
      vi_def=true,
      varname='p_inf',
      defaults={if_true={vi=false}}
    },
    {
      full_name='insertmode', abbreviation='im',
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_im',
      defaults={if_true={vi=false}}
    },
    {
      full_name='isfname', abbreviation='isf',
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
      type='string', list='comma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_isi',
      defaults={if_true={vi="@,48-57,_,192-255"}}
    },
    {
      full_name='iskeyword', abbreviation='isk',
      type='string', list='comma', scope={'buffer'},
      deny_duplicates=true,
      vim=true,
      alloced=true,
      varname='p_isk',
      defaults={if_true={vi="@,48-57,_", vim="@,48-57,_,192-255"}}
    },
    {
      full_name='isprint', abbreviation='isp',
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
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_js',
      defaults={if_true={vi=true}}
    },
    {
      full_name='keymap', abbreviation='kmp',
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
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_km',
      defaults={if_true={vi=""}}
    },
    {
      full_name='keywordprg', abbreviation='kp',
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
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      secure=true,
      vi_def=true,
      varname='p_langmap',
      defaults={if_true={vi=""}}
    },
    {
      full_name='langmenu', abbreviation='lm',
      type='string', scope={'global'},
      normal_fname_chars=true,
      vi_def=true,
      varname='p_lm',
      defaults={if_true={vi=""}}
    },
    {
      full_name='langnoremap', abbreviation='lnr',
      type='bool', scope={'global'},
      varname='p_lnr',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='langremap', abbreviation='lrm',
      type='bool', scope={'global'},
      varname='p_lrm',
      defaults={if_true={vi=true, vim=false}}
    },
    {
      full_name='laststatus', abbreviation='ls',
      type='number', scope={'global'},
      vim=true,
      redraw={'all_windows'},
      varname='p_ls',
      defaults={if_true={vi=1,vim=2}}
    },
    {
      full_name='lazyredraw', abbreviation='lz',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_lz',
      defaults={if_true={vi=false}}
    },
    {
      full_name='linebreak', abbreviation='lbr',
      type='bool', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='lines',
      type='number', scope={'global'},
      no_mkrc=true,
      nodefault=true,
      vi_def=true,
      redraw={'everything'},
      varname='Rows',
      defaults={if_true={vi=macros('DFLT_ROWS')}}
    },
    {
      full_name='linespace', abbreviation='lsp',
      type='number', scope={'global'},
      vi_def=true,
      redraw={'ui_option'},
      varname='p_linespace',
      defaults={if_true={vi=0}}
    },
    {
      full_name='lisp',
      type='bool', scope={'buffer'},
      vi_def=true,
      varname='p_lisp',
      defaults={if_true={vi=false}}
    },
    {
      full_name='lispwords', abbreviation='lw',
      type='string', list='onecomma', scope={'global', 'buffer'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_lispwords', pv_name='p_lw',
      defaults={if_true={vi=macros('LISPWORD_VALUE')}}
    },
    {
      full_name='list',
      type='bool', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='listchars', abbreviation='lcs',
      type='string', list='onecomma', scope={'window'},
      deny_duplicates=true,
      vim=true,
      alloced=true,
      redraw={'current_window'},
      defaults={if_true={vi="eol:$", vim="tab:> ,trail:-,nbsp:+"}}
    },
    {
      full_name='loadplugins', abbreviation='lpl',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_lpl',
      defaults={if_true={vi=true}}
    },
    {
      full_name='magic',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_magic',
      defaults={if_true={vi=true}}
    },
    {
      full_name='makeef', abbreviation='mef',
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      expand=true,
      varname='p_mef',
      defaults={if_true={vi=""}}
    },
    {
      full_name='makeencoding', abbreviation='menc',
      type='string', scope={'global', 'buffer'},
      vi_def=true,
      varname='p_menc',
      defaults={if_true={vi=""}}
    },
    {
      full_name='makeprg', abbreviation='mp',
      type='string', scope={'global', 'buffer'},
      secure=true,
      vi_def=true,
      expand=true,
      varname='p_mp',
      defaults={if_true={vi="make"}}
    },
    {
      full_name='matchpairs', abbreviation='mps',
      type='string', list='onecomma', scope={'buffer'},
      deny_duplicates=true,
      vi_def=true,
      alloced=true,
      varname='p_mps',
      defaults={if_true={vi="(:),{:},[:]"}}
    },
    {
      full_name='matchtime', abbreviation='mat',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_mat',
      defaults={if_true={vi=5}}
    },
    {
      full_name='maxcombine', abbreviation='mco',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_mco',
      defaults={if_true={vi=6}}
    },
    {
      full_name='maxfuncdepth', abbreviation='mfd',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_mfd',
      defaults={if_true={vi=100}}
    },
    {
      full_name='maxmapdepth', abbreviation='mmd',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_mmd',
      defaults={if_true={vi=1000}}
    },
    {
      full_name='maxmempattern', abbreviation='mmp',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_mmp',
      defaults={if_true={vi=1000}}
    },
    {
      full_name='menuitems', abbreviation='mis',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_mis',
      defaults={if_true={vi=25}}
    },
    {
      full_name='mkspellmem', abbreviation='msm',
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      expand=true,
      varname='p_msm',
      defaults={if_true={vi="460000,2000,500"}}
    },
    {
      full_name='modeline', abbreviation='ml',
      type='bool', scope={'buffer'},
      vim=true,
      varname='p_ml',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='modelines', abbreviation='mls',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_mls',
      defaults={if_true={vi=5}}
    },
    {
      full_name='modifiable', abbreviation='ma',
      type='bool', scope={'buffer'},
      noglob=true,
      vi_def=true,
      varname='p_ma',
      defaults={if_true={vi=true}}
    },
    {
      full_name='modified', abbreviation='mod',
      type='bool', scope={'buffer'},
      no_mkrc=true,
      vi_def=true,
      redraw={'statuslines'},
      varname='p_mod',
      defaults={if_true={vi=false}}
    },
    {
      full_name='more',
      type='bool', scope={'global'},
      vim=true,
      varname='p_more',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='mouse',
      type='string', list='flags', scope={'global'},
      varname='p_mouse',
      defaults={if_true={vi="", vim=""}}
    },
    {
      full_name='mousefocus', abbreviation='mousef',
      type='bool', scope={'global'},
      vi_def=true,
      enable_if=false,
      defaults={if_true={vi=false}}
    },
    {
      full_name='mousehide', abbreviation='mh',
      type='bool', scope={'global'},
      vi_def=true,
      enable_if=false,
      defaults={if_true={vi=true}}
    },
    {
      full_name='mousemodel', abbreviation='mousem',
      type='string', scope={'global'},
      vi_def=true,
      varname='p_mousem',
      defaults={if_true={vi="extend"}}
    },
    {
      full_name='mouseshape', abbreviation='mouses',
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      enable_if=false,
    },
    {
      full_name='mousetime', abbreviation='mouset',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_mouset',
      defaults={if_true={vi=500}}
    },
    {
      full_name='nrformats', abbreviation='nf',
      type='string', list='onecomma', scope={'buffer'},
      deny_duplicates=true,
      alloced=true,
      varname='p_nf',
      defaults={if_true={vi="bin,octal,hex", vim="bin,hex"}}
    },
    {
      full_name='number', abbreviation='nu',
      type='bool', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='numberwidth', abbreviation='nuw',
      type='number', scope={'window'},
      vim=true,
      redraw={'current_window'},
      defaults={if_true={vi=8, vim=4}}
    },
    {
      full_name='omnifunc', abbreviation='ofu',
      type='string', scope={'buffer'},
      secure=true,
      vi_def=true,
      alloced=true,
      varname='p_ofu',
      defaults={if_true={vi=""}}
    },
    {
      full_name='opendevice', abbreviation='odev',
      type='bool', scope={'global'},
      vi_def=true,
      enable_if=false,
      defaults={if_true={vi=false, vim=false}}
    },
    {
      full_name='operatorfunc', abbreviation='opfunc',
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_opfunc',
      defaults={if_true={vi=""}}
    },
    {
      full_name='packpath', abbreviation='pp',
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
      type='string', scope={'global'},
      vi_def=true,
      varname='p_para',
      defaults={if_true={vi="IPLPPPQPP TPHPLIPpLpItpplpipbp"}}
    },
    {
      full_name='paste',
      type='bool', scope={'global'},
      pri_mkrc=true,
      vi_def=true,
      varname='p_paste',
      defaults={if_true={vi=false}}
    },
    {
      full_name='pastetoggle', abbreviation='pt',
      type='string', scope={'global'},
      vi_def=true,
      varname='p_pt',
      defaults={if_true={vi=""}}
    },
    {
      full_name='patchexpr', abbreviation='pex',
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_pex',
      defaults={if_true={vi=""}}
    },
    {
      full_name='patchmode', abbreviation='pm',
      type='string', scope={'global'},
      normal_fname_chars=true,
      vi_def=true,
      varname='p_pm',
      defaults={if_true={vi=""}}
    },
    {
      full_name='path', abbreviation='pa',
      type='string', list='comma', scope={'global', 'buffer'},
      deny_duplicates=true,
      vi_def=true,
      expand=true,
      varname='p_path',
      defaults={if_true={vi=".,/usr/include,,"}}
    },
    {
      full_name='preserveindent', abbreviation='pi',
      type='bool', scope={'buffer'},
      vi_def=true,
      vim=true,
      varname='p_pi',
      defaults={if_true={vi=false}}
    },
    {
      full_name='previewheight', abbreviation='pvh',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_pvh',
      defaults={if_true={vi=12}}
    },
    {
      full_name='previewwindow', abbreviation='pvw',
      type='bool', scope={'window'},
      noglob=true,
      vi_def=true,
      redraw={'statuslines'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='printdevice', abbreviation='pdev',
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_pdev',
      defaults={if_true={vi=""}}
    },
    {
      full_name='printencoding', abbreviation='penc',
      type='string', scope={'global'},
      vi_def=true,
      varname='p_penc',
      defaults={if_true={vi=""}}
    },
    {
      full_name='printexpr', abbreviation='pexpr',
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_pexpr',
      defaults={if_true={vi=""}}
    },
    {
      full_name='printfont', abbreviation='pfn',
      type='string', scope={'global'},
      vi_def=true,
      varname='p_pfn',
      defaults={if_true={vi="courier"}}
    },
    {
      full_name='printheader', abbreviation='pheader',
      type='string', scope={'global'},
      vi_def=true,
      varname='p_header',
      defaults={if_true={vi="%<%f%h%m%=Page %N"}}
    },
    {
      full_name='printmbcharset', abbreviation='pmbcs',
      type='string', scope={'global'},
      vi_def=true,
      varname='p_pmcs',
      defaults={if_true={vi=""}}
    },
    {
      full_name='printmbfont', abbreviation='pmbfn',
      type='string', scope={'global'},
      vi_def=true,
      varname='p_pmfn',
      defaults={if_true={vi=""}}
    },
    {
      full_name='printoptions', abbreviation='popt',
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_popt',
      defaults={if_true={vi=""}}
    },
    {
      full_name='prompt',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_prompt',
      defaults={if_true={vi=true}}
    },
    {
      full_name='pumheight', abbreviation='ph',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_ph',
      defaults={if_true={vi=0}}
    },
    {
      full_name='pumblend', abbreviation='pb',
      type='number', scope={'global'},
      vi_def=true,
      redraw={'ui_option'},
      varname='p_pb',
      defaults={if_true={vi=0}}
    },
    {
      full_name='pyxversion', abbreviation='pyx',
      type='number', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_pyx',
      defaults={if_true={vi=0}}
    },
    {
      full_name='quoteescape', abbreviation='qe',
      type='string', scope={'buffer'},
      vi_def=true,
      alloced=true,
      varname='p_qe',
      defaults={if_true={vi="\\"}}
    },
    {
      full_name='readonly', abbreviation='ro',
      type='bool', scope={'buffer'},
      noglob=true,
      vi_def=true,
      redraw={'statuslines'},
      varname='p_ro',
      defaults={if_true={vi=false}}
    },
    {
      full_name='redrawtime', abbreviation='rdt',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_rdt',
      defaults={if_true={vi=2000}}
    },
    {
      full_name='regexpengine', abbreviation='re',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_re',
      defaults={if_true={vi=0}}
    },
    {
      full_name='relativenumber', abbreviation='rnu',
      type='bool', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='remap',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_remap',
      defaults={if_true={vi=true}}
    },
    {
      full_name='report',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_report',
      defaults={if_true={vi=2}}
    },
    {
      full_name='revins', abbreviation='ri',
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_ri',
      defaults={if_true={vi=false}}
    },
    {
      full_name='rightleft', abbreviation='rl',
      type='bool', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='rightleftcmd', abbreviation='rlc',
      type='string', scope={'window'},
      vi_def=true,
      alloced=true,
      redraw={'current_window'},
      defaults={if_true={vi="search"}}
    },
    {
      full_name='ruler', abbreviation='ru',
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      redraw={'statuslines'},
      varname='p_ru',
      defaults={if_true={vi=true}}
    },
    {
      full_name='rulerformat', abbreviation='ruf',
      type='string', scope={'global'},
      vi_def=true,
      alloced=true,
      redraw={'statuslines'},
      varname='p_ruf',
      defaults={if_true={vi=""}}
    },
    {
      full_name='runtimepath', abbreviation='rtp',
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
      type='number', scope={'window'},
      no_mkrc=true,
      vi_def=true,
      pv_name='p_scroll',
      defaults={if_true={vi=0}}
    },
    {
      full_name='scrollback', abbreviation='scbk',
      type='number', scope={'buffer'},
      vi_def=true,
      varname='p_scbk',
      redraw={'current_buffer'},
      defaults={if_true={vi=-1}}
    },
    {
      full_name='scrollbind', abbreviation='scb',
      type='bool', scope={'window'},
      vi_def=true,
      pv_name='p_scbind',
      defaults={if_true={vi=false}}
    },
    {
      full_name='scrolljump', abbreviation='sj',
      type='number', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_sj',
      defaults={if_true={vi=1}}
    },
    {
      full_name='scrolloff', abbreviation='so',
      type='number', scope={'global'},
      vi_def=true,
      vim=true,
      redraw={'all_windows'},
      varname='p_so',
      defaults={if_true={vi=0}}
    },
    {
      full_name='scrollopt', abbreviation='sbo',
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_sbo',
      defaults={if_true={vi="ver,jump"}}
    },
    {
      full_name='sections', abbreviation='sect',
      type='string', scope={'global'},
      vi_def=true,
      varname='p_sections',
      defaults={if_true={vi="SHNHH HUnhsh"}}
    },
    {
      full_name='secure',
      type='bool', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_secure',
      defaults={if_true={vi=false}}
    },
    {
      full_name='selection', abbreviation='sel',
      type='string', scope={'global'},
      vi_def=true,
      varname='p_sel',
      defaults={if_true={vi="inclusive"}}
    },
    {
      full_name='selectmode', abbreviation='slm',
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_slm',
      defaults={if_true={vi=""}}
    },
    {
      full_name='sessionoptions', abbreviation='ssop',
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
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      secure=true,
      varname='p_shada',
      defaults={if_true={vi="", vim="!,'100,<50,s10,h"}}
    },
    {
      full_name='shell', abbreviation='sh',
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
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_shq',
      defaults={if_true={vi=""}}
    },
    {
      full_name='shellredir', abbreviation='srr',
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
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_ssl',
      enable_if='BACKSLASH_IN_FILENAME',
      defaults={if_true={vi=false}}
    },
    {
      full_name='shelltemp', abbreviation='stmp',
      type='bool', scope={'global'},
      varname='p_stmp',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='shellxquote', abbreviation='sxq',
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
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      varname='p_sxe',
      defaults={if_true={vi=""}}
    },
    {
      full_name='shiftround', abbreviation='sr',
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_sr',
      defaults={if_true={vi=false}}
    },
    {
      full_name='shiftwidth', abbreviation='sw',
      type='number', scope={'buffer'},
      vi_def=true,
      varname='p_sw',
      defaults={if_true={vi=8}}
    },
    {
      full_name='shortmess', abbreviation='shm',
      type='string', list='flags', scope={'global'},
      vim=true,
      varname='p_shm',
      defaults={if_true={vi="", vim="filnxtToOF"}}
    },
    {
      full_name='showbreak', abbreviation='sbr',
      type='string', scope={'global'},
      vi_def=true,
      redraw={'all_windows'},
      varname='p_sbr',
      defaults={if_true={vi=""}}
    },
    {
      full_name='showcmd', abbreviation='sc',
      type='bool', scope={'global'},
      vim=true,
      varname='p_sc',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='showfulltag', abbreviation='sft',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_sft',
      defaults={if_true={vi=false}}
    },
    {
      full_name='showmatch', abbreviation='sm',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_sm',
      defaults={if_true={vi=false}}
    },
    {
      full_name='showmode', abbreviation='smd',
      type='bool', scope={'global'},
      vim=true,
      varname='p_smd',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='showtabline', abbreviation='stal',
      type='number', scope={'global'},
      vi_def=true,
      redraw={'all_windows', 'ui_option'},
      varname='p_stal',
      defaults={if_true={vi=1}}
    },
    {
      full_name='sidescroll', abbreviation='ss',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_ss',
      defaults={if_true={vi=1}}
    },
    {
      full_name='sidescrolloff', abbreviation='siso',
      type='number', scope={'global'},
      vi_def=true,
      vim=true,
      redraw={'current_buffer'},
      varname='p_siso',
      defaults={if_true={vi=0}}
    },
    {
      full_name='signcolumn', abbreviation='scl',
      type='string', scope={'window'},
      vi_def=true,
      alloced=true,
      redraw={'current_window'},
      defaults={if_true={vi="auto"}}
    },
    {
      full_name='smartcase', abbreviation='scs',
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_scs',
      defaults={if_true={vi=false}}
    },
    {
      full_name='smartindent', abbreviation='si',
      type='bool', scope={'buffer'},
      vi_def=true,
      vim=true,
      varname='p_si',
      defaults={if_true={vi=false}}
    },
    {
      full_name='smarttab', abbreviation='sta',
      type='bool', scope={'global'},
      vim=true,
      varname='p_sta',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='softtabstop', abbreviation='sts',
      type='number', scope={'buffer'},
      vi_def=true,
      vim=true,
      varname='p_sts',
      defaults={if_true={vi=0}}
    },
    {
      full_name='spell',
      type='bool', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='spellcapcheck', abbreviation='spc',
      type='string', scope={'buffer'},
      vi_def=true,
      alloced=true,
      redraw={'current_buffer'},
      varname='p_spc',
      defaults={if_true={vi="[.?!]\\_[\\])'\"	 ]\\+"}}
    },
    {
      full_name='spellfile', abbreviation='spf',
      type='string', list='onecomma', scope={'buffer'},
      secure=true,
      vi_def=true,
      alloced=true,
      expand=true,
      varname='p_spf',
      defaults={if_true={vi=""}}
    },
    {
      full_name='spelllang', abbreviation='spl',
      type='string', list='onecomma', scope={'buffer'},
      vi_def=true,
      alloced=true,
      expand=true,
      redraw={'current_buffer'},
      varname='p_spl',
      defaults={if_true={vi="en"}}
    },
    {
      full_name='spellsuggest', abbreviation='sps',
      type='string', list='onecomma', scope={'global'},
      secure=true,
      vi_def=true,
      expand=true,
      varname='p_sps',
      defaults={if_true={vi="best"}}
    },
    {
      full_name='splitbelow', abbreviation='sb',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_sb',
      defaults={if_true={vi=false}}
    },
    {
      full_name='splitright', abbreviation='spr',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_spr',
      defaults={if_true={vi=false}}
    },
    {
      full_name='startofline', abbreviation='sol',
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_sol',
      defaults={if_true={vi=true}}
    },
    {
      full_name='statusline', abbreviation='stl',
      type='string', scope={'global', 'window'},
      vi_def=true,
      alloced=true,
      redraw={'statuslines'},
      varname='p_stl',
      defaults={if_true={vi=""}}
    },
    {
      full_name='suffixes', abbreviation='su',
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_su',
      defaults={if_true={vi=".bak,~,.o,.h,.info,.swp,.obj"}}
    },
    {
      full_name='suffixesadd', abbreviation='sua',
      type='string', list='onecomma', scope={'buffer'},
      deny_duplicates=true,
      vi_def=true,
      alloced=true,
      varname='p_sua',
      defaults={if_true={vi=""}}
    },
    {
      full_name='swapfile', abbreviation='swf',
      type='bool', scope={'buffer'},
      vi_def=true,
      redraw={'statuslines'},
      varname='p_swf',
      defaults={if_true={vi=true}}
    },
    {
      full_name='switchbuf', abbreviation='swb',
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_swb',
      defaults={if_true={vi=""}}
    },
    {
      full_name='synmaxcol', abbreviation='smc',
      type='number', scope={'buffer'},
      vi_def=true,
      redraw={'current_buffer'},
      varname='p_smc',
      defaults={if_true={vi=3000}}
    },
    {
      full_name='syntax', abbreviation='syn',
      type='string', scope={'buffer'},
      noglob=true,
      normal_fname_chars=true,
      vi_def=true,
      alloced=true,
      varname='p_syn',
      defaults={if_true={vi=""}}
    },
    {
      full_name='tabline', abbreviation='tal',
      type='string', scope={'global'},
      vi_def=true,
      redraw={'all_windows'},
      varname='p_tal',
      defaults={if_true={vi=""}}
    },
    {
      full_name='tabpagemax', abbreviation='tpm',
      type='number', scope={'global'},
      vim=true,
      varname='p_tpm',
      defaults={if_true={vi=10, vim=50}}
    },
    {
      full_name='tabstop', abbreviation='ts',
      type='number', scope={'buffer'},
      vi_def=true,
      redraw={'current_buffer'},
      varname='p_ts',
      defaults={if_true={vi=8}}
    },
    {
      full_name='tagbsearch', abbreviation='tbs',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_tbs',
      defaults={if_true={vi=true}}
    },
    {
      full_name='tagcase', abbreviation='tc',
      type='string', scope={'global', 'buffer'},
      vim=true,
      varname='p_tc',
      defaults={if_true={vi="followic", vim="followic"}}
    },
    {
      full_name='taglength', abbreviation='tl',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_tl',
      defaults={if_true={vi=0}}
    },
    {
      full_name='tagrelative', abbreviation='tr',
      type='bool', scope={'global'},
      vim=true,
      varname='p_tr',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='tags', abbreviation='tag',
      type='string', list='onecomma', scope={'global', 'buffer'},
      deny_duplicates=true,
      vi_def=true,
      expand=true,
      varname='p_tags',
      defaults={if_true={vi="./tags;,tags"}}
    },
    {
      full_name='tagstack', abbreviation='tgst',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_tgst',
      defaults={if_true={vi=true}}
    },
    {
      full_name='termbidi', abbreviation='tbidi',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_tbidi',
      defaults={if_true={vi=false}}
    },
    {
      full_name='termencoding', abbreviation='tenc',
      type='string', scope={'global'},
      vi_def=true,
      defaults={if_true={vi=""}}
    },
    {
      full_name='termguicolors', abbreviation='tgc',
      type='bool', scope={'global'},
      vi_def=false,
      redraw={'ui_option'},
      varname='p_tgc',
      defaults={if_true={vi=false}}
    },
    {
      full_name='terse',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_terse',
      defaults={if_true={vi=false}}
    },
    {
      full_name='textwidth', abbreviation='tw',
      type='number', scope={'buffer'},
      vi_def=true,
      vim=true,
      redraw={'current_buffer'},
      varname='p_tw',
      defaults={if_true={vi=0}}
    },
    {
      full_name='thesaurus', abbreviation='tsr',
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
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_to',
      defaults={if_true={vi=false}}
    },
    {
      full_name='timeout', abbreviation='to',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_timeout',
      defaults={if_true={vi=true}}
    },
    {
      full_name='timeoutlen', abbreviation='tm',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_tm',
      defaults={if_true={vi=1000}}
    },
    {
      full_name='title',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_title',
      defaults={if_true={vi=false}}
    },
    {
      full_name='titlelen',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_titlelen',
      defaults={if_true={vi=85}}
    },
    {
      full_name='titleold',
      type='string', scope={'global'},
      secure=true,
      no_mkrc=true,
      vi_def=true,
      varname='p_titleold',
      defaults={if_true={vi=""}}
    },
    {
      full_name='titlestring',
      type='string', scope={'global'},
      vi_def=true,
      varname='p_titlestring',
      defaults={if_true={vi=""}}
    },
    {
      full_name='ttimeout',
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_ttimeout',
      defaults={if_true={vi=true}}
    },
    {
      full_name='ttimeoutlen', abbreviation='ttm',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_ttm',
      defaults={if_true={vi=50}}
    },
    {
      full_name='ttyfast', abbreviation='tf',
      type='bool', scope={'global'},
      no_mkrc=true,
      vi_def=true,
      varname='p_force_on',
      defaults={if_true={vi=true}}
    },
    {
      full_name='undodir', abbreviation='udir',
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
      type='bool', scope={'buffer'},
      vi_def=true,
      vim=true,
      varname='p_udf',
      defaults={if_true={vi=false}}
    },
    {
      full_name='undolevels', abbreviation='ul',
      type='number', scope={'global', 'buffer'},
      vi_def=true,
      varname='p_ul',
      defaults={if_true={vi=1000}}
    },
    {
      full_name='undoreload', abbreviation='ur',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_ur',
      defaults={if_true={vi=10000}}
    },
    {
      full_name='updatecount', abbreviation='uc',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_uc',
      defaults={if_true={vi=200}}
    },
    {
      full_name='updatetime', abbreviation='ut',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_ut',
      defaults={if_true={vi=4000}}
    },
    {
      full_name='verbose', abbreviation='vbs',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_verbose',
      defaults={if_true={vi=0}}
    },
    {
      full_name='verbosefile', abbreviation='vfile',
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      expand=true,
      varname='p_vfile',
      defaults={if_true={vi=""}}
    },
    {
      full_name='viewdir', abbreviation='vdir',
      type='string', scope={'global'},
      secure=true,
      vi_def=true,
      expand='nodefault',
      varname='p_vdir',
      defaults={if_true={vi=''}}
    },
    {
      full_name='viewoptions', abbreviation='vop',
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_vop',
      defaults={if_true={vi="folds,options,cursor,curdir"}}
    },
    {
      full_name='viminfo', abbreviation='vi',
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      secure=true,
      varname='p_shada',
      defaults={if_true={vi="", vim="!,'100,<50,s10,h"}}
    },
    {
      full_name='virtualedit', abbreviation='ve',
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
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_vb',
      defaults={if_true={vi=false}}
    },
    {
      full_name='warn',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_warn',
      defaults={if_true={vi=true}}
    },
    {
      full_name='whichwrap', abbreviation='ww',
      type='string', list='flagscomma', scope={'global'},
      vim=true,
      varname='p_ww',
      defaults={if_true={vi="", vim="b,s"}}
    },
    {
      full_name='wildchar', abbreviation='wc',
      type='number', scope={'global'},
      vim=true,
      varname='p_wc',
      defaults={if_true={vi=imacros('Ctrl_E'), vim=imacros('TAB')}}
    },
    {
      full_name='wildcharm', abbreviation='wcm',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_wcm',
      defaults={if_true={vi=0}}
    },
    {
      full_name='wildignore', abbreviation='wig',
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vi_def=true,
      varname='p_wig',
      defaults={if_true={vi=""}}
    },
    {
      full_name='wildignorecase', abbreviation='wic',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_wic',
      defaults={if_true={vi=false}}
    },
    {
      full_name='wildmenu', abbreviation='wmnu',
      type='bool', scope={'global'},
      vim=true,
      varname='p_wmnu',
      defaults={if_true={vi=false, vim=true}}
    },
    {
      full_name='wildmode', abbreviation='wim',
      type='string', list='onecomma', scope={'global'},
      deny_duplicates=true,
      vim=true,
      varname='p_wim',
      defaults={if_true={vi="", vim="full"}}
    },
    {
      full_name='wildoptions', abbreviation='wop',
      type='string', list='onecomma', scope={'global'},
      vi_def=true,
      varname='p_wop',
      defaults={if_true={vi=""}}
    },
    {
      full_name='winaltkeys', abbreviation='wak',
      type='string', scope={'global'},
      vi_def=true,
      varname='p_wak',
      defaults={if_true={vi="menu"}}
    },
    {
      full_name='winhighlight', abbreviation='winhl',
      type='string', scope={'window'},
      vi_def=true,
      alloced=true,
      redraw={'current_window'},
      defaults={if_true={vi=""}}
    },
    {
      full_name='window', abbreviation='wi',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_window',
      defaults={if_true={vi=0}}
    },
    {
      full_name='winheight', abbreviation='wh',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_wh',
      defaults={if_true={vi=1}}
    },
    {
      full_name='winfixheight', abbreviation='wfh',
      type='bool', scope={'window'},
      vi_def=true,
      redraw={'statuslines'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='winfixwidth', abbreviation='wfw',
      type='bool', scope={'window'},
      vi_def=true,
      redraw={'statuslines'},
      defaults={if_true={vi=false}}
    },
    {
      full_name='winminheight', abbreviation='wmh',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_wmh',
      defaults={if_true={vi=1}}
    },
    {
      full_name='winminwidth', abbreviation='wmw',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_wmw',
      defaults={if_true={vi=1}}
    },
    {
      full_name='winwidth', abbreviation='wiw',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_wiw',
      defaults={if_true={vi=20}}
    },
    {
      full_name='wrap',
      type='bool', scope={'window'},
      vi_def=true,
      redraw={'current_window'},
      defaults={if_true={vi=true}}
    },
    {
      full_name='wrapmargin', abbreviation='wm',
      type='number', scope={'buffer'},
      vi_def=true,
      varname='p_wm',
      defaults={if_true={vi=0}}
    },
    {
      full_name='wrapscan', abbreviation='ws',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_ws',
      defaults={if_true={vi=true}}
    },
    {
      full_name='write',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_write',
      defaults={if_true={vi=true}}
    },
    {
      full_name='writeany', abbreviation='wa',
      type='bool', scope={'global'},
      vi_def=true,
      varname='p_wa',
      defaults={if_true={vi=false}}
    },
    {
      full_name='writebackup', abbreviation='wb',
      type='bool', scope={'global'},
      vi_def=true,
      vim=true,
      varname='p_wb',
      defaults={if_true={vi=true}}
    },
    {
      full_name='writedelay', abbreviation='wd',
      type='number', scope={'global'},
      vi_def=true,
      varname='p_wd',
      defaults={if_true={vi=0}}
    },
  }
}
