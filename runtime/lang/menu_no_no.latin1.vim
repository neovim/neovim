" Menu Translations:	Norwegian / Norsk (Bokmål)
" Maintainer:		Øyvind A. Holm <sunny@sunbase.org>
" Last Change:		2012 May 01
" menu_no_no.latin1.vim 289 2004-05-16 18:00:52Z sunny

" Quit when menu translations have already been done.
if exists("did_menu_trans")
	finish
endif
let did_menu_trans = 1
let s:keepcpo= &cpo
set cpo&vim

" The translations below are in ISO-8859-1, but they work for ISO-8859-15 and
" CP1252 without conversion as well.
if &enc != "cp1252" && &enc != "iso-8859-15"
	scriptencoding latin1
endif

menutrans &File		&Fil
	menutrans &Open\.\.\.<Tab>:e		&Åpne \.\.\.<Tab>:e
	menutrans Sp&lit-Open\.\.\.<Tab>:sp	Åpne\ i\ nytt\ &vindu \.\.\.<Tab>:sp
	menutrans &New<Tab>:enew		&Ny\ fil<Tab>:enew
	menutrans &Close<Tab>:close		L&ukk<Tab>:close
	menutrans &Save<Tab>:w			&Lagre<Tab>:w
	menutrans Save\ &As\.\.\.<Tab>:sav	Lagre\ s&om \.\.\.<Tab>:sav
	if has("diff")
	menutrans Split\ &Diff\ with\.\.\.	Sa&mmenlign\ med\ ny\ fil \.\.\.
	menutrans Split\ Patched\ &By\.\.\.	&Patch\ i\ nytt\ vindu \.\.\.
	endif
	menutrans &Print			&Skriv\ ut
	menutrans Sa&ve-Exit<Tab>:wqa		Lagre\ o&g\ avslutt<Tab>:wqa
	menutrans E&xit<Tab>:qa			&Avslutt<Tab>:qa
menutrans &Edit		&Rediger
	menutrans &Undo<Tab>u						&Angre<Tab>u
	menutrans &Redo<Tab>^R						&Gjenopprett<Tab>^R
	menutrans Rep&eat<Tab>\.					&Repeter<Tab>\.
	menutrans Cu&t<Tab>"+x						&Klipp\ ut<Tab>"+x
	menutrans &Copy<Tab>"+y						K&opier<Tab>"+y
	menutrans &Paste<Tab>"+gP					&Lim\ inn<Tab>"+gP
	menutrans Put\ &Before<Tab>[p					Lim\ i&nn\ før\ markør<Tab>[p
	menutrans Put\ &After<Tab>]p					Lim\ inn\ &etter\ markør<Tab>]p
	menutrans &Select\ All<Tab>ggVG					&Merk\ alt<Tab>ggVG
	menutrans &Find\.\.\.						&Søk \.\.\.
	menutrans Find\ and\ Rep&lace\.\.\.				S&øk\ og\ erstatt \.\.\.
	menutrans Settings\ &Window					&Innstillinger
	menutrans &Global\ Settings					Glo&bale\ innstillinger
		menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls!		&Utheving\ av\ søketekst\ av/på<Tab>:set\ hls!
		menutrans Toggle\ &Ignore-case<Tab>:set\ ic!			&Forskjell\ mellom\ store/små bokstaver\ av/på<Tab>:set\ ic!
		menutrans Toggle\ &Showmatch<Tab>:set\ sm!			&Indikering\ av\ samsvarende\ parentes\ av/på<Tab>:set\ sm!
		menutrans &Context\ lines					&Kontekstlinjer
		menutrans &Virtual\ Edit					Vi&rtuell\ redigering
			menutrans Never							&Aldri
			menutrans Block\ Selection					I\ &blokkmodus
			menutrans Insert\ mode						I\ &Innsettingsmodus
			menutrans Block\ and\ Insert					I\ Blokk-\ &og\ innsettingsmodus
			menutrans Always						A&lltid
		menutrans Toggle\ Insert\ &Mode<Tab>:set\ im!			Innsettings&modus\ av/på<Tab>:set\ im!
		menutrans Toggle\ Vi\ C&ompatible<Tab>:set\ cp!			&Vi-kompatiblitet\ av/på<Tab>:set\ cp!
		menutrans Search\ &Path\.\.\.					&Søkesti \.\.\.
		menutrans Ta&g\ Files\.\.\.					Ta&gfiler \.\.\.
		menutrans Toggle\ &Toolbar					Verkt&øylinje
		menutrans Toggle\ &Bottom\ Scrollbar				Ne&dre\ rullefelt\ av/på
		menutrans Toggle\ &Left\ Scrollbar				Ve&nstre\ rullefelt\ av/på
		menutrans Toggle\ &Right\ Scrollbar				&Høyre\ rullefelt\ av/på
	menutrans F&ile\ Settings					Filo&ppsett
		menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!		&Linjenummer\ av/på<Tab>:set\ nu!
		menutrans Toggle\ &List\ Mode<Tab>:set\ list!			L&istemodus\ av/på<Tab>:set\ list!
		menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!			Li&njebryting\ av/på<Tab>:set\ wrap!
		menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!		Linjebryting\ ved\ &ord\ av/på<Tab>:set\ lbr!
		menutrans Toggle\ &expand-tab<Tab>:set\ et!			Utvidelse\ av\ &tabulatorer\ av/på<Tab>:set\ et!
		menutrans Toggle\ &auto-indent<Tab>:set\ ai!			A&utomatisk\ innrykk\ av/på<Tab>:set\ ai!
		menutrans Toggle\ &C-indenting<Tab>:set\ cin!			&C-innrykk\ av/på<Tab>:set\ cin!
		menutrans &Shiftwidth						&Størrelse\ på\ innrykk
		menutrans Soft\ &Tabstop					&Myke\ tabulatorstopp
		menutrans Te&xt\ Width\.\.\.					Te&kstbredde \.\.\.
		menutrans &File\ Format\.\.\.					&Filformat \.\.\.
	menutrans C&olor\ Scheme					&Fargekart
	menutrans &Keymap						&Tastaturoppsett
	menutrans Select\ Fo&nt\.\.\.					Skriftt&ype \.\.\.
menutrans &Tools	&Verktøy
	menutrans &Jump\ to\ this\ tag<Tab>g^]			&Hopp\ til\ tag\ under\ markør<Tab>g^]
	menutrans Jump\ &back<Tab>^T				Hopp\ &tilbake<Tab>^T
	menutrans Build\ &Tags\ File				Lag\ ta&gfil
	if has("folding")
	menutrans &Folding					Fol&der
		menutrans &Enable/Disable\ folds<Tab>zi			&Folder\ av/på<Tab>zi
		menutrans &View\ Cursor\ Line<Tab>zv			Se\ &markørlinje<Tab>zv
		menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx		Se\ &bare\ markørlinjen<Tab>zMzx
		menutrans C&lose\ more\ folds<Tab>zm			L&ukk\ flere\ folder<Tab>zm
		menutrans &Close\ all\ folds<Tab>zM			Lukk\ &alle\ folder<Tab>zM
		menutrans O&pen\ more\ folds<Tab>zr			&Åpne\ flere\ folder<Tab>zr
		menutrans &Open\ all\ folds<Tab>zR			Å&pne\ alle\ folder<Tab>zR
		menutrans Fold\ Met&hod					Foldme&tode
			menutrans M&anual					&Manuell
			menutrans I&ndent					&Innrykk
			menutrans E&xpression					&Uttrykk
			menutrans S&yntax					&Syntaks
			menutrans &Diff						&Forskjeller
			menutrans Ma&rker					M&arkering
		menutrans Create\ &Fold<Tab>zf				La&g\ fold<Tab>zf
		menutrans &Delete\ Fold<Tab>zd				&Slett\ fold<Tab>zd
		menutrans Delete\ &All\ Folds<Tab>zD			Sl&ett\ alle\ folder<Tab>zD
		menutrans Fold\ col&umn\ width				Bredde\ på\ fold&kolonne
	endif
	if has("diff")
	menutrans &Diff						&Forskjeller
		menutrans &Update					&Oppdater
		menutrans &Get\ Block					&Hent\ blokk
		menutrans &Put\ Block					&Putt\ blokk
	endif
	menutrans &Make<Tab>:make				&Kjør\ "make"<Tab>:make
	menutrans &List\ Errors<Tab>:cl				&List\ feil<Tab>:cl
	menutrans L&ist\ Messages<Tab>:cl!			List\ &meldinger<Tab>:cl!
	menutrans &Next\ Error<Tab>:cn				&Neste\ feil<Tab>:cn
	menutrans &Previous\ Error<Tab>:cp			Fo&rrige\ feil<Tab>:cp
	menutrans &Older\ List<Tab>:cold			&Eldre\ liste<Tab>:cold
	menutrans N&ewer\ List<Tab>:cnew			N&yere\ liste<Tab>:cnew
	menutrans Error\ &Window				Fe&ilvindu
		menutrans &Update<Tab>:cwin				&Oppdater<Tab>:cwin
		menutrans &Open<Tab>:copen				&Åpne<Tab>:copen
		menutrans &Close<Tab>:cclose				&Lukk<Tab>:cclose
	menutrans &Set\ Compiler				&Velg\ kompilator
	menutrans &Convert\ to\ HEX<Tab>:%!xxd			Konverter\ til\ hek&sadesimal<Tab>:%!xxd
	menutrans Conve&rt\ back<Tab>:%!xxd\ -r			K&onverter\ tilbake<Tab>:%!xxd\ -r
menutrans &Syntax	&Syntaks
	menutrans &Show\ filetypes\ in\ menu	&Vis\ filtyper\ i\ menyen
	menutrans Set\ '&syntax'\ only		Sett\ bare\ '&syntax'
	menutrans Set\ '&filetype'\ too		Sett\ '&filetype'\ også
	menutrans &Off				&Av
	menutrans &Manual			&Manuell
	menutrans A&utomatic			A&utomatisk
	menutrans on/off\ for\ &This\ file	Av/på\ for\ &denne\ filen
	menutrans Co&lor\ test			Far&getest
	menutrans &Highlight\ test		Uthevings&test
	menutrans &Convert\ to\ HTML		Konverter\ til\ &HTML
menutrans &Buffers	&Buffer
	menutrans &Refresh\ menu	&Oppdater
	menutrans Delete		&Slett
	menutrans &Alternate		&Veksle
	menutrans &Next			&Neste
	menutrans &Previous		&Forrige
	menutrans [No\ File]		[Uten\ navn]
menutrans &Window	Vi&ndu
	menutrans &New<Tab>^Wn			&Nytt<Tab>^Wn
	menutrans S&plit<Tab>^Ws		&Splitt<Tab>^Ws
	menutrans Sp&lit\ To\ #<Tab>^W^^	Splitt\ &til\ #<Tab>^W^^
	menutrans Split\ &Vertically<Tab>^Wv	S&plitt\ loddrett<Tab>^Ws
	menutrans Split\ File\ E&xplorer	&Filbehandler
	menutrans &Close<Tab>^Wc		&Lukk<Tab>^Wc
	menutrans Close\ &Other(s)<Tab>^Wo	Lukk\ &andre<Tab>^Wo
	menutrans Move\ &To			Fl&ytt\ til
		menutrans &Top<Tab>^WK			&Toppen<Tab>^WK
		menutrans &Bottom<Tab>^WJ		&Bunnen<Tab>^WJ
		menutrans &Left\ side<Tab>^WH		&Venstre\ side<Tab>^WH
		menutrans &Right\ side<Tab>^WL		&Høyre\ side<Tab>^WL
	menutrans Rotate\ &Up<Tab>^WR		Roter\ &opp<Tab>^WR
	menutrans Rotate\ &Down<Tab>^Wr		&Roter\ ned<Tab>^Wr
	menutrans &Equal\ Size<Tab>^W=		Lik\ st&ørrelse<Tab>^W=
	menutrans &Max\ Height<Tab>^W_		&Maksimal\ høyde<Tab>^W_
	menutrans M&in\ Height<Tab>^W1_		M&inimal\ høyde<Tab>^W1_
	menutrans Max\ &Width<Tab>^W\|		Ma&ksimal\ bredde<Tab>^W\|
	menutrans Min\ Widt&h<Tab>^W1\|		Minimal\ &bredde<Tab>^W1\|
menutrans &Help		&Hjelp
	menutrans &Overview<Tab><F1>	&Oversikt<Tab><F1>
	menutrans &User\ Manual		&Brukerhåndbok
	menutrans &How-to\ links	&Førstehjelp
	menutrans &Find\.\.\.		&Søk \.\.\.
	menutrans &Credits		&Kreditering
	menutrans Co&pying		&Programlisens
	menutrans &Sponsor/Register	S&tøtte/Registrering
	menutrans O&rphans		Fo&reldreløse
	menutrans &Version		&Versjon
	menutrans &About		&Om\ Vim

" Popup
	menutrans &Undo			&Angre
	menutrans Cu&t			Klipp\ &ut
	menutrans &Copy			&Kopier
	menutrans &Paste		&Lim\ inn
	menutrans &Delete		&Slett
	menutrans Select\ Blockwise	Marker\ blokk&vis
	menutrans Select\ &Word		Marker\ &ord
	menutrans Select\ &Line		Marker\ lin&je
	menutrans Select\ &Block	Marker\ &blokk
	menutrans Select\ &All		Marker\ al&t

" Verktøylinje
if has("toolbar")
	if exists("*Do_toolbar_tmenu")
		delfunction Do_toolbar_tmenu
	endif
	function Do_toolbar_tmenu()
		tmenu ToolBar.Open		Åpne fil
		tmenu ToolBar.Save		Lagre fil
		tmenu ToolBar.SaveAll		Lagre alle filer
		tmenu ToolBar.Print		Skriv ut
		tmenu ToolBar.Undo		Angre
		tmenu ToolBar.Redo		Gjenopprett
		tmenu ToolBar.Cut		Klipp
		tmenu ToolBar.Copy		Kopier
		tmenu ToolBar.Paste		Lim inn
		tmenu ToolBar.Find		Søk ...
		tmenu ToolBar.FindNext		Finn neste
		tmenu ToolBar.FindPrev		Finn forrige
		tmenu ToolBar.Replace		Søk og erstatt ...
		if 0 " Disabled, they are in the Windows menu
			tmenu ToolBar.New	Nytt vindu
			tmenu ToolBar.WinSplit	Splitt vindu
			tmenu ToolBar.WinMax	Maksimal vindushøyde
			tmenu ToolBar.WinMin	Minimal vindushøyde
			tmenu ToolBar.WinClose	Lukk vindu
		endif
		tmenu ToolBar.LoadSesn		Åpne økt
		tmenu ToolBar.SaveSesn		Lagre økt
		tmenu ToolBar.RunScript		Kjør Vim-skript
		tmenu ToolBar.Make		Kjør "make"
		tmenu ToolBar.Shell		Start skall
		tmenu ToolBar.RunCtags		Oppdater tag-fil
		tmenu ToolBar.TagJump		Hopp til tag
		tmenu ToolBar.Help		Hjelp!
		tmenu ToolBar.FindHelp		Søk i hjelpen ...
	endfunction
endif

" Dialogmeldinger
	let g:menutrans_no_file = "[Uten navn]"
	let g:menutrans_help_dialog = "Skriv en kommando eller ord du vil ha hjelp om:\n\nLegg til i_ i begynnelsen for inndatametoder (f.eks.: i_CTRL-X)\nLegg til c_ i begynnelsen for kommandoer som redigerer kommandolinjen (f.eks.: c_<Del>)\nLegg til ' i begynnelsen for et valgnavn (f.eks.: 'shiftwidth')"
	let g:menutrans_path_dialog = "Skriv søkesti for filer.\nSkill katalognavn med komma."
	let g:menutrans_tags_dialog = "Skriv navn på tagfiler.\nSkill navnene med komma."
	let g:menutrans_textwidth_dialog = "Velg ny tekstbredde (0 for å forhindre formatering): "
	let g:menutrans_fileformat_dialog = "Velg filformat som filen skal lagres med"

let &cpo = s:keepcpo
unlet s:keepcpo

"    vim: set ts=8 sw=8 :
" vim600: set fdm=indent :
