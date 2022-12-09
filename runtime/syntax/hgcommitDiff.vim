" Vim syntax file
" Language:	Sapling / Mecurial Diff (context or unified)
" Maintainer:	Bram Moolenaar <Bram@vim.org>
"               Max Coplan <mchcopl@gmail.com>
"               Translations by Jakson Alves de Aquino.
" Last Change:	2022-12-08
" Copied from:	runtime/syntax/diff.vim

" Quit when a (custom) syntax file was already loaded
if exists("b:current_syntax")
  finish
endif
scriptencoding utf-8

syn match diffOnly	"^\(SL\|HG\): Only in .*"
syn match diffIdentical	"^\(SL\|HG\): Files .* and .* are identical$"
syn match diffDiffer	"^\(SL\|HG\): Files .* and .* differ$"
syn match diffBDiffer	"^\(SL\|HG\): Binary files .* and .* differ$"
syn match diffIsA	"^\(SL\|HG\): File .* is a .* while file .* is a .*"
syn match diffNoEOL	"^\(SL\|HG\): \\ No newline at end of file .*"
syn match diffCommon	"^\(SL\|HG\): Common subdirectories: .*"

" Disable the translations by setting diff_translations to zero.
if !exists("diff_translations") || diff_translations

" ca
syn match diffOnly	"^\(SL\|HG\): Només a .*"
syn match diffIdentical	"^\(SL\|HG\): Els fitxers .* i .* són idèntics$"
syn match diffDiffer	"^\(SL\|HG\): Els fitxers .* i .* difereixen$"
syn match diffBDiffer	"^\(SL\|HG\): Els fitxers .* i .* difereixen$"
syn match diffIsA	"^\(SL\|HG\): El fitxer .* és un .* mentre que el fitxer .* és un .*"
syn match diffNoEOL	"^\(SL\|HG\): \\ No hi ha cap caràcter de salt de línia al final del fitxer"
syn match diffCommon	"^\(SL\|HG\): Subdirectoris comuns: .* i .*"

" cs
syn match diffOnly	"^\(SL\|HG\): Pouze v .*"
syn match diffIdentical	"^\(SL\|HG\): Soubory .* a .* jsou identické$"
syn match diffDiffer	"^\(SL\|HG\): Soubory .* a .* jsou různé$"
syn match diffBDiffer	"^\(SL\|HG\): Binární soubory .* a .* jsou rozdílné$"
syn match diffBDiffer	"^\(SL\|HG\): Soubory .* a .* jsou různé$"
syn match diffIsA	"^\(SL\|HG\): Soubor .* je .* pokud soubor .* je .*"
syn match diffNoEOL	"^\(SL\|HG\): \\ Chybí znak konce řádku na konci souboru"
syn match diffCommon	"^\(SL\|HG\): Společné podadresáře: .* a .*"

" da
syn match diffOnly	"^\(SL\|HG\): Kun i .*"
syn match diffIdentical	"^\(SL\|HG\): Filerne .* og .* er identiske$"
syn match diffDiffer	"^\(SL\|HG\): Filerne .* og .* er forskellige$"
syn match diffBDiffer	"^\(SL\|HG\): Binære filer .* og .* er forskellige$"
syn match diffIsA	"^\(SL\|HG\): Filen .* er en .* mens filen .* er en .*"
syn match diffNoEOL	"^\(SL\|HG\): \\ Intet linjeskift ved filafslutning"
syn match diffCommon	"^\(SL\|HG\): Identiske underkataloger: .* og .*"

" de
syn match diffOnly	"^\(SL\|HG\): Nur in .*"
syn match diffIdentical	"^\(SL\|HG\): Dateien .* und .* sind identisch.$"
syn match diffDiffer	"^\(SL\|HG\): Dateien .* und .* sind verschieden.$"
syn match diffBDiffer	"^\(SL\|HG\): Binärdateien .* and .* sind verschieden.$"
syn match diffBDiffer	"^\(SL\|HG\): Binärdateien .* und .* sind verschieden.$"
syn match diffIsA	"^\(SL\|HG\): Datei .* ist ein .* während Datei .* ein .* ist.$"
syn match diffNoEOL	"^\(SL\|HG\): \\ Kein Zeilenumbruch am Dateiende."
syn match diffCommon	"^\(SL\|HG\): Gemeinsame Unterverzeichnisse: .* und .*.$"

" el
syn match diffOnly	"^\(SL\|HG\): Μόνο στο .*"
syn match diffIdentical	"^\(SL\|HG\): Τα αρχεία .* καί .* είναι πανομοιότυπα$"
syn match diffDiffer	"^\(SL\|HG\): Τα αρχεία .* και .* διαφέρουν$"
syn match diffBDiffer	"^\(SL\|HG\): Τα αρχεία .* και .* διαφέρουν$"
syn match diffIsA	"^\(SL\|HG\): Το αρχείο .* είναι .* ενώ το αρχείο .* είναι .*"
syn match diffNoEOL	"^\(SL\|HG\): \\ Δεν υπάρχει χαρακτήρας νέας γραμμής στο τέλος του αρχείου"
syn match diffCommon	"^\(SL\|HG\): Οι υποκατάλογοι .* και .* είναι ταυτόσημοι$"

" eo
syn match diffOnly	"^\(SL\|HG\): Nur en .*"
syn match diffIdentical	"^\(SL\|HG\): Dosieroj .* kaj .* estas samaj$"
syn match diffDiffer	"^\(SL\|HG\): Dosieroj .* kaj .* estas malsamaj$"
syn match diffBDiffer	"^\(SL\|HG\): Dosieroj .* kaj .* estas malsamaj$"
syn match diffIsA	"^\(SL\|HG\): Dosiero .* estas .*, dum dosiero .* estas .*"
syn match diffNoEOL	"^\(SL\|HG\): \\ Mankas linifino ĉe fino de dosiero"
syn match diffCommon	"^\(SL\|HG\): Komunaj subdosierujoj: .* kaj .*"

" es
syn match diffOnly	"^\(SL\|HG\): Sólo en .*"
syn match diffIdentical	"^\(SL\|HG\): Los ficheros .* y .* son idénticos$"
syn match diffDiffer	"^\(SL\|HG\): Los ficheros .* y .* son distintos$"
syn match diffBDiffer	"^\(SL\|HG\): Los ficheros binarios .* y .* son distintos$"
syn match diffIsA	"^\(SL\|HG\): El fichero .* es un .* mientras que el .* es un .*"
syn match diffNoEOL	"^\(SL\|HG\): \\ No hay ningún carácter de nueva línea al final del fichero"
syn match diffCommon	"^\(SL\|HG\): Subdirectorios comunes: .* y .*"

" fi
syn match diffOnly	"^\(SL\|HG\): Vain hakemistossa .*"
syn match diffIdentical	"^\(SL\|HG\): Tiedostot .* ja .* ovat identtiset$"
syn match diffDiffer	"^\(SL\|HG\): Tiedostot .* ja .* eroavat$"
syn match diffBDiffer	"^\(SL\|HG\): Binääritiedostot .* ja .* eroavat$"
syn match diffIsA	"^\(SL\|HG\): Tiedosto .* on .*, kun taas tiedosto .* on .*"
syn match diffNoEOL	"^\(SL\|HG\): \\ Ei rivinvaihtoa tiedoston lopussa"
syn match diffCommon	"^\(SL\|HG\): Yhteiset alihakemistot: .* ja .*"

" fr
syn match diffOnly	"^\(SL\|HG\): Seulement dans .*"
syn match diffIdentical	"^\(SL\|HG\): Les fichiers .* et .* sont identiques.*"
syn match diffDiffer	"^\(SL\|HG\): Les fichiers .* et .* sont différents.*"
syn match diffBDiffer	"^\(SL\|HG\): Les fichiers binaires .* et .* sont différents.*"
syn match diffIsA	"^\(SL\|HG\): Le fichier .* est un .* alors que le fichier .* est un .*"
syn match diffNoEOL	"^\(SL\|HG\): \\ Pas de fin de ligne à la fin du fichier.*"
syn match diffCommon	"^\(SL\|HG\): Les sous-répertoires .* et .* sont identiques.*"

" ga
syn match diffOnly	"^\(SL\|HG\): I .* amháin: .*"
syn match diffIdentical	"^\(SL\|HG\): Is comhionann iad na comhaid .* agus .*"
syn match diffDiffer	"^\(SL\|HG\): Tá difríocht idir na comhaid .* agus .*"
syn match diffBDiffer	"^\(SL\|HG\): Tá difríocht idir na comhaid .* agus .*"
syn match diffIsA	"^\(SL\|HG\): Tá comhad .* ina .* ach tá comhad .* ina .*"
syn match diffNoEOL	"^\(SL\|HG\): \\ Gan líne nua ag an chomhadchríoch"
syn match diffCommon	"^\(SL\|HG\): Fochomhadlanna i gcoitianta: .* agus .*"

" gl
syn match diffOnly	"^\(SL\|HG\): Só en .*"
syn match diffIdentical	"^\(SL\|HG\): Os ficheiros .* e .* son idénticos$"
syn match diffDiffer	"^\(SL\|HG\): Os ficheiros .* e .* son diferentes$"
syn match diffBDiffer	"^\(SL\|HG\): Os ficheiros binarios .* e .* son diferentes$"
syn match diffIsA	"^\(SL\|HG\): O ficheiro .* é un .* mentres que o ficheiro .* é un .*"
syn match diffNoEOL	"^\(SL\|HG\): \\ Non hai un salto de liña na fin da liña"
syn match diffCommon	"^\(SL\|HG\): Subdirectorios comúns: .* e .*"

" he
" ^\(SL\|HG\): .* are expansive patterns for long lines, so disabled unless we can match
" some specific hebrew chars
if search('\%u05d5\|\%u05d1', 'nw', '', 100)
  syn match diffOnly	"^\(SL\|HG\): .*-ב קר אצמנ .*"
  syn match diffIdentical	"^\(SL\|HG\): םיהז םניה .*-ו .* םיצבקה$"
  syn match diffDiffer	"^\(SL\|HG\): הזמ הז םינוש `.*'-ו `.*' םיצבקה$"
  syn match diffBDiffer	"^\(SL\|HG\): הזמ הז םינוש `.*'-ו `.*' םיירניב םיצבק$"
  syn match diffIsA	"^\(SL\|HG\): .* .*-ל .* .* תוושהל ןתינ אל$"
  syn match diffNoEOL	"^\(SL\|HG\): \\ ץבוקה ףוסב השד.-הרוש ות רס."
  syn match diffCommon	"^\(SL\|HG\): .*-ו .* :תוהז תויקית-תת$"
endif

" hr
syn match diffOnly	"^\(SL\|HG\): Samo u .*"
syn match diffIdentical	"^\(SL\|HG\): Datoteke .* i .* su identične$"
syn match diffDiffer	"^\(SL\|HG\): Datoteke .* i .* se razlikuju$"
syn match diffBDiffer	"^\(SL\|HG\): Binarne datoteke .* i .* se razlikuju$"
syn match diffIsA	"^\(SL\|HG\): Datoteka .* je .*, a datoteka .* je .*"
syn match diffNoEOL	"^\(SL\|HG\): \\ Nema novog retka na kraju datoteke"
syn match diffCommon	"^\(SL\|HG\): Uobičajeni poddirektoriji: .* i .*"

" hu
syn match diffOnly	"^\(SL\|HG\): Csak .* -ben: .*"
syn match diffIdentical	"^\(SL\|HG\): .* és .* fájlok azonosak$"
syn match diffDiffer	"^\(SL\|HG\): A(z) .* és a(z) .* fájlok különböznek$"
syn match diffBDiffer	"^\(SL\|HG\): A(z) .* és a(z) .* fájlok különböznek$"
syn match diffIsA	"^\(SL\|HG\): A(z) .* fájl egy .*, viszont a(z) .* fájl egy .*"
syn match diffNoEOL	"^\(SL\|HG\): \\ Nincs újsor a fájl végén"
syn match diffCommon	"^\(SL\|HG\): Közös alkönyvtárak: .* és .*"

" id
syn match diffOnly	"^\(SL\|HG\): Hanya dalam .*"
syn match diffIdentical	"^\(SL\|HG\): File .* dan .* identik$"
syn match diffDiffer	"^\(SL\|HG\): Berkas .* dan .* berbeda$"
syn match diffBDiffer	"^\(SL\|HG\): File biner .* dan .* berbeda$"
syn match diffIsA	"^\(SL\|HG\): File .* adalah .* sementara file .* adalah .*"
syn match diffNoEOL	"^\(SL\|HG\): \\ Tidak ada baris-baru di akhir dari berkas"
syn match diffCommon	"^\(SL\|HG\): Subdirektori sama: .* dan .*"

" it
syn match diffOnly	"^\(SL\|HG\): Solo in .*"
syn match diffIdentical	"^\(SL\|HG\): I file .* e .* sono identici$"
syn match diffDiffer	"^\(SL\|HG\): I file .* e .* sono diversi$"
syn match diffBDiffer	"^\(SL\|HG\): I file .* e .* sono diversi$"
syn match diffBDiffer	"^\(SL\|HG\): I file binari .* e .* sono diversi$"
syn match diffIsA	"^\(SL\|HG\): File .* è un .* mentre file .* è un .*"
syn match diffNoEOL	"^\(SL\|HG\): \\ Manca newline alla fine del file"
syn match diffCommon	"^\(SL\|HG\): Sottodirectory in comune: .* e .*"

" ja
syn match diffOnly	"^\(SL\|HG\): .*だけに発見: .*"
syn match diffIdentical	"^\(SL\|HG\): ファイル.*と.*は同一$"
syn match diffDiffer	"^\(SL\|HG\): ファイル.*と.*は違います$"
syn match diffBDiffer	"^\(SL\|HG\): バイナリー・ファイル.*と.*は違います$"
syn match diffIsA	"^\(SL\|HG\): ファイル.*は.*、ファイル.*は.*"
syn match diffNoEOL	"^\(SL\|HG\): \\ ファイル末尾に改行がありません"
syn match diffCommon	"^\(SL\|HG\): 共通の下位ディレクトリー: .*と.*"

" ja DiffUtils 3.3
syn match diffOnly	"^\(SL\|HG\): .* のみに存在: .*"
syn match diffIdentical	"^\(SL\|HG\): ファイル .* と .* は同一です$"
syn match diffDiffer	"^\(SL\|HG\): ファイル .* と .* は異なります$"
syn match diffBDiffer	"^\(SL\|HG\): バイナリーファイル .* と.* は異なります$"
syn match diffIsA	"^\(SL\|HG\): ファイル .* は .* です。一方、ファイル .* は .* です$"
syn match diffNoEOL	"^\(SL\|HG\): \\ ファイル末尾に改行がありません"
syn match diffCommon	"^\(SL\|HG\): 共通のサブディレクトリー: .* と .*"

" lv
syn match diffOnly	"^\(SL\|HG\): Tikai iekš .*"
syn match diffIdentical	"^\(SL\|HG\): Fails .* un .* ir identiski$"
syn match diffDiffer	"^\(SL\|HG\): Faili .* un .* atšķiras$"
syn match diffBDiffer	"^\(SL\|HG\): Faili .* un .* atšķiras$"
syn match diffBDiffer	"^\(SL\|HG\): Binārie faili .* un .* atšķiras$"
syn match diffIsA	"^\(SL\|HG\): Fails .* ir .* kamēr fails .* ir .*"
syn match diffNoEOL	"^\(SL\|HG\): \\ Nav jaunu rindu faila beigās"
syn match diffCommon	"^\(SL\|HG\): Kopējās apakšdirektorijas: .* un .*"

" ms
syn match diffOnly	"^\(SL\|HG\): Hanya dalam .*"
syn match diffIdentical	"^\(SL\|HG\): Fail .* dan .* adalah serupa$"
syn match diffDiffer	"^\(SL\|HG\): Fail .* dan .* berbeza$"
syn match diffBDiffer	"^\(SL\|HG\): Fail .* dan .* berbeza$"
syn match diffIsA	"^\(SL\|HG\): Fail .* adalah .* manakala fail .* adalah .*"
syn match diffNoEOL	"^\(SL\|HG\): \\ Tiada baris baru pada penghujung fail"
syn match diffCommon	"^\(SL\|HG\): Subdirektori umum: .* dan .*"

" nl
syn match diffOnly	"^\(SL\|HG\): Alleen in .*"
syn match diffIdentical	"^\(SL\|HG\): Bestanden .* en .* zijn identiek$"
syn match diffDiffer	"^\(SL\|HG\): Bestanden .* en .* zijn verschillend$"
syn match diffBDiffer	"^\(SL\|HG\): Bestanden .* en .* zijn verschillend$"
syn match diffBDiffer	"^\(SL\|HG\): Binaire bestanden .* en .* zijn verschillend$"
syn match diffIsA	"^\(SL\|HG\): Bestand .* is een .* terwijl bestand .* een .* is$"
syn match diffNoEOL	"^\(SL\|HG\): \\ Geen regeleindeteken (LF) aan einde van bestand"
syn match diffCommon	"^\(SL\|HG\): Gemeenschappelijke submappen: .* en .*"

" pl
syn match diffOnly	"^\(SL\|HG\): Tylko w .*"
syn match diffIdentical	"^\(SL\|HG\): Pliki .* i .* są identyczne$"
syn match diffDiffer	"^\(SL\|HG\): Pliki .* i .* różnią się$"
syn match diffBDiffer	"^\(SL\|HG\): Pliki .* i .* różnią się$"
syn match diffBDiffer	"^\(SL\|HG\): Binarne pliki .* i .* różnią się$"
syn match diffIsA	"^\(SL\|HG\): Plik .* jest .*, podczas gdy plik .* jest .*"
syn match diffNoEOL	"^\(SL\|HG\): \\ Brak znaku nowej linii na końcu pliku"
syn match diffCommon	"^\(SL\|HG\): Wspólne podkatalogi: .* i .*"

" pt_BR
syn match diffOnly	"^\(SL\|HG\): Somente em .*"
syn match diffOnly	"^\(SL\|HG\): Apenas em .*"
syn match diffIdentical	"^\(SL\|HG\): Os aquivos .* e .* são idênticos$"
syn match diffDiffer	"^\(SL\|HG\): Os arquivos .* e .* são diferentes$"
syn match diffBDiffer	"^\(SL\|HG\): Os arquivos binários .* e .* são diferentes$"
syn match diffIsA	"^\(SL\|HG\): O arquivo .* é .* enquanto o arquivo .* é .*"
syn match diffNoEOL	"^\(SL\|HG\): \\ Falta o caracter nova linha no final do arquivo"
syn match diffCommon	"^\(SL\|HG\): Subdiretórios idênticos: .* e .*"

" ro
syn match diffOnly	"^\(SL\|HG\): Doar în .*"
syn match diffIdentical	"^\(SL\|HG\): Fişierele .* şi .* sunt identice$"
syn match diffDiffer	"^\(SL\|HG\): Fişierele .* şi .* diferă$"
syn match diffBDiffer	"^\(SL\|HG\): Fişierele binare .* şi .* diferă$"
syn match diffIsA	"^\(SL\|HG\): Fişierul .* este un .* pe când fişierul .* este un .*.$"
syn match diffNoEOL	"^\(SL\|HG\): \\ Nici un element de linie nouă la sfârşitul fişierului"
syn match diffCommon	"^\(SL\|HG\): Subdirectoare comune: .* şi .*.$"

" ru
syn match diffOnly	"^\(SL\|HG\): Только в .*"
syn match diffIdentical	"^\(SL\|HG\): Файлы .* и .* идентичны$"
syn match diffDiffer	"^\(SL\|HG\): Файлы .* и .* различаются$"
syn match diffBDiffer	"^\(SL\|HG\): Файлы .* и .* различаются$"
syn match diffIsA	"^\(SL\|HG\): Файл .* это .*, тогда как файл .* -- .*"
syn match diffNoEOL	"^\(SL\|HG\): \\ В конце файла нет новой строки"
syn match diffCommon	"^\(SL\|HG\): Общие подкаталоги: .* и .*"

" sr
syn match diffOnly	"^\(SL\|HG\): Само у .*"
syn match diffIdentical	"^\(SL\|HG\): Датотеке „.*“ и „.*“ се подударају$"
syn match diffDiffer	"^\(SL\|HG\): Датотеке .* и .* различите$"
syn match diffBDiffer	"^\(SL\|HG\): Бинарне датотеке .* и .* различите$"
syn match diffIsA	"^\(SL\|HG\): Датотека „.*“ је „.*“ док је датотека „.*“ „.*“$"
syn match diffNoEOL	"^\(SL\|HG\): \\ Без новог реда на крају датотеке"
syn match diffCommon	"^\(SL\|HG\): Заједнички поддиректоријуми: .* и .*"

" sv
syn match diffOnly	"^\(SL\|HG\): Endast i .*"
syn match diffIdentical	"^\(SL\|HG\): Filerna .* och .* är lika$"
syn match diffDiffer	"^\(SL\|HG\): Filerna .* och .* skiljer$"
syn match diffBDiffer	"^\(SL\|HG\): Filerna .* och .* skiljer$"
syn match diffIsA	"^\(SL\|HG\): Fil .* är en .* medan fil .* är en .*"
syn match diffBDiffer	"^\(SL\|HG\): De binära filerna .* och .* skiljer$"
syn match diffIsA	"^\(SL\|HG\): Filen .* är .* medan filen .* är .*"
syn match diffNoEOL	"^\(SL\|HG\): \\ Ingen nyrad vid filslut"
syn match diffCommon	"^\(SL\|HG\): Lika underkataloger: .* och .*"

" tr
syn match diffOnly	"^\(SL\|HG\): Yalnızca .*'da: .*"
syn match diffIdentical	"^\(SL\|HG\): .* ve .* dosyaları birbirinin aynı$"
syn match diffDiffer	"^\(SL\|HG\): .* ve .* dosyaları birbirinden farklı$"
syn match diffBDiffer	"^\(SL\|HG\): .* ve .* dosyaları birbirinden farklı$"
syn match diffBDiffer	"^\(SL\|HG\): İkili .* ve .* birbirinden farklı$"
syn match diffIsA	"^\(SL\|HG\): .* dosyası, bir .*, halbuki .* dosyası bir .*"
syn match diffNoEOL	"^\(SL\|HG\): \\ Dosya sonunda yenisatır yok."
syn match diffCommon	"^\(SL\|HG\): Ortak alt dizinler: .* ve .*"

" uk
syn match diffOnly	"^\(SL\|HG\): Лише у .*"
syn match diffIdentical	"^\(SL\|HG\): Файли .* та .* ідентичні$"
syn match diffDiffer	"^\(SL\|HG\): Файли .* та .* відрізняються$"
syn match diffBDiffer	"^\(SL\|HG\): Файли .* та .* відрізняються$"
syn match diffBDiffer	"^\(SL\|HG\): Двійкові файли .* та .* відрізняються$"
syn match diffIsA	"^\(SL\|HG\): Файл .* це .*, тоді як файл .* -- .*"
syn match diffNoEOL	"^\(SL\|HG\): \\ Наприкінці файлу немає нового рядка"
syn match diffCommon	"^\(SL\|HG\): Спільні підкаталоги: .* та .*"

" vi
syn match diffOnly	"^\(SL\|HG\): Chỉ trong .*"
syn match diffIdentical	"^\(SL\|HG\): Hai tập tin .* và .* là bằng nhau.$"
syn match diffIdentical	"^\(SL\|HG\): Cả .* và .* là cùng một tập tin$"
syn match diffDiffer	"^\(SL\|HG\): Hai tập tin .* và .* là khác nhau.$"
syn match diffBDiffer	"^\(SL\|HG\): Hai tập tin nhị phân .* và .* khác nhau$"
syn match diffIsA	"^\(SL\|HG\): Tập tin .* là một .* trong khi tập tin .* là một .*.$"
syn match diffBDiffer	"^\(SL\|HG\): Hai tập tin .* và .* là khác nhau.$"
syn match diffIsA	"^\(SL\|HG\): Tập tin .* là một .* còn tập tin .* là một .*.$"
syn match diffNoEOL	"^\(SL\|HG\): \\ Không có ký tự dòng mới tại kêt thức tập tin."
syn match diffCommon	"^\(SL\|HG\): Thư mục con chung: .* và .*"

" zh_CN
syn match diffOnly	"^\(SL\|HG\): 只在 .* 存在：.*"
syn match diffIdentical	"^\(SL\|HG\): 檔案 .* 和 .* 相同$"
syn match diffDiffer	"^\(SL\|HG\): 文件 .* 和 .* 不同$"
syn match diffBDiffer	"^\(SL\|HG\): 文件 .* 和 .* 不同$"
syn match diffIsA	"^\(SL\|HG\): 文件 .* 是.*而文件 .* 是.*"
syn match diffNoEOL	"^\(SL\|HG\): \\ 文件尾没有 newline 字符"
syn match diffCommon	"^\(SL\|HG\): .* 和 .* 有共同的子目录$"

" zh_TW
syn match diffOnly	"^\(SL\|HG\): 只在 .* 存在：.*"
syn match diffIdentical	"^\(SL\|HG\): 檔案 .* 和 .* 相同$"
syn match diffDiffer	"^\(SL\|HG\): 檔案 .* 與 .* 不同$"
syn match diffBDiffer	"^\(SL\|HG\): 二元碼檔 .* 與 .* 不同$"
syn match diffIsA	"^\(SL\|HG\): 檔案 .* 是.*而檔案 .* 是.*"
syn match diffNoEOL	"^\(SL\|HG\): \\ 檔案末沒有 newline 字元"
syn match diffCommon	"^\(SL\|HG\): .* 和 .* 有共同的副目錄$"

endif


syn match diffRemoved	"^\(SL\|HG\): -.*"
syn match diffRemoved	"^\(SL\|HG\): <.*"
syn match diffAdded	"^\(SL\|HG\): +.*"
syn match diffAdded	"^\(SL\|HG\): >.*"
syn match diffChanged	"^\(SL\|HG\): ! .*"

syn match diffSubname	" @@..*"ms=s+3 contained
syn match diffLine	"^\(SL\|HG\): @.*" contains=diffSubname
syn match diffLine	"^\(SL\|HG\): \<\d\+\>.*"
syn match diffLine	"^\(SL\|HG\): \*\*\*\*.*"
syn match diffLine	"^\(SL\|HG\): ---$"

" Some versions of diff have lines like "#c#" and "#d#" (where # is a number)
syn match diffLine	"^\(SL\|HG\): \d\+\(,\d\+\)\=[cda]\d\+\>.*"

syn match diffFile	"^\(SL\|HG\): diff\>.*"
syn match diffFile	"^\(SL\|HG\): Index: .*"
syn match diffFile	"^\(SL\|HG\): ==== .*"

if search('^\(SL\|HG\): @@ -\S\+ +\S\+ @@', 'nw', '', 100)
  " unified
  syn match diffOldFile	"^\(SL\|HG\): --- .*"
  syn match diffNewFile	"^\(SL\|HG\): +++ .*"
else
  " context / old style
  syn match diffOldFile	"^\(SL\|HG\): \*\*\* .*"
  syn match diffNewFile	"^\(SL\|HG\): --- .*"
endif

" Used by git
syn match diffIndexLine	"^\(SL\|HG\): index \x\x\x\x.*"

syn match diffComment	"^\(SL\|HG\): #.*"

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
