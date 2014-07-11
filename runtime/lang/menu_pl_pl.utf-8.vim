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

scriptencoding utf-8

" Help menu
menutrans &Help			Po&moc
menutrans &Overview<Tab><F1>			&Ogólnie<Tab><F1>
menutrans &User\ Manual	Podręcznik\ &użytkownika
menutrans &How-to\ links	&Odnośniki\ JTZ
menutrans &Find\.\.\.	&Szukaj\.\.\.
menutrans &Credits		Po&dziękowania
menutrans Co&pying		&Kopiowanie
menutrans &Sponsor/Register	&Sponsorowanie/Rejestracja
menutrans O&rphans		Sie&roty
menutrans &Version		&Wersja
menutrans &About		o\ &Programie

" File menu
menutrans &File				&Plik
menutrans &Open\.\.\.<Tab>:e		&Otwórz\.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp	Otwórz\ z\ &podziałem\.\.\.<Tab>:sp
menutrans &New<Tab>:enew       &Nowy<Tab>:enew
menutrans &Close<Tab>:close		&Zamknij<Tab>:close
menutrans &Save<Tab>:w			Za&pisz<Tab>:w
menutrans Save\ &As\.\.\.<Tab>:sav	Zapisz\ &jako\.\.\.<Tab>:sav
menutrans Split\ &Diff\ with\.\.\.	Podziel\ na\ diff-a\ między\.\.\.
menutrans Split\ Patched\ &By\.\.\.	Podziel\ łatane\ przez\.\.\.
menutrans &Print			&Drukuj
menutrans Sa&ve-Exit<Tab>:wqa		W&yjście\ z\ zapisem<Tab>:wqa
menutrans E&xit<Tab>:qa			&Wyjście<Tab>:qa
menutrans Open\ Tab\.\.\.<Tab>:tabnew	Otwórz\ &kartę\.\.\.<Tab>:tabnew

" Edit menu
menutrans &Edit				&Edycja
menutrans &Undo<Tab>u			&Cofnij<Tab>u
menutrans &Redo<Tab>^R			&Ponów<Tab>^R
menutrans Rep&eat<Tab>\.		P&owtórz<Tab>\.
menutrans Cu&t<Tab>"+x			W&ytnij<Tab>"+x
menutrans &Copy<Tab>"+y			&Kopiuj<Tab>"+y
menutrans &Paste<Tab>"+gP		&Wklej<Tab>"+gP
menutrans Put\ &Before<Tab>[p		Wstaw\ p&rzed<Tab>[p
menutrans Put\ &After<Tab>]p		Wstaw\ p&o<Tab>]p
menutrans &Select\ All<Tab>ggVG		Z&aznacz\ całość<Tab>ggVG
menutrans &Find\.\.\.			&Szukaj\.\.\.
menutrans &Find<Tab>/			&Szukaj<Tab>/
menutrans Find\ and\ Rep&lace\.\.\.	&Zamień\.\.\.
menutrans Find\ and\ Rep&lace<Tab>:%s	&Zamień<Tab>:%s
menutrans Find\ and\ Rep&lace		&Zamień
menutrans Find\ and\ Rep&lace<Tab>:s	&Zamień<Tab>:s
menutrans Options\.\.\.			Opcje\.\.\.
menutrans Settings\ &Window		Ustawienia
menutrans &Global\ Settings		Ustawienia\ &globalne
menutrans Startup\ &Settings	Ustawienia\ &startowe
menutrans F&ile\ Settings		Ustawienia\ dla\ pliku
menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!			&Numerowanie\ wierszy<Tab>:set\ nu!
menutrans Toggle\ &List\ Mode<Tab>:set\ list!					Tryb\ &listowania<Tab>:set\ list!
menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!			Za&wijanie\ wierszy<Tab>:set\ wrap!
menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!			Łamanie\ wie&rsza<Tab>:set\ lbr!
menutrans Toggle\ &expand-tab<Tab>:set\ et!			Rozwijani&e\ tabulatorów<Tab>:set\ et!
menutrans Toggle\ &auto-indent<Tab>:set\ ai!			&Automatyczne\ wcięcia<Tab>:set\ ai!
menutrans Toggle\ &C-indenting<Tab>:set\ cin!			Wcięcia\ &C<Tab>:set\ cin!
menutrans &Shiftwidth				&Szerokość\ wcięcia
menutrans Te&xt\ Width\.\.\.			Długość\ linii\.\.\.
menutrans &File\ Format\.\.\.			&Format\ pliku\.\.\.
menutrans Soft\ &Tabstop				Rozmiar\ &tabulacji
menutrans C&olor\ Scheme		Zestawy\ kolorów
menutrans &Keymap			Układy\ klawiatury
menutrans None				żaden
menutrans accents			akcenty
menutrans hebrew			hebrajski
menutrans hebrewp			hebrajski\ p
menutrans russian-jcuken		rosyjski-jcuken
menutrans russian-jcukenwin		rosyjski-jcukenwin

menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls!	Podświetlanie\ &wzorców<Tab>:set\ hls!

menutrans Toggle\ &Ignore-case<Tab>:set\ ic!	&Ignorowanie\ wielkości<Tab>:set\ ic!
menutrans Toggle\ &Showmatch<Tab>:set\ sm!		&Pokazywanie\ pasujących<Tab>:set\ sm!

menutrans &Context\ lines	Wiersze\ &kontekstowe
menutrans &Virtual\ Edit	Edycja\ &wirtualna

menutrans Never			Nigdy
menutrans Block\ Selection	Zaznaczanie\ blokowe
menutrans Insert\ mode		Tryb\ wprowadzania
menutrans Toggle\ Vi\ C&ompatible<Tab>:set\ cp!	Tryb\ zg&odności\ z\ Vi<Tab>:set\ cp!
menutrans Block\ and\ Insert	Blokowe\ i\ wprowadzanie
menutrans Always		Zawsze

menutrans Toggle\ Insert\ &Mode<Tab>:set\ im!	Tryb\ wprowadzania<Tab>:set\ im!
menutrans Search\ &Path\.\.\.	Scieżka\ poszukiwania\.\.\.
menutrans Ta&g\ Files\.\.\.	Pliki\ tagów\.\.\.


"
" GUI options
menutrans Toggle\ &Toolbar		Pasek\ narzędzi
menutrans Toggle\ &Bottom\ Scrollbar	Dolny\ przewijacz
menutrans Toggle\ &Left\ Scrollbar	&Lewy\ przewijacz
menutrans Toggle\ &Right\ Scrollbar	P&rawy\ przewijacz

" Programming menu
menutrans &Tools			&Narzędzia
menutrans &Jump\ to\ this\ tag<Tab>g^]	&Skocz\ do\ taga<Tab>g^]
menutrans Jump\ &back<Tab>^T		Skok\ w\ &tył<Tab>^T
menutrans Build\ &Tags\ File		&Twórz\ plik\ tagów
" Spelling
menutrans &Spelling	Pi&sownia
menutrans &Spell\ Check\ On	Włącz
menutrans Spell\ Check\ &Off	Wyłącz
menutrans To\ &Next\ error<Tab>]s	Do\ &następnego\ błędu<Tab>]s
menutrans To\ &Previous\ error<Tab>[s	Do\ &poprzedniego\ błędu<Tab>[s
menutrans Suggest\ &Corrections<Tab>z=	Sugestie\ poprawek<Tab>z=
menutrans &Repeat\ correction<Tab>:spellrepall	Powtór&z\ poprawkę<Tab>:spellrepall
menutrans Set\ language\ to\ "en"	Ustaw\ język\ na\ "en"
menutrans Set\ language\ to\ "en_au"	Ustaw\ język\ na\ "en_au"
menutrans Set\ language\ to\ "en_ca"	Ustaw\ język\ na\ "en_ca"
menutrans Set\ language\ to\ "en_gb"	Ustaw\ język\ na\ "en_gb"
menutrans Set\ language\ to\ "en_nz"	Ustaw\ język\ na\ "en_nz"
menutrans Set\ language\ to\ "en_us"	Ustaw\ język\ na\ "en_us"
menutrans Set\ language\ to\ "pl"	Ustaw\ język\ na\ "pl"
menutrans &Find\ More\ Languages	&Znajdź\ więcej\ języków

" Folding
menutrans &Folding				&Zwijanie
menutrans &Enable/Disable\ folds<Tab>zi		&Zwiń/rozwiń<Tab>zi
menutrans &View\ Cursor\ Line<Tab>zv			&Linia\ kursora<Tab>zv
menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx			&Tylko\ linia\ kursora<Tab>zMzx
menutrans C&lose\ more\ folds<Tab>zm				Zwiń\ więcej<Tab>zm
menutrans &Close\ all\ folds<Tab>zM				Z&wiń\ wszystkie<Tab>zM
menutrans &Open\ all\ folds<Tab>zR				Rozwiń\ wszystkie<Tab>zR
menutrans O&pen\ more\ folds<Tab>zr				R&ozwiń\ więcej<Tab>zr

menutrans Create\ &Fold<Tab>zf				T&wórz\ zawinięcie<Tab>zf
menutrans &Delete\ Fold<Tab>zd				U&suń\ zawinięcie<Tab>zd
menutrans Delete\ &All\ Folds<Tab>zD				&Usuń\ wszystkie\ zawinięcia<Tab>zD
menutrans Fold\ column\ &width				Szerokość\ kolumny\ za&winięć
menutrans Fold\ Met&hod		Me&toda\ zawijania
menutrans M&anual			&Ręcznie
menutrans I&ndent			W&cięcie
menutrans E&xpression W&yrażenie
menutrans S&yntax			S&kładnia
menutrans Ma&rker			Zn&acznik

" Diff
menutrans &Update					&Odśwież
menutrans &Get\ Block			&Pobierz\ blok
menutrans &Put\ Block			&Wstaw\ blok

" Make and stuff...
menutrans &Make<Tab>:make		M&ake<Tab>:make
menutrans &List\ Errors<Tab>:cl		&Pokaż\ błędy<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!	W&ylicz\ powiadomienia<Tab>:cl!
menutrans &Next\ Error<Tab>:cn		&Następny\ błąd<Tab>:cn
menutrans &Previous\ Error<Tab>:cp	&Poprzedni\ błąd<Tab>:cp
menutrans &Older\ List<Tab>:cold	&Starsza\ lista<Tab>:cold
menutrans N&ewer\ List<Tab>:cnew	N&owsza\ lista<Tab>:cnew
menutrans Error\ &Window	Okno\ błędó&w
menutrans &Update<Tab>:cwin			Akt&ualizuj<Tab>:cwin
menutrans &Close<Tab>:cclose			&Zamknij<Tab>:cclose
menutrans &Open<Tab>:copen			&Otwórz<Tab>:copen

menutrans Se&T\ Compiler				U&staw\ kompilator
menutrans &Convert\ to\ HEX<Tab>:%!xxd     Kody\ szesnastkowe<Tab>:%!xxd
menutrans Conve&rt\ back<Tab>:%!xxd\ -r     Zwykły\ tekst<Tab>:%!xxd\ -r

" Names for buffer menu.
menutrans &Buffers	&Bufory
menutrans &Refresh\ menu	&Odśwież
menutrans &Delete	&Skasuj
menutrans &Alternate	&Zmień
menutrans &Next		&Następny
menutrans &Previous	&Poprzedni
menutrans [No\ File]	[Brak\ Pliku]

" Window menu
menutrans &Window			&Widoki
menutrans &New<Tab>^Wn			&Nowy<Tab>^Wn
menutrans S&plit<Tab>^Ws		Po&dziel<Tab>^Ws
menutrans Sp&lit\ To\ #<Tab>^W^^	P&odziel\ na\ #<Tab>^W^^
menutrans Split\ &Vertically<Tab>^Wv	Podziel\ pionowo<Tab>^Wv
menutrans Split\ File\ E&xplorer		Otwórz\ menedżer\ plików

menutrans &Close<Tab>^Wc		&Zamknij<Tab>^Wc
menutrans Close\ &Other(s)<Tab>^Wo	Zamknij\ &inne<Tab>^Wo
menutrans Ne&xt<Tab>^Ww			&Następny<Tab>^Ww
menutrans P&revious<Tab>^WW		&Poprzedni<Tab>^WW
menutrans &Equal\ Size<Tab>^W=		&Wyrównaj\ wysokości<Tab>^W=
menutrans &Max\ Height<Tab>^W_		Z&maksymalizuj\ wysokość<Tab>^W_
menutrans M&in\ Height<Tab>^W1_		Zminim&alizuj\ wysokość<Tab>^W1_
menutrans Max\ Width<Tab>^W\|		Maksymalna\ szerokość<Tab>^W\|
menutrans Min\ Width<Tab>^W1\|		Minimalna\ szerokość<Tab>^W1\|
menutrans Max\ &Width<Tab>^W\|		Zmaksymalizuj\ szerokość<Tab>^W\|
menutrans Min\ Widt&h<Tab>^W1\|		Zminimalizuj\ szerokość<Tab>^W1\|
menutrans Move\ &To			&Idź\ do
menutrans &Top<Tab>^WK			&Góra<Tab>^WK
menutrans &Bottom<Tab>^WJ		&Dół<Tab>^WJ
menutrans &Left\ side<Tab>^WH		&Lewa\ strona<Tab>^WH
menutrans &Right\ side<Tab>^WL		&Prawa\ strona<Tab>^WL
menutrans Rotate\ &Up<Tab>^WR		Obróć\ w\ &górę<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr		Obróć\ w\ &dół<Tab>^Wr
menutrans Split\ &Vertically<Tab>^Wv	&Podziel\ w\ poziomie<Tab>^Wv
menutrans Select\ Fo&nt\.\.\.		Wybierz\ &czcionkę\.\.\.

" The popup menu
menutrans &Undo			&Cofnij
menutrans Cu&t			W&ytnij
menutrans &Copy			&Kopiuj
menutrans &Paste		&Wklej
menutrans &Delete		&Skasuj
menutrans Select\ Blockwise	Zaznacz\ &blok
menutrans Select\ &Sentence	Zaznacz\ &zdanie
menutrans Select\ Pa&ragraph	Zaznacz\ aka&pit
menutrans Select\ &Word		Zaznacz\ &słowo
menutrans Select\ &Line		Zaznacz\ w&iersz
menutrans Select\ &Block	Zaznacz\ &blok
menutrans Select\ &All		Zaznacz\ c&ałość
menutrans Input\ &Methods	Wprowadza&nie

" The GUI toolbar
if has("toolbar")
  if exists("*Do_toolbar_tmenu")
    delfun Do_toolbar_tmenu
  endif
  fun Do_toolbar_tmenu()
    tmenu ToolBar.Open		Otwórz plik
    tmenu ToolBar.Save		Zapisz bieżący plik
    tmenu ToolBar.SaveAll		Zapisz wszystkie pliki
    tmenu ToolBar.Print		Drukuj
    tmenu ToolBar.Undo		Cofnij
    tmenu ToolBar.Redo		Ponów
    tmenu ToolBar.Cut		Wytnij
    tmenu ToolBar.Copy		Skopiuj
    tmenu ToolBar.Paste		Wklej
    tmenu ToolBar.Find		Szukaj...
    tmenu ToolBar.FindNext	Szukaj następnego
    tmenu ToolBar.FindPrev	Szukaj poprzedniego
    tmenu ToolBar.Replace		Szukaj i zamieniaj...
    if 0	" disabled; These are in the Windows menu
      tmenu ToolBar.New		Nowy widok
      tmenu ToolBar.WinSplit	Podziel widok
      tmenu ToolBar.WinMax		Zmaksymalizuj widok
      tmenu ToolBar.WinMin		Zminimalizuj widok
      tmenu ToolBar.WinClose	Zamknij widok
    endif
    tmenu ToolBar.LoadSesn	Załaduj sesję
    tmenu ToolBar.SaveSesn	Zachowaj bieżącą sesję
    tmenu ToolBar.RunScript	Uruchom skrypt Vima
    tmenu ToolBar.Make		Wykonaj bieżący projekt
    tmenu ToolBar.Shell		Otwórz powłokę
    tmenu ToolBar.RunCtags	Twórz tagi w bieżącym katalogu
    tmenu ToolBar.TagJump		Skok do taga pod kursorem
    tmenu ToolBar.Help		Pomoc Vima
    tmenu ToolBar.FindHelp	Przeszukuj pomoc Vim-a
  endfun
endif

" Syntax menu
menutrans &Syntax &Składnia
menutrans &Show\ filetypes\ in\ menu	Pokaż\ typy\ &plików\ w\ menu
menutrans Set\ '&syntax'\ only	Ustaw\ tylko\ '&syntax'
menutrans Set\ '&filetype'\ too	Ustaw\ również\ '&filetype'
menutrans &Off			&Wyłącz
menutrans &Manual		&Ręcznie
menutrans A&utomatic		A&utomatyczne
menutrans on/off\ for\ &This\ file			włącz/w&yłącz\ dla\ pliku
menutrans Co&lor\ test		Test\ &kolorów
menutrans &Highlight\ test	&Test\ podświetlania
menutrans &Convert\ to\ HTML	Przetwórz\ na\ &HTML

" dialog texts
let menutrans_no_file = "[Brak pliku]"
let menutrans_help_dialog = "Wprowadź komendę lub słowo, aby otrzymać pomoc o:\n\nPrzedrostek i_ oznacza komendę trybu Wprowadzania (np. i_CTRL-X)\nPrzedrostek c_ oznacza komendę edycji wiersza komend (np. c_<Del>)\nPrzedrostek ' oznacza nazwę opcji (np. 'shiftwidth')"
let g:menutrans_path_dialog = "Wprowadź ścieżkę poszukiwania plików.\nProszę rozdzielać nazwy katalogów przecinkiem."
let g:menutrans_tags_dialog = "Podaj nazwy plików tagów.\nProszę rozdzielać nazwy przecinkiem."
let g:menutrans_textwidth_dialog = "Wprowadź nową szerokość tekstu (0 wyłącza przewijanie): "
let g:menutrans_fileformat_dialog = "Wybierz format w którym ten plik ma być zapisany"
let g:menutrans_fileformat_choices = "&Unix\n&Dos\n&Mac\n&Anuluj"

let &cpo = s:keepcpo
unlet s:keepcpo
