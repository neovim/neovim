" Menu Translations:	German / Deutsch
" Maintainer:		Georg Dahn <gorgyd@yahoo.co.uk>
" Originally By:	Marcin Dalecki <dalecki@cs.net.pl>
"			Johannes Zellner <johannes@zellner.org>
" Last Change:	Sat, 11 Mar 2006 22:40:00 CEST
" vim:set foldmethod=marker tabstop=8:

" Quit when menu translations have already been done.
if exists("did_menu_trans")
  finish
endif
let did_menu_trans = 1
let s:keepcpo= &cpo
set cpo&vim

" The translations below are in latin1, but they work for cp1252 and
" iso-8859-15 without conversion as well.
if &enc != "cp1252" && &enc != "iso-8859-15"
  scriptencoding latin1
endif

" {{{ FILE / DATEI
menutrans &File				&Datei
menutrans &Open\.\.\.<Tab>:e		&Öffnen\.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp	In\ geteiltem\ &Fenster\ öffnen\.\.\.<Tab>:sp
menutrans Open\ Tab\.\.\.<Tab>:tabnew	In\ neuem\ &Tab\ öffnen\.\.\.<Tab>:tabnew
menutrans &New<Tab>:enew		&Neue\ Datei<Tab>:enew
menutrans &Close<Tab>:close		S&chließen<Tab>:close
menutrans &Save<Tab>:w			&Speichern<Tab>:w
menutrans Save\ &As\.\.\.<Tab>:sav	Speichern\ &als\.\.\.<Tab>:sav
menutrans &Print			&Drucken
menutrans Sa&ve-Exit<Tab>:wqa		Speichern\ und\ Be&enden<Tab>:wqa
menutrans E&xit<Tab>:qa			&Beenden<Tab>:qa

if has("diff")
    menutrans Split\ &Diff\ with\.\.\.	D&ifferenz\ in\ geteiltem\ Fenster\ mit\.\.\.
    menutrans Split\ Patched\ &By\.\.\.	&Patch\ in\ geteiltem\ Fenster\ mit\.\.\.
endif
" }}} FILE / DATEI

" {{{ EDIT / EDITIEREN
menutrans &Edit				&Editieren
menutrans &Undo<Tab>u			Z&urück<Tab>u
menutrans &Redo<Tab>^R			Vo&r<Tab>^R
menutrans Rep&eat<Tab>\.		&Wiederholen<Tab>\.
menutrans Cu&t<Tab>"+x			&Ausschneiden<Tab>"+x
menutrans &Copy<Tab>"+y			&Kopieren<Tab>"+y
menutrans &Paste<Tab>"+gP		Ein&fügen<Tab>"+gP
menutrans Put\ &Before<Tab>[p		Da&vor\ einfügen<Tab>[p
menutrans Put\ &After<Tab>]p		Da&nach\ einfügen<Tab>]p
menutrans &Delete<Tab>x			&Löschen<Tab>x
menutrans &Select\ All<Tab>ggVG		Alles\ &markieren<Tab>ggVG
menutrans &Find\.\.\.			&Suchen\.\.\.
menutrans Find\ and\ Rep&lace\.\.\.	Suchen\ und\ &Ersetzen\.\.\.

" [-- SETTINGS --]
" XXX &E would conflict with 'Suchen\ und\ &Ersetzen', see above
menutrans Settings\ &Window				E&instellungen\.\.\.
menutrans &Global\ Settings				&Globale\ Einstellungen
menutrans Startup\ &Settings				&Starteinstellungen

menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls!	&Hervorhebungen\ ein-\ und\ ausschalten<Tab>:set\ hls!
menutrans Toggle\ &Ignore-case<Tab>:set\ ic!		Großschreibung\ &ignorieren\ oder\ benutzen<Tab>:set\ ic!
menutrans Toggle\ &Showmatch<Tab>:set\ sm!		Anzeige\ des\ passenden\ &Symbols\ ein-\ und\ ausschalten<Tab>:set\ sm!

menutrans &Context\ lines				&Zusammenhang

menutrans &Virtual\ Edit				&Virtueller\ Editier-Modus
menutrans Never						Nie
menutrans Block\ Selection				Block-Auswahl
menutrans Insert\ mode					Einfüge-Modus
menutrans Block\ and\ Insert				Block-Auswahl\ und\ Einfüge-Modus
menutrans Always					Immer
menutrans Toggle\ Insert\ &Mode<Tab>:set\ im!		Einfüge-&Modus\ ein-\ und\ ausschalten<Tab>:set\ im!
menutrans Toggle\ Vi\ C&ompatible<Tab>:set\ cp!		Vi-Kompatibilität\ ein-\ und\ ausschalten<Tab>:set\ cp!

menutrans Search\ &Path\.\.\.				Such-&Pfad\.\.\.
menutrans Ta&g\ Files\.\.\.				Ta&g-Dateien\.\.\.

menutrans Toggle\ &Toolbar				Werkzeugleiste\ ein-\ und\ ausschalten
menutrans Toggle\ &Bottom\ Scrollbar			Unteren\ Rollbalken\ ein-\ und\ ausschalten
menutrans Toggle\ &Left\ Scrollbar			Linken\ Rollbalken\ ein-\ und\ ausschalten
menutrans Toggle\ &Right\ Scrollbar			Rechten\ Rollbalken\ ein-\ und\ ausschalten

" Edit/File Settings
menutrans F&ile\ Settings				&Datei-Einstellungen

" Boolean options
menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!		Anzeige\ der\ Zeilen&nummer\ ein-\ und\ ausschalten<Tab>:set\ nu!
menutrans Toggle\ relati&ve\ Line\ Numbering<Tab>:set\ rnu!	Anzeige\ der\ relati&ven\ Zeilennummer\ ein-\ und\ ausschalten<Tab>:set\ rnu!
menutrans Toggle\ &List\ Mode<Tab>:set\ list!			&List-Modus\ ein-\ und\ ausschalten<Tab>:set\ list!
menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!			&Zeilenumbruch\ ein-\ und\ ausschalten<Tab>:set\ wrap!
menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!		Umbruch\ an\ &Wortgrenzen\ ein-\ und\ ausschalten<Tab>:set\ lbr!
menutrans Toggle\ &expand-tab<Tab>:set\ et!			&Erweiterung\ von\ Tabulatoren\ ein-\ und\ ausschalten<Tab>:set\ et!
menutrans Toggle\ &auto-indent<Tab>:set\ ai!			&Automatische\ Einrückung\ ein-\ und\ ausschalten<Tab>:set\ ai!
menutrans Toggle\ &C-indenting<Tab>:set\ cin!			&C-Einrückung\ ein-\ und\ ausschalten<Tab>:set\ cin!

" other options
menutrans &Shiftwidth					&Schiebeweite
menutrans Soft\ &Tabstop				&Tabulator
menutrans Te&xt\ Width\.\.\.				Te&xtbreite\.\.\.
menutrans &File\ Format\.\.\.				&Dateiformat\.\.\.
menutrans C&olor\ Scheme				F&arbschema\.\.\.
menutrans &Keymap					&Tastaturbelegung
" }}} EDIT / EDITIEREN

" {{{  TOOLS / WERKZEUGE
if has("spell")
    menutrans &Spelling					&Rechtschreibung
    menutrans &Spell\ Check\ On				&Rechtschreibprüfung\ an
    menutrans Spell\ Check\ &Off			Rechtschreibprüfung\ &aus
    menutrans To\ &Next\ error<Tab>]s			Zum\ &nächsten\ Fehler<Tab>]s
    menutrans To\ &Previous\ error<Tab>[s		Zum\ &vorherigen\ Fehler<Tab>[s
    menutrans Suggest\ &Corrections<Tab>z=		&Korrekturvorschläge<Tab>z=
    menutrans &Repeat\ correction<Tab>:spellrepall	&Wiederhole\ Korrektur<Tab>:spellrepall
    menutrans Set\ language\ to\ "en"			Verwende\ Wörterbuch\ "en"
    menutrans Set\ language\ to\ "en_au"		Verwende\ Wörterbuch\ "en_au"
    menutrans Set\ language\ to\ "en_ca"		Verwende\ Wörterbuch\ "en_ca"
    menutrans Set\ language\ to\ "en_gb"		Verwende\ Wörterbuch\ "en_gb"
    menutrans Set\ language\ to\ "en_nz"		Verwende\ Wörterbuch\ "en_nz"
    menutrans Set\ language\ to\ "en_us"		Verwende\ Wörterbuch\ "en_us"
    menutrans Set\ language\ to\ "de"			Verwende\ Wörterbuch\ "de"
    menutrans &Find\ More\ Languages			&Suche\ nach\ Wörterbüchern
endif
if has("folding")
  menutrans &Folding					Fa&ltung
  " open close folds
  menutrans &Enable/Disable\ folds<Tab>zi		&Ein-\ und\ ausschalten<Tab>zi
  menutrans &View\ Cursor\ Line<Tab>zv			Momentane\ &Position\ anzeigen<Tab>zv
  menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx		&Ausschließlich\ momentane\ Position\ anzeigen<Tab>zMzx
  menutrans C&lose\ more\ folds<Tab>zm			Faltungen\ &schließen<Tab>zm
  menutrans &Close\ all\ folds<Tab>zM			Alle\ Faltungen\ schließen<Tab>zM
  menutrans O&pen\ more\ folds<Tab>zr			Faltungen\ &öffnen<Tab>zr
  menutrans &Open\ all\ folds<Tab>zR			Alle\ Faltungen\ öffnen<Tab>zR
  " fold method
  menutrans Fold\ Met&hod				Faltungs-&Methode
  menutrans M&anual					&Manuell
  menutrans I&ndent					&Einrückungen
  menutrans E&xpression					&Ausdruck
  menutrans S&yntax					&Syntax
  menutrans &Diff					&Differenz
  menutrans Ma&rker					Ma&rkierungen
  " create and delete folds
  " TODO accelerators
  menutrans Create\ &Fold<Tab>zf			Faltung\ erzeugen<Tab>zf
  menutrans &Delete\ Fold<Tab>zd			Faltung\ löschen<Tab>zd
  menutrans Delete\ &All\ Folds<Tab>zD			Alle\ Faltungen\ löschen<Tab>zD
  " moving around in folds
  menutrans Fold\ column\ &width			&Breite\ der\ Faltungsspalte
endif  " has folding

if has("diff")
  menutrans &Diff					&Differenz
  menutrans &Update					&Aktualisieren
  menutrans &Get\ Block					Block\ &einfügen
  menutrans &Put\ Block					Block\ &übertragen
endif

menutrans &Tools					&Werkzeuge
menutrans &Jump\ to\ this\ tag<Tab>g^]			&Springe\ zum\ Tag<Tab>g^]
menutrans Jump\ &back<Tab>^T				Springe\ &zurück<Tab>^T
menutrans Build\ &Tags\ File				Erstelle\ &Tag-Datei
menutrans &Make<Tab>:make				&Erstellen<Tab>:make
menutrans &List\ Errors<Tab>:cl				&Fehler\ anzeigen<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!			&Hinweise\ anzeigen<Tab>:cl!
menutrans &Next\ Error<Tab>:cn				Zum\ &nächsten\ Fehler<Tab>:cn
menutrans &Previous\ Error<Tab>:cp			Zum\ &vorherigen\ Fehler<Tab>:cp
menutrans &Older\ List<Tab>:cold			&Ältere\ Liste<Tab>:cold
menutrans N&ewer\ List<Tab>:cnew			&Neuere\ Liste<Tab>:cnew

menutrans Error\ &Window				Feh&ler-Fenster
menutrans Se&t\ Compiler				&Compiler
menutrans Se&T\ Compiler				&Compiler
menutrans &Update<Tab>:cwin				&Aktualisieren<Tab>:cwin
menutrans &Open<Tab>:copen				&Öffnen<Tab>:copen
menutrans &Close<Tab>:cclose				&Schließen<Tab>:cclose

menutrans &Convert\ to\ HEX<Tab>:%!xxd			Nach\ HE&X\ konvertieren<Tab>:%!xxd
menutrans Conve&rt\ back<Tab>:%!xxd\ -r			Zurück\ konvertieren<Tab>:%!xxd\ -r
" }}}  TOOLS / WERKZEUGE

" {{{ SYNTAX / SYNTAX
menutrans &Syntax				&Syntax
menutrans &Show\ filetypes\ in\ menu		Dateitypen\ an&zeigen
menutrans Set\ '&syntax'\ only			Nur\ '&syntax'\ setzen
menutrans Set\ '&filetype'\ too			Auch\ '&filetype'\ setzen
menutrans &Off					&Aus
menutrans &Manual				&Manuell
menutrans A&utomatic				A&utomatisch
menutrans on/off\ for\ &This\ file		An/Aus (diese\ &Datei)
menutrans Co&lor\ test				Test\ der\ Farben
menutrans &Highlight\ test			Test\ der\ Un&terstreichungen
menutrans &Convert\ to\ HTML			Konvertieren\ nach\ &HTML
" }}} SYNTAX / SYNTAX

" {{{ BUFFERS / PUFFER
menutrans &Buffers					&Puffer
menutrans &Refresh\ menu				&Aktualisieren
menutrans Delete					Löschen
menutrans &Alternate					&Wechseln
menutrans &Next						&Nächster
menutrans &Previous					&Vorheriger
" }}} BUFFERS / PUFFER

" {{{ WINDOW / ANSICHT
menutrans &Window			&Ansicht
menutrans &New<Tab>^Wn			&Neu<Tab>^Wn
menutrans S&plit<Tab>^Ws		Aufs&palten<Tab>^Ws
menutrans Split\ &Vertically<Tab>^Wv	&Vertikal\ aufspalten<Tab>^Wv
menutrans Split\ File\ E&xplorer	Ver&zeichnis
menutrans Sp&lit\ To\ #<Tab>^W^^	Aufspa&lten\ in\ #<Tab>^W^^
menutrans &Close<Tab>^Wc		&Schließen<Tab>^Wc
menutrans Close\ &Other(s)<Tab>^Wo	&Andere\ schließen<Tab>^Wo
menutrans Ne&xt<Tab>^Ww			N&ächstes<Tab>^Ww
menutrans P&revious<Tab>^WW		Vor&heriges<Tab>^WW
menutrans &Equal\ Size<Tab>^W=		&Gleiche\ Höhen<Tab>^W=
menutrans &Max\ Height<Tab>^W_		&Maximale\ Höhe<Tab>^W_
menutrans M&in\ Height<Tab>^W1_		M&inimale\ Höhe<Tab>^W1_
menutrans Max\ &Width<Tab>^W\|		Maximale\ &Breite<Tab>^W\|
menutrans Min\ Widt&h<Tab>^W1\|		Minimale\ Brei&te<Tab>^W1\|
menutrans Move\ &To			V&erschiebe\ nach
menutrans &Top<Tab>^WK			&Oben<Tab>^WK
menutrans &Bottom<Tab>^WJ		&Unten<Tab>^WJ
menutrans &Left\ side<Tab>^WH		&Links<Tab>^WH
menutrans &Right\ side<Tab>^WL		&Rechts<Tab>^WL
menutrans Rotate\ &Up<Tab>^WR		Rotiere\ nach\ &oben<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr		Rotiere\ nach\ &unten<Tab>^Wr
menutrans Select\ Fo&nt\.\.\.		Auswahl\ der\ Schriftart\.\.\.
" }}} WINDOW / ANSICHT

" {{{ HELP / HILFE
menutrans &Help			&Hilfe
menutrans &Overview<Tab><F1>	&Überblick<Tab><F1>
menutrans &User\ Manual		&Handbuch
menutrans &How-to\ links	How-to\ &Index
menutrans &GUI			&Graphische\ Oberfläche
menutrans &Credits		&Autoren
menutrans Co&pying		&Urheberrecht
menutrans O&rphans		&Waisen
menutrans &Find\.\.\.		&Suchen\.\.\.	" conflicts with Edit.Find
menutrans &Version		&Version
menutrans &About		&Titelseite
" }}} HELP / HILFE

" {{{ POPUP
menutrans &Undo				&Zurück
menutrans Cu&t				Aus&schneiden
menutrans &Copy				&Kopieren
menutrans &Paste			&Einfügen
menutrans &Delete			&Löschen
menutrans Select\ Blockwise		Auswahl\ blockartig
menutrans Select\ &Word			Auswahl\ des\ &Wortes
menutrans Select\ &Sentence		Auswahl\ des\ Sa&tzes
menutrans Select\ Pa&ragraph		Auswahl\ des\ Absatzes
menutrans Select\ &Line			Auswahl\ der\ &Zeile
menutrans Select\ &Block		Auswahl\ des\ &Blocks
menutrans Select\ &All			&Alles\ Auswählen
" }}} POPUP

" {{{ TOOLBAR
if has("toolbar")
  if exists("*Do_toolbar_tmenu")
    delfun Do_toolbar_tmenu
  endif
  fun Do_toolbar_tmenu()
    tmenu ToolBar.Open		Datei öffnen
    tmenu ToolBar.Save		Datei speichern
    tmenu ToolBar.SaveAll	Alle Dateien speichern
    tmenu ToolBar.Print		Drucken
    tmenu ToolBar.Undo		Zurück
    tmenu ToolBar.Redo		Wiederholen
    tmenu ToolBar.Cut		Ausschneiden
    tmenu ToolBar.Copy		Kopieren
    tmenu ToolBar.Paste		Einfügen
    tmenu ToolBar.Find		Suchen...
    tmenu ToolBar.FindNext	Suche nächsten
    tmenu ToolBar.FindPrev	Suche vorherigen
    tmenu ToolBar.Replace	Suchen und Ersetzen...
    if 0	" disabled; These are in the Windows menu
      tmenu ToolBar.New		Neue Ansicht
      tmenu ToolBar.WinSplit	Ansicht aufspalten
      tmenu ToolBar.WinMax	Ansicht maximale Höhen
      tmenu ToolBar.WinMin	Ansicht minimale Höhen
      tmenu ToolBar.WinClose	Ansicht schließen
    endif
    tmenu ToolBar.LoadSesn	Sitzung laden
    tmenu ToolBar.SaveSesn	Sitzung speichern
    tmenu ToolBar.RunScript	Vim-Skript ausführen
    tmenu ToolBar.Make		Erstellen
    tmenu ToolBar.Shell		Shell starten
    tmenu ToolBar.RunCtags	Erstelle Tag-Datei
    tmenu ToolBar.TagJump	Springe zum Tag
    tmenu ToolBar.Help		Hilfe!
    tmenu ToolBar.FindHelp	Hilfe durchsuchen...
  endfun
endif
" }}} TOOLBAR

" {{{ DIALOG TEXTS
let g:menutrans_no_file = "[Keine Datei]"
let g:menutrans_help_dialog = "Geben Sie einen Befehl oder ein Wort ein, für das Sie Hilfe benötigen:\n\nVerwenden Sie i_ für Eingabe ('input') Befehle (z.B.: i_CTRL-X)\nVerwenden Sie c_ für Befehls-Zeilen ('command-line') Befehle (z.B.: c_<Del>)\nVerwenden Sie ' für Options-Namen (z.B.: 'shiftwidth')"
let g:menutrans_path_dialog = "Geben Sie Such-Pfade für Dateien ein.\nTrennen Sie die Verzeichnis-Namen durch Kommata."
let g:menutrans_tags_dialog = "Geben Sie die Namen der 'tag'-Dateien ein.\nTrennen Sie die Namen durch Kommata."
let g:menutrans_textwidth_dialog = "Geben Sie eine neue Text-Breite ein (oder 0, um die Formatierung abzuschalten)"
let g:menutrans_fileformat_dialog = "Wählen Sie ein Datei-Format aus"
" }}}

let &cpo = s:keepcpo
unlet s:keepcpo
