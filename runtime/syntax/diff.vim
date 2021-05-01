" Vim syntax file
" Language:	Diff (context or unified)
" Maintainer:	Bram Moolenaar <Bram@vim.org>
"               Translations by Jakson Alves de Aquino.
" Last Change:	2020 Dec 07

" Quit when a (custom) syntax file was already loaded
if exists("b:current_syntax")
  finish
endif
scriptencoding utf-8

syn match diffOnly	"^Only in .*"
syn match diffIdentical	"^Files .* and .* are identical$"
syn match diffDiffer	"^Files .* and .* differ$"
syn match diffBDiffer	"^Binary files .* and .* differ$"
syn match diffIsA	"^File .* is a .* while file .* is a .*"
syn match diffNoEOL	"^\\ No newline at end of file .*"
syn match diffCommon	"^Common subdirectories: .*"

" Disable the translations by setting diff_translations to zero.
if !exists("diff_translations") || diff_translations

" ca
syn match diffOnly	"^Només a .*"
syn match diffIdentical	"^Els fitxers .* i .* són idèntics$"
syn match diffDiffer	"^Els fitxers .* i .* difereixen$"
syn match diffBDiffer	"^Els fitxers .* i .* difereixen$"
syn match diffIsA	"^El fitxer .* és un .* mentre que el fitxer .* és un .*"
syn match diffNoEOL	"^\\ No hi ha cap caràcter de salt de línia al final del fitxer"
syn match diffCommon	"^Subdirectoris comuns: .* i .*"

" cs
syn match diffOnly	"^Pouze v .*"
syn match diffIdentical	"^Soubory .* a .* jsou identické$"
syn match diffDiffer	"^Soubory .* a .* jsou různé$"
syn match diffBDiffer	"^Binární soubory .* a .* jsou rozdílné$"
syn match diffBDiffer	"^Soubory .* a .* jsou různé$"
syn match diffIsA	"^Soubor .* je .* pokud soubor .* je .*"
syn match diffNoEOL	"^\\ Chybí znak konce řádku na konci souboru"
syn match diffCommon	"^Společné podadresáře: .* a .*"

" da
syn match diffOnly	"^Kun i .*"
syn match diffIdentical	"^Filerne .* og .* er identiske$"
syn match diffDiffer	"^Filerne .* og .* er forskellige$"
syn match diffBDiffer	"^Binære filer .* og .* er forskellige$"
syn match diffIsA	"^Filen .* er en .* mens filen .* er en .*"
syn match diffNoEOL	"^\\ Intet linjeskift ved filafslutning"
syn match diffCommon	"^Identiske underkataloger: .* og .*"

" de
syn match diffOnly	"^Nur in .*"
syn match diffIdentical	"^Dateien .* und .* sind identisch.$"
syn match diffDiffer	"^Dateien .* und .* sind verschieden.$"
syn match diffBDiffer	"^Binärdateien .* and .* sind verschieden.$"
syn match diffBDiffer	"^Binärdateien .* und .* sind verschieden.$"
syn match diffIsA	"^Datei .* ist ein .* während Datei .* ein .* ist.$"
syn match diffNoEOL	"^\\ Kein Zeilenumbruch am Dateiende."
syn match diffCommon	"^Gemeinsame Unterverzeichnisse: .* und .*.$"

" el
syn match diffOnly	"^Μόνο στο .*"
syn match diffIdentical	"^Τα αρχεία .* καί .* είναι πανομοιότυπα$"
syn match diffDiffer	"^Τα αρχεία .* και .* διαφέρουν$"
syn match diffBDiffer	"^Τα αρχεία .* και .* διαφέρουν$"
syn match diffIsA	"^Το αρχείο .* είναι .* ενώ το αρχείο .* είναι .*"
syn match diffNoEOL	"^\\ Δεν υπάρχει χαρακτήρας νέας γραμμής στο τέλος του αρχείου"
syn match diffCommon	"^Οι υποκατάλογοι .* και .* είναι ταυτόσημοι$"

" eo
syn match diffOnly	"^Nur en .*"
syn match diffIdentical	"^Dosieroj .* kaj .* estas samaj$"
syn match diffDiffer	"^Dosieroj .* kaj .* estas malsamaj$"
syn match diffBDiffer	"^Dosieroj .* kaj .* estas malsamaj$"
syn match diffIsA	"^Dosiero .* estas .*, dum dosiero .* estas .*"
syn match diffNoEOL	"^\\ Mankas linifino ĉe fino de dosiero"
syn match diffCommon	"^Komunaj subdosierujoj: .* kaj .*"

" es
syn match diffOnly	"^Sólo en .*"
syn match diffIdentical	"^Los ficheros .* y .* son idénticos$"
syn match diffDiffer	"^Los ficheros .* y .* son distintos$"
syn match diffBDiffer	"^Los ficheros binarios .* y .* son distintos$"
syn match diffIsA	"^El fichero .* es un .* mientras que el .* es un .*"
syn match diffNoEOL	"^\\ No hay ningún carácter de nueva línea al final del fichero"
syn match diffCommon	"^Subdirectorios comunes: .* y .*"

" fi
syn match diffOnly	"^Vain hakemistossa .*"
syn match diffIdentical	"^Tiedostot .* ja .* ovat identtiset$"
syn match diffDiffer	"^Tiedostot .* ja .* eroavat$"
syn match diffBDiffer	"^Binääritiedostot .* ja .* eroavat$"
syn match diffIsA	"^Tiedosto .* on .*, kun taas tiedosto .* on .*"
syn match diffNoEOL	"^\\ Ei rivinvaihtoa tiedoston lopussa"
syn match diffCommon	"^Yhteiset alihakemistot: .* ja .*"

" fr
syn match diffOnly	"^Seulement dans .*"
syn match diffIdentical	"^Les fichiers .* et .* sont identiques.*"
syn match diffDiffer	"^Les fichiers .* et .* sont différents.*"
syn match diffBDiffer	"^Les fichiers binaires .* et .* sont différents.*"
syn match diffIsA	"^Le fichier .* est un .* alors que le fichier .* est un .*"
syn match diffNoEOL	"^\\ Pas de fin de ligne à la fin du fichier.*"
syn match diffCommon	"^Les sous-répertoires .* et .* sont identiques.*"

" ga
syn match diffOnly	"^I .* amháin: .*"
syn match diffIdentical	"^Is comhionann iad na comhaid .* agus .*"
syn match diffDiffer	"^Tá difríocht idir na comhaid .* agus .*"
syn match diffBDiffer	"^Tá difríocht idir na comhaid .* agus .*"
syn match diffIsA	"^Tá comhad .* ina .* ach tá comhad .* ina .*"
syn match diffNoEOL	"^\\ Gan líne nua ag an chomhadchríoch"
syn match diffCommon	"^Fochomhadlanna i gcoitianta: .* agus .*"

" gl
syn match diffOnly	"^Só en .*"
syn match diffIdentical	"^Os ficheiros .* e .* son idénticos$"
syn match diffDiffer	"^Os ficheiros .* e .* son diferentes$"
syn match diffBDiffer	"^Os ficheiros binarios .* e .* son diferentes$"
syn match diffIsA	"^O ficheiro .* é un .* mentres que o ficheiro .* é un .*"
syn match diffNoEOL	"^\\ Non hai un salto de liña na fin da liña"
syn match diffCommon	"^Subdirectorios comúns: .* e .*"

" he
" ^.* are expansive patterns for long lines, so disabled unless we can match
" some specific hebrew chars
if search('\%u05d5\|\%u05d1', 'nw', '', 100)
  syn match diffOnly	"^.*-ב קר אצמנ .*"
  syn match diffIdentical	"^םיהז םניה .*-ו .* םיצבקה$"
  syn match diffDiffer	"^הזמ הז םינוש `.*'-ו `.*' םיצבקה$"
  syn match diffBDiffer	"^הזמ הז םינוש `.*'-ו `.*' םיירניב םיצבק$"
  syn match diffIsA	"^.* .*-ל .* .* תוושהל ןתינ אל$"
  syn match diffNoEOL	"^\\ ץבוקה ףוסב השד.-הרוש ות רס."
  syn match diffCommon	"^.*-ו .* :תוהז תויקית-תת$"
endif

" hr
syn match diffOnly	"^Samo u .*"
syn match diffIdentical	"^Datoteke .* i .* su identične$"
syn match diffDiffer	"^Datoteke .* i .* se razlikuju$"
syn match diffBDiffer	"^Binarne datoteke .* i .* se razlikuju$"
syn match diffIsA	"^Datoteka .* je .*, a datoteka .* je .*"
syn match diffNoEOL	"^\\ Nema novog retka na kraju datoteke"
syn match diffCommon	"^Uobičajeni poddirektoriji: .* i .*"

" hu
syn match diffOnly	"^Csak .* -ben: .*"
syn match diffIdentical	"^.* és .* fájlok azonosak$"
syn match diffDiffer	"^A(z) .* és a(z) .* fájlok különböznek$"
syn match diffBDiffer	"^A(z) .* és a(z) .* fájlok különböznek$"
syn match diffIsA	"^A(z) .* fájl egy .*, viszont a(z) .* fájl egy .*"
syn match diffNoEOL	"^\\ Nincs újsor a fájl végén"
syn match diffCommon	"^Közös alkönyvtárak: .* és .*"

" id
syn match diffOnly	"^Hanya dalam .*"
syn match diffIdentical	"^File .* dan .* identik$"
syn match diffDiffer	"^Berkas .* dan .* berbeda$"
syn match diffBDiffer	"^File biner .* dan .* berbeda$"
syn match diffIsA	"^File .* adalah .* sementara file .* adalah .*"
syn match diffNoEOL	"^\\ Tidak ada baris-baru di akhir dari berkas"
syn match diffCommon	"^Subdirektori sama: .* dan .*"

" it
syn match diffOnly	"^Solo in .*"
syn match diffIdentical	"^I file .* e .* sono identici$"
syn match diffDiffer	"^I file .* e .* sono diversi$"
syn match diffBDiffer	"^I file .* e .* sono diversi$"
syn match diffBDiffer	"^I file binari .* e .* sono diversi$"
syn match diffIsA	"^File .* è un .* mentre file .* è un .*"
syn match diffNoEOL	"^\\ Manca newline alla fine del file"
syn match diffCommon	"^Sottodirectory in comune: .* e .*"

" ja
syn match diffOnly	"^.*だけに発見: .*"
syn match diffIdentical	"^ファイル.*と.*は同一$"
syn match diffDiffer	"^ファイル.*と.*は違います$"
syn match diffBDiffer	"^バイナリー・ファイル.*と.*は違います$"
syn match diffIsA	"^ファイル.*は.*、ファイル.*は.*"
syn match diffNoEOL	"^\\ ファイル末尾に改行がありません"
syn match diffCommon	"^共通の下位ディレクトリー: .*と.*"

" ja DiffUtils 3.3
syn match diffOnly	"^.* のみに存在: .*"
syn match diffIdentical	"^ファイル .* と .* は同一です$"
syn match diffDiffer	"^ファイル .* と .* は異なります$"
syn match diffBDiffer	"^バイナリーファイル .* と.* は異なります$"
syn match diffIsA	"^ファイル .* は .* です。一方、ファイル .* は .* です$"
syn match diffNoEOL	"^\\ ファイル末尾に改行がありません"
syn match diffCommon	"^共通のサブディレクトリー: .* と .*"

" lv
syn match diffOnly	"^Tikai iekš .*"
syn match diffIdentical	"^Fails .* un .* ir identiski$"
syn match diffDiffer	"^Faili .* un .* atšķiras$"
syn match diffBDiffer	"^Faili .* un .* atšķiras$"
syn match diffBDiffer	"^Binārie faili .* un .* atšķiras$"
syn match diffIsA	"^Fails .* ir .* kamēr fails .* ir .*"
syn match diffNoEOL	"^\\ Nav jaunu rindu faila beigās"
syn match diffCommon	"^Kopējās apakšdirektorijas: .* un .*"

" ms
syn match diffOnly	"^Hanya dalam .*"
syn match diffIdentical	"^Fail .* dan .* adalah serupa$"
syn match diffDiffer	"^Fail .* dan .* berbeza$"
syn match diffBDiffer	"^Fail .* dan .* berbeza$"
syn match diffIsA	"^Fail .* adalah .* manakala fail .* adalah .*"
syn match diffNoEOL	"^\\ Tiada baris baru pada penghujung fail"
syn match diffCommon	"^Subdirektori umum: .* dan .*"

" nl
syn match diffOnly	"^Alleen in .*"
syn match diffIdentical	"^Bestanden .* en .* zijn identiek$"
syn match diffDiffer	"^Bestanden .* en .* zijn verschillend$"
syn match diffBDiffer	"^Bestanden .* en .* zijn verschillend$"
syn match diffBDiffer	"^Binaire bestanden .* en .* zijn verschillend$"
syn match diffIsA	"^Bestand .* is een .* terwijl bestand .* een .* is$"
syn match diffNoEOL	"^\\ Geen regeleindeteken (LF) aan einde van bestand"
syn match diffCommon	"^Gemeenschappelijke submappen: .* en .*"

" pl
syn match diffOnly	"^Tylko w .*"
syn match diffIdentical	"^Pliki .* i .* są identyczne$"
syn match diffDiffer	"^Pliki .* i .* różnią się$"
syn match diffBDiffer	"^Pliki .* i .* różnią się$"
syn match diffBDiffer	"^Binarne pliki .* i .* różnią się$"
syn match diffIsA	"^Plik .* jest .*, podczas gdy plik .* jest .*"
syn match diffNoEOL	"^\\ Brak znaku nowej linii na końcu pliku"
syn match diffCommon	"^Wspólne podkatalogi: .* i .*"

" pt_BR
syn match diffOnly	"^Somente em .*"
syn match diffOnly	"^Apenas em .*"
syn match diffIdentical	"^Os aquivos .* e .* são idênticos$"
syn match diffDiffer	"^Os arquivos .* e .* são diferentes$"
syn match diffBDiffer	"^Os arquivos binários .* e .* são diferentes$"
syn match diffIsA	"^O arquivo .* é .* enquanto o arquivo .* é .*"
syn match diffNoEOL	"^\\ Falta o caracter nova linha no final do arquivo"
syn match diffCommon	"^Subdiretórios idênticos: .* e .*"

" ro
syn match diffOnly	"^Doar în .*"
syn match diffIdentical	"^Fişierele .* şi .* sunt identice$"
syn match diffDiffer	"^Fişierele .* şi .* diferă$"
syn match diffBDiffer	"^Fişierele binare .* şi .* diferă$"
syn match diffIsA	"^Fişierul .* este un .* pe când fişierul .* este un .*.$"
syn match diffNoEOL	"^\\ Nici un element de linie nouă la sfârşitul fişierului"
syn match diffCommon	"^Subdirectoare comune: .* şi .*.$"

" ru
syn match diffOnly	"^Только в .*"
syn match diffIdentical	"^Файлы .* и .* идентичны$"
syn match diffDiffer	"^Файлы .* и .* различаются$"
syn match diffBDiffer	"^Файлы .* и .* различаются$"
syn match diffIsA	"^Файл .* это .*, тогда как файл .* -- .*"
syn match diffNoEOL	"^\\ В конце файла нет новой строки"
syn match diffCommon	"^Общие подкаталоги: .* и .*"

" sr
syn match diffOnly	"^Само у .*"
syn match diffIdentical	"^Датотеке „.*“ и „.*“ се подударају$"
syn match diffDiffer	"^Датотеке .* и .* различите$"
syn match diffBDiffer	"^Бинарне датотеке .* и .* различите$"
syn match diffIsA	"^Датотека „.*“ је „.*“ док је датотека „.*“ „.*“$"
syn match diffNoEOL	"^\\ Без новог реда на крају датотеке"
syn match diffCommon	"^Заједнички поддиректоријуми: .* и .*"

" sv
syn match diffOnly	"^Endast i .*"
syn match diffIdentical	"^Filerna .* och .* är lika$"
syn match diffDiffer	"^Filerna .* och .* skiljer$"
syn match diffBDiffer	"^Filerna .* och .* skiljer$"
syn match diffIsA	"^Fil .* är en .* medan fil .* är en .*"
syn match diffBDiffer	"^De binära filerna .* och .* skiljer$"
syn match diffIsA	"^Filen .* är .* medan filen .* är .*"
syn match diffNoEOL	"^\\ Ingen nyrad vid filslut"
syn match diffCommon	"^Lika underkataloger: .* och .*"

" tr
syn match diffOnly	"^Yalnızca .*'da: .*"
syn match diffIdentical	"^.* ve .* dosyaları birbirinin aynı$"
syn match diffDiffer	"^.* ve .* dosyaları birbirinden farklı$"
syn match diffBDiffer	"^.* ve .* dosyaları birbirinden farklı$"
syn match diffBDiffer	"^İkili .* ve .* birbirinden farklı$"
syn match diffIsA	"^.* dosyası, bir .*, halbuki .* dosyası bir .*"
syn match diffNoEOL	"^\\ Dosya sonunda yenisatır yok."
syn match diffCommon	"^Ortak alt dizinler: .* ve .*"

" uk
syn match diffOnly	"^Лише у .*"
syn match diffIdentical	"^Файли .* та .* ідентичні$"
syn match diffDiffer	"^Файли .* та .* відрізняються$"
syn match diffBDiffer	"^Файли .* та .* відрізняються$"
syn match diffBDiffer	"^Двійкові файли .* та .* відрізняються$"
syn match diffIsA	"^Файл .* це .*, тоді як файл .* -- .*"
syn match diffNoEOL	"^\\ Наприкінці файлу немає нового рядка"
syn match diffCommon	"^Спільні підкаталоги: .* та .*"

" vi
syn match diffOnly	"^Chỉ trong .*"
syn match diffIdentical	"^Hai tập tin .* và .* là bằng nhau.$"
syn match diffIdentical	"^Cả .* và .* là cùng một tập tin$"
syn match diffDiffer	"^Hai tập tin .* và .* là khác nhau.$"
syn match diffBDiffer	"^Hai tập tin nhị phân .* và .* khác nhau$"
syn match diffIsA	"^Tập tin .* là một .* trong khi tập tin .* là một .*.$"
syn match diffBDiffer	"^Hai tập tin .* và .* là khác nhau.$"
syn match diffIsA	"^Tập tin .* là một .* còn tập tin .* là một .*.$"
syn match diffNoEOL	"^\\ Không có ký tự dòng mới tại kêt thức tập tin."
syn match diffCommon	"^Thư mục con chung: .* và .*"

" zh_CN
syn match diffOnly	"^只在 .* 存在：.*"
syn match diffIdentical	"^檔案 .* 和 .* 相同$"
syn match diffDiffer	"^文件 .* 和 .* 不同$"
syn match diffBDiffer	"^文件 .* 和 .* 不同$"
syn match diffIsA	"^文件 .* 是.*而文件 .* 是.*"
syn match diffNoEOL	"^\\ 文件尾没有 newline 字符"
syn match diffCommon	"^.* 和 .* 有共同的子目录$"

" zh_TW
syn match diffOnly	"^只在 .* 存在：.*"
syn match diffIdentical	"^檔案 .* 和 .* 相同$"
syn match diffDiffer	"^檔案 .* 與 .* 不同$"
syn match diffBDiffer	"^二元碼檔 .* 與 .* 不同$"
syn match diffIsA	"^檔案 .* 是.*而檔案 .* 是.*"
syn match diffNoEOL	"^\\ 檔案末沒有 newline 字元"
syn match diffCommon	"^.* 和 .* 有共同的副目錄$"

endif


syn match diffRemoved	"^-.*"
syn match diffRemoved	"^<.*"
syn match diffAdded	"^+.*"
syn match diffAdded	"^>.*"
syn match diffChanged	"^! .*"

syn match diffSubname	" @@..*"ms=s+3 contained
syn match diffLine	"^@.*" contains=diffSubname
syn match diffLine	"^\<\d\+\>.*"
syn match diffLine	"^\*\*\*\*.*"
syn match diffLine	"^---$"

" Some versions of diff have lines like "#c#" and "#d#" (where # is a number)
syn match diffLine	"^\d\+\(,\d\+\)\=[cda]\d\+\>.*"

syn match diffFile	"^diff\>.*"
syn match diffFile	"^Index: .*"
syn match diffFile	"^==== .*"
" Old style diff uses *** for old and --- for new.
" Unified diff uses --- for old and +++ for new; names are wrong but it works.
syn match diffOldFile	"^+++ .*"
syn match diffOldFile	"^\*\*\* .*"
syn match diffNewFile	"^--- .*"

" Used by git
syn match diffIndexLine	"^index \x\x\x\x.*"

syn match diffComment	"^#.*"

" Define the default highlighting.
" Only used when an item doesn't have highlighting yet
hi def link diffOldFile		diffFile
hi def link diffNewFile		diffFile
hi def link diffIndexLine	PreProc
hi def link diffFile		Type
hi def link diffOnly		Constant
hi def link diffIdentical	Constant
hi def link diffDiffer		Constant
hi def link diffBDiffer		Constant
hi def link diffIsA		Constant
hi def link diffNoEOL		Constant
hi def link diffCommon		Constant
hi def link diffRemoved		Special
hi def link diffChanged		PreProc
hi def link diffAdded		Identifier
hi def link diffLine		Statement
hi def link diffSubname		PreProc
hi def link diffComment		Comment

let b:current_syntax = "diff"

" vim: ts=8 sw=2
