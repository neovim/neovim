" Menu Translations:	Francais
" Maintainer:		Adrien Beau <version.francaise@free.fr>
" First Version:	Francois Thunus <thunus@systran.fr>
" Last Modification:    David Blanchet <david.blanchet@free.fr>
" Last Change:		2012 May 01

" Quit when menu translations have already been done.
if exists("did_menu_trans")
  finish
endif
let did_menu_trans = 1
let s:keepcpo= &cpo
set cpo&vim

" The translations below are in latin1, but they work for cp1252 and
" iso-8859-15 without conversion as well.
if &enc != "cp1252" && &enc != "iso-8859-15" && &enc != "iso-8859-1"
  scriptencoding latin1
endif

menutrans &Help				&Aide

menutrans &Overview<Tab><F1>			&Sommaire<Tab><F1>
menutrans &User\ Manual				&Manuel\ utilisateur
menutrans &How-to\ links			&Tâches\ courantes
menutrans &Find\.\.\.				Rec&hercher\.\.\.
" -sep1-
menutrans &Credits				&Remerciements
menutrans Co&pying				&License
menutrans &Sponsor/Register			Sponsor/&Enregistrement
menutrans O&rphans				&Orphelins
" -sep2-
menutrans &Version				&Version
menutrans &About				À\ &propos\ de\ Vim

let g:menutrans_help_dialog = "Entrez une commande ou un mot à rechercher dans l'aide.\n\nAjoutez i_ pour les commandes du mode Insertion (ex: i_CTRL-X)\nAjoutez c_ pour l'édition de la ligne de commande (ex: c_<Del>)\nEntourez les options avec des apostrophes (ex: 'shiftwidth')"


menutrans &File				&Fichier

menutrans &Open\.\.\.<Tab>:e			&Ouvrir\.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp		Ouvrir\ à\ p&art\.\.\.<Tab>:sp
menutrans Open\ Tab\.\.\.<Tab>:tabnew		Ouvrir\ dans\ un\ onglet\.\.\.<Tab>:tabnew
menutrans &New<Tab>:enew			&Nouveau<Tab>:enew
menutrans &Close<Tab>:close			&Fermer<Tab>:close
" -SEP1-
menutrans &Save<Tab>:w				&Enregistrer<Tab>:w
menutrans Save\ &As\.\.\.<Tab>:sav		Enregistrer\ &sous\.\.\.<Tab>:sav
" -SEP2-
menutrans Split\ &Diff\ with\.\.\.		&Difference\ avec\.\.\.
"menutrans Split\ Patched\ &By\.\.\.		&Patcher\ avec\.\.\.
menutrans Split\ Patched\ &By\.\.\.		&Tester\ un\ patch\.\.\.
" -SEP3-
menutrans &Print				&Imprimer
" -SEP4-
menutrans Sa&ve-Exit<Tab>:wqa			En&registrer\ et\ quitter<Tab>:wqa
menutrans E&xit<Tab>:qa				&Quitter<Tab>:qa


menutrans &Edit				&Edition

menutrans &Undo<Tab>u				&Annuler<Tab>u
menutrans &Redo<Tab>^R				Re&faire<Tab>^R
menutrans Rep&eat<Tab>\.			R&épéter<Tab>\.
" -SEP1-
menutrans Cu&t<Tab>"+x				Co&uper<Tab>"+x
menutrans &Copy<Tab>"+y				Cop&ier<Tab>"+y
menutrans &Paste<Tab>"+gP			C&oller<Tab>"+gP
menutrans Put\ &Before<Tab>[p			Placer\ a&vant<Tab>[p
menutrans Put\ &After<Tab>]p			Placer\ apr&ès<Tab>]p
menutrans &Delete<Tab>x				Effa&cer<Tab>x
menutrans &Select\ All<Tab>ggVG			&Sélectionner\ tout<Tab>ggVG
" -SEP2-
menutrans &Find\.\.\.				Rec&hercher\.\.\.
menutrans Find\ and\ Rep&lace\.\.\.		Re&mplacer\.\.\.
menutrans &Find<Tab>/				Rec&hercher<Tab>/
menutrans Find\ and\ Rep&lace<Tab>:%s		Re&mplacer<Tab>:%s
menutrans Find\ and\ Rep&lace<Tab>:s		Re&mplacer<Tab>:s
" -SEP3-
menutrans Settings\ &Window			Fe&nêtre\ des\ réglages
menutrans &Global\ Settings			Réglages\ globau&x

menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls!	&Surligner\ recherche\ on/off<Tab>:set\ hls!
menutrans Toggle\ &Ignore-case<Tab>:set\ ic!		&Ignorer\ casse\ on/off<Tab>:set\ ic!
menutrans Toggle\ &Showmatch<Tab>:set\ sm!		Vérifier\ parenth&èses\ on/off<Tab>:set\ sm!

menutrans &Context\ lines				Lignes\ &autour\ du\ curseur

menutrans &Virtual\ Edit				Édition\ &virtuelle
menutrans Never							&Jamais
menutrans Block\ Selection					&Sélection\ en\ bloc
menutrans Insert\ mode						&Mode\ insertion
menutrans Block\ and\ Insert					&Bloc\ et\ insertion
menutrans Always						&Toujours

menutrans Toggle\ Insert\ &Mode<Tab>:set\ im!		I&nsertion\ permanente\ on/off<Tab>:set\ im!
menutrans Toggle\ Vi\ C&ompatible<Tab>:set\ cp!		&Compatibilité\ Vi\ on/off<Tab>:set\ cp!
menutrans Search\ &Path\.\.\.				Chemin\ de\ rec&herche\ des\ fichiers\.\.\.
menutrans Ta&g\ Files\.\.\.				Fichiers\ d'&étiquettes\.\.\.
" -SEP1-
menutrans Toggle\ &Toolbar				Barre\ d'&outils\ on/off
menutrans Toggle\ &Bottom\ Scrollbar			Ascenseur\ &horizontal\ on/off
menutrans Toggle\ &Left\ Scrollbar			Ascenseur\ à\ ga&uche\ on/off
menutrans Toggle\ &Right\ Scrollbar			Ascenseur\ à\ &droite\ on/off

let g:menutrans_path_dialog = "Entrez le chemin de recherche des fichiers.\nSéparez les répertoires par des virgules."
let g:menutrans_tags_dialog = "Entrez les noms des fichiers d'étiquettes.\nSéparez les noms par des virgules."

menutrans F&ile\ Settings			Réglages\ fichie&r

menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!	&Numérotation\ on/off<Tab>:set\ nu!
menutrans Toggle\ &List\ Mode<Tab>:set\ list!		Mode\ &listing\ on/off<Tab>:set\ list!
menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!		&Retour\ à\ la\ ligne\ on/off<Tab>:set\ wrap!
menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!	Retour\ sur\ &mot\ on/off<Tab>:set\ lbr!
menutrans Toggle\ &expand-tab<Tab>:set\ et!		&Tab\.\ en\ espaces\ on/off<Tab>:set\ et!
menutrans Toggle\ &auto-indent<Tab>:set\ ai!		Indentation\ &auto\.\ on/off<Tab>:set\ ai!
menutrans Toggle\ &C-indenting<Tab>:set\ cin!		Indent\.\ langage\ &C\ on/off<Tab>:set\ cin!
" -SEP2-
menutrans &Shiftwidth					Largeur\ des\ in&dentations
menutrans Soft\ &Tabstop				&Pseudo-tabulations
menutrans Te&xt\ Width\.\.\.				Largeur\ du\ te&xte\.\.\.
menutrans &File\ Format\.\.\.				Format\ du\ &fichier\.\.\.

let g:menutrans_textwidth_dialog = "Entrez la nouvelle largeur du texte\n(0 pour désactiver le formattage)."
let g:menutrans_fileformat_dialog = "Choisissez le format dans lequel écrire le fichier."
let g:menutrans_fileformat_choices = " &Unix \n &Dos \n &Mac \n &Annuler "

menutrans C&olor\ Scheme			&Jeu\ de\ couleurs
menutrans &Keymap				&Type\ de\ clavier
menutrans None						(aucun)
menutrans Select\ Fo&nt\.\.\.			Sélectionner\ &police\.\.\.


menutrans &Tools			&Outils

menutrans &Jump\ to\ this\ tag<Tab>g^]		&Atteindre\ cette\ étiquette<Tab>g^]
menutrans Jump\ &back<Tab>^T			Repartir\ en\ arri&ère<Tab>^T
menutrans Build\ &Tags\ File			&Générer\ fichier\ d'étiquettes

" -SEP1-
menutrans &Spelling			&Orthographe
menutrans &Spell\ Check\ On			&Activer
menutrans Spell\ Check\ &Off			&Désactiver
menutrans To\ &Next\ error<Tab>]s		À\ l'erreur\ &suivante<Tab>]s
menutrans To\ &Previous\ error<Tab>[s		À\ l'erreur\ &précédente<Tab>[s
menutrans Suggest\ &Corrections<Tab>z=		Suggérer\ &correction<Tab>z=
menutrans &Repeat\ correction<Tab>:spellrepall	&Reporter\ la\ correction<Tab>:spellrepall

an 40.335.205 &Tools.&Spelling.Français\ (fr)	:set spl=fr spell<CR>
menutrans Set\ language\ to\ "en"		Anglais
menutrans Set\ language\ to\ "en_au"		Anglais\ (en_au)
menutrans Set\ language\ to\ "en_ca"		Anglais\ (en_ca)
menutrans Set\ language\ to\ "en_gb"		Anglais\ (en_gb)
menutrans Set\ language\ to\ "en_nz"		Anglais\ (en_nz)
menutrans Set\ language\ to\ "en_us"		Anglais\ (en_us)

menutrans &Find\ More\ Languages		&Trouver\ d'autres\ langues



menutrans &Folding				&Replis

menutrans &Enable/Disable\ folds<Tab>zi			&Replis\ on/off<Tab>zi
menutrans &View\ Cursor\ Line<Tab>zv			D&éplier\ ligne\ curseur<Tab>zv
menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx		Tout\ plier\ &sauf\ ligne\ curseur<Tab>zMzx
menutrans C&lose\ more\ folds<Tab>zm			Fermer\ &plus\ de\ replis<Tab>zm
menutrans &Close\ all\ folds<Tab>zM			F&ermer\ tous\ les\ replis<Tab>zM
menutrans O&pen\ more\ folds<Tab>zr			Ouvrir\ pl&us\ de\ replis<Tab>zr
menutrans &Open\ all\ folds<Tab>zR			&Ouvrir\ tous\ les\ replis<Tab>zR
" -SEP1-
menutrans Fold\ Met&hod					&Méthode\ de\ repli

menutrans M&anual						&Manuelle
menutrans I&ndent						&Indentation
menutrans E&xpression						&Expression
menutrans S&yntax						&Syntaxe
menutrans &Diff							&Différence
menutrans Ma&rker						Ma&rqueurs

menutrans Create\ &Fold<Tab>zf				&Créer\ repli<Tab>zf
menutrans &Delete\ Fold<Tab>zd				E&ffacer\ repli<Tab>zd
menutrans Delete\ &All\ Folds<Tab>zD			Effacer\ &tous\ les\ replis<Tab>zD
" -SEP2-
menutrans Fold\ col&umn\ width				&Largeur\ colonne\ replis

menutrans &Diff					&Différence

menutrans &Update					&Mettre\ à\ jour
menutrans &Get\ Block					Corriger\ &ce\ tampon
menutrans &Put\ Block					Corriger\ l'&autre\ tampon

" -SEP2-
menutrans &Make<Tab>:make			Lancer\ ma&ke<Tab>:make
menutrans &List\ Errors<Tab>:cl			Lister\ &erreurs<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!		Lister\ &messages<Tab>:cl!
menutrans &Next\ Error<Tab>:cn			Erreur\ &suivante<Tab>:cn
menutrans &Previous\ Error<Tab>:cp		Erreur\ pr&écédente<Tab>:cp
"menutrans &Older\ List<Tab>:cold		A&ncienne\ liste<Tab>:cold
menutrans &Older\ List<Tab>:cold		Liste\ &précédente<Tab>:cold
"menutrans N&ewer\ List<Tab>:cnew		No&uvelle\ liste<Tab>:cnew
menutrans N&ewer\ List<Tab>:cnew		Liste\ suivan&te<Tab>:cnew

menutrans Error\ &Window			&Fenêtre\ d'erreurs

menutrans &Update<Tab>:cwin				&Mettre\ à\ jour<Tab>:cwin
menutrans &Open<Tab>:copen				&Ouvrir<Tab>:copen
menutrans &Close<Tab>:cclose				&Fermer<Tab>:cclose

" -SEP3-
menutrans &Convert\ to\ HEX<Tab>:%!xxd		Convertir\ en\ he&xa<Tab>:%!xxd
menutrans Conve&rt\ back<Tab>:%!xxd\ -r		Décon&vertir<Tab>:%!xxd\ -r

menutrans Se&T\ Compiler			&Type\ de\ compilateur


menutrans &Buffers			&Tampons

menutrans Dummy					Factice
menutrans &Refresh\ menu			&Mettre\ ce\ menu\ à\ jour
menutrans &Delete				&Effacer
menutrans &Alternate				&Alterner
menutrans &Next					&Suivant
menutrans &Previous				&Précédent
" -SEP-

menutrans &others				au&tres
menutrans &u-z					&uvwxyz
let g:menutrans_no_file = "[Aucun fichier]"


menutrans &Window			Fe&nêtre

menutrans &New<Tab>^Wn				&Nouvelle\ fenêtre<Tab>^Wn
menutrans S&plit<Tab>^Ws			&Fractionner<Tab>^Ws
menutrans Sp&lit\ To\ #<Tab>^W^^		Fractionner\ p&our\ #<Tab>^W^^
menutrans Split\ &Vertically<Tab>^Wv		Fractionner\ &verticalement<Tab>^Wv
menutrans Split\ File\ E&xplorer		Fractionner\ &explorateur
" -SEP1-
menutrans &Close<Tab>^Wc			Fer&mer<Tab>^Wc
menutrans Close\ &Other(s)<Tab>^Wo		Fermer\ les\ &autres<Tab>^Wo
" -SEP2-
menutrans Move\ &To				&Déplacer\ vers\ le

menutrans &Top<Tab>^WK					&Haut<Tab>^WK
menutrans &Bottom<Tab>^WJ				&Bas<Tab>^WJ
menutrans &Left\ side<Tab>^WH				Côté\ &gauche<Tab>^WH
menutrans &Right\ side<Tab>^WL				Côté\ &droit<Tab>^WL

menutrans Rotate\ &Up<Tab>^WR			Rotation\ vers\ le\ &haut<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr			Rotation\ vers\ le\ &bas<Tab>^Wr
" -SEP3-
menutrans &Equal\ Size<Tab>^W=			Égaliser\ ta&illes<Tab>^W=
menutrans &Max\ Height<Tab>^W_			Hau&teur\ maximale<Tab>^W_
menutrans M&in\ Height<Tab>^W1_			Ha&uteur\ minimale<Tab>^W1_
menutrans Max\ &Width<Tab>^W\|			&Largeur\ maximale<Tab>^W\|
menutrans Min\ Widt&h<Tab>^W1\|			La&rgeur\ minimale<Tab>^W1\|


" PopUp

menutrans &Undo					&Annuler
" -SEP1-
menutrans Cu&t					Co&uper
menutrans &Copy					Cop&ier
menutrans &Paste				C&oller
" &Buffers.&Delete overwrites this one
menutrans &Delete				&Effacer
" -SEP2-
menutrans Select\ Blockwise			Sélectionner\ &bloc
menutrans Select\ &Word				Sélectionner\ &mot
menutrans Select\ &Line				Sélectionner\ &ligne
menutrans Select\ &Block			Sélectionner\ &bloc
menutrans Select\ &All				Sélectionner\ &tout


" ToolBar

menutrans Open					Ouvrir
menutrans Save					Enreg
menutrans SaveAll				EnregTout
menutrans Print					Imprimer
" -sep1-
menutrans Undo					Annuler
menutrans Redo					Refaire
" -sep2-
menutrans Cut					Couper
menutrans Copy					Copier
menutrans Paste					Coller
" -sep3-
menutrans Find					Chercher
menutrans FindNext				CherchSuiv
menutrans FindPrev				CherchPrec
menutrans Replace				Remplacer
" -sep4-
menutrans New					Nouvelle
menutrans WinSplit				FenFract
menutrans WinMax				FenMax
menutrans WinMin				FenMin
menutrans WinVSplit				FenVFract
menutrans WinMaxWidth				FenMaxLarg
menutrans WinMinWidth				FenMinLarg
menutrans WinClose				FenFerme
" -sep5-
menutrans LoadSesn				OuvrirSess
menutrans SaveSesn				EnregSess
menutrans RunScript				LancScript
" -sep6-
menutrans Make					Make
menutrans RunCtags				CréerEtiqu
menutrans TagJump				AllerEtiqu
" -sep7-
menutrans Help					Aide
menutrans FindHelp				CherchAide

fun! Do_toolbar_tmenu()
  let did_toolbar_tmenu = 1
  tmenu ToolBar.Open				Ouvrir fichier
  tmenu ToolBar.Save				Enregistrer fichier courant
  tmenu ToolBar.SaveAll				Enregistrer tous les fichiers
  tmenu ToolBar.Print				Imprimer
  tmenu ToolBar.Undo				Annuler
  tmenu ToolBar.Redo				Refaire
  tmenu ToolBar.Cut				Couper
  tmenu ToolBar.Copy				Copier
  tmenu ToolBar.Paste				Coller
  if !has("gui_athena")
    tmenu ToolBar.Find				Rechercher
    tmenu ToolBar.FindNext			Chercher suivant
    tmenu ToolBar.FindPrev			Chercher précédent
    tmenu ToolBar.Replace			Remplacer
  endif
 if 0	" disabled; These are in the Windows menu
  tmenu ToolBar.New				Nouvelle fenêtre
  tmenu ToolBar.WinSplit			Fractionner fenêtre
  tmenu ToolBar.WinMax				Maximiser fenêtre
  tmenu ToolBar.WinMin				Minimiser fenêtre
  tmenu ToolBar.WinVSplit			Fractionner verticalement
  tmenu ToolBar.WinMaxWidth			Maximiser largeur fenêtre
  tmenu ToolBar.WinMinWidth			Minimiser largeur fenêtre
  tmenu ToolBar.WinClose			Fermer fenêtre
 endif
  tmenu ToolBar.LoadSesn			Ouvrir session
  tmenu ToolBar.SaveSesn			Enregister session courante
  tmenu ToolBar.RunScript			Lancer un script Vim
  tmenu ToolBar.Make				Lancer make
  tmenu ToolBar.RunCtags			Créer les étiquettes
  tmenu ToolBar.TagJump				Atteindre cette étiquette
  tmenu ToolBar.Help				Aide de Vim
  tmenu ToolBar.FindHelp			Rechercher dans l'aide
endfun


menutrans &Syntax			&Syntaxe

menutrans &Off					Désactiver
menutrans &Manual				&Manuelle
menutrans A&utomatic				&Automatique
menutrans on/off\ for\ &This\ file		On/off\ pour\ &ce\ fichier

" The Start Of The Syntax Menu
menutrans ABC\ music\ notation		ABC\ (notation\ musicale)
menutrans AceDB\ model			Modèle\ AceDB
menutrans Apache\ config		Config\.\ Apache
menutrans Apache-style\ config		Config\.\ style\ Apache
menutrans ASP\ with\ VBScript		ASP\ avec\ VBScript
menutrans ASP\ with\ Perl		ASP\ avec\ Perl
menutrans Assembly			Assembleur
menutrans BC\ calculator		Calculateur\ BC
menutrans BDF\ font			Fonte\ BDF
menutrans BIND\ config			Config\.\ BIND
menutrans BIND\ zone			Zone\ BIND
menutrans Cascading\ Style\ Sheets	Feuilles\ de\ style\ en\ cascade
menutrans Cfg\ Config\ file		Fichier\ de\ config\.\ \.cfg
menutrans Cheetah\ template		Patron\ Cheetah
menutrans commit\ file			Fichier\ commit
menutrans Generic\ Config\ file		Fichier\ de\ config\.\ générique
menutrans Digital\ Command\ Lang	DCL
menutrans DNS/BIND\ zone		Zone\ BIND/DNS
menutrans Dylan\ interface		Interface
menutrans Dylan\ lid			LID
menutrans Elm\ filter\ rules		Règles\ de\ filtrage\ Elm
menutrans ERicsson\ LANGuage		Erlang\ (langage\ Ericsson)
menutrans Essbase\ script		Script\ Essbase
menutrans Eterm\ config			Config\.\ Eterm
menutrans Exim\ conf			Config\.\ Exim
menutrans Fvwm\ configuration		Config\.\ Fvwm
menutrans Fvwm2\ configuration		Config\.\ Fvwm2
menutrans Fvwm2\ configuration\ with\ M4	Config\.\ Fvwm2\ avec\ M4
menutrans GDB\ command\ file		Fichier\ de\ commandes\ GDB
menutrans HTML\ with\ M4		HTML\ avec\ M4
menutrans Cheetah\ HTML\ template	Patron\ Cheetah\ pour\ HTML
menutrans IDL\Generic\ IDL		IDL\IDL\ générique
menutrans IDL\Microsoft\ IDL		IDL\IDL\ Microsoft
menutrans Indent\ profile		Profil\ Indent
menutrans Inno\ setup			Config\.\ Inno
menutrans InstallShield\ script		Script\ InstallShield
menutrans KDE\ script			Script\ KDE
menutrans LFTP\ config			Config\.\ LFTP
menutrans LifeLines\ script		Script\ LifeLines
menutrans Lynx\ Style			Style\ Lynx
menutrans Lynx\ config			Config\.\ Lynx
menutrans Man\ page			Page\ Man
menutrans MEL\ (for\ Maya)		MEL\ (pour\ Maya)
menutrans 4DOS\ \.bat\ file		Fichier\ \.bat\ 4DOS
menutrans \.bat\/\.cmd\ file		Fichier\ \.bat\ /\ \.cmd
menutrans \.ini\ file			Fichier\ \.ini
menutrans Module\ Definition		Définition\ de\ module
menutrans Registry			Extrait\ du\ registre
menutrans Resource\ file		Fichier\ de\ ressources
menutrans Novell\ NCF\ batch		Batch\ Novell\ NCF
menutrans NSIS\ script			Script\ NSIS
menutrans Oracle\ config		Config\.\ Oracle
menutrans Palm\ resource\ compiler	Compil\.\ de\ resources\ Palm
menutrans PHP\ 3-4			PHP\ 3\ et\ 4
menutrans Postfix\ main\ config		Config\.\ Postfix
menutrans Povray\ scene\ descr		Scène\ Povray
menutrans Povray\ configuration		Config\.\ Povray
menutrans Purify\ log			Log\ Purify
menutrans Readline\ config		Config\.\ Readline
menutrans RCS\ log\ output		Log\ RCS
menutrans RCS\ file			Fichier\ RCS
menutrans RockLinux\ package\ desc\.	Desc\.\ pkg\.\ RockLinux
menutrans Samba\ config			Config\.\ Samba
menutrans SGML\ catalog			Catalogue\ SGML
menutrans SGML\ DTD			DTD\ SGML
menutrans SGML\ Declaration		Déclaration\ SGML
menutrans Shell\ script			Script\ shell
menutrans sh\ and\ ksh			sh\ et\ ksh
menutrans Sinda\ compare		Comparaison\ Sinda
menutrans Sinda\ input			Entrée\ Sinda
menutrans Sinda\ output			Sortie\ Sinda
menutrans SKILL\ for\ Diva		SKILL\ pour\ Diva
menutrans Smarty\ Templates		Patrons\ Smarty
menutrans SNNS\ network			Réseau\ SNNS
menutrans SNNS\ pattern			Motif\ SNNS
menutrans SNNS\ result			Résultat\ SNNS
menutrans Snort\ Configuration		Config\.\ Snort
menutrans Squid\ config			Config\.\ Squid
menutrans Subversion\ commit		Commit\ Subversion
menutrans TAK\ compare			Comparaison\ TAK
menutrans TAK\ input			Entrée\ TAK
menutrans TAK\ output			Sortie\ TAK
menutrans TeX\ configuration		Config\.\ TeX
menutrans TF\ mud\ client		TF\ (client\ MUD)
menutrans Tidy\ configuration		Config\.\ Tidy
menutrans Trasys\ input			Entrée\ Trasys
menutrans Command\ Line			Ligne\ de\ commande
menutrans Geometry			Géométrie
menutrans Optics			Optiques
menutrans Vim\ help\ file		Fichier\ d'aide\ Vim
menutrans Vim\ script			Script\ Vim
menutrans Viminfo\ file			Fichier\ Viminfo
menutrans Virata\ config		Config\.\ Virata
menutrans Wget\ config			Config\.\ wget
menutrans Whitespace\ (add)		Espaces\ et\ tabulations
menutrans WildPackets\ EtherPeek\ Decoder	Décodeur\ WildPackets\ EtherPeek
menutrans X\ resources			Resources\ X
menutrans XXD\ hex\ dump		Sortie\ hexa\.\ de\ xxd
menutrans XFree86\ Config		Config\.\ XFree86
" The End Of The Syntax Menu

menutrans &Show\ filetypes\ in\ menu		&Afficher\ tout\ le\ menu
" -SEP1-
menutrans Set\ '&syntax'\ only			Changer\ '&syntax'\ seulement
menutrans Set\ '&filetype'\ too			Changer\ '&filetype'\ aussi
menutrans &Off					&Off
" -SEP3-
menutrans Co&lor\ test				Tester\ les\ co&uleurs
menutrans &Highlight\ test			Tester\ les\ g&roupes\ de\ surbrillance
menutrans &Convert\ to\ HTML			Con&vertir\ en\ HTML

let &cpo = s:keepcpo
unlet s:keepcpo
