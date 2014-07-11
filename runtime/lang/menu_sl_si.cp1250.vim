" Menu Translations:	Slovenian / Slovensko
" Maintainer:		Mojca Miklavec <mojca.miklavec.lists@gmail.com>
" Originally By:	Mojca Miklavec <mojca.miklavec.lists@gmail.com>
" Last Change:		Sat, 17 Jun 2006
" vim:set foldmethod=marker tabstop=8:

" TODO: add/check all '&'s

" Quit when menu translations have already been done.
if exists("did_menu_trans")
  finish
endif
let did_menu_trans = 1
let s:keepcpo= &cpo
set cpo&vim

scriptencoding cp1250

" {{{ FILE / DATOTEKA
menutrans &File				&Datoteka
menutrans &Open\.\.\.<Tab>:e		&Odpri\ \.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp	Odpri\ de&ljeno\ \.\.\.<Tab>:sp
menutrans Open\ Tab\.\.\.<Tab>:tabnew	Odpri\ v\ zavi&hku\ \.\.\.<Tab>:tabnew
menutrans &New<Tab>:enew		&Nova<Tab>:enew
menutrans &Close<Tab>:close		&Zapri<Tab>:close
menutrans &Save<Tab>:w			&Shrani<Tab>:w
menutrans Save\ &As\.\.\.<Tab>:sav	Shrani\ &kot\ \.\.\.<Tab>:sav
menutrans &Print			Na&tisni
menutrans Sa&ve-Exit<Tab>:wqa		Shrani\ in\ &konèaj<Tab>:wqa
menutrans E&xit<Tab>:qa			&Izhod<Tab>:qa

if has("diff")
    menutrans Split\ &Diff\ with\.\.\.	Primerjaj\ z\ (di&ff)\ \.\.\.
    menutrans Split\ Patched\ &By\.\.\.	&Popravi\ z\ (patch)\ \.\.\.
endif
" }}} FILE / DATOTEKA

" {{{ EDIT / UREDI
menutrans &Edit				&Uredi
menutrans &Undo<Tab>u			&Razveljavi<Tab>u
menutrans &Redo<Tab>^R			&Obnovi<Tab>^R
menutrans Rep&eat<Tab>\.		Po&novi<Tab>\.
menutrans Cu&t<Tab>"+x			&Izreži<Tab>"+x
menutrans &Copy<Tab>"+y			&Kopiraj<Tab>"+y
menutrans &Paste<Tab>"+gP		&Prilepi<Tab>"+gP
menutrans Put\ &Before<Tab>[p		Vrini\ pred<Tab>[p
menutrans Put\ &After<Tab>]p		Vrini\ za<Tab>]p
menutrans &Delete<Tab>x			Iz&briši<Tab>x
menutrans &Select\ all<Tab>ggVG		Izberi\ vse<Tab>ggVG
menutrans &Find\.\.\.			Po&išèi\ \.\.\.
menutrans Find\ and\ Rep&lace\.\.\.	Poišèi\ in\ &zamenjaj\ \.\.\.

" [-- SETTINGS --]
menutrans Settings\ &Window				Nastavitve\ \.\.\.
menutrans Startup\ &Settings				Zaèetne\ nastavitve
menutrans &Global\ Settings				&Globalne\ nastavitve

menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls!	Vkljuèi/izkljuèi\ poudarjanje\ iskanega\ niza<Tab>:set\ hls!
menutrans Toggle\ &Ignore-case<Tab>:set\ ic!		Vkljuèi/izkljuèi\ loèevanje\ velikih\ in\ malih\ èrk<Tab>:set\ ic!
menutrans Toggle\ &Showmatch<Tab>:set\ sm!		Vkljuèi/izkljuèi\ kratek\ skok\ na\ pripadajoèi\ oklepaj<Tab>:set\ sm!

menutrans &Context\ lines				Št\.\ vidnih\ vrstic\ pred/za\ kurzorjem

menutrans &Virtual\ Edit				Dovoli\ položaj\ kazalèka,\ kjer\ ni\ besedila
menutrans Never						Nikoli
menutrans Block\ Selection				Le\ med\ izbiranjem\ bloka
menutrans Insert\ mode					Le\ v\ naèinu\ za\ pisanje
menutrans Block\ and\ Insert				Pri\ obojem
menutrans Always					Vedno
menutrans Toggle\ Insert\ &Mode<Tab>:set\ im!		Vkljuèi/izkljuèi\ naèin\ za\ pisanje<Tab>:set\ im!
menutrans Toggle\ Vi\ C&ompatible<Tab>:set\ cp!		Vkljuèi/izkljuèi\ združljivost\ z\ Vi-jem<Tab>:set\ cp!

menutrans Search\ &Path\.\.\.				Pot\ za\ iskanje\ \.\.\.
menutrans Ta&g\ Files\.\.\.				Ta&g-datoteke\.\.\.

menutrans Toggle\ &Toolbar				Pokaži/skrij\ Orodja
menutrans Toggle\ &Bottom\ Scrollbar			Pokaži/skrij\ spodnji\ drsnik
menutrans Toggle\ &Left\ Scrollbar			Pokaži/skrij\ levi\ drsnik
menutrans Toggle\ &Right\ Scrollbar			Pokaži/skrij\ desni\ drsnik

" Edit/File Settings
menutrans F&ile\ Settings				&Nastavitve\ datoteke

" Boolean options
menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!	Pokaži/skrij\ številke\ vrstic<Tab>:set\ nu!
menutrans Toggle\ &List\ Mode<Tab>:set\ list!		Pokaži/skrij\ nevidne\ znake<Tab>:set\ list! " space/tab
menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!		Vkljuèi/izkljuèi\ prelome\ vrstic<Tab>:set\ wrap!
menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!	Vkljuèi/izkljuèi\ prelome\ vrstic\ med\ besedami<Tab>:set\ lbr!
menutrans Toggle\ &expand-tab<Tab>:set\ et!		Vkljuèi/izkljuèi\ zamenjavo\ tabulatorjev\ s\ presledki<Tab>:set\ et!
menutrans Toggle\ &auto-indent<Tab>:set\ ai!		Vkljuèi/izkljuèi\ avtomatsko\ zamikanje\ vrstic<Tab>:set\ ai!
menutrans Toggle\ &C-indenting<Tab>:set\ cin!		Vkljuèi/izkljuèi\ C-jevski\ naèin\ zamikanja\ vrstic<Tab>:set\ cin!

" other options
menutrans &Shiftwidth					Širina\ zamika\ vrstic
menutrans Soft\ &Tabstop				Širina\ &tabulatorja
menutrans Te&xt\ Width\.\.\.				Širina\ besedila\ \.\.\.
menutrans &File\ Format\.\.\.				Format\ &datoteke\ \.\.\.
menutrans C&olor\ Scheme				&Barvna\ shema\ \.\.\.
menutrans &Keymap					&Keymap
menutrans Select\ Fo&nt\.\.\.				Pisava\ \.\.\.
" }}} EDIT / UREDI

" {{{  TOOLS / ORODJA
menutrans &Tools					&Orodja
menutrans &Jump\ to\ this\ tag<Tab>g^]			&Skoèi\ k\ tej\ znaèki<Tab>g^]
menutrans Jump\ &back<Tab>^T				Skoèi\ Na&zaj<Tab>^T
menutrans Build\ &Tags\ File				Napravi\ datoteke\ z\ znaèkami\ (tag)
if has("spell")
    menutrans &Spelling					Èrkovalnik
    menutrans &Spell\ Check\ On				&Vkljuèi
    menutrans Spell\ Check\ &Off			&Izkljuèi
    menutrans To\ &Next\ error<Tab>]s			K\ &naslednji\ napaki<Tab>]s
    menutrans To\ &Previous\ error<Tab>[s		K\ &prejšnji\ napaki<Tab>[s
    menutrans Suggest\ &Corrections<Tab>z=		Predlagaj\ popravek<Tab>z=
    menutrans &Repeat\ correction<Tab>:spellrepall	Po&novi\ popravke\ na\ vseh\ besedah<Tab>:spellrepall
    menutrans Set\ language\ to\ "en"			Angleški\ "en"
    menutrans Set\ language\ to\ "en_au"		Angleški\ "en_au"
    menutrans Set\ language\ to\ "en_ca"		Angleški\ "en_ca"
    menutrans Set\ language\ to\ "en_gb"		Angleški\ "en_gb"
    menutrans Set\ language\ to\ "en_nz"		Angleški\ "en_nz"
    menutrans Set\ language\ to\ "en_us"		Angleški\ "en_us"
    menutrans Set\ language\ to\ "sl"			Slovenski\ "sl"
    menutrans Set\ language\ to\ "de"			Nemški\ "de"
    menutrans Set\ language\ to\ 			Èrkovalnik:\
    menutrans &Find\ More\ Languages			&Ostali\ jeziki
endif
if has("folding")
  menutrans &Folding					Zvijanje\ kode
  " open close folds
  menutrans &Enable/Disable\ folds<Tab>zi		Omogoèi/onemogoèi\ zvijanje<Tab>zi " Omogoèi/onemogoèi\ zavihke
  menutrans &View\ Cursor\ Line<Tab>zv			Pokaži\ vrstico\ s\ kazalèkom<Tab>zv " kjer je kazalec
  menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx		Pokaži\ samo\ vrstico\ s\ kazalèkom<Tab>zMzx
  menutrans C&lose\ more\ folds<Tab>zm			Zvij\ naslednji\ nivo<Tab>zm " Zapri\ veè\ zavihkov
  menutrans &Close\ all\ folds<Tab>zM			Zvij\ vso\ kodo<Tab>zM " Zapri\ vse\ zavihke
  menutrans O&pen\ more\ folds<Tab>zr			Razvij\ en\ nivo<Tab>zr " Odpri\ veè\ zavihkov
  menutrans &Open\ all\ folds<Tab>zR			Razvij\ vso\ kodo<Tab>zR " Odpri\ vse\ zavihke
  " fold method
  menutrans Fold\ Met&hod				Kriterij\ za\ zvijanje " Ustvarjanje\ zavihkov
  menutrans M&anual					&Roèno
  menutrans I&ndent					Glede\ na\ &poravnavo
  menutrans E&xpression					Z\ &izrazi\ (foldexpr)
  menutrans S&yntax					Glede\ na\ &sintakso
  menutrans &Diff					Razlike\ (&diff)
  menutrans Ma&rker					Z\ &markerji/oznaèbami
  " create and delete folds
  " TODO accelerators
  menutrans Create\ &Fold<Tab>zf			Ustvari\ zvitek<Tab>zf
  menutrans &Delete\ Fold<Tab>zd			Izbriši\ zvitek<Tab>zd
  menutrans Delete\ &All\ Folds<Tab>zD			Izbriši\ vse\ zvitke<Tab>zD
  " moving around in folds
  menutrans Fold\ column\ &width			Širina\ drevesa\ z\ zvitki
endif  " has folding

if has("diff")
  menutrans &Diff					Razlike\ (&Diff)
  menutrans &Update					&Posodobi<Tab>
  menutrans &Get\ Block					&Sprejmi\ (spremeni\ to\ okno) " XXX: check if translation is OK
  menutrans &Put\ Block					&Pošlji\ (spremeni\ drugo\ okno)
endif

menutrans &Make<Tab>:make				Napravi\ (&make)<Tab>:make
menutrans &List\ Errors<Tab>:cl				Pokaži\ napake<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!			Pokaži\ sporoèila<Tab>:cl!
menutrans &Next\ Error<Tab>:cn				K\ &naslednji\ napaki<Tab>:cn
menutrans &Previous\ Error<Tab>:cp			K\ &prejšnji\ napaki<Tab>:cp
menutrans &Older\ List<Tab>:cold			K\ &starejšemu\ seznamu\ napak<Tab>:cold
menutrans N&ewer\ List<Tab>:cnew			K\ &novejšemu\ seznamu\ napak<Tab>:cnew

menutrans Error\ &Window				Okno\ z\ napakami
menutrans &Update<Tab>:cwin				&Posodobi<Tab>:cwin
menutrans &Open<Tab>:copen				&Odpri<Tab>:copen
menutrans &Close<Tab>:cclose				&Zapri<Tab>:cclose

menutrans &Set\ Compiler				Nastavi\ &prevajalnik
menutrans Se&T\ Compiler				Nastavi\ &prevajalnik " bug in original translation?

menutrans &Convert\ to\ HEX<Tab>:%!xxd			Pretvori\ v\ HE&X<Tab>:%!xxd
menutrans Conve&rt\ back<Tab>:%!xxd\ -r			Pretvori\ nazaj<Tab>:%!xxd\ -r
" }}}  TOOLS / ORODJA

" {{{ SYNTAX / BARVANJE KODE
menutrans &Syntax				&Barvanje\ kode
menutrans &Show\ filetypes\ in\ menu		Podprte\ vrste\ datotek
menutrans Set\ '&syntax'\ only			Samo\ barvanje\ ('&syntax')
menutrans Set\ '&filetype'\ too			Tudi\ obnašanje\ ('&filetype')
menutrans &Off					&Izkljuèeno
menutrans &Manual				&Roèno
menutrans A&utomatic				&Avtomatsko
menutrans on/off\ for\ &This\ file		Vkljuèi/izkljuèi\ za\ to\ datoteko
menutrans Co&lor\ test				Preizkus\ barv
menutrans &Highlight\ test			Preizkus\ barvanja\ kode
menutrans &Convert\ to\ HTML			Pretvori\ v\ &HTML
" }}} SYNTAX / BARVANJE KODE

" {{{ BUFFERS / MEDPOMNILNIK
menutrans &Buffers					&Medpomnilnik " XXX: ni najbolje: okno bi bolj pristajalo, ampak okno je že
menutrans &Refresh\ menu				&Osveži
menutrans Delete					&Briši
menutrans &Alternate					&Menjaj
menutrans &Next						&Naslednji
menutrans &Previous					&Prejšnji
menutrans [No\ File]					[Brez\ datoteke]
" }}} BUFFERS / MEDPOMNILNIK

" {{{ WINDOW / OKNO
menutrans &Window			&Okno
menutrans &New<Tab>^Wn			&Novo<Tab>^Wn
menutrans S&plit<Tab>^Ws		Razdeli<Tab>^Ws
menutrans Split\ &Vertically<Tab>^Wv	Razdeli\ navpièno<Tab>^Ws
menutrans Split\ File\ E&xplorer	Razdeli:\ Vsebina\ mape
menutrans Sp&lit\ To\ #<Tab>^W^^	Razdeli\ v\ #<Tab>^W^^
menutrans &Close<Tab>^Wc		&Zapri<Tab>^Wc
menutrans Close\ &Other(s)<Tab>^Wo	Zapri\ &ostala<Tab>^Wo
menutrans Move\ &To			Premakni
menutrans &Top<Tab>^WK			&Gor<Tab>^WK
menutrans &Bottom<Tab>^WJ		&Dol<Tab>^WJ
menutrans &Left\ side<Tab>^WH		&Levo<Tab>^WH
menutrans &Right\ side<Tab>^WL		&Desno<Tab>^WL
menutrans Rotate\ &Up<Tab>^WR		Zavrti\ navzgor<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr		Zavrti\ navzdol<Tab>^Wr
menutrans &Equal\ Size<Tab>^W=		&Enaka\ velikost<Tab>^W=
menutrans &Max\ Height<Tab>^W_		Najvišje<Tab>^W_
menutrans M&in\ Height<Tab>^W1_		Najnižje<Tab>^W1_
menutrans Max\ &Width<Tab>^W\|		Najširše<Tab>^W\|
menutrans Min\ Widt&h<Tab>^W1\|		Najožje<Tab>^W1\|
" }}} WINDOW / OKNO

" {{{ HELP / POMOÈ
menutrans &Help			&Pomoè
menutrans &Overview<Tab><F1>	Hitri\ pregled<Tab><F1>
menutrans &User\ Manual		P&riroènik
menutrans &How-to\ links	&How-to\ kazalo
menutrans &Find\.\.\.		Po&išèi\ \.\.\.	" conflicts with Edit.Find
menutrans &Credits		&Avtorji
menutrans Co&pying		&Licenca
menutrans &Sponsor/Register	Registracija\ in\ &donacije
menutrans O&rphans		&Sirotam
menutrans &Version		&Verzija
menutrans &About		&O\ programu
" }}} HELP / POMOÈ

" {{{ POPUP
menutrans &Undo				&Razveljavi
menutrans Cu&t				&Izreži
menutrans &Copy				&Kopieraj
menutrans &Paste			&Prilepi
menutrans &Delete			&Zbriši
menutrans Select\ Blockwise		Izbiraj\ po\ blokih
menutrans Select\ &Word			Izberi\ &besedo
menutrans Select\ &Sentence		Izberi\ &stavek
menutrans Select\ Pa&ragraph		Izberi\ &odstavek
menutrans Select\ &Line			Izberi\ vrs&tico
menutrans Select\ &Block		Izberi\ b&lok
menutrans &Select\ All<Tab>ggVG		Izberi\ &vse<Tab>ggVG
" }}} POPUP

" {{{ TOOLBAR
if has("toolbar")
  if exists("*Do_toolbar_tmenu")
    delfun Do_toolbar_tmenu
  endif
  fun Do_toolbar_tmenu()
    tmenu ToolBar.Open		Odpri datoteko
    tmenu ToolBar.Save		Shrani datoteko
    tmenu ToolBar.SaveAll	Shrani vse datoteke
    tmenu ToolBar.Print		Natisni
    tmenu ToolBar.Undo		Razveljavi
    tmenu ToolBar.Redo		Obnovi
    tmenu ToolBar.Cut		Izreži
    tmenu ToolBar.Copy		Kopiraj
    tmenu ToolBar.Paste		Prilepi
    tmenu ToolBar.Find		Najdi ...
    tmenu ToolBar.FindNext	Najdi naslednje
    tmenu ToolBar.FindPrev	Najdi prejšnje
    tmenu ToolBar.Replace	Najdi in zamenjaj ...
    tmenu ToolBar.LoadSesn	Naloži sejo
    tmenu ToolBar.SaveSesn	Shrani trenutno sejo
    tmenu ToolBar.RunScript	Izberi Vim skripto za izvajanje
    tmenu ToolBar.Make		Napravi trenutni projekt (:make)
    tmenu ToolBar.RunCtags	Napravi znaèke v trenutnem direktoriju (!ctags -R.)
    tmenu ToolBar.TagJump	Skoèi k znaèki pod kurzorjem
    tmenu ToolBar.Help		Pomoè za Vim
    tmenu ToolBar.FindHelp	Išèi v pomoèi za Vim
  endfun
endif
" }}} TOOLBAR

" {{{ DIALOG TEXTS
let g:menutrans_no_file = "[Brez datoteke]"
let g:menutrans_help_dialog = "Vnesite ukaz ali besedo, za katero želite pomoè:\n\nUporabite predpono i_ za ukaze v naèinu za pisanje (npr.: i_CTRL-X)\nUporabite predpono c_ za ukaze v ukazni vrstici (command-line) (npr.: c_<Del>)\nUporabite predpono ' za imena opcij (npr.: 'shiftwidth')"
let g:menutrans_path_dialog = "Vnesite poti za iskanje datotek.\nImena direktorijev loèite z vejico."
let g:menutrans_tags_dialog = "Vnesite imena datotek z znaèkami ('tag').\nImana loèite z vejicami."
let g:menutrans_textwidth_dialog = "Vnesite novo širino besedila (ali 0 za izklop formatiranja): "
let g:menutrans_fileformat_dialog = "Izberite format datoteke"
let g:menutrans_fileformat_choices = "&Unix\n&Dos\n&Mac\n&Preklièi"
" }}}

let &cpo = s:keepcpo
unlet s:keepcpo
