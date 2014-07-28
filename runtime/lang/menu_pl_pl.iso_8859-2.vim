" Menu Translations:	Polish
" Maintainer:		Mikolaj Machowski ( mikmach AT wp DOT pl )
" Initial Translation:	Marcin Dalecki <martin@dalecki.de>
" Last Change: 17 May  2010

" Quit when menu translations have already been done.
if exists("did_menu_trans")
  finish
endif
let did_menu_trans = 1
let s:keepcpo= &cpo
set cpo&vim

scriptencoding iso-8859-2

" Help menu
menutrans &Help			Po&moc
menutrans &Overview<Tab><F1>			&Og�lnie<Tab><F1>
menutrans &User\ Manual	Podr�cznik\ &u�ytkownika
menutrans &How-to\ links	&Odno�niki\ JTZ
menutrans &Find\.\.\.	&Szukaj\.\.\.
menutrans &Credits		Po&dzi�kowania
menutrans Co&pying		&Kopiowanie
menutrans &Sponsor/Register	&Sponsorowanie/Rejestracja
menutrans O&rphans		Sie&roty
menutrans &Version		&Wersja
menutrans &About		o\ &Programie

" File menu
menutrans &File				&Plik
menutrans &Open\.\.\.<Tab>:e		&Otw�rz\.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp	Otw�rz\ z\ &podzia�em\.\.\.<Tab>:sp
menutrans &New<Tab>:enew       &Nowy<Tab>:enew
menutrans &Close<Tab>:close		&Zamknij<Tab>:close
menutrans &Save<Tab>:w			Za&pisz<Tab>:w
menutrans Save\ &As\.\.\.<Tab>:sav	Zapisz\ &jako\.\.\.<Tab>:sav
menutrans Split\ &Diff\ with\.\.\.	Podziel\ na\ diff-a\ mi�dzy\.\.\.
menutrans Split\ Patched\ &By\.\.\.	Podziel\ �atane\ przez\.\.\.
menutrans &Print			&Drukuj
menutrans Sa&ve-Exit<Tab>:wqa		W&yj�cie\ z\ zapisem<Tab>:wqa
menutrans E&xit<Tab>:qa			&Wyj�cie<Tab>:qa
menutrans Open\ Tab\.\.\.<Tab>:tabnew	Otw�rz\ &kart�\.\.\.<Tab>:tabnew

" Edit menu
menutrans &Edit				&Edycja
menutrans &Undo<Tab>u			&Cofnij<Tab>u
menutrans &Redo<Tab>^R			&Pon�w<Tab>^R
menutrans Rep&eat<Tab>\.		P&owt�rz<Tab>\.
menutrans Cu&t<Tab>"+x			W&ytnij<Tab>"+x
menutrans &Copy<Tab>"+y			&Kopiuj<Tab>"+y
menutrans &Paste<Tab>"+gP		&Wklej<Tab>"+gP
menutrans Put\ &Before<Tab>[p		Wstaw\ p&rzed<Tab>[p
menutrans Put\ &After<Tab>]p		Wstaw\ p&o<Tab>]p
menutrans &Select\ All<Tab>ggVG		Z&aznacz\ ca�o��<Tab>ggVG
menutrans &Find\.\.\.			&Szukaj\.\.\.
menutrans &Find<Tab>/			&Szukaj<Tab>/
menutrans Find\ and\ Rep&lace\.\.\.	&Zamie�\.\.\.
menutrans Find\ and\ Rep&lace<Tab>:%s	&Zamie�<Tab>:%s
menutrans Find\ and\ Rep&lace		&Zamie�
menutrans Find\ and\ Rep&lace<Tab>:s	&Zamie�<Tab>:s
menutrans Options\.\.\.			Opcje\.\.\.
menutrans Settings\ &Window		Ustawienia
menutrans &Global\ Settings		Ustawienia\ &globalne
menutrans Startup\ &Settings	Ustawienia\ &startowe
menutrans F&ile\ Settings		Ustawienia\ dla\ pliku
menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!			&Numerowanie\ wierszy<Tab>:set\ nu!
menutrans Toggle\ &List\ Mode<Tab>:set\ list!					Tryb\ &listowania<Tab>:set\ list!
menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!			Za&wijanie\ wierszy<Tab>:set\ wrap!
menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!			�amanie\ wie&rsza<Tab>:set\ lbr!
menutrans Toggle\ &expand-tab<Tab>:set\ et!			Rozwijani&e\ tabulator�w<Tab>:set\ et!
menutrans Toggle\ &auto-indent<Tab>:set\ ai!			&Automatyczne\ wci�cia<Tab>:set\ ai!
menutrans Toggle\ &C-indenting<Tab>:set\ cin!			Wci�cia\ &C<Tab>:set\ cin!
menutrans &Shiftwidth				&Szeroko��\ wci�cia
menutrans Te&xt\ Width\.\.\.			D�ugo��\ linii\.\.\.
menutrans &File\ Format\.\.\.			&Format\ pliku\.\.\.
menutrans Soft\ &Tabstop				Rozmiar\ &tabulacji
menutrans C&olor\ Scheme		Zestawy\ kolor�w
menutrans &Keymap			Uk�ady\ klawiatury
menutrans None				�aden
menutrans accents			akcenty
menutrans hebrew			hebrajski
menutrans hebrewp			hebrajski\ p
menutrans russian-jcuken		rosyjski-jcuken
menutrans russian-jcukenwin		rosyjski-jcukenwin

menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls!	Pod�wietlanie\ &wzorc�w<Tab>:set\ hls!

menutrans Toggle\ &Ignore-case<Tab>:set\ ic!	&Ignorowanie\ wielko�ci<Tab>:set\ ic!
menutrans Toggle\ &Showmatch<Tab>:set\ sm!		&Pokazywanie\ pasuj�cych<Tab>:set\ sm!

menutrans &Context\ lines	Wiersze\ &kontekstowe
menutrans &Virtual\ Edit	Edycja\ &wirtualna

menutrans Never			Nigdy
menutrans Block\ Selection	Zaznaczanie\ blokowe
menutrans Insert\ mode		Tryb\ wprowadzania
menutrans Toggle\ Vi\ C&ompatible<Tab>:set\ cp!	Tryb\ zg&odno�ci\ z\ Vi<Tab>:set\ cp!
menutrans Block\ and\ Insert	Blokowe\ i\ wprowadzanie
menutrans Always		Zawsze

menutrans Toggle\ Insert\ &Mode<Tab>:set\ im!	Tryb\ wprowadzania<Tab>:set\ im!
menutrans Search\ &Path\.\.\.	Scie�ka\ poszukiwania\.\.\.
menutrans Ta&g\ Files\.\.\.	Pliki\ tag�w\.\.\.


"
" GUI options
menutrans Toggle\ &Toolbar		Pasek\ narz�dzi
menutrans Toggle\ &Bottom\ Scrollbar	Dolny\ przewijacz
menutrans Toggle\ &Left\ Scrollbar	&Lewy\ przewijacz
menutrans Toggle\ &Right\ Scrollbar	P&rawy\ przewijacz

" Programming menu
menutrans &Tools			&Narz�dzia
menutrans &Jump\ to\ this\ tag<Tab>g^]	&Skocz\ do\ taga<Tab>g^]
menutrans Jump\ &back<Tab>^T		Skok\ w\ &ty�<Tab>^T
menutrans Build\ &Tags\ File		&Tw�rz\ plik\ tag�w
" Spelling
menutrans &Spelling	Pi&sownia
menutrans &Spell\ Check\ On	W��cz
menutrans Spell\ Check\ &Off	Wy��cz
menutrans To\ &Next\ error<Tab>]s	Do\ &nast�pnego\ b��du<Tab>]s
menutrans To\ &Previous\ error<Tab>[s	Do\ &poprzedniego\ b��du<Tab>[s
menutrans Suggest\ &Corrections<Tab>z=	Sugestie\ poprawek<Tab>z=
menutrans &Repeat\ correction<Tab>:spellrepall	Powt�r&z\ poprawk�<Tab>:spellrepall
menutrans Set\ language\ to\ "en"	Ustaw\ j�zyk\ na\ "en"
menutrans Set\ language\ to\ "en_au"	Ustaw\ j�zyk\ na\ "en_au"
menutrans Set\ language\ to\ "en_ca"	Ustaw\ j�zyk\ na\ "en_ca"
menutrans Set\ language\ to\ "en_gb"	Ustaw\ j�zyk\ na\ "en_gb"
menutrans Set\ language\ to\ "en_nz"	Ustaw\ j�zyk\ na\ "en_nz"
menutrans Set\ language\ to\ "en_us"	Ustaw\ j�zyk\ na\ "en_us"
menutrans Set\ language\ to\ "pl"	Ustaw\ j�zyk\ na\ "pl"
menutrans &Find\ More\ Languages	&Znajd�\ wi�cej\ j�zyk�w

" Folding
menutrans &Folding				&Zwijanie
menutrans &Enable/Disable\ folds<Tab>zi		&Zwi�/rozwi�<Tab>zi
menutrans &View\ Cursor\ Line<Tab>zv			&Linia\ kursora<Tab>zv
menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx			&Tylko\ linia\ kursora<Tab>zMzx
menutrans C&lose\ more\ folds<Tab>zm				Zwi�\ wi�cej<Tab>zm
menutrans &Close\ all\ folds<Tab>zM				Z&wi�\ wszystkie<Tab>zM
menutrans &Open\ all\ folds<Tab>zR				Rozwi�\ wszystkie<Tab>zR
menutrans O&pen\ more\ folds<Tab>zr				R&ozwi�\ wi�cej<Tab>zr

menutrans Create\ &Fold<Tab>zf				T&w�rz\ zawini�cie<Tab>zf
menutrans &Delete\ Fold<Tab>zd				U&su�\ zawini�cie<Tab>zd
menutrans Delete\ &All\ Folds<Tab>zD				&Usu�\ wszystkie\ zawini�cia<Tab>zD
menutrans Fold\ column\ &width				Szeroko��\ kolumny\ za&wini��
menutrans Fold\ Met&hod		Me&toda\ zawijania
menutrans M&anual			&R�cznie
menutrans I&ndent			W&ci�cie
menutrans E&xpression W&yra�enie
menutrans S&yntax			S&k�adnia
menutrans Ma&rker			Zn&acznik

" Diff
menutrans &Update					&Od�wie�
menutrans &Get\ Block			&Pobierz\ blok
menutrans &Put\ Block			&Wstaw\ blok

" Make and stuff...
menutrans &Make<Tab>:make		M&ake<Tab>:make
menutrans &List\ Errors<Tab>:cl		&Poka�\ b��dy<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!	W&ylicz\ powiadomienia<Tab>:cl!
menutrans &Next\ Error<Tab>:cn		&Nast�pny\ b��d<Tab>:cn
menutrans &Previous\ Error<Tab>:cp	&Poprzedni\ b��d<Tab>:cp
menutrans &Older\ List<Tab>:cold	&Starsza\ lista<Tab>:cold
menutrans N&ewer\ List<Tab>:cnew	N&owsza\ lista<Tab>:cnew
menutrans Error\ &Window	Okno\ b��d�&w
menutrans &Update<Tab>:cwin			Akt&ualizuj<Tab>:cwin
menutrans &Close<Tab>:cclose			&Zamknij<Tab>:cclose
menutrans &Open<Tab>:copen			&Otw�rz<Tab>:copen

menutrans Se&T\ Compiler				U&staw\ kompilator
menutrans &Convert\ to\ HEX<Tab>:%!xxd     Kody\ szesnastkowe<Tab>:%!xxd
menutrans Conve&rt\ back<Tab>:%!xxd\ -r     Zwyk�y\ tekst<Tab>:%!xxd\ -r

" Names for buffer menu.
menutrans &Buffers	&Bufory
menutrans &Refresh\ menu	&Od�wie�
menutrans &Delete	&Skasuj
menutrans &Alternate	&Zmie�
menutrans &Next		&Nast�pny
menutrans &Previous	&Poprzedni
menutrans [No\ File]	[Brak\ Pliku]

" Window menu
menutrans &Window			&Widoki
menutrans &New<Tab>^Wn			&Nowy<Tab>^Wn
menutrans S&plit<Tab>^Ws		Po&dziel<Tab>^Ws
menutrans Sp&lit\ To\ #<Tab>^W^^	P&odziel\ na\ #<Tab>^W^^
menutrans Split\ &Vertically<Tab>^Wv	Podziel\ pionowo<Tab>^Wv
menutrans Split\ File\ E&xplorer		Otw�rz\ mened�er\ plik�w

menutrans &Close<Tab>^Wc		&Zamknij<Tab>^Wc
menutrans Close\ &Other(s)<Tab>^Wo	Zamknij\ &inne<Tab>^Wo
menutrans Ne&xt<Tab>^Ww			&Nast�pny<Tab>^Ww
menutrans P&revious<Tab>^WW		&Poprzedni<Tab>^WW
menutrans &Equal\ Size<Tab>^W=		&Wyr�wnaj\ wysoko�ci<Tab>^W=
menutrans &Max\ Height<Tab>^W_		Z&maksymalizuj\ wysoko��<Tab>^W_
menutrans M&in\ Height<Tab>^W1_		Zminim&alizuj\ wysoko��<Tab>^W1_
menutrans Max\ Width<Tab>^W\|		Maksymalna\ szeroko��<Tab>^W\|
menutrans Min\ Width<Tab>^W1\|		Minimalna\ szeroko��<Tab>^W1\|
menutrans Max\ &Width<Tab>^W\|		Zmaksymalizuj\ szeroko��<Tab>^W\|
menutrans Min\ Widt&h<Tab>^W1\|		Zminimalizuj\ szeroko��<Tab>^W1\|
menutrans Move\ &To			&Id�\ do
menutrans &Top<Tab>^WK			&G�ra<Tab>^WK
menutrans &Bottom<Tab>^WJ		&D�<Tab>^WJ
menutrans &Left\ side<Tab>^WH		&Lewa\ strona<Tab>^WH
menutrans &Right\ side<Tab>^WL		&Prawa\ strona<Tab>^WL
menutrans Rotate\ &Up<Tab>^WR		Obr��\ w\ &g�r�<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr		Obr��\ w\ &d�<Tab>^Wr
menutrans Split\ &Vertically<Tab>^Wv	&Podziel\ w\ poziomie<Tab>^Wv
menutrans Select\ Fo&nt\.\.\.		Wybierz\ &czcionk�\.\.\.

" The popup menu
menutrans &Undo			&Cofnij
menutrans Cu&t			W&ytnij
menutrans &Copy			&Kopiuj
menutrans &Paste		&Wklej
menutrans &Delete		&Skasuj
menutrans Select\ Blockwise	Zaznacz\ &blok
menutrans Select\ &Sentence	Zaznacz\ &zdanie
menutrans Select\ Pa&ragraph	Zaznacz\ aka&pit
menutrans Select\ &Word		Zaznacz\ &s�owo
menutrans Select\ &Line		Zaznacz\ w&iersz
menutrans Select\ &Block	Zaznacz\ &blok
menutrans Select\ &All		Zaznacz\ c&a�o��
menutrans Input\ &Methods	Wprowadza&nie

" The GUI toolbar
if has("toolbar")
  if exists("*Do_toolbar_tmenu")
    delfun Do_toolbar_tmenu
  endif
  fun Do_toolbar_tmenu()
    tmenu ToolBar.Open		Otw�rz plik
    tmenu ToolBar.Save		Zapisz bie��cy plik
    tmenu ToolBar.SaveAll		Zapisz wszystkie pliki
    tmenu ToolBar.Print		Drukuj
    tmenu ToolBar.Undo		Cofnij
    tmenu ToolBar.Redo		Pon�w
    tmenu ToolBar.Cut		Wytnij
    tmenu ToolBar.Copy		Skopiuj
    tmenu ToolBar.Paste		Wklej
    tmenu ToolBar.Find		Szukaj...
    tmenu ToolBar.FindNext	Szukaj nast�pnego
    tmenu ToolBar.FindPrev	Szukaj poprzedniego
    tmenu ToolBar.Replace		Szukaj i zamieniaj...
    if 0	" disabled; These are in the Windows menu
      tmenu ToolBar.New		Nowy widok
      tmenu ToolBar.WinSplit	Podziel widok
      tmenu ToolBar.WinMax		Zmaksymalizuj widok
      tmenu ToolBar.WinMin		Zminimalizuj widok
      tmenu ToolBar.WinClose	Zamknij widok
    endif
    tmenu ToolBar.LoadSesn	Za�aduj sesj�
    tmenu ToolBar.SaveSesn	Zachowaj bie��c� sesj�
    tmenu ToolBar.RunScript	Uruchom skrypt Vima
    tmenu ToolBar.Make		Wykonaj bie��cy projekt
    tmenu ToolBar.Shell		Otw�rz pow�ok�
    tmenu ToolBar.RunCtags	Tw�rz tagi w bie��cym katalogu
    tmenu ToolBar.TagJump		Skok do taga pod kursorem
    tmenu ToolBar.Help		Pomoc Vima
    tmenu ToolBar.FindHelp	Przeszukuj pomoc Vim-a
  endfun
endif

" Syntax menu
menutrans &Syntax &Sk�adnia
menutrans &Show\ filetypes\ in\ menu	Poka�\ typy\ &plik�w\ w\ menu
menutrans Set\ '&syntax'\ only	Ustaw\ tylko\ '&syntax'
menutrans Set\ '&filetype'\ too	Ustaw\ r�wnie�\ '&filetype'
menutrans &Off			&Wy��cz
menutrans &Manual		&R�cznie
menutrans A&utomatic		A&utomatyczne
menutrans on/off\ for\ &This\ file			w��cz/w&y��cz\ dla\ pliku
menutrans Co&lor\ test		Test\ &kolor�w
menutrans &Highlight\ test	&Test\ pod�wietlania
menutrans &Convert\ to\ HTML	Przetw�rz\ na\ &HTML

" dialog texts
let menutrans_no_file = "[Brak pliku]"
let menutrans_help_dialog = "Wprowad� komend� lub s�owo, aby otrzyma� pomoc o:\n\nPrzedrostek i_ oznacza komend� trybu Wprowadzania (np. i_CTRL-X)\nPrzedrostek c_ oznacza komend� edycji wiersza komend (np. c_<Del>)\nPrzedrostek ' oznacza nazw� opcji (np. 'shiftwidth')"
let g:menutrans_path_dialog = "Wprowad� �cie�k� poszukiwania plik�w.\nProsz� rozdziela� nazwy katalog�w przecinkiem."
let g:menutrans_tags_dialog = "Podaj nazwy plik�w tag�w.\nProsz� rozdziela� nazwy przecinkiem."
let g:menutrans_textwidth_dialog = "Wprowad� now� szeroko�� tekstu (0 wy��cza przewijanie): "
let g:menutrans_fileformat_dialog = "Wybierz format w kt�rym ten plik ma by� zapisany"
let g:menutrans_fileformat_choices = "&Unix\n&Dos\n&Mac\n&Anuluj"

let &cpo = s:keepcpo
unlet s:keepcpo
