" Vim syntax file
" Language:	Sapling / Mecurial Diff (context or unified)
" Maintainer:	Max Coplan <mchcopl@gmail.com>
"               Translations by Jakson Alves de Aquino.
" Last Change:	2022-12-08
" 2025-08-16 by Vim project, update zh_CN translations, #18011
" Copied from:	runtime/syntax/diff.vim

" Quit when a (custom) syntax file was already loaded
if exists("b:current_syntax")
  finish
endif
scriptencoding utf-8

syn match hgDiffOnly		"^\%(SL\|HG\): Only in .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): Files .* and .* are identical$"
syn match hgDiffDiffer		"^\%(SL\|HG\): Files .* and .* differ$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Binary files .* and .* differ$"
syn match hgDiffIsA		"^\%(SL\|HG\): File .* is a .* while file .* is a .*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ No newline at end of file .*"
syn match hgDiffCommon		"^\%(SL\|HG\): Common subdirectories: .*"

" Disable the translations by setting diff_translations to zero.
if !exists("diff_translations") || diff_translations

" ca
syn match hgDiffOnly		"^\%(SL\|HG\): Només a .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): Els fitxers .* i .* són idèntics$"
syn match hgDiffDiffer		"^\%(SL\|HG\): Els fitxers .* i .* difereixen$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Els fitxers .* i .* difereixen$"
syn match hgDiffIsA		"^\%(SL\|HG\): El fitxer .* és un .* mentre que el fitxer .* és un .*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ No hi ha cap caràcter de salt de línia al final del fitxer"
syn match hgDiffCommon		"^\%(SL\|HG\): Subdirectoris comuns: .* i .*"

" cs
syn match hgDiffOnly		"^\%(SL\|HG\): Pouze v .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): Soubory .* a .* jsou identické$"
syn match hgDiffDiffer		"^\%(SL\|HG\): Soubory .* a .* jsou různé$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Binární soubory .* a .* jsou rozdílné$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Soubory .* a .* jsou různé$"
syn match hgDiffIsA		"^\%(SL\|HG\): Soubor .* je .* pokud soubor .* je .*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ Chybí znak konce řádku na konci souboru"
syn match hgDiffCommon		"^\%(SL\|HG\): Společné podadresáře: .* a .*"

" da
syn match hgDiffOnly		"^\%(SL\|HG\): Kun i .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): Filerne .* og .* er identiske$"
syn match hgDiffDiffer		"^\%(SL\|HG\): Filerne .* og .* er forskellige$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Binære filer .* og .* er forskellige$"
syn match hgDiffIsA		"^\%(SL\|HG\): Filen .* er en .* mens filen .* er en .*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ Intet linjeskift ved filafslutning"
syn match hgDiffCommon		"^\%(SL\|HG\): Identiske underkataloger: .* og .*"

" de
syn match hgDiffOnly		"^\%(SL\|HG\): Nur in .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): Dateien .* und .* sind identisch.$"
syn match hgDiffDiffer		"^\%(SL\|HG\): Dateien .* und .* sind verschieden.$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Binärdateien .* and .* sind verschieden.$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Binärdateien .* und .* sind verschieden.$"
syn match hgDiffIsA		"^\%(SL\|HG\): Datei .* ist ein .* während Datei .* ein .* ist.$"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ Kein Zeilenumbruch am Dateiende."
syn match hgDiffCommon		"^\%(SL\|HG\): Gemeinsame Unterverzeichnisse: .* und .*.$"

" el
syn match hgDiffOnly		"^\%(SL\|HG\): Μόνο στο .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): Τα αρχεία .* καί .* είναι πανομοιότυπα$"
syn match hgDiffDiffer		"^\%(SL\|HG\): Τα αρχεία .* και .* διαφέρουν$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Τα αρχεία .* και .* διαφέρουν$"
syn match hgDiffIsA		"^\%(SL\|HG\): Το αρχείο .* είναι .* ενώ το αρχείο .* είναι .*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ Δεν υπάρχει χαρακτήρας νέας γραμμής στο τέλος του αρχείου"
syn match hgDiffCommon		"^\%(SL\|HG\): Οι υποκατάλογοι .* και .* είναι ταυτόσημοι$"

" eo
syn match hgDiffOnly		"^\%(SL\|HG\): Nur en .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): Dosieroj .* kaj .* estas samaj$"
syn match hgDiffDiffer		"^\%(SL\|HG\): Dosieroj .* kaj .* estas malsamaj$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Dosieroj .* kaj .* estas malsamaj$"
syn match hgDiffIsA		"^\%(SL\|HG\): Dosiero .* estas .*, dum dosiero .* estas .*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ Mankas linifino ĉe fino de dosiero"
syn match hgDiffCommon		"^\%(SL\|HG\): Komunaj subdosierujoj: .* kaj .*"

" es
syn match hgDiffOnly		"^\%(SL\|HG\): Sólo en .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): Los ficheros .* y .* son idénticos$"
syn match hgDiffDiffer		"^\%(SL\|HG\): Los ficheros .* y .* son distintos$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Los ficheros binarios .* y .* son distintos$"
syn match hgDiffIsA		"^\%(SL\|HG\): El fichero .* es un .* mientras que el .* es un .*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ No hay ningún carácter de nueva línea al final del fichero"
syn match hgDiffCommon		"^\%(SL\|HG\): Subdirectorios comunes: .* y .*"

" fi
syn match hgDiffOnly		"^\%(SL\|HG\): Vain hakemistossa .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): Tiedostot .* ja .* ovat identtiset$"
syn match hgDiffDiffer		"^\%(SL\|HG\): Tiedostot .* ja .* eroavat$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Binääritiedostot .* ja .* eroavat$"
syn match hgDiffIsA		"^\%(SL\|HG\): Tiedosto .* on .*, kun taas tiedosto .* on .*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ Ei rivinvaihtoa tiedoston lopussa"
syn match hgDiffCommon		"^\%(SL\|HG\): Yhteiset alihakemistot: .* ja .*"

" fr
syn match hgDiffOnly		"^\%(SL\|HG\): Seulement dans .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): Les fichiers .* et .* sont identiques.*"
syn match hgDiffDiffer		"^\%(SL\|HG\): Les fichiers .* et .* sont différents.*"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Les fichiers binaires .* et .* sont différents.*"
syn match hgDiffIsA		"^\%(SL\|HG\): Le fichier .* est un .* alors que le fichier .* est un .*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ Pas de fin de ligne à la fin du fichier.*"
syn match hgDiffCommon		"^\%(SL\|HG\): Les sous-répertoires .* et .* sont identiques.*"

" ga
syn match hgDiffOnly		"^\%(SL\|HG\): I .* amháin: .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): Is comhionann iad na comhaid .* agus .*"
syn match hgDiffDiffer		"^\%(SL\|HG\): Tá difríocht idir na comhaid .* agus .*"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Tá difríocht idir na comhaid .* agus .*"
syn match hgDiffIsA		"^\%(SL\|HG\): Tá comhad .* ina .* ach tá comhad .* ina .*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ Gan líne nua ag an chomhadchríoch"
syn match hgDiffCommon		"^\%(SL\|HG\): Fochomhadlanna i gcoitianta: .* agus .*"

" gl
syn match hgDiffOnly		"^\%(SL\|HG\): Só en .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): Os ficheiros .* e .* son idénticos$"
syn match hgDiffDiffer		"^\%(SL\|HG\): Os ficheiros .* e .* son diferentes$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Os ficheiros binarios .* e .* son diferentes$"
syn match hgDiffIsA		"^\%(SL\|HG\): O ficheiro .* é un .* mentres que o ficheiro .* é un .*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ Non hai un salto de liña na fin da liña"
syn match hgDiffCommon		"^\%(SL\|HG\): Subdirectorios comúns: .* e .*"

" he
" ^\%(SL\|HG\): .* are expansive patterns for long lines, so disabled unless we can match
" some specific hebrew chars
if search('\%u05d5\|\%u05d1', 'nw', '', 100)
  syn match hgDiffOnly		"^\%(SL\|HG\): .*-ב קר אצמנ .*"
  syn match hgDiffIdentical	"^\%(SL\|HG\): םיהז םניה .*-ו .* םיצבקה$"
  syn match hgDiffDiffer	"^\%(SL\|HG\): הזמ הז םינוש `.*'-ו `.*' םיצבקה$"
  syn match hgDiffBDiffer	"^\%(SL\|HG\): הזמ הז םינוש `.*'-ו `.*' םיירניב םיצבק$"
  syn match hgDiffIsA		"^\%(SL\|HG\): .* .*-ל .* .* תוושהל ןתינ אל$"
  syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ ץבוקה ףוסב השד.-הרוש ות רס."
  syn match hgDiffCommon	"^\%(SL\|HG\): .*-ו .* :תוהז תויקית-תת$"
endif

" hr
syn match hgDiffOnly		"^\%(SL\|HG\): Samo u .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): Datoteke .* i .* su identične$"
syn match hgDiffDiffer		"^\%(SL\|HG\): Datoteke .* i .* se razlikuju$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Binarne datoteke .* i .* se razlikuju$"
syn match hgDiffIsA		"^\%(SL\|HG\): Datoteka .* je .*, a datoteka .* je .*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ Nema novog retka na kraju datoteke"
syn match hgDiffCommon		"^\%(SL\|HG\): Uobičajeni poddirektoriji: .* i .*"

" hu
syn match hgDiffOnly		"^\%(SL\|HG\): Csak .* -ben: .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): .* és .* fájlok azonosak$"
syn match hgDiffDiffer		"^\%(SL\|HG\): A(z) .* és a(z) .* fájlok különböznek$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): A(z) .* és a(z) .* fájlok különböznek$"
syn match hgDiffIsA		"^\%(SL\|HG\): A(z) .* fájl egy .*, viszont a(z) .* fájl egy .*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ Nincs újsor a fájl végén"
syn match hgDiffCommon		"^\%(SL\|HG\): Közös alkönyvtárak: .* és .*"

" id
syn match hgDiffOnly		"^\%(SL\|HG\): Hanya dalam .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): File .* dan .* identik$"
syn match hgDiffDiffer		"^\%(SL\|HG\): Berkas .* dan .* berbeda$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): File biner .* dan .* berbeda$"
syn match hgDiffIsA		"^\%(SL\|HG\): File .* adalah .* sementara file .* adalah .*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ Tidak ada baris-baru di akhir dari berkas"
syn match hgDiffCommon		"^\%(SL\|HG\): Subdirektori sama: .* dan .*"

" it
syn match hgDiffOnly		"^\%(SL\|HG\): Solo in .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): I file .* e .* sono identici$"
syn match hgDiffDiffer		"^\%(SL\|HG\): I file .* e .* sono diversi$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): I file .* e .* sono diversi$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): I file binari .* e .* sono diversi$"
syn match hgDiffIsA		"^\%(SL\|HG\): File .* è un .* mentre file .* è un .*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ Manca newline alla fine del file"
syn match hgDiffCommon		"^\%(SL\|HG\): Sottodirectory in comune: .* e .*"

" ja
syn match hgDiffOnly		"^\%(SL\|HG\): .*だけに発見: .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): ファイル.*と.*は同一$"
syn match hgDiffDiffer		"^\%(SL\|HG\): ファイル.*と.*は違います$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): バイナリー・ファイル.*と.*は違います$"
syn match hgDiffIsA		"^\%(SL\|HG\): ファイル.*は.*、ファイル.*は.*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ ファイル末尾に改行がありません"
syn match hgDiffCommon		"^\%(SL\|HG\): 共通の下位ディレクトリー: .*と.*"

" ja DiffUtils 3.3
syn match hgDiffOnly		"^\%(SL\|HG\): .* のみに存在: .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): ファイル .* と .* は同一です$"
syn match hgDiffDiffer		"^\%(SL\|HG\): ファイル .* と .* は異なります$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): バイナリーファイル .* と.* は異なります$"
syn match hgDiffIsA		"^\%(SL\|HG\): ファイル .* は .* です。一方、ファイル .* は .* です$"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ ファイル末尾に改行がありません"
syn match hgDiffCommon		"^\%(SL\|HG\): 共通のサブディレクトリー: .* と .*"

" lv
syn match hgDiffOnly		"^\%(SL\|HG\): Tikai iekš .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): Fails .* un .* ir identiski$"
syn match hgDiffDiffer		"^\%(SL\|HG\): Faili .* un .* atšķiras$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Faili .* un .* atšķiras$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Binārie faili .* un .* atšķiras$"
syn match hgDiffIsA		"^\%(SL\|HG\): Fails .* ir .* kamēr fails .* ir .*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ Nav jaunu rindu faila beigās"
syn match hgDiffCommon		"^\%(SL\|HG\): Kopējās apakšdirektorijas: .* un .*"

" ms
syn match hgDiffOnly		"^\%(SL\|HG\): Hanya dalam .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): Fail .* dan .* adalah serupa$"
syn match hgDiffDiffer		"^\%(SL\|HG\): Fail .* dan .* berbeza$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Fail .* dan .* berbeza$"
syn match hgDiffIsA		"^\%(SL\|HG\): Fail .* adalah .* manakala fail .* adalah .*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ Tiada baris baru pada penghujung fail"
syn match hgDiffCommon		"^\%(SL\|HG\): Subdirektori umum: .* dan .*"

" nl
syn match hgDiffOnly		"^\%(SL\|HG\): Alleen in .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): Bestanden .* en .* zijn identiek$"
syn match hgDiffDiffer		"^\%(SL\|HG\): Bestanden .* en .* zijn verschillend$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Bestanden .* en .* zijn verschillend$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Binaire bestanden .* en .* zijn verschillend$"
syn match hgDiffIsA		"^\%(SL\|HG\): Bestand .* is een .* terwijl bestand .* een .* is$"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ Geen regeleindeteken (LF) aan einde van bestand"
syn match hgDiffCommon		"^\%(SL\|HG\): Gemeenschappelijke submappen: .* en .*"

" pl
syn match hgDiffOnly		"^\%(SL\|HG\): Tylko w .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): Pliki .* i .* są identyczne$"
syn match hgDiffDiffer		"^\%(SL\|HG\): Pliki .* i .* różnią się$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Pliki .* i .* różnią się$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Binarne pliki .* i .* różnią się$"
syn match hgDiffIsA		"^\%(SL\|HG\): Plik .* jest .*, podczas gdy plik .* jest .*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ Brak znaku nowej linii na końcu pliku"
syn match hgDiffCommon		"^\%(SL\|HG\): Wspólne podkatalogi: .* i .*"

" pt_BR
syn match hgDiffOnly		"^\%(SL\|HG\): Somente em .*"
syn match hgDiffOnly		"^\%(SL\|HG\): Apenas em .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): Os aquivos .* e .* são idênticos$"
syn match hgDiffDiffer		"^\%(SL\|HG\): Os arquivos .* e .* são diferentes$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Os arquivos binários .* e .* são diferentes$"
syn match hgDiffIsA		"^\%(SL\|HG\): O arquivo .* é .* enquanto o arquivo .* é .*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ Falta o caracter nova linha no final do arquivo"
syn match hgDiffCommon		"^\%(SL\|HG\): Subdiretórios idênticos: .* e .*"

" ro
syn match hgDiffOnly		"^\%(SL\|HG\): Doar în .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): Fişierele .* şi .* sunt identice$"
syn match hgDiffDiffer		"^\%(SL\|HG\): Fişierele .* şi .* diferă$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Fişierele binare .* şi .* diferă$"
syn match hgDiffIsA		"^\%(SL\|HG\): Fişierul .* este un .* pe când fişierul .* este un .*.$"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ Nici un element de linie nouă la sfârşitul fişierului"
syn match hgDiffCommon		"^\%(SL\|HG\): Subdirectoare comune: .* şi .*.$"

" ru
syn match hgDiffOnly		"^\%(SL\|HG\): Только в .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): Файлы .* и .* идентичны$"
syn match hgDiffDiffer		"^\%(SL\|HG\): Файлы .* и .* различаются$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Файлы .* и .* различаются$"
syn match hgDiffIsA		"^\%(SL\|HG\): Файл .* это .*, тогда как файл .* -- .*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ В конце файла нет новой строки"
syn match hgDiffCommon		"^\%(SL\|HG\): Общие подкаталоги: .* и .*"

" sr
syn match hgDiffOnly		"^\%(SL\|HG\): Само у .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): Датотеке „.*“ и „.*“ се подударају$"
syn match hgDiffDiffer		"^\%(SL\|HG\): Датотеке .* и .* различите$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Бинарне датотеке .* и .* различите$"
syn match hgDiffIsA		"^\%(SL\|HG\): Датотека „.*“ је „.*“ док је датотека „.*“ „.*“$"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ Без новог реда на крају датотеке"
syn match hgDiffCommon		"^\%(SL\|HG\): Заједнички поддиректоријуми: .* и .*"

" sv
syn match hgDiffOnly		"^\%(SL\|HG\): Endast i .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): Filerna .* och .* är lika$"
syn match hgDiffDiffer		"^\%(SL\|HG\): Filerna .* och .* skiljer$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Filerna .* och .* skiljer$"
syn match hgDiffIsA		"^\%(SL\|HG\): Fil .* är en .* medan fil .* är en .*"
syn match hgDiffBDiffer		"^\%(SL\|HG\): De binära filerna .* och .* skiljer$"
syn match hgDiffIsA		"^\%(SL\|HG\): Filen .* är .* medan filen .* är .*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ Ingen nyrad vid filslut"
syn match hgDiffCommon		"^\%(SL\|HG\): Lika underkataloger: .* och .*"

" tr
syn match hgDiffOnly		"^\%(SL\|HG\): Yalnızca .*'da: .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): .* ve .* dosyaları birbirinin aynı$"
syn match hgDiffDiffer		"^\%(SL\|HG\): .* ve .* dosyaları birbirinden farklı$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): .* ve .* dosyaları birbirinden farklı$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): İkili .* ve .* birbirinden farklı$"
syn match hgDiffIsA		"^\%(SL\|HG\): .* dosyası, bir .*, halbuki .* dosyası bir .*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ Dosya sonunda yenisatır yok."
syn match hgDiffCommon		"^\%(SL\|HG\): Ortak alt dizinler: .* ve .*"

" uk
syn match hgDiffOnly		"^\%(SL\|HG\): Лише у .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): Файли .* та .* ідентичні$"
syn match hgDiffDiffer		"^\%(SL\|HG\): Файли .* та .* відрізняються$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Файли .* та .* відрізняються$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Двійкові файли .* та .* відрізняються$"
syn match hgDiffIsA		"^\%(SL\|HG\): Файл .* це .*, тоді як файл .* -- .*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ Наприкінці файлу немає нового рядка"
syn match hgDiffCommon		"^\%(SL\|HG\): Спільні підкаталоги: .* та .*"

" vi
syn match hgDiffOnly		"^\%(SL\|HG\): Chỉ trong .*"
syn match hgDiffIdentical	"^\%(SL\|HG\): Hai tập tin .* và .* là bằng nhau.$"
syn match hgDiffIdentical	"^\%(SL\|HG\): Cả .* và .* là cùng một tập tin$"
syn match hgDiffDiffer		"^\%(SL\|HG\): Hai tập tin .* và .* là khác nhau.$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Hai tập tin nhị phân .* và .* khác nhau$"
syn match hgDiffIsA		"^\%(SL\|HG\): Tập tin .* là một .* trong khi tập tin .* là một .*.$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): Hai tập tin .* và .* là khác nhau.$"
syn match hgDiffIsA		"^\%(SL\|HG\): Tập tin .* là một .* còn tập tin .* là một .*.$"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ Không có ký tự dòng mới tại kêt thức tập tin."
syn match hgDiffCommon		"^\%(SL\|HG\): Thư mục con chung: .* và .*"

" zh_CN
syn match hgDiffOnly		"^\%(SL\|HG\): 只在 .* 存在：.*"
syn match hgDiffIdentical	"^\%(SL\|HG\): 文件 .* 和 .* 相同$"
syn match hgDiffDiffer		"^\%(SL\|HG\): 文件 .* 和 .* 不同$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): 二进制文件 .* 和 .* 不同$"
syn match hgDiffIsA		"^\%(SL\|HG\): 文件 .* 是.*而文件 .* 是.*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ 文件尾没有 newline 字符"
syn match hgDiffCommon		"^\%(SL\|HG\): .* 和 .* 有共同的子目录$"

" zh_TW
syn match hgDiffOnly		"^\%(SL\|HG\): 只在 .* 存在：.*"
syn match hgDiffIdentical	"^\%(SL\|HG\): 檔案 .* 和 .* 相同$"
syn match hgDiffDiffer		"^\%(SL\|HG\): 檔案 .* 與 .* 不同$"
syn match hgDiffBDiffer		"^\%(SL\|HG\): 二元碼檔 .* 與 .* 不同$"
syn match hgDiffIsA		"^\%(SL\|HG\): 檔案 .* 是.*而檔案 .* 是.*"
syn match hgDiffNoEOL		"^\%(SL\|HG\): \\ 檔案末沒有 newline 字元"
syn match hgDiffCommon		"^\%(SL\|HG\): .* 和 .* 有共同的副目錄$"

endif


syn match hgDiffRemoved		"^\%(SL\|HG\): -.*"
syn match hgDiffRemoved		"^\%(SL\|HG\): <.*"
syn match hgDiffAdded		"^\%(SL\|HG\): +.*"
syn match hgDiffAdded		"^\%(SL\|HG\): >.*"
syn match hgDiffChanged		"^\%(SL\|HG\): ! .*"

syn match hgDiffSubname		" @@..*"ms=s+3 contained
syn match hgDiffLine		"^\%(SL\|HG\): @.*" contains=hgDiffSubname
syn match hgDiffLine		"^\%(SL\|HG\): \<\d\+\>.*"
syn match hgDiffLine		"^\%(SL\|HG\): \*\*\*\*.*"
syn match hgDiffLine		"^\%(SL\|HG\): ---$"

" Some versions of diff have lines like "#c#" and "#d#" (where # is a number)
syn match hgDiffLine		"^\%(SL\|HG\): \d\+\(,\d\+\)\=[cda]\d\+\>.*"

syn match hgDiffFile		"^\%(SL\|HG\): diff\>.*"
syn match hgDiffFile		"^\%(SL\|HG\): Index: .*"
syn match hgDiffFile		"^\%(SL\|HG\): ==== .*"

if search('^\%(SL\|HG\): @@ -\S\+ +\S\+ @@', 'nw', '', 100)
  " unified
  syn match hgDiffOldFile	"^\%(SL\|HG\): --- .*"
  syn match hgDiffNewFile	"^\%(SL\|HG\): +++ .*"
else
  " context / old style
  syn match hgDiffOldFile	"^\%(SL\|HG\): \*\*\* .*"
  syn match hgDiffNewFile	"^\%(SL\|HG\): --- .*"
endif

" Used by git
syn match hgDiffIndexLine	"^\%(SL\|HG\): index \x\x\x\x.*"

syn match hgDiffComment		"^\%(SL\|HG\): #.*"

" Define the default highlighting.
" Only used when an item doesn't have highlighting yet
hi def link hgDiffOldFile	hgDiffFile
hi def link hgDiffNewFile	hgDiffFile
hi def link hgDiffIndexLine	PreProc
hi def link hgDiffFile		Type
hi def link hgDiffOnly		Constant
hi def link hgDiffIdentical	Constant
hi def link hgDiffDiffer	Constant
hi def link hgDiffBDiffer	Constant
hi def link hgDiffIsA		Constant
hi def link hgDiffNoEOL		Constant
hi def link hgDiffCommon	Constant
hi def link hgDiffRemoved	Special
hi def link hgDiffChanged	PreProc
hi def link hgDiffAdded		Identifier
hi def link hgDiffLine		Statement
hi def link hgDiffSubname	PreProc
hi def link hgDiffComment	Comment

let b:current_syntax = "hgcommitDiff"

" vim: ts=8 sw=2
