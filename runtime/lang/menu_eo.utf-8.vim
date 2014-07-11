" Menu Translations:	Esperanto
" Maintainer:		Dominique PELLE <dominique.pelle@free.fr>
" Last Change:		2012 May 01
" 
" Quit when menu translations have already been done.
if exists("did_menu_trans")
  finish
endif
let did_menu_trans = 1
let s:keepcpo= &cpo
set cpo&vim

scriptencoding utf-8

menutrans &Help				&Helpo

menutrans &Overview<Tab><F1>			&Enhavtabelo<Tab><F1>
menutrans &User\ Manual				&Uzula\ manlibro
menutrans &How-to\ links			&Kiel\ fari
menutrans &Find\.\.\.				T&rovi\.\.\.
" -sep1-
menutrans &Credits				&Dankoj
menutrans Co&pying				&Permisilo
menutrans &Sponsor/Register			&Subteni/Registriĝi
menutrans O&rphans				&Orfoj
" -sep2-
menutrans &Version				&Versio
menutrans &About				Pri\ &Vim

let g:menutrans_help_dialog = "Tajpu komandon aŭ serĉendan vorton en la helparo.\n\nAldonu i_ por la komandoj de la enmeta reĝimo (ekz: i_CTRL-X)\nAldonu c_ por redakto de la komanda linio (ekz: c_<Del>)\nĈirkaŭi la opciojn per apostrofoj (ekz: 'shiftwidth')"

menutrans &File				&Dosiero

menutrans &Open\.\.\.<Tab>:e			&Malfermi\.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp		Malfermi\ &divide\.\.\.<Tab>:sp
menutrans Open\ Tab\.\.\.<Tab>:tabnew		Malfermi\ &langeton\.\.\.<Tab>:tabnew
menutrans &New<Tab>:enew			&Nova<Tab>:enew
menutrans &Close<Tab>:close			&Fermi<Tab>:close
" -SEP1-
menutrans &Save<Tab>:w				&Konservi<Tab>:w
menutrans Save\ &As\.\.\.<Tab>:sav		Konservi\ ki&el\.\.\.<Tab>:sav
" -SEP2-
menutrans Split\ &Diff\ with\.\.\.		Kom&pari\ divide\.\.\.
menutrans Split\ Patched\ &By\.\.\.		&Testi\ flikaĵon\.\.\.
" -SEP3-
menutrans &Print				&Presi
" -SEP4-
menutrans Sa&ve-Exit<Tab>:wqa			Konservi\ kaj\ eli&ri<Tab>:wqa
menutrans E&xit<Tab>:qa				&Eliri<Tab>:qa


menutrans &Edit				&Redakti

menutrans &Undo<Tab>u				&Malfari<Tab>u
menutrans &Redo<Tab>^R				Re&fari<Tab>^R
menutrans Rep&eat<Tab>\.			R&ipeti<Tab>\.
" -SEP1-
menutrans Cu&t<Tab>"+x				&Tondi<Tab>"+x
menutrans &Copy<Tab>"+y				&Kopii<Tab>"+y
menutrans &Paste<Tab>"+gP			Al&glui<Tab>"+gP
menutrans Put\ &Before<Tab>[p			Enmeti\ &antaŭ<Tab>[p
menutrans Put\ &After<Tab>]p			Enmeti\ ma&lantaŭ<Tab>]p
menutrans &Delete<Tab>x				&Forviŝi<Tab>x
menutrans &Select\ All<Tab>ggVG			A&partigi\ ĉion<Tab>ggVG
" -SEP2-
menutrans &Find\.\.\.				&Trovi\.\.\.
menutrans Find\ and\ Rep&lace\.\.\.		Trovi\ kaj\ a&nstataŭigi\.\.\.
menutrans &Find<Tab>/				&Trovi<Tab>/
menutrans Find\ and\ Rep&lace<Tab>:%s		Trovi\ kaj\ ansta&taŭigi<Tab>:%s
menutrans Find\ and\ Rep&lace<Tab>:s		Trovi\ kaj\ ansta&taŭigi<Tab>:s
" -SEP3-
menutrans Settings\ &Window			Fenestro\ de\ a&gordoj
menutrans Startup\ &Settings	                Agordoj\ de\ prav&aloroj
menutrans &Global\ Settings			Mallo&kaj\ agordoj

menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls!	Baskuli\ emfazon\ de\ ŝa&blono<Tab>:set\ hls!
menutrans Toggle\ &Ignore-case<Tab>:set\ ic!		Baskuli\ kongruon\ de\ uskle&co<Tab>:set\ ic!
menutrans Toggle\ &Showmatch<Tab>:set\ sm!		Baskuli\ kongruon\ de\ kram&poj<Tab>:set\ sm!

menutrans &Context\ lines				Linioj\ de\ &kunteksto

menutrans &Virtual\ Edit				&Virtuala\ redakto
menutrans Never							&Neniam
menutrans Block\ Selection					&Bloka\ apartigo
menutrans Insert\ mode						&Enmeta\ reĝimo
menutrans Block\ and\ Insert					Blo&ko\ kaj\ enmeto
menutrans Always						Ĉia&m

menutrans Toggle\ Insert\ &Mode<Tab>:set\ im!		Baskuli\ &enmetan\ reĝimon<Tab>:set\ im!
menutrans Toggle\ Vi\ C&ompatible<Tab>:set\ cp!		Baskuli\ kongruon\ kun\ &Vi<Tab>:set\ cp!
menutrans Search\ &Path\.\.\.				&Serĉvojo\ de\ dosieroj\.\.\.
menutrans Ta&g\ Files\.\.\.				Dosiero\ de\ etike&doj\.\.\.
" -SEP1-
menutrans Toggle\ &Toolbar				Baskuli\ &ilobreton
menutrans Toggle\ &Bottom\ Scrollbar			Baskuli\ su&ban\ rulumskalon
menutrans Toggle\ &Left\ Scrollbar			Baskuli\ &maldekstran\ rulumskalon
menutrans Toggle\ &Right\ Scrollbar			Baskuli\ &dekstran\ rulumskalon

let g:menutrans_path_dialog = "Tajpu la vojon de serĉo de dosieroj.\nDisigu la dosierujojn per komoj."
let g:menutrans_tags_dialog = "Tajpu la nomojn de dosieroj de etikedoj.\nDisigu la nomojn per komoj."

menutrans F&ile\ Settings			A&gordoj\ de\ dosiero

menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!	Baskuli\ &numerojn\ de\ linioj<Tab>:set\ nu!
menutrans Toggle\ &List\ Mode<Tab>:set\ list!		Baskuli\ &listan\ reĝimon<Tab>:set\ list!
menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!		Baskuli\ linifal&don<Tab>:set\ wrap!
menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!	Baskuli\ &vortofaldon<Tab>:set\ lbr!
menutrans Toggle\ &expand-tab<Tab>:set\ et!		Baskuli\ ekspansio\ de\ &taboj<Tab>:set\ et!
menutrans Toggle\ &auto-indent<Tab>:set\ ai!		Baskuli\ &aŭtokrommarĝenon<Tab>:set\ ai!
menutrans Toggle\ &C-indenting<Tab>:set\ cin!		Baskuli\ &C-krommarĝenon<Tab>:set\ cin!
" -SEP2-
menutrans &Shiftwidth					&Larĝo\ de\ krommarĝeno
menutrans Soft\ &Tabstop				&Malm&olaj\ taboj
menutrans Te&xt\ Width\.\.\.				Larĝo\ de\ te&ksto\.\.\.
menutrans &File\ Format\.\.\.				&Formato\ de\ &dosiero\.\.\.

let g:menutrans_textwidth_dialog = "Tajpu la novan larĝon de teksto\n(0 por malŝalti formatigon)."
let g:menutrans_fileformat_dialog = "Elektu la formaton de la skribonta dosiero."
let g:menutrans_fileformat_choices = " &Unikso \n &Dos \n &Mak \n &Rezigni "

menutrans C&olor\ Scheme			&Koloraro
menutrans &Keymap				Klavo&mapo
menutrans None					(nenio)
menutrans Select\ Fo&nt\.\.\.			Elekti\ &tiparon\.\.\.


menutrans &Tools				&Iloj

menutrans &Jump\ to\ this\ tag<Tab>g^]		&Aliri\ al\ tiu\ etikedo<Tab>g^]
menutrans Jump\ &back<Tab>^T			&Retroiri<Tab>^T
menutrans Build\ &Tags\ File			Krei\ &etikedan\ dosieron

" -SEP1-
menutrans &Spelling				&Literumilo
menutrans &Spell\ Check\ On			Ŝal&ti\ literumilon
menutrans Spell\ Check\ &Off			&Malŝalti\ literumilon
menutrans To\ &Next\ error<Tab>]s		Al\ sek&vonta\ eraro<Tab>]s
menutrans To\ &Previous\ error<Tab>[s		Al\ an&taŭa\ eraro<Tab>[s
menutrans Suggest\ &Corrections<Tab>z=		&Sugesti\ korektojn<Tab>z=
menutrans &Repeat\ correction<Tab>:spellrepall	R&ipeti\ korekton<Tab>:spellrepall
  
menutrans Set\ language\ to\ "en"		Angla
menutrans Set\ language\ to\ "en_au"		Angla\ (Aŭstralio)
menutrans Set\ language\ to\ "en_ca"		Angla\ (Kanado)
menutrans Set\ language\ to\ "en_gb"		Angla\ (Britio)
menutrans Set\ language\ to\ "en_nz"		Angla\ (Novzelando)
menutrans Set\ language\ to\ "en_us"		Angla\ (Usono)

menutrans &Find\ More\ Languages		&Trovi\ pli\ da\ lingvoj


menutrans &Folding				&Faldo

menutrans &Enable/Disable\ folds<Tab>zi			&Baskuli\ faldojn<Tab>zi
menutrans &View\ Cursor\ Line<Tab>zv			&Vidi\ linion\ de\ kursoro<Tab>zv
menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx		Vidi\ nur\ &kursoran\ linion<Tab>zMzx
menutrans C&lose\ more\ folds<Tab>zm			F&ermi\ pli\ da\ faldoj<Tab>zm
menutrans &Close\ all\ folds<Tab>zM			Fermi\ ĉiu&jn\ faldojn<Tab>zM
menutrans O&pen\ more\ folds<Tab>zr			&Malfermi\ pli\ da\ faldoj<Tab>zr
menutrans &Open\ all\ folds<Tab>zR			Malfermi\ ĉiuj&n\ faldojn<Tab>zR
" -SEP1-
menutrans Fold\ Met&hod					&Metodo\ de\ faldo

menutrans M&anual						&Permana\ metodo
menutrans I&ndent						&Krommarĝeno
menutrans E&xpression						&Esprimo
menutrans S&yntax						&Sintakso
menutrans &Diff							&Komparo
menutrans Ma&rker						Ma&rko

menutrans Create\ &Fold<Tab>zf				&Krei\ faldon<Tab>zf
menutrans &Delete\ Fold<Tab>zd				Forv&iŝi\ faldon<Tab>zd
menutrans Delete\ &All\ Folds<Tab>zD			Forviŝi\ ĉiu&jn\ faldojn<Tab>zD
" -SEP2-
menutrans Fold\ col&umn\ width				&Larĝo\ de\ falda\ kolumno

menutrans &Diff					Kom&pari

menutrans &Update					Ĝis&datigi
menutrans &Get\ Block					&Akiri\ blokon
menutrans &Put\ Block					Enme&ti\ blokon

" -SEP2-
menutrans &Make<Tab>:make			Lanĉi\ ma&ke<Tab>:make
menutrans &List\ Errors<Tab>:cl			Listigi\ &erarojn<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!		Listigi\ &mesaĝojn<Tab>:cl!
menutrans &Next\ Error<Tab>:cn			Sek&vanta\ eraro<Tab>:cn
menutrans &Previous\ Error<Tab>:cp		An&taŭa\ eraro<Tab>:cp
menutrans &Older\ List<Tab>:cold		Pli\ ma&lnova\ listo<Tab>:cold
menutrans N&ewer\ List<Tab>:cnew		Pli\ nova\ listo<Tab>:cnew

menutrans Error\ &Window			&Fenestro\ de\ eraroj

menutrans &Update<Tab>:cwin				Ĝis&datigi<Tab>:cwin
menutrans &Open<Tab>:copen				&Malfermi<Tab>:copen
menutrans &Close<Tab>:cclose				&Fermi<Tab>:cclose

" -SEP3-
menutrans &Convert\ to\ HEX<Tab>:%!xxd		Konverti\ al\ deksesuma<Tab>:%!xxd
menutrans Conve&rt\ back<Tab>:%!xxd\ -r		Retrokonverti<Tab>:%!xxd\ -r

menutrans Se&T\ Compiler			&Elekti\ kompililon


menutrans &Buffers			&Bufroj

menutrans Dummy					Fikcia
menutrans &Refresh\ menu			Ĝis&datigi\ menuon
menutrans &Delete				&Forviŝi
menutrans &Alternate				&Alterni
menutrans &Next					&Sekvanta
menutrans &Previous				An&taŭa
" -SEP-

menutrans &others				a&liaj
menutrans &u-z					&u-z
let g:menutrans_no_file = "[Neniu dosiero]"


menutrans &Window			Fene&stro

menutrans &New<Tab>^Wn				&Nova<Tab>^Wn
menutrans S&plit<Tab>^Ws			Di&vidi<Tab>^Ws
menutrans Sp&lit\ To\ #<Tab>^W^^		Dividi\ &al\ #<Tab>^W^^
menutrans Split\ &Vertically<Tab>^Wv		Dividi\ &vertikale<Tab>^Wv
menutrans Split\ File\ E&xplorer		Dividi\ &dosierfoliumilo
" -SEP1-
menutrans &Close<Tab>^Wc			&Fermi<Tab>^Wc
menutrans Close\ &Other(s)<Tab>^Wo		Fermi\ &aliajn<Tab>^Wo
" -SEP2-
menutrans Move\ &To				&Movu\ al

menutrans &Top<Tab>^WK					Su&pro<Tab>^WK
menutrans &Bottom<Tab>^WJ				Su&bo<Tab>^WJ
menutrans &Left\ side<Tab>^WH				Maldekstra\ &flanko<Tab>^WH
menutrans &Right\ side<Tab>^WL				Dekstra\ f&lanko<Tab>^WL

menutrans Rotate\ &Up<Tab>^WR			Rota&cii\ supre<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr			Rotac&ii\ sube<Tab>^Wr
" -SEP3-
menutrans &Equal\ Size<Tab>^W=			&Egala\ grando<Tab>^W=
menutrans &Max\ Height<Tab>^W_			Ma&ksimuma\ alto<Tab>^W_
menutrans M&in\ Height<Tab>^W1_			Mi&nimuma\ alto<Tab>^W1_
menutrans Max\ &Width<Tab>^W\|			Maksimuma\ &larĝo<Tab>^W\|
menutrans Min\ Widt&h<Tab>^W1\|			Minimuma\ lar&ĝo<Tab>^W1\|


" PopUp

menutrans &Undo					&Malfari
" -SEP1-
menutrans Cu&t					&Tondi
menutrans &Copy					&Kopii
menutrans &Paste				&Al&glui
" &Buffers.&Delete overwrites this one
menutrans &Delete				&Forviŝi
" -SEP2-
menutrans Select\ Blockwise			Apartigi\ &bloke
menutrans Select\ &Word				Apartigi\ &vorton
menutrans Select\ &Line				Apartigi\ &linion
menutrans Select\ &Block			Apartigi\ blo&kon
menutrans Select\ &All				Apartigi\ ĉi&on


" ToolBar

menutrans Open					Malfermi
menutrans Save					Konservi
menutrans SaveAll				Konservi\ ĉion
menutrans Print					Presi
" -sep1-
menutrans Undo					Rezigni
menutrans Redo					Refari
" -sep2-
menutrans Cut					Tondi
menutrans Copy					Kopii
menutrans Paste					Alglui
" -sep3-
menutrans Find					Trovi
menutrans FindNext				Trovi\ sekvanten
menutrans FindPrev				Trovi\ antaŭen
menutrans Replace				Anstataŭigi
" -sep4-
menutrans New					Nova
menutrans WinSplit				DividFen
menutrans WinMax				MaksFen
menutrans WinMin				MinFen
menutrans WinVSplit				VDividFen
menutrans WinMaxWidth				MaksLarĝFen
menutrans WinMinWidth				MinLarĝFen
menutrans WinClose				FermFen
" -sep5-
menutrans LoadSesn				ŜargSeanc
menutrans SaveSesn				KonsSeanc
menutrans RunScript				LanĉSkript
" -sep6-
menutrans Make					Make
menutrans RunCtags				KreiEtik
menutrans TagJump				IriAlEtik
" -sep7-
menutrans Help					Helpo
menutrans FindHelp				SerĉHelp

fun! Do_toolbar_tmenu()
  let did_toolbar_tmenu = 1
  tmenu ToolBar.Open				Malfermi dosieron
  tmenu ToolBar.Save				Konservi aktualan dosieron
  tmenu ToolBar.SaveAll				Konservi ĉiujn dosierojn
  tmenu ToolBar.Print				Presi
  tmenu ToolBar.Undo				Rezigni
  tmenu ToolBar.Redo				Refari
  tmenu ToolBar.Cut				Tondi
  tmenu ToolBar.Copy				Kopii
  tmenu ToolBar.Paste				Alglui
  if !has("gui_athena")
    tmenu ToolBar.Find				Trovi
    tmenu ToolBar.FindNext			Trovi sekvanten
    tmenu ToolBar.FindPrev			Trovi antaŭen
    tmenu ToolBar.Replace			Anstataŭigi
  endif
 if 0	" disabled; These are in the Windows menu
  tmenu ToolBar.New				Nova fenestro
  tmenu ToolBar.WinSplit			Dividi fenestron
  tmenu ToolBar.WinMax				Maksimumi fenestron
  tmenu ToolBar.WinMin				Minimumi fenestron
  tmenu ToolBar.WinVSplit			Dividi vertikale
  tmenu ToolBar.WinMaxWidth			Maksimumi larĝon de fenestro
  tmenu ToolBar.WinMinWidth			Minimumi larĝon de fenestro
  tmenu ToolBar.WinClose			Fermi fenestron
 endif
  tmenu ToolBar.LoadSesn			Malfermi seancon
  tmenu ToolBar.SaveSesn			Konservi aktualan seancon
  tmenu ToolBar.RunScript			Ruli skripton Vim
  tmenu ToolBar.Make				Lanĉi make
  tmenu ToolBar.RunCtags			Krei etikedojn
  tmenu ToolBar.TagJump				Atingi tiun etikedon
  tmenu ToolBar.Help				Helpo de Vim
  tmenu ToolBar.FindHelp			Serĉo en helparo
endfun


menutrans &Syntax			&Sintakso

menutrans &Off					&Malŝalti
menutrans &Manual				&Permana
menutrans A&utomatic				&Aŭtomata
menutrans on/off\ for\ &This\ file		Ŝalti/Malŝalti\ por\ &tiu\ dosiero

" The Start Of The Syntax Menu
menutrans ABC\ music\ notation		ABC\ (muzika\ notacio)
menutrans AceDB\ model			Modelo\ AceDB
menutrans Apache\ config		Konfiguro\ de\ Apache
menutrans Apache-style\ config		Konfiguro\ de\ stilo\ Apache
menutrans ASP\ with\ VBScript		ASP\ kun\ VBScript
menutrans ASP\ with\ Perl		ASP\ kun\ Perl
menutrans Assembly			Asemblilo
menutrans BC\ calculator		Kalkulilo\ BC
menutrans BDF\ font			Tiparo\ BDF
menutrans BIND\ config			Konfiguro\ de\ BIND
menutrans BIND\ zone			Zone\ BIND
menutrans Cascading\ Style\ Sheets	CSS
menutrans Cfg\ Config\ file		Konfigura\ dosiero\ \.cfg
menutrans Cheetah\ template		Ŝablono\ Cheetah
menutrans commit\ file			Dosiero\ commit
menutrans Generic\ Config\ file		Dosiero\ de\ ĝenerala\ konfiguro
menutrans Digital\ Command\ Lang	DCL
menutrans DNS/BIND\ zone		Regiono\ BIND/DNS
menutrans Dylan\ interface		Interfaco\ Dylan
menutrans Dylan\ lid			Dylan\ lid
menutrans Elm\ filter\ rules		Reguloj\ de\ filtrado\ Elm
menutrans ERicsson\ LANGuage		Erlang\ (Lingvo\ de\ Ericsson)
menutrans Essbase\ script		Skripto\ Essbase
menutrans Eterm\ config			Konfiguro\ de\ Eterm
menutrans Exim\ conf			Konfiguro\ de\ Exim
menutrans Fvwm\ configuration		Konfiguro\ de\ Fvwm
menutrans Fvwm2\ configuration		Konfiguro\ de\ Fvwm2
menutrans Fvwm2\ configuration\ with\ M4	Konfiguro\ de\ Fvwm2\ kun\ M4
menutrans GDB\ command\ file		Komanda\ dosiero\ de\ GDB
menutrans HTML\ with\ M4		HTML\ kun\ M4
menutrans Cheetah\ HTML\ template	Ŝablono\ Cheetah\ HTML
menutrans IDL\Generic\ IDL		Ĝenerala\ IDL\IDL
menutrans IDL\Microsoft\ IDL		IDL\IDL\ Mikrosofto
menutrans Indent\ profile		Profilo\ Indent
menutrans Inno\ setup			Konfiguro\ de\ Inno
menutrans InstallShield\ script		Skripto\ InstallShield
menutrans KDE\ script			Skripto\ KDE
menutrans LFTP\ config			Konfiguro\ de\ LFTP
menutrans LifeLines\ script		Skripto\ LifeLines
menutrans Lynx\ Style			Stilo\ de\ Lynx
menutrans Lynx\ config			Konfiguro\ de\ Lynx
menutrans Man\ page			Manlibra\ paĝo
menutrans MEL\ (for\ Maya)		MEL\ (por\ Maya)
menutrans 4DOS\ \.bat\ file		Dosiero\ \.bat\ 4DOS
menutrans \.bat\/\.cmd\ file		Dosiero\ \.bat\/\.cmd
menutrans \.ini\ file			Dosiero\ \.ini
menutrans Module\ Definition		Difino\ de\ modulo
menutrans Registry			Registraro
menutrans Resource\ file		Dosiero\ de\ rimedoj
menutrans Novell\ NCF\ batch		Staplo\ Novell\ NCF
menutrans NSIS\ script			Skripto\ NSIS
menutrans Oracle\ config		Konfiguro\ de\ Oracle
menutrans Palm\ resource\ compiler	Tradukilo\ de\ rimedoj\ Palm
menutrans PHP\ 3-4			PHP\ 3\ et\ 4
menutrans Postfix\ main\ config		Ĉefa\ konfiguro\ de\ Postfix
menutrans Povray\ scene\ descr		Scenejo\ Povray
menutrans Povray\ configuration		Konfiguro\ de\ Povray
menutrans Purify\ log			Protokolo\ de\ Purify
menutrans Readline\ config		Konfiguro\ de\ Readline
menutrans RCS\ log\ output		Protokola\ eligo\ de\ RCS
menutrans RCS\ file			Dosiero\ RCS
menutrans RockLinux\ package\ desc\.	Priskribo\ de\ pakaĵoj\ RockLinux
menutrans Samba\ config			Konfiguro\ de\ Samba
menutrans SGML\ catalog			Katalogo\ SGML
menutrans SGML\ DTD			DTD\ SGML
menutrans SGML\ Declaration		Deklaracio\ SGML
menutrans Shell\ script			Skripto-ŝelo
menutrans sh\ and\ ksh			sh\ kaj\ ksh
menutrans Sinda\ compare		Komparo\ Sinda
menutrans Sinda\ input			Enigo\ Sinda
menutrans Sinda\ output			Eligo\ Sinda
menutrans SKILL\ for\ Diva		SKILL\ por\ Diva
menutrans Smarty\ Templates		Ŝablono\ Smarty
menutrans SNNS\ network			Reto\ SNNS
menutrans SNNS\ pattern			Ŝablono\ SNNS
menutrans SNNS\ result			Rezulto\ SNNS
menutrans Snort\ Configuration		Konfiguro\ de\ Snort
menutrans Squid\ config			Konfiguro\ de\ Squid
menutrans Subversion\ commit		Commit\ Subversion
menutrans TAK\ compare			Komparo\ TAK
menutrans TAK\ input			Enigo\ TAK
menutrans TAK\ output			Eligo\ TAK
menutrans TeX\ configuration		Konfiguro\ de\ TeX
menutrans TF\ mud\ client		TF\ (client\ MUD)
menutrans Tidy\ configuration		Konfiguro\ de\ Tidy
menutrans Trasys\ input			Enigo\ Trasys
menutrans Command\ Line			Komanda\ linio
menutrans Geometry			Geometrio
menutrans Optics			Optiko
menutrans Vim\ help\ file		Helpa\ dosiero\ de\ Vim
menutrans Vim\ script			Skripto\ Vim
menutrans Viminfo\ file			Dosiero\ Viminfo
menutrans Virata\ config		Konfiguro\ de\ Virata
menutrans Wget\ config			Konfiguro\ de\ wget
menutrans Whitespace\ (add)		Spacetoj
menutrans WildPackets\ EtherPeek\ Decoder	Malkodilo\ WildPackets\ EtherPeek
menutrans X\ resources			Rimedoj\ X
menutrans XXD\ hex\ dump		Eligo\ deksesuma\.\ de\ xxd
menutrans XFree86\ Config		Konfiguro\ de\ XFree86
" The End Of The Syntax Menu

menutrans &Show\ filetypes\ in\ menu		&Montri\ dosiertipojn\ en\ menuo
" -SEP1-
menutrans Set\ '&syntax'\ only			Ŝalti\ nur\ '&syntax'
menutrans Set\ '&filetype'\ too			Ŝalti\ ankaŭ\ '&filetype'
menutrans &Off					M&alŝaltita
" -SEP3-
menutrans Co&lor\ test				Testo\ de\ &koloroj
menutrans &Highlight\ test			Testo\ de\ &emfazo
menutrans &Convert\ to\ HTML			Konverti\ al\ &HTML

let &cpo = s:keepcpo
unlet s:keepcpo
