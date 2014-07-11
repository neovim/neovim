" Vim syntax file
" Language:	Vim 7.4 script
" Maintainer:	Charles E. Campbell <NdrOchipS@PcampbellAfamily.Mbiz>
" Last Change:	Mar 20, 2014
" Version:	7.4-27
" Automatically generated keyword lists: {{{1

" Quit when a syntax file was already loaded {{{2
if exists("b:current_syntax")
  finish
endif
let s:keepcpo= &cpo
set cpo&vim

" vimTodo: contains common special-notices for comments {{{2
" Use the vimCommentGroup cluster to add your own.
syn cluster vimCommentGroup	contains=vimTodo,@Spell

" regular vim commands {{{2
syn keyword vimCommand contained	a arga[dd] ar[gs] bd[elete] bN[ext] breakd[el] bufdo cabc[lear] cat[ch] cex[pr] c[hange] cla[st] cnew[er] cNf[ile] con cp[revious] cuna[bbrev] del deletep delm[arks] diffp[atch] dig[raphs] do e echon endf endw[hile] f[ile] fin[d] folddoc[losed] fu[nction] gvim helpt[ags] iabc[lear] intro k l lan lc[d] lefta[bove] lg[etfile] lla[st] lnew[er] lNf[ile] lockv[ar] ls lvimgrepa[dd] mat[ch] mk[exrc] mo n n[ext] o ownsyntax perld[o] pre[serve] promptf[ind] ptl[ast] ptr[ewind] py3do qa[ll] r[ead] redr[aw] retu[rn] rub[y] rv[iminfo] sba[ll] sbN[ext] scripte[ncoding] setf[iletype] sh[ell] sim[alt] sm[ap] sni[ff] sor[t] spelli[nfo] spr[evious] start st[op] sunmenu syn ta tabf[ind] tabnew tabr[ewind] tcld[o] tj[ump] tN tr tu[nmenu] undoj[oin] uns[ilent] ve[rsion] vimgrepa[dd] vs[plit] winc[md] wN[ext] ws[verb] x[it] xnoremenu
syn keyword vimCommand contained	ab argd[elete] argu[ment] bel[owright] bo[tright] breakl[ist] b[uffer] cad cb[uffer] cf[ile] changes cl[ist] cn[ext] col[der] conf[irm] cq[uit] cw[indow] delc[ommand] deletl delp diffpu[t] dir doau ea e[dit] endfo[r] ene[w] files fini[sh] foldd[oopen] g h hi if is[earch] keepa la lan[guage] lch[dir] lex[pr] lgr[ep] lli[st] lne[xt] lo lol[der] lt[ag] lw[indow] menut mks[ession] mod[e] nbc[lose] nmapc[lear] ol[dfiles] p po[p] prev[ious] promptr[epl] ptn pts[elect] pydo q[uit] rec[over] redraws[tatus] rew[ind] rubyd[o] sal[l] sbf[irst] sbp[revious] scrip[tnames] setg[lobal] si sl sme sno[magic] so[urce] spellr[epall] sre[wind] startg[replace] stopi[nsert] sus[pend] sync tab tabfir[st] tabn[ext] tabs tclf[ile] tl[ast] tn[ext] tr[ewind] u undol[ist] up[date] vert[ical] vi[sual] w windo wp[revious] wundo xmapc[lear] xunme
syn keyword vimCommand contained	abc[lear] argdo as[cii] bf[irst] bp[revious] br[ewind] buffers caddb[uffer] cc cfir[st] chd[ir] clo[se] cN[ext] colo[rscheme] con[tinue] cr[ewind] d delel deletp dep diffs[plit] di[splay] dp earlier el[se] endfun ex filet fir[st] foldo[pen] go[to] ha[rdcopy] hid[e] ij[ump] isp[lit] keepalt lad la[st] lcl[ose] lf[ile] lgrepa[dd] lmak[e] lN[ext] loadk lop[en] lua ma menut[ranslate] mksp[ell] m[ove] nb[key] noa omapc[lear] pc[lose] popu p[rint] ps[earch] ptN pu[t] pyf[ile] quita[ll] red reg[isters] ri[ght] rubyf[ile] san[dbox] sbl[ast] sbr[ewind] scs setl[ocal] sig sla[st] smenu snoreme spe spellu[ndo] st star[tinsert] sts[elect] sv[iew] syncbind tabc[lose] tabl[ast] tabN[ext] ta[g] te[aroff] tm tN[ext] try un unh[ide] v vi viu[sage] wa[ll] winp[os] wq wv[iminfo] xme xunmenu
syn keyword vimCommand contained	abo[veleft] arge[dit] au bl[ast] br bro[wse] bun[load] cad[dexpr] ccl[ose] cgetb[uffer] che[ckpath] cmapc[lear] cnf com cope[n] cs de delep delf di difft[his] dj[ump] dr[op] ec elsei[f] endf[unction] exi[t] filetype fix[del] for gr[ep] h[elp] his[tory] il[ist] iuna[bbrev] keepj[umps] laddb[uffer] lat lcs lfir[st] lh[elpgrep] lmapc[lear] lnf loadkeymap lpf[ile] luado mak[e] mes mkv mz nbs[tart] noautocmd on[ly] pe popu[p] pro pta[g] ptn[ext] pw[d] py[thon] r redi[r] res[ize] rightb[elow] rundo sa[rgument] sbm[odified] sb[uffer] scscope sf[ind] sign sl[eep] sn[ext] snoremenu spelld[ump] spellw[rong] sta[g] startr[eplace] sun[hide] sw[apname] syntime tabd[o] tabm[ove] tabo[nly] tags tf[irst] tm[enu] to[pleft] ts[elect] una[bbreviate] unl ve vie[w] vmapc[lear] wh[ile] win[size] wqa[ll] x xmenu xwininfo
syn keyword vimCommand contained	al[l] argg[lobal] bad[d] bm[odified] brea[k] bu bw[ipeout] caddf[ile] cd cgete[xpr] checkt[ime] cn cNf comc[lear] co[py] cscope debug d[elete] delf[unction] diffg[et] diffu[pdate] dl ds[earch] echoe[rr] em[enu] en[dif] exu[sage] fin fo[ld] fu grepa[dd] helpf[ind] i imapc[lear] j[oin] kee[pmarks] lad[dexpr] later lcscope lgetb[uffer] l[ist] lN lNf lo[adview] lp[revious] luafile ma[rk] messages mkvie[w] mzf[ile] ne noh[lsearch] o[pen] ped[it] pp[op] profd[el] ptf[irst] ptN[ext] py python3 re red[o] ret[ab] ru ru[ntime] sav[eas] sbn[ext] scrip se[t] sfir[st] sil[ent] sm[agic] sN[ext] so spe[llgood] sp[lit] star stj[ump] sunme sy t tabe[dit] tabN tabp[revious] tc[l] th[row] tn tp[revious] tu u[ndo] unlo[ckvar] verb[ose] vim[grep] vne[w] win wn[ext] w[rite] xa[ll] xnoreme y[ank]
syn keyword vimCommand contained	ar argl[ocal] ba[ll] bn[ext] breaka[dd] buf c cal[l] ce[nter] cg[etfile] cl cN cnf[ile] comp[iler] cpf[ile] cstag debugg[reedy] deletel dell diffo[ff] dig dli[st] dsp[lit] echom[sg] en endt[ry] f fina[lly] foldc[lose] fun gui helpg[rep] ia in ju[mps] keepp[atterns] laddf[ile] lb[uffer] le[ft] lgete[xpr] ll lne lnf[ile] loc[kmarks] lr[ewind] lv[imgrep] marks mk mkv[imrc] mz[scheme] new nu[mber] opt[ions] pe[rl] pr prof[ile] ptj[ump] ptp[revious] py3 q 
syn match   vimCommand contained	"\<z[-+^.=]\="
syn keyword vimStdPlugin contained	DiffOrig Man N[ext] P[rint] S TOhtml XMLent XMLns 

" vimOptions are caught only when contained in a vimSet {{{2
syn keyword vimOption contained	acd ambiwidth arabicshape autowriteall backupdir bdlay binary breakat bufhidden cd ci cinw co commentstring confirm cpoptions cscoperelative csre cursorcolumn delcombine diffopt ea efm ep et fdc fdo ffs filetype fo foldlevelstart formatexpr ft gfw gtt guipty hh hkmap ic imaf iminsert includeexpr inf isident key langmap lines lmap ma matchtime mco ml modeline mousefocus mousetime nrformats ofu para pdev pi previewwindow printmbfont qe relativenumber rightleftcmd ru sbr scrolloff selection shellcmdflag shellxescape showbreak si smartcase softtabstop spelllang sps sta su swb synmaxcol tagbsearch tbi termencoding thesaurus titlestring tpm ttm ttytype undodir ut vfile vop wcm whichwrap wildignore winaltkeys winminwidth wmnu write
syn keyword vimOption contained	ai ambw ari aw backupext beval biosk brk buflisted cdpath cin cinwords cocu compatible consk cpt cscopetag cst cursorline dex digraph ead ei equalalways eventignore fde fdt fic fillchars foldclose foldmarker formatlistpat gcr ghr guicursor guitablabel hi hkmapp icon imak ims incsearch infercase isk keymap langmenu linespace loadplugins macatsui maxcombine mef mls modelines mousehide mp nu omnifunc paragraphs penc pm printdevice printoptions quoteescape remap rl ruf sc scrollopt selectmode shellpipe shellxquote showcmd sidescroll smartindent sol spellsuggest sr stal sua swf syntax taglength tbidi terse tildeop tl tr tty tw undofile vb vi wa wd wi wildignorecase window winwidth wmw writeany
syn keyword vimOption contained	akm anti arshape awa backupskip bex bioskey browsedir buftype cedit cindent clipboard cole complete conskey crb cscopetagorder csto cwh dg dip eadirection ek equalprg ex fdi fen fileencoding fk foldcolumn foldmethod formatoptions gd go guifont guitabtooltip hid hkp iconstring imc imsearch inde insertmode iskeyword keymodel laststatus lisp lpl magic maxfuncdepth menuitems mm modifiable mousem mps number opendevice paste pex pmbcs printencoding prompt rdt report rlc ruler scb scs sessionoptions shellquote shiftround showfulltag sidescrolloff smarttab sp spf srr startofline suffixes switchbuf ta tagrelative tbis textauto timeout tm ts ttybuiltin tx undolevels vbs viewdir wak weirdinvert wic wildmenu winfixheight wiv wop writebackup
syn keyword vimOption contained	al antialias autochdir background balloondelay bexpr bk bs casemap cf cink cmdheight colorcolumn completefunc copyindent cryptmethod cscopeverbose csverb debug dict dir eb enc errorbells expandtab fdl fenc fileencodings fkmap foldenable foldminlines formatprg gdefault gp guifontset helpfile hidden hl ignorecase imcmdline imsf indentexpr is isp keywordprg lazyredraw lispwords ls makeef maxmapdepth mfd mmd modified mousemodel msm numberwidth operatorfunc pastetoggle pexpr pmbfn printexpr pt re restorescreen rnu rulerformat scr sect sft shellredir shiftwidth showmatch siso smc spc spl ss statusline suffixesadd sws tabline tags tbs textmode timeoutlen to tsl ttyfast uc undoreload vdir viewoptions warn wfh wig wildmode winfixwidth wiw wrap writedelay
syn keyword vimOption contained	aleph ar autoindent backspace ballooneval bg bkc bsdir cb cfu cinkeys cmdwinheight columns completeopt cot cscopepathcomp cspc cuc deco dictionary directory ed encoding errorfile exrc fdls fencs fileformat flp foldexpr foldnestmax fp gfm grepformat guifontwide helpheight highlight hlg im imd imstatusfunc indentkeys isf isprint km lbr list lsp makeprg maxmem mh mmp more mouses mzq nuw opfunc patchexpr pfn popt printfont pumheight readonly revins ro runtimepath scroll sections sh shellslash shm showmode sj smd spell splitbelow ssl stl sw sxe tabpagemax tagstack tenc textwidth title toolbar tsr ttym udf updatecount ve viminfo wb wfw wildchar wildoptions winheight wm wrapmargin ws
syn keyword vimOption contained	allowrevins arab autoread backup balloonexpr bh bl bsk cc ch cino cmp com concealcursor cp cscopeprg csprg cul def diff display edcompatible endofline errorformat fcl fdm fex fileformats fml foldignore foldopen fs gfn grepprg guiheadroom helplang history hls imactivatefunc imdisable inc indk isfname joinspaces kmp lcs listchars lw mat maxmempattern mis mmt mouse mouseshape mzquantum odev osfiletype patchmode ph preserveindent printheader pvh redrawtime ri rs sb scrollbind secure shcf shelltemp shortmess showtabline slm sn spellcapcheck splitright ssop stmp swapfile sxq tabstop tal term tf titlelen toolbariconsize ttimeout ttymouse udir updatetime verbose virtualedit wc wh wildcharm wim winminheight wmh wrapscan ww
syn keyword vimOption contained	altkeymap arabic autowrite backupcopy bdir bin bomb bt ccv charconvert cinoptions cms comments conceallevel cpo cscopequickfix csqf cursorbind define diffexpr dy ef eol esckeys fcs fdn ff fileignorecase fmr foldlevel foldtext fsync gfs gtl guioptions hf hk hlsearch imactivatekey imi include inex isi js kp linebreak lm lz matchpairs maxmemtot mkspellmem mod mousef mouset nf oft pa path pheader previewheight printmbcharset pvw regexpengine rightleft rtp sbo scrolljump sel shell shelltype shortname shq sm so spellfile spr st sts swapsync syn tag tb termbidi tgst titleold top ttimeoutlen ttyscroll ul ur verbosefile visualbell 

" vimOptions: These are the turn-off setting variants {{{2
syn keyword vimOption contained	noacd noallowrevins noantialias noarabic noarshape noautoread noaw noballooneval nobinary nobk nobuflisted nocin noconfirm nocopyindent nocscoperelative nocsre nocuc nocursorcolumn nodelcombine nodigraph noed noendofline noerrorbells noex nofen nofk nogd nohid nohkmap nohkp nohlsearch noicon noim noimcmdline noimdisable noinf noinsertmode nojoinspaces nolazyredraw nolinebreak nolist nolpl noma nomagic noml nomodeline nomodified nomousef nomousehide nonumber noopendevice nopi nopreviewwindow nopvw norelativenumber norestorescreen nori norl noro noru nosb noscb noscs nosft noshelltemp noshortname noshowfulltag noshowmode nosm nosmartindent nosmd nosol nosplitbelow nospr nossl nostartofline noswapfile nota notagrelative notbi notbs noterse notextmode notgst notimeout noto notr nottybuiltin notx noundofile novisualbell nowarn noweirdinvert nowfw nowildignorecase nowinfixheight nowiv nowrap nowrite nowritebackup
syn keyword vimOption contained	noai noaltkeymap noar noarabicshape noautochdir noautowrite noawa nobeval nobiosk nobl nocf nocindent noconsk nocp nocscopetag nocst nocul nocursorline nodg noea noedcompatible noeol noesckeys noexpandtab nofic nofkmap nogdefault nohidden nohkmapp nohls noic noignorecase noimc noimd noincsearch noinfercase nois nojs nolbr nolisp noloadplugins nolz nomacatsui nomh nomod nomodifiable nomore nomousefocus nonu noodev nopaste nopreserveindent noprompt noreadonly noremap norevins norightleft nornu nors noruler nosc noscrollbind nosecure noshellslash noshiftround noshowcmd noshowmatch nosi nosmartcase nosmarttab nosn nospell nosplitright nosr nosta nostmp noswf notagbsearch notagstack notbidi notermbidi notextauto notf notildeop notitle notop nottimeout nottyfast noudf novb nowa nowb nowfh nowic nowildmenu nowinfixwidth nowmnu nowrapscan nowriteany nows
syn keyword vimOption contained	noakm noanti noarab noari noautoindent noautowriteall nobackup nobin nobioskey nobomb noci nocompatible noconskey nocrb nocscopeverbose nocsverb nocursorbind nodeco nodiff noeb noek noequalalways noet noexrc nofileignorecase nofoldenable noguipty nohk 

" vimOptions: These are the invertible variants {{{2
syn keyword vimOption contained	invacd invallowrevins invantialias invarabic invarshape invautoread invaw invballooneval invbinary invbk invbuflisted invcin invconfirm invcopyindent invcscoperelative invcsre invcuc invcursorcolumn invdelcombine invdigraph inved invendofline inverrorbells invex invfen invfk invgd invhid invhkmap invhkp invhlsearch invicon invim invimcmdline invimdisable invinf invinsertmode invjoinspaces invlazyredraw invlinebreak invlist invlpl invma invmagic invml invmodeline invmodified invmousef invmousehide invnumber invopendevice invpi invpreviewwindow invpvw invrelativenumber invrestorescreen invri invrl invro invru invsb invscb invscs invsft invshelltemp invshortname invshowfulltag invshowmode invsm invsmartindent invsmd invsol invsplitbelow invspr invssl invstartofline invswapfile invta invtagrelative invtbi invtbs invterse invtextmode invtgst invtimeout invto invtr invttybuiltin invtx invundofile invvisualbell invwarn invweirdinvert invwfw invwildignorecase invwinfixheight invwiv invwrap invwrite invwritebackup
syn keyword vimOption contained	invai invaltkeymap invar invarabicshape invautochdir invautowrite invawa invbeval invbiosk invbl invcf invcindent invconsk invcp invcscopetag invcst invcul invcursorline invdg invea invedcompatible inveol invesckeys invexpandtab invfic invfkmap invgdefault invhidden invhkmapp invhls invic invignorecase invimc invimd invincsearch invinfercase invis invjs invlbr invlisp invloadplugins invlz invmacatsui invmh invmod invmodifiable invmore invmousefocus invnu invodev invpaste invpreserveindent invprompt invreadonly invremap invrevins invrightleft invrnu invrs invruler invsc invscrollbind invsecure invshellslash invshiftround invshowcmd invshowmatch invsi invsmartcase invsmarttab invsn invspell invsplitright invsr invsta invstmp invswf invtagbsearch invtagstack invtbidi invtermbidi invtextauto invtf invtildeop invtitle invtop invttimeout invttyfast invudf invvb invwa invwb invwfh invwic invwildmenu invwinfixwidth invwmnu invwrapscan invwriteany invws
syn keyword vimOption contained	invakm invanti invarab invari invautoindent invautowriteall invbackup invbin invbioskey invbomb invci invcompatible invconskey invcrb invcscopeverbose invcsverb invcursorbind invdeco invdiff inveb invek invequalalways invet invexrc invfileignorecase invfoldenable invguipty invhk 

" termcap codes (which can also be set) {{{2
syn keyword vimOption contained	t_AB t_al t_bc t_ce t_cl t_Co t_Cs t_CS t_CV t_da t_db t_dl t_DL t_EI t_F1 t_F2 t_F3 t_F4 t_F5 t_F6 t_F7 t_F8 t_F9 t_fs t_IE t_IS t_k1 t_K1 t_k2 t_k3 t_K3 t_k4 t_K4 t_k5 t_K5 t_k6 t_K6 t_k7 t_K7 t_k8 t_K8 t_k9 t_K9 t_KA t_kb t_kB t_KB t_KC t_kd t_kD t_KD t_ke t_KE t_KF t_KG t_kh t_KH t_kI t_KI t_KJ t_KK t_kl t_KL t_kN t_kP t_kr t_ks t_ku t_le t_mb t_md t_me t_mr t_ms t_nd t_op t_RI t_RV t_Sb t_se t_Sf t_SI t_so t_sr t_te t_ti t_ts t_u7 t_ue t_us t_ut t_vb t_ve t_vi t_vs t_WP t_WS t_xs t_ZH t_ZR
syn keyword vimOption contained	t_AF t_AL t_cd t_Ce t_cm t_cs 
syn match   vimOption contained	"t_%1"
syn match   vimOption contained	"t_#2"
syn match   vimOption contained	"t_#4"
syn match   vimOption contained	"t_@7"
syn match   vimOption contained	"t_*7"
syn match   vimOption contained	"t_&8"
syn match   vimOption contained	"t_%i"
syn match   vimOption contained	"t_k;"

" unsupported settings: these are supported by vi but don't do anything in vim {{{2
syn keyword vimErrSetting contained	hardtabs ht w1200 w300 w9600 

" AutoCmd Events {{{2
syn case ignore
syn keyword vimAutoEvent contained	BufAdd BufCreate BufDelete BufEnter BufFilePost BufFilePre BufHidden BufLeave BufNew BufNewFile BufRead BufReadCmd BufReadPost BufReadPre BufUnload BufWinEnter BufWinLeave BufWipeout BufWrite BufWriteCmd BufWritePost BufWritePre Cmd-event CmdwinEnter CmdwinLeave ColorScheme CompleteDone CursorHold CursorHoldI CursorMoved CursorMovedI EncodingChanged FileAppendCmd FileAppendPost FileAppendPre FileChangedRO FileChangedShell FileChangedShellPost FileEncoding FileReadCmd FileReadPost FileReadPre FileType FileWriteCmd FileWritePost FileWritePre FilterReadPost FilterReadPre FilterWritePost FilterWritePre FocusGained FocusLost FuncUndefined GUIEnter GUIFailed InsertChange InsertCharPre InsertEnter InsertLeave MenuPopup QuickFixCmdPost QuickFixCmdPre QuitPre RemoteReply SessionLoadPost ShellCmdPost ShellFilterPost SourceCmd SourcePre SpellFileMissing StdinReadPost StdinReadPre SwapExists Syntax TabEnter TabLeave TermChanged TermResponse TextChanged TextChangedI User UserGettingBored VimEnter VimLeave VimLeavePre VimResized WinEnter WinLeave 

" Highlight commonly used Groupnames {{{2
syn keyword vimGroup contained	Comment Constant String Character Number Boolean Float Identifier Function Statement Conditional Repeat Label Operator Keyword Exception PreProc Include Define Macro PreCondit Type StorageClass Structure Typedef Special SpecialChar Tag Delimiter SpecialComment Debug Underlined Ignore Error Todo 

" Default highlighting groups {{{2
syn keyword vimHLGroup contained	ColorColumn Cursor CursorColumn CursorIM CursorLine CursorLineNr DiffAdd DiffChange DiffDelete DiffText Directory ErrorMsg FoldColumn Folded IncSearch LineNr MatchParen Menu ModeMsg MoreMsg NonText Normal Pmenu PmenuSbar PmenuSel PmenuThumb Question Scrollbar Search SignColumn SpecialKey SpellBad SpellCap SpellLocal SpellRare StatusLine StatusLineNC TabLine TabLineFill TabLineSel Title Tooltip VertSplit Visual VisualNOS WarningMsg WildMenu 
syn match vimHLGroup contained	"Conceal"
syn case match

" Function Names {{{2
syn keyword vimFuncName contained	abs and argidx atan browsedir bufloaded bufwinnr byteidxcomp changenr clearmatches complete_add copy count deepcopy diff_filler escape executable expand feedkeys filter float2nr fnameescape foldclosedend foldtextresult garbagecollect getbufvar getcmdline getcwd getfsize getline getpid getreg gettabwinvar getwinvar has hasmapto histget hlID indent inputdialog inputsave invert items len line localtime luaeval mapcheck matcharg matchlist min mzeval or prevnonblank py3eval readfile remote_expr remote_read rename reverse screenchar search searchpairpos serverlist setcmdpos setloclist setpos setreg settabwinvar sha256 shiftwidth sin sort spellbadword split str2float strchars strftime string strpart strtrans submatch synconcealed synIDattr synstack tabpagebuflist tabpagewinnr taglist tanh tolower tr type undotree virtcol wildmenumode wincol winline winrestcmd winsaveview writefile
syn keyword vimFuncName contained	acos append argv atan2 bufexists bufname byte2line call char2nr col complete_check cos cscope_connection delete diff_hlID eval exists expr8 filereadable finddir floor fnamemodify foldlevel foreground get getchar getcmdpos getfontname getftime getloclist getpos getregtype getwinposx glob has_key histadd histnr hostname index inputlist inputsecret isdirectory join libcall line2byte log map match matchdelete matchstr mkdir nextnonblank pathshorten printf pyeval reltime remote_foreground remote_send repeat round screencol searchdecl searchpos setbufvar setline setmatches setqflist settabvar setwinvar shellescape simplify sinh soundfold spellsuggest sqrt str2nr strdisplaywidth stridx strlen strridx strwidth substitute synID synIDtrans system tabpagenr tagfiles tan tempname toupper trunc undofile values visualmode winbufnr winheight winnr winrestview winwidth xor
syn keyword vimFuncName contained	add argc asin browse buflisted bufnr byteidx ceil cindent complete confirm cosh cursor did_filetype empty eventhandler exp extend filewritable findfile fmod foldclosed foldtext function getbufline getcharmod getcmdtype getfperm getftype getmatches getqflist gettabvar getwinposy globpath haslocaldir histdel hlexists iconv input inputrestore insert islocked keys libcallnr lispindent log10 maparg matchadd matchend max mode nr2char pow pumvisible range reltimestr remote_peek remove resolve screenattr screenrow searchpair server2client 

"--- syntax here and above generated by mkvimvim ---
" Special Vim Highlighting (not automatic) {{{1

" commands not picked up by the generator (due to non-standard format)
syn keyword vimCommand contained	py3

" Deprecated variable options {{{2
if exists("g:vim_minlines")
 let g:vimsyn_minlines= g:vim_minlines
endif
if exists("g:vim_maxlines")
 let g:vimsyn_maxlines= g:vim_maxlines
endif
if exists("g:vimsyntax_noerror")
 let g:vimsyn_noerror= g:vimsyntax_noerror
endif

" Numbers {{{2
" =======
syn match vimNumber	"\<\d\+\%(\.\d\+\%([eE][+-]\=\d\+\)\=\)\=" skipwhite nextgroup=vimGlobal,vimSubst,vimCommand
syn match vimNumber	"-\d\+\%(\.\d\+\%([eE][+-]\=\d\+\)\=\)\="  skipwhite nextgroup=vimGlobal,vimSubst,vimCommand
syn match vimNumber	"\<0[xX]\x\+"
syn match vimNumber	"#\x\{6}"

" All vimCommands are contained by vimIsCommands. {{{2
syn match vimCmdSep	"[:|]\+"	skipwhite nextgroup=vimAddress,vimAutoCmd,vimCommand,vimExtCmd,vimFilter,vimLet,vimMap,vimMark,vimSet,vimSyntax,vimUserCmd
syn match vimIsCommand	"\<\h\w*\>"	contains=vimCommand
syn match vimVar        contained	"\<\h[a-zA-Z0-9#_]*\>"
syn match vimVar		"\<[bwglsav]:\h[a-zA-Z0-9#_]*\>"
syn match vimFBVar      contained   "\<[bwglsav]:\h[a-zA-Z0-9#_]*\>"
syn keyword vimCommand  contained	in

" Insertions And Appends: insert append {{{2
" =======================
syn region vimInsert	matchgroup=vimCommand start="^[: \t]*\(\d\+\(,\d\+\)\=\)\=a\%[ppend]$"	matchgroup=vimCommand end="^\.$""
syn region vimInsert	matchgroup=vimCommand start="^[: \t]*\(\d\+\(,\d\+\)\=\)\=c\%[hange]$"	matchgroup=vimCommand end="^\.$""
syn region vimInsert	matchgroup=vimCommand start="^[: \t]*\(\d\+\(,\d\+\)\=\)\=i\%[nsert]$"	matchgroup=vimCommand end="^\.$""

" Behave! {{{2
" =======
syn match   vimBehave	"\<be\%[have]\>" skipwhite nextgroup=vimBehaveModel,vimBehaveError
syn keyword vimBehaveModel contained	mswin	xterm
if !exists("g:vimsyn_noerror") && !exists("g:vimsyn_nobehaveerror")
 syn match   vimBehaveError contained	"[^ ]\+"
endif

" Filetypes {{{2
" =========
syn match   vimFiletype	"\<filet\%[ype]\(\s\+\I\i*\)*"	skipwhite contains=vimFTCmd,vimFTOption,vimFTError
if !exists("g:vimsyn_noerror") && !exists("g:vimsyn_vimFTError")
 syn match   vimFTError  contained	"\I\i*"
endif
syn keyword vimFTCmd    contained	filet[ype]
syn keyword vimFTOption contained	detect indent off on plugin

" Augroup : vimAugroupError removed because long augroups caused sync'ing problems. {{{2
" ======= : Trade-off: Increasing synclines with slower editing vs augroup END error checking.
syn cluster vimAugroupList	contains=vimIsCommand,vimCommand,vimUserCmd,vimExecute,vimNotFunc,vimFuncName,vimFunction,vimFunctionError,vimLineComment,vimSpecFile,vimOper,vimNumber,vimOperParen,vimComment,vimString,vimSubst,vimMark,vimRegister,vimAddress,vimFilter,vimCmplxRepeat,vimComment,vimLet,vimSet,vimAutoCmd,vimRegion,vimSynLine,vimNotation,vimCtrlChar,vimFuncVar,vimContinue
if exists("g:vimsyn_folding") && g:vimsyn_folding =~ 'a'
 syn region  vimAugroup	fold start="\<aug\%[roup]\>\s\+\h\w*" end="\<aug\%[roup]\>\s\+[eE][nN][dD]\>"	contains=vimAugroupKey,vimAutoCmd,@vimAugroupList keepend
else
 syn region  vimAugroup	start="\<aug\%[roup]\>\s\+\h\w*" end="\<aug\%[roup]\>\s\+[eE][nN][dD]\>"	contains=vimAugroupKey,vimAutoCmd,@vimAugroupList keepend
endif
syn match   vimAugroup	"aug\%[roup]!" contains=vimAugroupKey
if !exists("g:vimsyn_noerror") && !exists("g:vimsyn_noaugrouperror")
 syn match   vimAugroupError	"\<aug\%[roup]\>\s\+[eE][nN][dD]\>"
endif
syn keyword vimAugroupKey contained	aug[roup]

" Operators: {{{2
" =========
" COMBAK: vimOperParen used to have "oneline"
syn cluster	vimOperGroup	contains=vimEnvvar,vimFunc,vimFuncVar,vimOper,vimOperParen,vimNumber,vimString,vimRegister,vimContinue
syn match	vimOper	"\(==\|!=\|>=\|<=\|=\~\|!\~\|>\|<\|=\)[?#]\{0,2}"	skipwhite nextgroup=vimString,vimSpecFile
syn match	vimOper	"||\|&&\|[-+.]"	skipwhite nextgroup=vimString,vimSpecFile
syn region	vimOperParen 	matchgroup=vimParenSep	start="(" end=")" contains=@vimOperGroup
syn region	vimOperParen	matchgroup=vimSep	start="{" end="}" contains=@vimOperGroup nextgroup=vimVar,vimFuncVar
if !exists("g:vimsyn_noerror") && !exists("g:vimsyn_noopererror")
 syn match	vimOperError	")"
endif

" Functions : Tag is provided for those who wish to highlight tagged functions {{{2
" =========
syn cluster	vimFuncList	contains=vimCommand,vimFunctionError,vimFuncKey,Tag,vimFuncSID
syn cluster	vimFuncBodyList	contains=vimAbb,vimAddress,vimAugroupKey,vimAutoCmd,vimCmplxRepeat,vimComment,vimComment,vimContinue,vimCtrlChar,vimEcho,vimEchoHL,vimExecute,vimIf,vimIsCommand,vimFBVar,vimFunc,vimFunction,vimFuncVar,vimHighlight,vimIsCommand,vimLet,vimLineComment,vimMap,vimMark,vimNorm,vimNotation,vimNotFunc,vimNumber,vimOper,vimOperParen,vimRegion,vimRegister,vimSet,vimSpecFile,vimString,vimSubst,vimSynLine,vimUnmap,vimUserCommand
syn match	vimFunction	"\<fu\%[nction]!\=\s\+\%(<[sS][iI][dD]>\|[sSgGbBwWtTlL]:\)\=\%(\i\|[#.]\|{.\{-1,}}\)*\ze\s*("	contains=@vimFuncList nextgroup=vimFuncBody

if exists("g:vimsyn_folding") && g:vimsyn_folding =~ 'f'
 syn region	vimFuncBody  contained	fold start="\ze("	matchgroup=vimCommand end="\<\(endf\>\|endfu\%[nction]\>\)"		contains=@vimFuncBodyList
else
 syn region	vimFuncBody  contained	start="\ze("	matchgroup=vimCommand end="\<\(endf\>\|endfu\%[nction]\>\)"		contains=@vimFuncBodyList
endif
syn match	vimFuncVar   contained	"a:\(\h\w*\|\d\+\)"
syn match	vimFuncSID   contained	"\c<sid>\|\<s:"
syn keyword	vimFuncKey   contained	fu[nction]
syn match	vimFuncBlank contained	"\s\+"

syn keyword	vimPattern   contained	start	skip	end

" Special Filenames, Modifiers, Extension Removal: {{{2
" ===============================================
syn match	vimSpecFile	"<c\(word\|WORD\)>"	nextgroup=vimSpecFileMod,vimSubst
syn match	vimSpecFile	"<\([acs]file\|amatch\|abuf\)>"	nextgroup=vimSpecFileMod,vimSubst
syn match	vimSpecFile	"\s%[ \t:]"ms=s+1,me=e-1	nextgroup=vimSpecFileMod,vimSubst
syn match	vimSpecFile	"\s%$"ms=s+1	nextgroup=vimSpecFileMod,vimSubst
syn match	vimSpecFile	"\s%<"ms=s+1,me=e-1	nextgroup=vimSpecFileMod,vimSubst
syn match	vimSpecFile	"#\d\+\|[#%]<\>"	nextgroup=vimSpecFileMod,vimSubst
syn match	vimSpecFileMod	"\(:[phtre]\)\+"	contained

" User-Specified Commands: {{{2
" =======================
syn cluster	vimUserCmdList	contains=vimAddress,vimSyntax,vimHighlight,vimAutoCmd,vimCmplxRepeat,vimComment,vimCtrlChar,vimEscapeBrace,vimFilter,vimFunc,vimFuncName,vimFunction,vimFunctionError,vimIsCommand,vimMark,vimNotation,vimNumber,vimOper,vimRegion,vimRegister,vimLet,vimSet,vimSetEqual,vimSetString,vimSpecFile,vimString,vimSubst,vimSubstRep,vimSubstRange,vimSynLine
syn keyword	vimUserCommand	contained	com[mand]
syn match	vimUserCmd	"\<com\%[mand]!\=\>.*$"	contains=vimUserAttrb,vimUserCommand,@vimUserCmdList
syn match	vimUserAttrb	contained	"-n\%[args]=[01*?+]"	contains=vimUserAttrbKey,vimOper
syn match	vimUserAttrb	contained	"-com\%[plete]="	contains=vimUserAttrbKey,vimOper nextgroup=vimUserAttrbCmplt,vimUserCmdError
syn match	vimUserAttrb	contained	"-ra\%[nge]\(=%\|=\d\+\)\="	contains=vimNumber,vimOper,vimUserAttrbKey
syn match	vimUserAttrb	contained	"-cou\%[nt]=\d\+"	contains=vimNumber,vimOper,vimUserAttrbKey
syn match	vimUserAttrb	contained	"-bang\=\>"	contains=vimOper,vimUserAttrbKey
syn match	vimUserAttrb	contained	"-bar\>"	contains=vimOper,vimUserAttrbKey
syn match	vimUserAttrb	contained	"-re\%[gister]\>"	contains=vimOper,vimUserAttrbKey
if !exists("g:vimsyn_noerror") && !exists("g:vimsyn_nousercmderror")
 syn match	vimUserCmdError	contained	"\S\+\>"
endif
syn case ignore
syn keyword	vimUserAttrbKey   contained	bar	ban[g]	cou[nt]	ra[nge] com[plete]	n[args]	re[gister]
syn keyword	vimUserAttrbCmplt contained	augroup buffer color command compiler cscope dir environment event expression file file_in_path filetype function help highlight locale mapping menu option shellcmd sign syntax tag tag_listfiles var
syn keyword	vimUserAttrbCmplt contained	custom customlist nextgroup=vimUserAttrbCmpltFunc,vimUserCmdError
syn match	vimUserAttrbCmpltFunc contained	",\%([sS]:\|<[sS][iI][dD]>\)\=\%(\h\w*\%(#\h\w*\)\+\|\h\w*\)"hs=s+1 nextgroup=vimUserCmdError

syn case match
syn match	vimUserAttrbCmplt contained	"custom,\u\w*"

" Lower Priority Comments: after some vim commands... {{{2
" =======================
syn match	vimComment	excludenl +\s"[^\-:.%#=*].*$+lc=1	contains=@vimCommentGroup,vimCommentString
syn match	vimComment	+\<endif\s\+".*$+lc=5	contains=@vimCommentGroup,vimCommentString
syn match	vimComment	+\<else\s\+".*$+lc=4	contains=@vimCommentGroup,vimCommentString
syn region	vimCommentString	contained oneline start='\S\s\+"'ms=e	end='"'

" Environment Variables: {{{2
" =====================
syn match	vimEnvvar	"\$\I\i*"
syn match	vimEnvvar	"\${\I\i*}"

" In-String Specials: {{{2
" Try to catch strings, if nothing else matches (therefore it must precede the others!)
"  vimEscapeBrace handles ["]  []"] (ie. "s don't terminate string inside [])
syn region	vimEscapeBrace	oneline   contained transparent start="[^\\]\(\\\\\)*\[\zs\^\=\]\=" skip="\\\\\|\\\]" end="]"me=e-1
syn match	vimPatSepErr	contained	"\\)"
syn match	vimPatSep	contained	"\\|"
syn region	vimPatSepZone	oneline   contained   matchgroup=vimPatSepZ start="\\%\=\ze(" skip="\\\\" end="\\)\|[^\]['"]"	contains=@vimStringGroup
syn region	vimPatRegion	contained transparent matchgroup=vimPatSepR start="\\[z%]\=(" end="\\)"	contains=@vimSubstList oneline
syn match	vimNotPatSep	contained	"\\\\"
syn cluster	vimStringGroup	contains=vimEscapeBrace,vimPatSep,vimNotPatSep,vimPatSepErr,vimPatSepZone,@Spell
syn region	vimString	oneline keepend	start=+[^:a-zA-Z>!\\@]"+lc=1 skip=+\\\\\|\\"+ end=+"+	contains=@vimStringGroup
syn region	vimString	oneline keepend	start=+[^:a-zA-Z>!\\@]'+lc=1 end=+'+
syn region	vimString	oneline	start=+=!+lc=1	skip=+\\\\\|\\!+ end=+!+	contains=@vimStringGroup
syn region	vimString	oneline	start="=+"lc=1	skip="\\\\\|\\+" end="+"	contains=@vimStringGroup
syn region	vimString	oneline	start="\s/\s*\A"lc=1 skip="\\\\\|\\+" end="/"	contains=@vimStringGroup
syn match	vimString	contained	+"[^"]*\\$+	skipnl nextgroup=vimStringCont
syn match	vimStringCont	contained	+\(\\\\\|.\)\{-}[^\\]"+

" Substitutions: {{{2
" =============
syn cluster	vimSubstList	contains=vimPatSep,vimPatRegion,vimPatSepErr,vimSubstTwoBS,vimSubstRange,vimNotation
syn cluster	vimSubstRepList	contains=vimSubstSubstr,vimSubstTwoBS,vimNotation
syn cluster	vimSubstList	add=vimCollection
syn match	vimSubst	"\(:\+\s*\|^\s*\||\s*\)\<\%(s\%[ubstitute]\|sm\%[agic]\|sno\%[magic]\)[:[:alpha:]]\@!" nextgroup=vimSubstPat
syn match	vimSubst	"s\%[ubstitute][:#[:alpha:]]\@!"	nextgroup=vimSubstPat contained
syn match	vimSubst	"/\zss\%[ubstitute]\ze/"	nextgroup=vimSubstPat
syn match	vimSubst1       contained	"s\%[ubstitute]\>"	nextgroup=vimSubstPat
syn region	vimSubstPat     contained	matchgroup=vimSubstDelim start="\z([^a-zA-Z( \t[\]&]\)"rs=s+1 skip="\\\\\|\\\z1" end="\z1"re=e-1,me=e-1	 contains=@vimSubstList	nextgroup=vimSubstRep4	oneline
syn region	vimSubstRep4    contained	matchgroup=vimSubstDelim start="\z(.\)" skip="\\\\\|\\\z1" end="\z1" matchgroup=vimNotation end="<[cC][rR]>" contains=@vimSubstRepList	nextgroup=vimSubstFlagErr	oneline
syn region	vimCollection   contained transparent	start="\\\@<!\[" skip="\\\[" end="\]"	contains=vimCollClass
syn match	vimCollClassErr contained	"\[:.\{-\}:\]"
syn match	vimCollClass    contained transparent	"\[:\(alnum\|alpha\|blank\|cntrl\|digit\|graph\|lower\|print\|punct\|space\|upper\|xdigit\|return\|tab\|escape\|backspace\):\]"
syn match	vimSubstSubstr  contained	"\\z\=\d"
syn match	vimSubstTwoBS   contained	"\\\\"
syn match	vimSubstFlagErr contained	"[^< \t\r|]\+" contains=vimSubstFlags
syn match	vimSubstFlags   contained	"[&cegiIpr]\+"

" 'String': {{{2
syn match	vimString	"[^(,]'[^']\{-}\zs'"

" Marks, Registers, Addresses, Filters: {{{2
syn match	vimMark	"'[a-zA-Z0-9]\ze[-+,!]"	nextgroup=vimOper,vimMarkNumber,vimSubst
syn match	vimMark	"'[<>]\ze[-+,!]"		nextgroup=vimOper,vimMarkNumber,vimSubst
syn match	vimMark	",\zs'[<>]\ze"		nextgroup=vimOper,vimMarkNumber,vimSubst
syn match	vimMark	"[!,:]\zs'[a-zA-Z0-9]"	nextgroup=vimOper,vimMarkNumber,vimSubst
syn match	vimMark	"\<norm\%[al]\s\zs'[a-zA-Z0-9]"	nextgroup=vimOper,vimMarkNumber,vimSubst
syn match	vimMarkNumber	"[-+]\d\+"		nextgroup=vimSubst contained contains=vimOper
syn match	vimPlainMark contained	"'[a-zA-Z0-9]"

syn match	vimRegister	'[^,;[{]\zs"[a-zA-Z0-9.%#:_\-/]\ze[^a-zA-Z_":0-9]'
syn match	vimRegister	'\<norm\s\+\zs"[a-zA-Z0-9]'
syn match	vimRegister	'\<normal\s\+\zs"[a-zA-Z0-9]'
syn match	vimRegister	'@"'
syn match	vimPlainRegister contained	'"[a-zA-Z0-9\-:.%#*+=]'

syn match	vimAddress	",\zs[.$]"	skipwhite nextgroup=vimSubst1
syn match	vimAddress	"%\ze\a"	skipwhite nextgroup=vimString,vimSubst1

syn match	vimFilter contained	"^!.\{-}\(|\|$\)"		contains=vimSpecFile
syn match	vimFilter contained	"\A!.\{-}\(|\|$\)"ms=s+1	contains=vimSpecFile,vimFunction,vimFuncName,vimOperParen

" Complex repeats (:h complex-repeat) {{{2
syn match	vimCmplxRepeat	'[^a-zA-Z_/\\()]q[0-9a-zA-Z"]\>'lc=1
syn match	vimCmplxRepeat	'@[0-9a-z".=@:]\ze\($\|[^a-zA-Z]\>\)'

" Set command and associated set-options (vimOptions) with comment {{{2
syn region	vimSet		matchgroup=vimCommand start="\<\%(setl\%[ocal]\|setg\%[lobal]\|se\%[t]\)\>" skip="\%(\\\\\)*\\." end="$" matchgroup=vimNotation end="<[cC][rR]>" keepend oneline contains=vimSetEqual,vimOption,vimErrSetting,vimComment,vimSetString,vimSetMod
syn region	vimSetEqual	contained	start="[=:]\|[-+^]=" skip="\\\\\|\\\s" end="[| \t]\|$"me=e-1 contains=vimCtrlChar,vimSetSep,vimNotation,vimEnvvar oneline
syn region	vimSetString	contained	start=+="+hs=s+1	skip=+\\\\\|\\"+  end=+"+	contains=vimCtrlChar
syn match	vimSetSep	contained	"[,:]"
syn match	vimSetMod	contained	"&vim\=\|[!&?<]\|all&"

" Let {{{2
" ===
syn keyword	vimLet	let	unl[et]	skipwhite nextgroup=vimVar,vimFuncVar

" Abbreviations {{{2
" =============
syn keyword vimAbb	ab[breviate] ca[bbrev] inorea[bbrev] cnorea[bbrev] norea[bbrev] ia[bbrev] skipwhite nextgroup=vimMapMod,vimMapLhs

" Autocmd {{{2
" =======
syn match	vimAutoEventList	contained	"\(!\s\+\)\=\(\a\+,\)*\a\+"	contains=vimAutoEvent nextgroup=vimAutoCmdSpace
syn match	vimAutoCmdSpace	contained	"\s\+"	nextgroup=vimAutoCmdSfxList
syn match	vimAutoCmdSfxList	contained	"\S*"
syn keyword	vimAutoCmd	au[tocmd] do[autocmd] doautoa[ll]	skipwhite nextgroup=vimAutoEventList

" Echo and Execute -- prefer strings! {{{2
" ================
syn region	vimEcho	oneline excludenl matchgroup=vimCommand start="\<ec\%[ho]\>" skip="\(\\\\\)*\\|" end="$\||" contains=vimFunc,vimFuncVar,vimString,vimVar
syn region	vimExecute	oneline excludenl matchgroup=vimCommand start="\<exe\%[cute]\>" skip="\(\\\\\)*\\|" end="$\||\|<[cC][rR]>" contains=vimFuncVar,vimIsCommand,vimOper,vimNotation,vimOperParen,vimString,vimVar
syn match	vimEchoHL	"echohl\="	skipwhite nextgroup=vimGroup,vimHLGroup,vimEchoHLNone
syn case ignore
syn keyword	vimEchoHLNone	none
syn case match

" Maps {{{2
" ====
syn match	vimMap		"\<map\>!\=\ze\s*[^(]" skipwhite nextgroup=vimMapMod,vimMapLhs
syn keyword	vimMap		cm[ap] cno[remap] im[ap] ino[remap] lm[ap] ln[oremap] nm[ap] nn[oremap] no[remap] om[ap] ono[remap] smap snor[emap] vm[ap] vn[oremap] xm[ap] xn[oremap] skipwhite nextgroup=vimMapBang,vimMapMod,vimMapLhs
syn keyword	vimMap		mapc[lear] smapc[lear]
syn keyword	vimUnmap		cu[nmap] iu[nmap] lu[nmap] nun[map] ou[nmap] sunm[ap] unm[ap] unm[ap] vu[nmap] xu[nmap] skipwhite nextgroup=vimMapBang,vimMapMod,vimMapLhs
syn match	vimMapLhs	contained	"\S\+"			contains=vimNotation,vimCtrlChar skipwhite nextgroup=vimMapRhs
syn match	vimMapBang	contained	"!"			skipwhite nextgroup=vimMapMod,vimMapLhs
syn match	vimMapMod	contained	"\c<\(buffer\|expr\|\(local\)\=leader\|plug\|script\|sid\|unique\|silent\)\+>" contains=vimMapModKey,vimMapModErr skipwhite nextgroup=vimMapMod,vimMapLhs
syn match	vimMapRhs	contained	".*" contains=vimNotation,vimCtrlChar	skipnl nextgroup=vimMapRhsExtend
syn match	vimMapRhsExtend	contained	"^\s*\\.*$"			contains=vimNotation,vimCtrlChar,vimContinue	skipnl nextgroup=vimMapRhsExtend
syn case ignore
syn keyword	vimMapModKey	contained	buffer	expr	leader	localleader	plug	script	sid	silent	unique
syn case match

" Menus {{{2
" =====
syn cluster	vimMenuList contains=vimMenuBang,vimMenuPriority,vimMenuName,vimMenuMod
syn keyword	vimCommand	am[enu] an[oremenu] aun[menu] cme[nu] cnoreme[nu] cunme[nu] ime[nu] inoreme[nu] iunme[nu] me[nu] nme[nu] nnoreme[nu] noreme[nu] nunme[nu] ome[nu] onoreme[nu] ounme[nu] unme[nu] vme[nu] vnoreme[nu] vunme[nu] skipwhite nextgroup=@vimMenuList
syn match	vimMenuName	"[^ \t\\<]\+"	contained nextgroup=vimMenuNameMore,vimMenuMap
syn match	vimMenuPriority	"\d\+\(\.\d\+\)*"	contained skipwhite nextgroup=vimMenuName
syn match	vimMenuNameMore	"\c\\\s\|<tab>\|\\\."	contained nextgroup=vimMenuName,vimMenuNameMore contains=vimNotation
syn match	vimMenuMod    contained	"\c<\(script\|silent\)\+>"  skipwhite contains=vimMapModKey,vimMapModErr nextgroup=@vimMenuList
syn match	vimMenuMap	"\s"	contained skipwhite nextgroup=vimMenuRhs
syn match	vimMenuRhs	".*$"	contained contains=vimString,vimComment,vimIsCommand
syn match	vimMenuBang	"!"	contained skipwhite nextgroup=@vimMenuList

" Angle-Bracket Notation (tnx to Michael Geddes) {{{2
" ======================
syn case ignore
syn match	vimNotation	"\(\\\|<lt>\)\=<\([scamd]-\)\{0,4}x\=\(f\d\{1,2}\|[^ \t:]\|cr\|lf\|linefeed\|return\|k\=del\%[ete]\|bs\|backspace\|tab\|esc\|right\|left\|help\|undo\|insert\|ins\|k\=home\|k\=end\|kplus\|kminus\|kdivide\|kmultiply\|kenter\|kpoint\|space\|k\=\(page\)\=\(\|down\|up\|k\d\>\)\)>" contains=vimBracket
syn match	vimNotation	"\(\\\|<lt>\)\=<\([scam2-4]-\)\{0,4}\(right\|left\|middle\)\(mouse\)\=\(drag\|release\)\=>"	contains=vimBracket
syn match	vimNotation	"\(\\\|<lt>\)\=<\(bslash\|plug\|sid\|space\|bar\|nop\|nul\|lt\)>"		contains=vimBracket
syn match	vimNotation	'\(\\\|<lt>\)\=<C-R>[0-9a-z"%#:.\-=]'he=e-1			contains=vimBracket
syn match	vimNotation	'\(\\\|<lt>\)\=<\%(q-\)\=\(line[12]\|count\|bang\|reg\|args\|f-args\|lt\)>'	contains=vimBracket
syn match	vimNotation	"\(\\\|<lt>\)\=<\([cas]file\|abuf\|amatch\|cword\|cWORD\|client\)>"		contains=vimBracket
syn match	vimBracket contained	"[\\<>]"
syn case match

" User Function Highlighting {{{2
" (following Gautam Iyer's suggestion)
" ==========================
syn match vimFunc		"\%(\%([sSgGbBwWtTlL]:\|<[sS][iI][dD]>\)\=\%([a-zA-Z0-9_]\+\.\)*\I[a-zA-Z0-9_.]*\)\ze\s*("		contains=vimFuncName,vimUserFunc,vimExecute
syn match vimUserFunc contained	"\%(\%([sSgGbBwWtTlL]:\|<[sS][iI][dD]>\)\=\%([a-zA-Z0-9_]\+\.\)*\I[a-zA-Z0-9_.]*\)\|\<\u[a-zA-Z0-9.]*\>\|\<if\>"	contains=vimNotation
syn match vimNotFunc	"\<if\>\|\<el\%[seif]\>\|\<return\>\|\<while\>"

" Errors And Warnings: {{{2
" ====================
if !exists("g:vimsyn_noerror") && !exists("g:vimsyn_novimfunctionerror")
 syn match	vimFunctionError	"\s\zs[a-z0-9]\i\{-}\ze\s*("			contained contains=vimFuncKey,vimFuncBlank
" syn match	vimFunctionError	"\s\zs\%(<[sS][iI][dD]>\|[sSgGbBwWtTlL]:\)[0-9]\i\{-}\ze\s*("	contained contains=vimFuncKey,vimFuncBlank
 syn match	vimElseIfErr	"\<else\s\+if\>"
 syn match	vimBufnrWarn	/\<bufnr\s*(\s*["']\.['"]\s*)/
endif

" Norm {{{2
" ====
syn match	vimNorm		"\<norm\%[al]!\=" skipwhite nextgroup=vimNormCmds
syn match	vimNormCmds contained	".*$"

" Syntax {{{2
"=======
syn match	vimGroupList	contained	"@\=[^ \t,]*"	contains=vimGroupSpecial,vimPatSep
syn match	vimGroupList	contained	"@\=[^ \t,]*,"	nextgroup=vimGroupList contains=vimGroupSpecial,vimPatSep
syn keyword	vimGroupSpecial	contained	ALL	ALLBUT	CONTAINED	TOP
if !exists("g:vimsyn_noerror") && !exists("g:vimsyn_novimsynerror")
 syn match	vimSynError	contained	"\i\+"
 syn match	vimSynError	contained	"\i\+="	nextgroup=vimGroupList
endif
syn match	vimSynContains	contained	"\<contain\(s\|edin\)="	nextgroup=vimGroupList
syn match	vimSynKeyContainedin	contained	"\<containedin="	nextgroup=vimGroupList
syn match	vimSynNextgroup	contained	"nextgroup="	nextgroup=vimGroupList

syn match	vimSyntax	"\<sy\%[ntax]\>"	contains=vimCommand skipwhite nextgroup=vimSynType,vimComment
syn match	vimAuSyntax	contained	"\s+sy\%[ntax]"	contains=vimCommand skipwhite nextgroup=vimSynType,vimComment
syn cluster vimFuncBodyList add=vimSyntax

" Syntax: case {{{2
syn keyword	vimSynType	contained	case	skipwhite nextgroup=vimSynCase,vimSynCaseError
if !exists("g:vimsyn_noerror") && !exists("g:vimsyn_novimsyncaseerror")
 syn match	vimSynCaseError	contained	"\i\+"
endif
syn keyword	vimSynCase	contained	ignore	match

" Syntax: clear {{{2
syn keyword	vimSynType	contained	clear	skipwhite nextgroup=vimGroupList

" Syntax: cluster {{{2
syn keyword	vimSynType	contained	cluster	skipwhite nextgroup=vimClusterName
syn region	vimClusterName	contained	matchgroup=vimGroupName start="\h\w*" skip="\\\\\|\\|" matchgroup=vimSep end="$\||" contains=vimGroupAdd,vimGroupRem,vimSynContains,vimSynError
syn match	vimGroupAdd	contained	"add="	nextgroup=vimGroupList
syn match	vimGroupRem	contained	"remove="	nextgroup=vimGroupList
syn cluster vimFuncBodyList add=vimSynType,vimGroupAdd,vimGroupRem

" Syntax: include {{{2
syn keyword	vimSynType	contained	include	skipwhite nextgroup=vimGroupList
syn cluster vimFuncBodyList add=vimSynType

" Syntax: keyword {{{2
syn cluster	vimSynKeyGroup	contains=vimSynNextgroup,vimSynKeyOpt,vimSynKeyContainedin
syn keyword	vimSynType	contained	keyword	skipwhite nextgroup=vimSynKeyRegion
syn region	vimSynKeyRegion	contained oneline keepend	matchgroup=vimGroupName start="\h\w*" skip="\\\\\|\\|" matchgroup=vimSep end="|\|$" contains=@vimSynKeyGroup
syn match	vimSynKeyOpt	contained	"\<\(conceal\|contained\|transparent\|skipempty\|skipwhite\|skipnl\)\>"
syn cluster vimFuncBodyList add=vimSynType

" Syntax: match {{{2
syn cluster	vimSynMtchGroup	contains=vimMtchComment,vimSynContains,vimSynError,vimSynMtchOpt,vimSynNextgroup,vimSynRegPat,vimNotation
syn keyword	vimSynType	contained	match	skipwhite nextgroup=vimSynMatchRegion
syn region	vimSynMatchRegion	contained keepend	matchgroup=vimGroupName start="\h\w*" matchgroup=vimSep end="|\|$" contains=@vimSynMtchGroup
syn match	vimSynMtchOpt	contained	"\<\(conceal\|transparent\|contained\|excludenl\|skipempty\|skipwhite\|display\|extend\|skipnl\|fold\)\>"
if has("conceal")
 syn match	vimSynMtchOpt	contained	"\<cchar="	nextgroup=vimSynMtchCchar
 syn match	vimSynMtchCchar	contained	"\S"
endif
syn cluster vimFuncBodyList add=vimSynMtchGroup

" Syntax: off and on {{{2
syn keyword	vimSynType	contained	enable	list	manual	off	on	reset

" Syntax: region {{{2
syn cluster	vimSynRegPatGroup	contains=vimPatSep,vimNotPatSep,vimSynPatRange,vimSynNotPatRange,vimSubstSubstr,vimPatRegion,vimPatSepErr,vimNotation
syn cluster	vimSynRegGroup	contains=vimSynContains,vimSynNextgroup,vimSynRegOpt,vimSynReg,vimSynMtchGrp
syn keyword	vimSynType	contained	region	skipwhite nextgroup=vimSynRegion
syn region	vimSynRegion	contained keepend	matchgroup=vimGroupName start="\h\w*" skip="\\\\\|\\|" end="|\|$" contains=@vimSynRegGroup
syn match	vimSynRegOpt	contained	"\<\(conceal\(ends\)\=\|transparent\|contained\|excludenl\|skipempty\|skipwhite\|display\|keepend\|oneline\|extend\|skipnl\|fold\)\>"
syn match	vimSynReg	contained	"\(start\|skip\|end\)="he=e-1	nextgroup=vimSynRegPat
syn match	vimSynMtchGrp	contained	"matchgroup="	nextgroup=vimGroup,vimHLGroup
syn region	vimSynRegPat	contained extend	start="\z([-`~!@#$%^&*_=+;:'",./?]\)"  skip="\\\\\|\\\z1"  end="\z1"  contains=@vimSynRegPatGroup skipwhite nextgroup=vimSynPatMod,vimSynReg
syn match	vimSynPatMod	contained	"\(hs\|ms\|me\|hs\|he\|rs\|re\)=[se]\([-+]\d\+\)\="
syn match	vimSynPatMod	contained	"\(hs\|ms\|me\|hs\|he\|rs\|re\)=[se]\([-+]\d\+\)\=," nextgroup=vimSynPatMod
syn match	vimSynPatMod	contained	"lc=\d\+"
syn match	vimSynPatMod	contained	"lc=\d\+," nextgroup=vimSynPatMod
syn region	vimSynPatRange	contained	start="\["	skip="\\\\\|\\]"   end="]"
syn match	vimSynNotPatRange	contained	"\\\\\|\\\["
syn match	vimMtchComment	contained	'"[^"]\+$'
syn cluster vimFuncBodyList add=vimSynType

" Syntax: sync {{{2
" ============
syn keyword vimSynType	contained	sync	skipwhite	nextgroup=vimSyncC,vimSyncLines,vimSyncMatch,vimSyncError,vimSyncLinebreak,vimSyncLinecont,vimSyncRegion
if !exists("g:vimsyn_noerror") && !exists("g:vimsyn_novimsyncerror")
 syn match	vimSyncError	contained	"\i\+"
endif
syn keyword	vimSyncC	contained	ccomment	clear	fromstart
syn keyword	vimSyncMatch	contained	match	skipwhite	nextgroup=vimSyncGroupName
syn keyword	vimSyncRegion	contained	region	skipwhite	nextgroup=vimSynReg
syn match	vimSyncLinebreak	contained	"\<linebreaks="	skipwhite	nextgroup=vimNumber
syn keyword	vimSyncLinecont	contained	linecont	skipwhite	nextgroup=vimSynRegPat
syn match	vimSyncLines	contained	"\(min\|max\)\=lines="	nextgroup=vimNumber
syn match	vimSyncGroupName	contained	"\h\w*"	skipwhite	nextgroup=vimSyncKey
syn match	vimSyncKey	contained	"\<groupthere\|grouphere\>"	skipwhite nextgroup=vimSyncGroup
syn match	vimSyncGroup	contained	"\h\w*"	skipwhite	nextgroup=vimSynRegPat,vimSyncNone
syn keyword	vimSyncNone	contained	NONE

" Additional IsCommand, here by reasons of precedence {{{2
" ====================
syn match	vimIsCommand	"<Bar>\s*\a\+"	transparent contains=vimCommand,vimNotation

" Highlighting {{{2
" ============
syn cluster	vimHighlightCluster		contains=vimHiLink,vimHiClear,vimHiKeyList,vimComment
if !exists("g:vimsyn_noerror") && !exists("g:vimsyn_novimhictermerror")
 syn match	vimHiCtermError	contained	"[^0-9]\i*"
endif
syn match	vimHighlight	"\<hi\%[ghlight]\>"	skipwhite nextgroup=vimHiBang,@vimHighlightCluster
syn match	vimHiBang	contained	"!"	skipwhite nextgroup=@vimHighlightCluster

syn match	vimHiGroup	contained	"\i\+"
syn case ignore
syn keyword	vimHiAttrib	contained	none bold inverse italic reverse standout underline undercurl
syn keyword	vimFgBgAttrib	contained	none bg background fg foreground
syn case match
syn match	vimHiAttribList	contained	"\i\+"	contains=vimHiAttrib
syn match	vimHiAttribList	contained	"\i\+,"he=e-1	contains=vimHiAttrib nextgroup=vimHiAttribList
syn case ignore
syn keyword	vimHiCtermColor	contained	black blue brown cyan darkblue darkcyan darkgray darkgreen darkgrey darkmagenta darkred darkyellow gray green grey lightblue lightcyan lightgray lightgreen lightgrey lightmagenta lightred magenta red white yellow
syn match	vimHiCtermColor	contained	"\<color\d\{1,3}\>"

syn case match
syn match	vimHiFontname	contained	"[a-zA-Z\-*]\+"
syn match	vimHiGuiFontname	contained	"'[a-zA-Z\-* ]\+'"
syn match	vimHiGuiRgb	contained	"#\x\{6}"

" Highlighting: hi group key=arg ... {{{2
syn cluster	vimHiCluster contains=vimGroup,vimHiGroup,vimHiTerm,vimHiCTerm,vimHiStartStop,vimHiCtermFgBg,vimHiGui,vimHiGuiFont,vimHiGuiFgBg,vimHiKeyError,vimNotation
syn region	vimHiKeyList	contained oneline start="\i\+" skip="\\\\\|\\|" end="$\||"	contains=@vimHiCluster
if !exists("g:vimsyn_noerror") && !exists("g:vimsyn_vimhikeyerror")
 syn match	vimHiKeyError	contained	"\i\+="he=e-1
endif
syn match	vimHiTerm	contained	"\cterm="he=e-1		nextgroup=vimHiAttribList
syn match	vimHiStartStop	contained	"\c\(start\|stop\)="he=e-1	nextgroup=vimHiTermcap,vimOption
syn match	vimHiCTerm	contained	"\ccterm="he=e-1		nextgroup=vimHiAttribList
syn match	vimHiCtermFgBg	contained	"\ccterm[fb]g="he=e-1	nextgroup=vimHiNmbr,vimHiCtermColor,vimFgBgAttrib,vimHiCtermError
syn match	vimHiGui	contained	"\cgui="he=e-1		nextgroup=vimHiAttribList
syn match	vimHiGuiFont	contained	"\cfont="he=e-1		nextgroup=vimHiFontname
syn match	vimHiGuiFgBg	contained	"\cgui\%([fb]g\|sp\)="he=e-1	nextgroup=vimHiGroup,vimHiGuiFontname,vimHiGuiRgb,vimFgBgAttrib
syn match	vimHiTermcap	contained	"\S\+"		contains=vimNotation
syn match	vimHiNmbr	contained	'\d\+'

" Highlight: clear {{{2
syn keyword	vimHiClear	contained	clear	nextgroup=vimHiGroup

" Highlight: link {{{2
syn region	vimHiLink	contained oneline matchgroup=vimCommand start="\(\<hi\%[ghlight]\s\+\)\@<=\(\(def\%[ault]\s\+\)\=link\>\|\<def\>\)" end="$"	contains=vimHiGroup,vimGroup,vimHLGroup,vimNotation
syn cluster vimFuncBodyList add=vimHiLink

" Control Characters {{{2
" ==================
syn match	vimCtrlChar	"[--]"

" Beginners - Patterns that involve ^ {{{2
" =========
syn match	vimLineComment	+^[ \t:]*".*$+	contains=@vimCommentGroup,vimCommentString,vimCommentTitle
syn match	vimCommentTitle	'"\s*\%([sS]:\|\h\w*#\)\=\u\w*\(\s\+\u\w*\)*:'hs=s+1	contained contains=vimCommentTitleLeader,vimTodo,@vimCommentGroup
syn match	vimContinue	"^\s*\\"
syn region	vimString	start="^\s*\\\z(['"]\)" skip='\\\\\|\\\z1' end="\z1" oneline keepend contains=@vimStringGroup,vimContinue
syn match	vimCommentTitleLeader	'"\s\+'ms=s+1	contained

" Searches And Globals: {{{2
" ====================
syn match	vimSearch	'^\s*[/?].*'		contains=vimSearchDelim
syn match	vimSearchDelim	'^\s*\zs[/?]\|[/?]$'	contained
syn region	vimGlobal	matchgroup=Statement start='\<g\%[lobal]!\=/'  skip='\\.' end='/'	skipwhite nextgroup=vimSubst
syn region	vimGlobal	matchgroup=Statement start='\<v\%[global]!\=/' skip='\\.' end='/'	skipwhite nextgroup=vimSubst

" Scripts  : perl,ruby : Benoit Cerrina {{{2
" =======    python,tcl: Johannes Zellner
"            lua

" Allows users to specify the type of embedded script highlighting
" they want:  (perl/python/ruby/tcl support)
"   g:vimsyn_embed == 0   : don't embed any scripts
"   g:vimsyn_embed ~= 'l' : embed lua      (but only if vim supports it)
"   g:vimsyn_embed ~= 'm' : embed mzscheme (but only if vim supports it)
"   g:vimsyn_embed ~= 'p' : embed perl     (but only if vim supports it)
"   g:vimsyn_embed ~= 'P' : embed python   (but only if vim supports it)
"   g:vimsyn_embed ~= 'r' : embed ruby     (but only if vim supports it)
"   g:vimsyn_embed ~= 't' : embed tcl      (but only if vim supports it)
if !exists("g:vimsyn_embed")
 let g:vimsyn_embed= "lmpPr"
endif

" [-- lua --] {{{3
let s:luapath= fnameescape(expand("<sfile>:p:h")."/lua.vim")
if !filereadable(s:luapath)
 for s:luapath in split(globpath(&rtp,"syntax/lua.vim"),"\n")
  if filereadable(fnameescape(s:luapath))
   let s:luapath= fnameescape(s:luapath)
   break
  endif
 endfor
endif
if (g:vimsyn_embed =~ 'l' && has("lua")) && filereadable(s:luapath)
 unlet! b:current_syntax
 exe "syn include @vimLuaScript ".s:luapath
 if exists("g:vimsyn_folding") && g:vimsyn_folding =~ 'l'
  syn region vimLuaRegion fold matchgroup=vimScriptDelim start=+lua\s*<<\s*\z(.*\)$+ end=+^\z1$+	contains=@vimLuaScript
  syn region vimLuaRegion fold matchgroup=vimScriptDelim start=+lua\s*<<\s*$+ end=+\.$+		contains=@vimLuaScript
 else
  syn region vimLuaRegion matchgroup=vimScriptDelim start=+lua\s*<<\s*\z(.*\)$+ end=+^\z1$+	contains=@vimLuaScript
  syn region vimLuaRegion matchgroup=vimScriptDelim start=+lua\s*<<\s*$+ end=+\.$+		contains=@vimLuaScript
 endif
 syn cluster vimFuncBodyList	add=vimLuaRegion
else
 syn region vimEmbedError start=+lua\s*<<\s*\z(.*\)$+ end=+^\z1$+
 syn region vimEmbedError start=+lua\s*<<\s*$+ end=+\.$+
endif
unlet s:luapath

" [-- perl --] {{{3
let s:perlpath= fnameescape(expand("<sfile>:p:h")."/perl.vim")
if !filereadable(s:perlpath)
 for s:perlpath in split(globpath(&rtp,"syntax/perl.vim"),"\n")
  if filereadable(fnameescape(s:perlpath))
   let s:perlpath= fnameescape(s:perlpath)
   break
  endif
 endfor
endif
if (g:vimsyn_embed =~ 'p' && has("perl")) && filereadable(s:perlpath)
 unlet! b:current_syntax
 exe "syn include @vimPerlScript ".s:perlpath
 if exists("g:vimsyn_folding") && g:vimsyn_folding =~ 'p'
  syn region vimPerlRegion fold matchgroup=vimScriptDelim start=+pe\%[rl]\s*<<\s*\z(.*\)$+ end=+^\z1$+	contains=@vimPerlScript
  syn region vimPerlRegion fold matchgroup=vimScriptDelim start=+pe\%[rl]\s*<<\s*$+ end=+\.$+	contains=@vimPerlScript
 else
  syn region vimPerlRegion matchgroup=vimScriptDelim start=+pe\%[rl]\s*<<\s*\z(.*\)$+ end=+^\z1$+	contains=@vimPerlScript
  syn region vimPerlRegion matchgroup=vimScriptDelim start=+pe\%[rl]\s*<<\s*$+ end=+\.$+		contains=@vimPerlScript
 endif
 syn cluster vimFuncBodyList	add=vimPerlRegion
else
 syn region vimEmbedError start=+pe\%[rl]\s*<<\s*\z(.*\)$+ end=+^\z1$+
 syn region vimEmbedError start=+pe\%[rl]\s*<<\s*$+ end=+\.$+
endif
unlet s:perlpath

" [-- ruby --] {{{3
let s:rubypath= fnameescape(expand("<sfile>:p:h")."/ruby.vim")
if !filereadable(s:rubypath)
 for s:rubypath in split(globpath(&rtp,"syntax/ruby.vim"),"\n")
  if filereadable(fnameescape(s:rubypath))
   let s:rubypath= fnameescape(s:rubypath)
   break
  endif
 endfor
endif
if (g:vimsyn_embed =~ 'r' && has("ruby")) && filereadable(s:rubypath)
 unlet! b:current_syntax
 exe "syn include @vimRubyScript ".s:rubypath
 if exists("g:vimsyn_folding") && g:vimsyn_folding =~ 'r'
  syn region vimRubyRegion fold matchgroup=vimScriptDelim start=+rub[y]\s*<<\s*\z(.*\)$+ end=+^\z1$+	contains=@vimRubyScript
 else
  syn region vimRubyRegion matchgroup=vimScriptDelim start=+rub[y]\s*<<\s*\z(.*\)$+ end=+^\z1$+	contains=@vimRubyScript
 endif
 syn region vimRubyRegion matchgroup=vimScriptDelim start=+rub[y]\s*<<\s*$+ end=+\.$+		contains=@vimRubyScript
 syn cluster vimFuncBodyList	add=vimRubyRegion
else
 syn region vimEmbedError start=+rub[y]\s*<<\s*\z(.*\)$+ end=+^\z1$+
 syn region vimEmbedError start=+rub[y]\s*<<\s*$+ end=+\.$+
endif
unlet s:rubypath

" [-- python --] {{{3
let s:pythonpath= fnameescape(expand("<sfile>:p:h")."/python.vim")
if !filereadable(s:pythonpath)
 for s:pythonpath in split(globpath(&rtp,"syntax/python.vim"),"\n")
  if filereadable(fnameescape(s:pythonpath))
   let s:pythonpath= fnameescape(s:pythonpath)
   break
  endif
 endfor
endif
if g:vimsyn_embed =~ 'P' && (has("python") || has("python3")) && filereadable(s:pythonpath)
 unlet! b:current_syntax
 exe "syn include @vimPythonScript ".s:pythonpath
 if exists("g:vimsyn_folding") && g:vimsyn_folding =~ 'P'
  syn region vimPythonRegion fold matchgroup=vimScriptDelim start=+py\%[thon]3\=\s*<<\s*\z(.*\)$+ end=+^\z1$+	contains=@vimPythonScript
  syn region vimPythonRegion fold matchgroup=vimScriptDelim start=+py\%[thon]3\=\s*<<\s*$+ end=+\.$+		contains=@vimPythonScript
 else
  syn region vimPythonRegion matchgroup=vimScriptDelim start=+py\%[thon]3\=\s*<<\s*\z(.*\)$+ end=+^\z1$+		contains=@vimPythonScript
  syn region vimPythonRegion matchgroup=vimScriptDelim start=+py\%[thon]3\=\s*<<\s*$+ end=+\.$+		contains=@vimPythonScript
 endif
 syn cluster vimFuncBodyList	add=vimPythonRegion
else
 syn region vimEmbedError start=+py\%[thon]3\=\s*<<\s*\z(.*\)$+ end=+^\z1$+
 syn region vimEmbedError start=+py\%[thon]3\=\s*<<\s*$+ end=+\.$+
endif
unlet s:pythonpath

" [-- tcl --] {{{3
if has("win32") || has("win95") || has("win64") || has("win16")
 " apparently has("tcl") has been hanging vim on some windows systems with cygwin
 let s:trytcl= (&shell !~ '\<\%(bash\>\|4[nN][tT]\|\<zsh\)\>\%(\.exe\)\=$')
else
 let s:trytcl= 1
endif
if s:trytcl
 let s:tclpath= fnameescape(expand("<sfile>:p:h")."/tcl.vim")
 if !filereadable(s:tclpath)
  for s:tclpath in split(globpath(&rtp,"syntax/tcl.vim"),"\n")
   if filereadable(fnameescape(s:tclpath))
    let s:tclpath= fnameescape(s:tclpath)
    break
   endif
  endfor
 endif
 if (g:vimsyn_embed =~ 't' && has("tcl")) && filereadable(s:tclpath)
  unlet! b:current_syntax
  exe "syn include @vimTclScript ".s:tclpath
  if exists("g:vimsyn_folding") && g:vimsyn_folding =~ 't'
   syn region vimTclRegion fold matchgroup=vimScriptDelim start=+tc[l]\=\s*<<\s*\z(.*\)$+ end=+^\z1$+	contains=@vimTclScript
   syn region vimTclRegion fold matchgroup=vimScriptDelim start=+tc[l]\=\s*<<\s*$+ end=+\.$+	contains=@vimTclScript
  else
   syn region vimTclRegion matchgroup=vimScriptDelim start=+tc[l]\=\s*<<\s*\z(.*\)$+ end=+^\z1$+	contains=@vimTclScript
   syn region vimTclRegion matchgroup=vimScriptDelim start=+tc[l]\=\s*<<\s*$+ end=+\.$+		contains=@vimTclScript
  endif
  syn cluster vimFuncBodyList	add=vimTclScript
 else
  syn region vimEmbedError start=+tc[l]\=\s*<<\s*\z(.*\)$+ end=+^\z1$+
  syn region vimEmbedError start=+tc[l]\=\s*<<\s*$+ end=+\.$+
 endif
 unlet s:tclpath
else
 syn region vimEmbedError start=+tc[l]\=\s*<<\s*\z(.*\)$+ end=+^\z1$+
 syn region vimEmbedError start=+tc[l]\=\s*<<\s*$+ end=+\.$+
endif
unlet s:trytcl

" [-- mzscheme --] {{{3
let s:mzschemepath= fnameescape(expand("<sfile>:p:h")."/scheme.vim")
if !filereadable(s:mzschemepath)
 for s:mzschemepath in split(globpath(&rtp,"syntax/mzscheme.vim"),"\n")
  if filereadable(fnameescape(s:mzschemepath))
   let s:mzschemepath= fnameescape(s:mzschemepath)
   break
  endif
 endfor
endif
if (g:vimsyn_embed =~ 'm' && has("mzscheme")) && filereadable(s:mzschemepath)
 unlet! b:current_syntax
 let iskKeep= &isk
 exe "syn include @vimMzSchemeScript ".s:mzschemepath
 let &isk= iskKeep
 if exists("g:vimsyn_folding") && g:vimsyn_folding =~ 'm'
  syn region vimMzSchemeRegion fold matchgroup=vimScriptDelim start=+mz\%[scheme]\s*<<\s*\z(.*\)$+ end=+^\z1$+	contains=@vimMzSchemeScript
  syn region vimMzSchemeRegion fold matchgroup=vimScriptDelim start=+mz\%[scheme]\s*<<\s*$+ end=+\.$+		contains=@vimMzSchemeScript
 else
  syn region vimMzSchemeRegion matchgroup=vimScriptDelim start=+mz\%[scheme]\s*<<\s*\z(.*\)$+ end=+^\z1$+		contains=@vimMzSchemeScript
  syn region vimMzSchemeRegion matchgroup=vimScriptDelim start=+mz\%[scheme]\s*<<\s*$+ end=+\.$+		contains=@vimMzSchemeScript
 endif
 syn cluster vimFuncBodyList	add=vimMzSchemeRegion
else
 syn region vimEmbedError start=+mz\%[scheme]\s*<<\s*\z(.*\)$+ end=+^\z1$+
 syn region vimEmbedError start=+mz\%[scheme]\s*<<\s*$+ end=+\.$+
endif
unlet s:mzschemepath

" Synchronize (speed) {{{2
"============
if exists("g:vimsyn_minlines")
 exe "syn sync minlines=".g:vimsyn_minlines
endif
if exists("g:vimsyn_maxlines")
 exe "syn sync maxlines=".g:vimsyn_maxlines
else
 syn sync maxlines=60
endif
syn sync linecont	"^\s\+\\"
syn sync match vimAugroupSyncA	groupthere NONE	"\<aug\%[roup]\>\s\+[eE][nN][dD]"

" ====================
" Highlighting Settings {{{2
" ====================


if !exists("g:vimsyn_noerror")
 hi def link vimBehaveError	vimError
 hi def link vimCollClassErr	vimError
 hi def link vimErrSetting	vimError
 hi def link vimEmbedError	vimError
 hi def link vimFTError	vimError
 hi def link vimFunctionError	vimError
 hi def link vimFunc         	vimError
 hi def link vimHiAttribList	vimError
 hi def link vimHiCtermError	vimError
 hi def link vimHiKeyError	vimError
 hi def link vimKeyCodeError	vimError
 hi def link vimMapModErr	vimError
 hi def link vimSubstFlagErr	vimError
 hi def link vimSynCaseError	vimError
 hi def link vimBufnrWarn	vimWarn
endif

hi def link vimAbb	vimCommand
hi def link vimAddress	vimMark
hi def link vimAugroupKey	vimCommand
hi def link vimAuHighlight	vimHighlight
hi def link vimAutoCmdOpt	vimOption
hi def link vimAutoCmd	vimCommand
hi def link vimAutoEvent	Type
hi def link vimAutoSet	vimCommand
hi def link vimBehaveModel	vimBehave
hi def link vimBehave	vimCommand
hi def link vimBracket	Delimiter
hi def link vimCmplxRepeat	SpecialChar
hi def link vimCommand	Statement
hi def link vimComment	Comment
hi def link vimCommentString	vimString
hi def link vimCommentTitle	PreProc
hi def link vimCondHL	vimCommand
hi def link vimContinue	Special
hi def link vimCtrlChar	SpecialChar
hi def link vimEchoHLNone	vimGroup
hi def link vimEchoHL	vimCommand
hi def link vimElseIfErr	Error
hi def link vimElseif	vimCondHL
hi def link vimEnvvar	PreProc
hi def link vimError	Error
hi def link vimFBVar	vimVar
hi def link vimFgBgAttrib	vimHiAttrib
hi def link vimFold	Folded
hi def link vimFTCmd	vimCommand
hi def link vimFTOption	vimSynType
hi def link vimFuncKey	vimCommand
hi def link vimFuncName	Function
hi def link vimFuncSID	Special
hi def link vimFuncVar	Identifier
hi def link vimGroupAdd	vimSynOption
hi def link vimGroupName	vimGroup
hi def link vimGroupRem	vimSynOption
hi def link vimGroupSpecial	Special
hi def link vimGroup	Type
hi def link vimHiAttrib	PreProc
hi def link vimHiClear	vimHighlight
hi def link vimHiCtermFgBg	vimHiTerm
hi def link vimHiCTerm	vimHiTerm
hi def link vimHighlight	vimCommand
hi def link vimHiGroup	vimGroupName
hi def link vimHiGuiFgBg	vimHiTerm
hi def link vimHiGuiFont	vimHiTerm
hi def link vimHiGuiRgb	vimNumber
hi def link vimHiGui	vimHiTerm
hi def link vimHiNmbr	Number
hi def link vimHiStartStop	vimHiTerm
hi def link vimHiTerm	Type
hi def link vimHLGroup	vimGroup
hi def link vimHLMod	PreProc
hi def link vimInsert	vimString
hi def link vimKeyCode	vimSpecFile
hi def link vimKeyword	Statement
hi def link vimLet	vimCommand
hi def link vimLineComment	vimComment
hi def link vimMapBang	vimCommand
hi def link vimMapModKey	vimFuncSID
hi def link vimMapMod	vimBracket
hi def link vimMap	vimCommand
hi def link vimMark	Number
hi def link vimMarkNumber	vimNumber
hi def link vimMenuMod	vimMapMod
hi def link vimMenuNameMore	vimMenuName
hi def link vimMenuName	PreProc
hi def link vimMtchComment	vimComment
hi def link vimNorm	vimCommand
hi def link vimNotation	Special
hi def link vimNotFunc	vimCommand
hi def link vimNotPatSep	vimString
hi def link vimNumber	Number
hi def link vimOperError	Error
hi def link vimOper	Operator
hi def link vimOption	PreProc
hi def link vimParenSep	Delimiter
hi def link vimPatSepErr	vimPatSep
hi def link vimPatSepR	vimPatSep
hi def link vimPatSep	SpecialChar
hi def link vimPatSepZone	vimString
hi def link vimPatSepZ	vimPatSep
hi def link vimPattern	Type
hi def link vimPlainMark	vimMark
hi def link vimPlainRegister	vimRegister
hi def link vimRegister	SpecialChar
hi def link vimScriptDelim	Comment
hi def link vimSearchDelim	Statement
hi def link vimSearch	vimString
hi def link vimSep	Delimiter
hi def link vimSetMod	vimOption
hi def link vimSetSep	Statement
hi def link vimSetString	vimString
hi def link vimSpecFile	Identifier
hi def link vimSpecFileMod	vimSpecFile
hi def link vimSpecial	Type
hi def link vimStatement	Statement
hi def link vimStringCont	vimString
hi def link vimString	String
hi def link vimSubst1	vimSubst
hi def link vimSubstDelim	Delimiter
hi def link vimSubstFlags	Special
hi def link vimSubstSubstr	SpecialChar
hi def link vimSubstTwoBS	vimString
hi def link vimSubst	vimCommand
hi def link vimSynCaseError	Error
hi def link vimSynCase	Type
hi def link vimSyncC	Type
hi def link vimSyncError	Error
hi def link vimSyncGroupName	vimGroupName
hi def link vimSyncGroup	vimGroupName
hi def link vimSyncKey	Type
hi def link vimSyncNone	Type
hi def link vimSynContains	vimSynOption
hi def link vimSynError	Error
hi def link vimSynKeyContainedin	vimSynContains
hi def link vimSynKeyOpt	vimSynOption
hi def link vimSynMtchGrp	vimSynOption
hi def link vimSynMtchOpt	vimSynOption
hi def link vimSynNextgroup	vimSynOption
hi def link vimSynNotPatRange	vimSynRegPat
hi def link vimSynOption	Special
hi def link vimSynPatRange	vimString
hi def link vimSynRegOpt	vimSynOption
hi def link vimSynRegPat	vimString
hi def link vimSynReg	Type
hi def link vimSyntax	vimCommand
hi def link vimSynType	vimSpecial
hi def link vimTodo	Todo
hi def link vimUnmap	vimMap
hi def link vimUserAttrbCmpltFunc	Special
hi def link vimUserAttrbCmplt	vimSpecial
hi def link vimUserAttrbKey	vimOption
hi def link vimUserAttrb	vimSpecial
hi def link vimUserCmdError	Error
hi def link vimUserCommand	vimCommand
hi def link vimUserFunc	Normal
hi def link vimVar	Identifier
hi def link vimWarn	WarningMsg

" Current Syntax Variable: {{{2
let b:current_syntax = "vim"

" ---------------------------------------------------------------------
" Cleanup: {{{1
let &cpo = s:keepcpo
unlet s:keepcpo
" vim:ts=18  fdm=marker
