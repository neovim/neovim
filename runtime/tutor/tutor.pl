===============================================================================
=    W i t a j   w   t u t o r i a l u   V I M - a      -    Wersja  1.7.     =
===============================================================================

     Vim to potê¿ny edytor, który posiada wiele poleceñ, zbyt du¿o, by
     wyja¶niæ je wszystkie w tym tutorialu. Ten przewodnik ma nauczyæ
     Ciê pos³ugiwaæ siê wystarczaj±co wieloma komendami, by¶ móg³ ³atwo
     u¿ywaæ Vima jako edytora ogólnego przeznaczenia.

     Czas potrzebny na ukoñczenie tutoriala to 25 do 30 minut i zale¿y
     od tego jak wiele czasu spêdzisz na eksperymentowaniu.

	 UWAGA:
	 Polecenia wykonywane w czasie lekcji zmodyfikuj± tekst. Zrób
	 wcze¶niej kopiê tego pliku do æwiczeñ (je¶li zacz±³e¶ komend±
	 "vimtutor", to ju¿ pracujesz na kopii).

	 Pamiêtaj, ¿e przewodnik ten zosta³ zaprojektowany do nauki poprzez
	 æwiczenia. Oznacza to, ¿e musisz wykonywaæ polecenia, by nauczyæ siê ich
	 prawid³owo. Je¶li bêdziesz jedynie czyta³ tekst, szybko zapomnisz wiele
	 poleceñ!

     Teraz upewnij siê, ¿e nie masz wci¶niêtego Caps Locka i wciskaj  j
     tak d³ugo dopóki Lekcja 1.1. nie wype³ni ca³kowicie ekranu.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		  Lekcja 1.1.: PORUSZANIE SIÊ KURSOREM

       ** By wykonaæ ruch kursorem, wci¶nij h, j, k, l jak pokazano. **

	       ^
	       k		      Wskazówka:  h jest po lewej
	  < h	  l >				  l jest po prawej
	       j				  j wygl±da jak strza³ka w dó³
	       v
  1. Poruszaj kursorem dopóki nie bêdziesz pewien, ¿e pamiêtasz polecenia.

  2. Trzymaj  j  tak d³ugo a¿ bêdzie siê powtarza³.
     Teraz wiesz jak doj¶æ do nastêpnej lekcji.

  3. U¿ywaj±c strza³ki w dó³ przejd¼ do nastêpnej lekcji.

Uwaga: Je¶li nie jeste¶ pewien czego¶ co wpisa³e¶, wci¶nij <ESC>, by wróciæ do
       trybu Normal. Wtedy powtórz polecenie.

Uwaga: Klawisze kursora tak¿e powinny dzia³aæ, ale u¿ywaj±c  hjkl  bêdziesz
       w stanie poruszaæ siê o wiele szybciej, jak siê tylko przyzwyczaisz.
       Naprawdê!

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		    Lekcja 1.2.: WYCHODZENIE Z VIM-a

 !! UWAGA: Przed wykonaniem jakiegokolwiek polecenia przeczytaj ca³± lekcjê !!

  1. Wci¶nij <ESC> (aby upewniæ siê, ¿e jeste¶ w trybie Normal).
  2. Wpisz:			:q!<ENTER>.
     To spowoduje wyj¶cie z edytora PORZUCAJ¡C wszelkie zmiany, jakie
     zd±¿y³e¶ zrobiæ. Je¶li chcesz zapamiêtaæ zmiany i wyj¶æ,
     wpisz:			:wq<ENTER>

  3. Kiedy widzisz znak zachêty pow³oki wpisz komendê, ¿eby wróciæ
     do tutoriala. Czyli:	vimtutor<ENTER>

  4. Je¶li chcesz zapamiêtaæ polecenia, wykonaj kroki 1. do 3., aby
     wyj¶æ i wróciæ do edytora.

UWAGA: :q!<ENTER> porzuca wszelkie zmiany jakie zrobi³e¶. W nastêpnych
       lekcjach dowiesz siê jak je zapamiêtywaæ.

  5. Przenie¶ kursor do lekcji 1.3.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		 Lekcja 1.3.: EDYCJA TEKSTU - KASOWANIE

	    ** Wci¶nij  x  aby usun±æ znak pod kursorem. **

  1. Przenie¶ kursor do linii poni¿ej oznaczonej --->.

  2. By poprawiæ b³êdy, naprowad¼ kursor na znak do usuniêcia.

  3. Wci¶nij  x  aby usun±æ niechciany znak.

  4. Powtarzaj kroki 2. do 4. dopóki zdanie nie jest poprawne.

---> Kkrowa prrzeskoczy³a prrzez ksiiê¿ycc.

  5. Teraz, kiedy zdanie jest poprawione, przejd¼ do Lekcji 1.4.

UWAGA: Ucz siê przez æwiczenie, nie wkuwanie.





~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	   Lekcja 1.4.: EDYCJA TEKSTU - INSERT (wprowadzanie)


		  ** Wci¶nij  i  aby wstawiæ tekst. **

  1. Przenie¶ kursor do pierwszej linii poni¿ej oznaczonej --->.

  2. Aby poprawiæ pierwszy wiersz, ustaw kursor na pierwszym znaku PO tym,
     gdzie tekst ma byæ wstawiony.

  3. Wci¶nij  i  a nastêpnie wpisz konieczne poprawki.

  4. Po poprawieniu b³êdu wci¶nij <ESC>, by wróciæ do trybu Normal.
     Powtarzaj kroki 2. do 4., aby poprawiæ ca³e zdanie.

---> W tej brkje trochê .
---> W tej linii brakuje trochê tekstu.

  5. Kiedy czujesz siê swobodnie wstawiaj±c tekst, przejd¼ do
     podsumowania poni¿ej.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	   Lekcja 1.5.: EDYCJA TEKSTU - APPENDING (dodawanie)


		   ** Wci¶nij  A  by dodaæ tekst. **

  1. Przenie¶ kursor do pierwszej linii poni¿ej oznaczonej --->.
     Nie ma znaczenia, który to bêdzie znak.

  2. Wci¶nij  A  i wpisz odpowiednie dodatki.

  3. Kiedy tekst zosta³ dodany, wci¶nij <ESC> i wróæ do trybu Normalnego.

  4. Przenie¶ kursor do drugiej linii oznaczonej ---> i powtórz kroki 2. i 3.,
     aby poprawiæ zdanie.

---> Brakuje tu tro
     Brakuje tu trochê tekstu.
---> Tu te¿ trochê bra
     Tu te¿ trochê brakuje.

  5. Kiedy ju¿ utrwali³e¶ æwiczenie, przejd¼ do lekcji 1.6.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			  Lekcja 1.6.: EDYCJA PLIKU

		  ** U¿yj  :wq  aby zapisaæ plik i wyj¶æ. **

   !! UWAGA: zanim wykonasz jakiekolwiek polecenia przeczytaj ca³± lekcjê !!

  1. Zakoñcz tutorial tak jak w lekcji 1.2.:  :q!
     lub, je¶li masz dostêp do innego terminala, wykonaj kolejne kroki tam.

  2. W pow³oce wydaj polecenie:  vim tutor<ENTER>
     "vim" jest poleceniem uruchamiaj±cym edytor Vim. 'tutor' to nazwa pliku,
     jaki chcesz edytowaæ. U¿yj pliku, który mo¿e zostaæ zmieniony.

  3. Dodaj i usuñ tekst tak, jak siê nauczy³e¶ w poprzednich lekcjach.

  4. Zapisz plik ze zmianami i opu¶æ Vima:  :wq<ENTER>

  5. Je¶li zakoñczy³e¶ vimtutor w kroku 1., uruchom go ponownie i przejd¼
     do podsumowania poni¿ej.

  6. Po przeczytaniu wszystkich kroków i ich zrozumieniu: wykonaj je.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			     LEKCJA 1. PODSUMOWANIE

  1. Poruszasz kursorem u¿ywaj±c "strza³ek" i klawiszy  hjkl .
       h (w lewo)	 j (w dó³)	 k (do góry)		l (w prawo)

  2. By wej¶æ do Vima, (z pow³oki) wpisz:
			    vim NAZWA_PLIKU<ENTER>

  3. By wyj¶æ z Vima, wpisz:
			    <ESC> :q!<ENTER>  by usun±æ wszystkie zmiany.
	     LUB:	    <ESC> :wq<ENTER>  by zmiany zachowaæ.

  4. By usun±æ znak pod kursorem, wci¶nij:  x

  5. By wstawiæ tekst przed kursorem lub dodaæ:
	i   wpisz tekst   <ESC>         wstawi przed kursorem
	A   wpisz tekst   <ESC>         doda na koñcu linii

UWAGA: Wci¶niêcie <ESC> przeniesie Ciê z powrotem do trybu Normal
       lub odwo³a niechciane lub czê¶ciowo wprowadzone polecenia.

Teraz mo¿emy kontynuowaæ i przej¶æ do Lekcji 2.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		  Lekcja 2.1.: POLECENIE DELETE (usuwanie)


		      ** Wpisz  dw  by usun±æ wyraz. **

  1. Wci¶nij  <ESC>, by upewniæ siê, ¿e jeste¶ w trybie Normal.

  2. Przenie¶ kursor do linii poni¿ej oznaczonej --->.

  3. Przesuñ kursor na pocz±tek wyrazu, który chcesz usun±æ.

  4. Wpisz   dw   by usun±æ wyraz.

  UWAGA: Litera  d  pojawi siê na dole ekranu. Vim czeka na wpisanie  w .
	 Je¶li zobaczysz inny znak, oznacza to, ¿e wpisa³e¶ co¶ ¼le; wci¶nij
	 <ESC> i zacznij od pocz±tku.

---> Jest tu parê papier wyrazów, które kamieñ nie nale¿± do no¿yce tego zdania.

  5. Powtarzaj kroki 3. i 4. dopóki zdanie nie bêdzie poprawne, potem
  przejd¼ do Lekcji 2.2.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		    Lekcja 2.2.: WIÊCEJ POLECEÑ USUWAJ¡CYCH


	      ** Wpisz	d$  aby usun±æ tekst do koñca linii. **

  1. Wci¶nij  <ESC>  aby siê upewniæ, ¿e jeste¶ w trybie Normal.

  2. Przenie¶ kursor do linii poni¿ej oznaczonej --->.

  3. Przenie¶ kursor do koñca poprawnego zdania (PO pierwszej  . ).

  4. Wpisz  d$  aby usun±æ resztê linii.

---> Kto¶ wpisa³ koniec tego zdania dwukrotnie. zdania dwukrotnie.


  5. Przejd¼ do Lekcji 2.3., by zrozumieæ co siê sta³o.





~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lekcja 2.3.: O OPERATORACH I RUCHACH


  Wiele poleceñ zmieniaj±cych tekst jest z³o¿onych z operatora i ruchu.
  Format dla polecenia usuwaj±cego z operatorem  d  jest nastêpuj±cy:

	    d  ruch

  gdzie:
   d      - operator usuwania.
   ruch   - na czym polecenie bêdzie wykonywane (lista poni¿ej).

  Krótka lista ruchów:
    w - do pocz±tku nastêpnego wyrazu WY£¡CZAJ¡C pierwszy znak.
    e - do koñca bie¿±cego wyrazu, W£¡CZAJ¡C ostatni znak.
    $ - do koñca linii, W£¡CZAJ¡C ostatni znak.

W ten sposób wpisanie  de  usunie znaki od kursora do koñca wyrazu.

UWAGA: Wpisanie tylko ruchu w trybie Normal bez operatora przeniesie kursor
       tak, jak to okre¶lono.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		    Lekcja 2.4.: U¯YCIE MNO¯NIKA DLA RUCHU


   ** Wpisanie liczby przed ruchem powtarza ruch odpowiedni± ilo¶æ razy. **

  1. Przenie¶ kursor na pocz±tek linii poni¿ej zaznaczonej --->.

  2. Wpisz  2w  aby przenie¶æ kursor o dwa wyrazy do przodu.

  3. Wpisz  3e  aby przenie¶æ kursor do koñca trzeciego wyrazu w przód.

  4. Wpisz  0  (zero), aby przenie¶æ kursor na pocz±tek linii.

  5. Powtórz kroki 2. i 3. z innymi liczbami.


 ---> To jest zwyk³y wiersz z wyrazami, po których mo¿esz siê poruszaæ.

  6. Przejd¼ do lekcji 2.5.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		Lekcja 2.5.: U¯YCIE MNO¯NIKA, BY WIÊCEJ USUN¡Æ


    ** Wpisanie liczby z operatorem powtarza go odpowiedni± ilo¶æ razy. **

  W wy¿ej wspomnianej kombinacji operatora usuwania i ruchu podaj mno¿nik
  przed ruchem, by wiêcej usun±æ:
	d  liczba  ruch

  1. Przenie¶ kursor do pierwszego wyrazu KAPITALIKAMI w linii zaznaczonej --->.

  2. Wpisz  2dw  aby usun±æ dwa wyrazy KAPITALIKAMI.

  3. Powtarzaj kroki 1. i 2. z innymi mno¿nikami, aby usun±æ kolejne wyrazy
     KAPITALIKAMI jednym poleceniem

---> ta ASD WE linia QWE ASDF ZXCV FG wyrazów zosta³a ERT FGH CF oczyszczona.

UWAGA:  Mno¿nik pomiêdzy operatorem  d  i ruchem dzia³a podobnie do ruchu bez
        operatora.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		      Lekcja 2.6.: OPEROWANIE NA LINIACH


		   ** Wpisz  dd  aby usun±æ ca³± liniê. **

  Z powodu czêsto¶ci usuwania ca³ych linii, projektanci Vi zdecydowali, ¿e
  bêdzie ³atwiej wpisaæ dwa razy  d  aby usun±æ liniê.

  1. Przenie¶ kursor do drugiego zdania z wierszyka poni¿ej.
  2. Wpisz  dd  aby usun±æ wiersz.
  3. Teraz przenie¶ siê do czwartego wiersza.
  4. Wpisz  2dd  aby usun±æ dwa wiersze.

--->  1)  Ró¿e s± czerwone,
--->  2)  B³oto jest fajne,
--->  3)  Fio³ki s± niebieskie,
--->  4)  Mam samochód,
--->  5)  Zegar podaje czas,
--->  6)  Cukier jest s³odki,
--->  7)  I ty te¿.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		      Lekcja 2.7.: POLECENIE UNDO (cofnij)


	  ** Wci¶nij  u  aby cofn±æ skutki ostatniego polecenia.
		 U za¶, by cofn±æ skutki dla ca³ej linii. **

  1. Przenie¶ kursor do zdania poni¿ej oznaczonego ---> i umie¶æ go na
     pierwszym b³êdzie.
  2. Wpisz  x  aby usun±æ pierwszy niechciany znak.
  3. Teraz wci¶nij  u  aby cofn±æ skutki ostatniego polecenia.
  4. Tym razem popraw wszystkie b³êdy w linii u¿ywaj±c polecenia  x .
  5. Teraz wci¶nij wielkie  U  aby przywróciæ liniê do oryginalnego stanu.
  6. Teraz wci¶nij  u  kilka razy, by cofn±æ  U  i poprzednie polecenia.
  7. Teraz wpisz CTRL-R (trzymaj równocze¶nie wci¶niête klawisze CTRL i R)
     kilka razy, by cofn±æ cofniêcia.

---> Poopraw b³êdyyy w teej liniii i zaamiieñ je prrzez coofnij.

  8. To s± bardzo po¿yteczne polecenia.

     Przejd¼ teraz do podsumowania Lekcji 2.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			     LEKCJA 2. PODSUMOWANIE


  1. By usun±æ znaki od kursora do nastêpnego wyrazu, wpisz:   dw
  2. By usun±æ znaki od kursora do koñca linii, wpisz:    d$
  3. By usun±æ ca³± liniê:    dd
  4. By powtórzyæ ruch, poprzed¼ go liczb±:    2w
  5. Format polecenia zmiany to:
                operator  [liczba]  ruch
  gdzie:
   operator  - to, co trzeba zrobiæ (np.  d  dla usuwania)
   [liczba]  - opcjonalne, ile razy powtórzyæ ruch
   ruch      - przenosi nad tekstem do operowania, takim jak  w (wyraz),
	       $  (do koñca linii) etc.

  6. By przej¶æ do pocz±tku linii, u¿yj zera:  0
  7. By cofn±æ poprzednie polecenie, wpisz:	  u  (ma³e u)
     By cofn±æ wszystkie zmiany w linii, wpisz:	  U  (wielkie U)
     By cofn±æ cofniêcie, wpisz:			  CTRL-R



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			 Lekcja 3.1.: POLECENIE PUT (wstaw)


	  ** Wpisz  p  by wstawiæ ostatnie usuniêcia za kursorem. **

  1. Przenie¶ kursor do pierwszej linii ---> poni¿ej.

  2. Wpisz  dd  aby usun±æ liniê i przechowaæ j± w rejestrze Vima.

  3. Przenie¶ kursor do linii c), POWY¯EJ tej, gdzie usuniêta linia powinna
     siê znajdowaæ.

  4. Wci¶nij  p  by wstawiæ liniê poni¿ej kursora.

  5. Powtarzaj kroki 2. do 4. a¿ znajd± siê w odpowiednim porz±dku.

---> d) Jak dwa anio³ki.
---> b) Na dole fio³ki,
---> c) A my siê kochamy,
---> a) Na górze ró¿e,


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		    Lekcja 3.2.: POLECENIE REPLACE (zast±p)


	   ** Wpisz  rx  aby zast±piæ znak pod kursorem na  x . **

  1. Przenie¶ kursor do pierwszej linii poni¿ej oznaczonej --->

  2. Ustaw kursor na pierwszym b³êdzie.

  3. Wpisz  r  a potem znak jaki powinien go zast±piæ.

  4. Powtarzaj kroki 2. i 3. dopóki pierwsza linia nie bêdzie taka, jak druga.

--->  Kjedy ten wiersz bi³ wstókiwany, kto¶ wcizn±³ perê z³ych klawirzy!
--->  Kiedy ten wiersz by³ wstukiwany, kto¶ wcisn±³ parê z³ych klawiszy!

  5. Teraz czas na Lekcjê 3.3.


UWAGA: Pamiêtaj, by uczyæ siê æwicz±c, a nie pamiêciowo.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lekcja 3.3.: OPERATOR CHANGE (zmieñ)

		 ** By zmieniæ do koñca wyrazu, wpisz  ce . **

  1. Przenie¶ kursor do pierwszej linii poni¿ej oznaczonej --->.

  2. Umie¶æ kursor na  u  w lunos.

  3. Wpisz  ce  i popraw wyraz (w tym wypadku wstaw  inia ).

  4. Wci¶nij <ESC> i przejd¼ do nastêpnej planowanej zmiany.

  5. Powtarzaj kroki 3. i 4. dopóki pierwsze zdanie nie bêdzie takie same,
     jak drugie.

---> Ta lunos ma pire s³ów, które t¿ina zbnic u¿ifajonc pcmazu zmieñ.
---> Ta linia ma parê s³ów, które trzeba zmieniæ u¿ywaj±c polecenia zmieñ.

  Zauwa¿, ¿e  ce  nie tylko zamienia wyraz, ale tak¿e zmienia tryb na
  Insert (wprowadzanie).


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		      Lekcja 3.4.: WIÊCEJ ZMIAN U¯YWAJ¡C c


	** Polecenie change u¿ywa takich samych ruchów, jak delete. **

  1. Operator change dzia³a tak samo, jak delete. Format wygl±da tak:

	    c   [liczba]   ruch

  2. Ruchy s± tak¿e takie same, np.:  w  (wyraz),  $  (koniec linii) etc.

  3. Przenie¶ siê do pierwszej linii poni¿ej oznaczonej --->

  4. Ustaw kursor na pierwszym b³êdzie.

  5. Wpisz  c$ , popraw koniec wiersza i wci¶nij <ESC>.

---> Koniec tego wiersza musi byæ poprawiony, aby wygl±da³ tak, jak drugi.
---> Koniec tego wiersza musi byæ poprawiony u¿ywaj±c polecenia  c$ .

UWAGA:  Mo¿esz u¿ywaæ <BS> aby poprawiaæ b³êdy w czasie pisania.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			     LEKCJA 3. PODSUMOWANIE


  1. Aby wstawiæ tekst, który zosta³ wcze¶niej usuniêty wci¶nij  p . To
     polecenie wstawia skasowany tekst PO kursorze (je¶li ca³a linia
     zosta³a usuniêta, zostanie ona umieszczona w linii poni¿ej kursora).

  2. By zamieniæ znak pod kursorem, wci¶nij  r  a potem znak, który ma zast±piæ
     oryginalny.

  3. Operator change pozwala Ci na zast±pienie od kursora do miejsca, gdzie
     zabra³by Ciê ruch. Np. wpisz  ce  aby zamieniæ tekst od kursora do koñca
     wyrazu,  c$  aby zmieniæ tekst do koñca linii.

  4. Format do polecenia change (zmieñ):

	c   [liczba]   obiekt

     Teraz przejd¼ do nastêpnej lekcji.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	       Lekcja 4.1.: PO£O¯ENIE KURSORA ORAZ STATUS PLIKU

       ** Naci¶nij CTRL-G aby zobaczyæ swoje po³o¿enie w pliku i status
	  pliku. Naci¶nij  G  aby przej¶æ do linii w pliku. **

  UWAGA: Przeczytaj ca³± lekcjê zanim wykonasz jakie¶ polecenia!!!

  1. Przytrzymaj klawisz CTRL i wci¶nij  g . U¿ywamy notacji CTRL-G.
     Na dole strony pojawi siê pasek statusu z nazw± pliku i pozycj± w pliku.
     Zapamiêtaj numer linii dla potrzeb kroku 3.

UWAGA: Mo¿esz te¿ zobaczyæ pozycjê kursora w prawym, dolnym rogu ekranu.
       Dzieje siê tak kiedy ustawiona jest opcja 'ruler' (wiêcej w lekcji 6.).

  2. Wci¶nij G aby przej¶æ na koniec pliku.
     Wci¶nij  gg  aby przej¶æ do pocz±tku pliku.

  3. Wpisz numer linii, w której by³e¶ a potem  G . To przeniesie Ciê
     z powrotem do linii, w której by³e¶ kiedy wcisn±³e¶ CTRL-G.

  4. Je¶li czujesz siê wystarczaj±co pewnie, wykonaj kroki 1-3.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			 Lekcja 4.2.: POLECENIE SZUKAJ


	     ** Wpisz  /  a nastêpnie wyra¿enie, aby je znale¼æ. **

  1. W trybie Normal wpisz  / . Zauwa¿, ¿e znak ten oraz kursor pojawi±
     siê na dole ekranu tak samo, jak polecenie  : .

  2. Teraz wpisz  b³ond<ENTER> .  To jest s³owo, którego chcesz szukaæ.

  3. By szukaæ tej samej frazy ponownie, po prostu wci¶nij  n .
     Aby szukaæ tej frazy w przeciwnym, kierunku wci¶nij  N .

  4. Je¶li chcesz szukaæ frazy do ty³u, u¿yj polecenia  ?  zamiast  / .

  5. Aby wróciæ gdzie by³e¶, wci¶nij  CTRL-O. Powtarzaj, by wróciæ dalej. CTRL-I
     idzie do przodu.

Uwaga:  'b³ond' to nie jest metoda, by przeliterowaæ b³±d; 'b³ond' to b³±d.
Uwaga:  Kiedy szukanie osi±gnie koniec pliku, bêdzie kontynuowane od pocz±tku
        o ile opcja 'wrapscan' nie zosta³a przestawiona.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		Lekcja 4.3.: W POSZUKIWANIU PARUJ¡CYCH NAWIASÓW


	       ** Wpisz  %  by znale¼æ paruj±cy ), ], lub } . **

  1. Umie¶æ kursor na którym¶ z (, [, lub { w linii poni¿ej oznaczonej --->.

  2. Teraz wpisz znak  % .

  3. Kursor powinien siê znale¼æ na paruj±cym nawiasie.

  4. Wci¶nij  %  aby przenie¶æ kursor z powrotem do paruj±cego nawiasu.

  5. Przenie¶ kursor do innego (,),[,],{ lub } i zobacz co robi  % .

---> To ( jest linia testowa z (, [, ] i {, } . ))

Uwaga: Ta funkcja jest bardzo u¿yteczna w debuggowaniu programu
       z niesparowanymi nawiasami!



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		  Lekcja 4.4.: POLECENIE SUBSTITUTE (zamiana)


	 ** Wpisz  :s/stary/nowy/g  aby zamieniæ 'stary' na 'nowy'. **

  1. Przenie¶ kursor do linii poni¿ej oznaczonej --->.

  2. Wpisz  :s/czaas/czas<ENTER> .  Zauwa¿, ¿e to polecenie zmienia
     tylko pierwsze wyst±pienie 'czaas' w linii.

  3. Teraz wpisz  :s/czaas/czas/g  . Dodane  g  oznacza zamianê (substytucjê)
     globalnie w ca³ej linii.  Zmienia wszystkie wyst±pienia 'czaas' w linii.

---> Najlepszy czaas na zobaczenie naj³adniejszych kwiatów to czaas wiosny.

  4. Aby zmieniæ wszystkie wyst±pienia ³añcucha znaków pomiêdzy dwoma liniami,
     wpisz: :#,#s/stare/nowe/g gdzie #,# s± numerami linii ograniczaj±cych
                               region, gdzie ma nast±piæ zamiana.
     wpisz  :%s/stare/nowe/g   by zmieniæ wszystkie wyst±pienia w ca³ym pliku.
     wpisz  :%s/stare/nowe/gc  by zmieniæ wszystkie wyst±pienia w ca³ym
                               pliku, prosz±c o potwierdzenie za ka¿dym razem.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			     LEKCJA 4. PODSUMOWANIE

  1. CTRL-G   poka¿e Twoj± pozycjê w pliku i status pliku.  SHIFT-G przenosi
	      Ciê do koñca pliku.
     G        przenosi do koñca pliku.
     liczba G przenosi do linii [liczba].
     gg       przenosi do pierwszej linii.

  2. Wpisanie  /  a nastêpnie ³añcucha znaków szuka ³añcucha DO PRZODU.
     Wpisanie  ?  a nastêpnie ³añcucha znaków szuka ³añcucha DO TY£U.
     Po wyszukiwaniu wci¶nij  n  by znale¼æ nastêpne wyst±pienie szukanej
     frazy w tym samym kierunku lub  N  by szukaæ w kierunku przeciwnym.
     CTRL-O przenosi do starszych pozycji, CTRL-I do nowszych.

  3. Wpisanie  %  gdy kursor znajduje siê na (,),[,],{, lub } lokalizuje
     paruj±cy znak.

  4. By zamieniæ pierwszy stary na nowy w linii, wpisz      :s/stary/nowy
     By zamieniæ wszystkie stary na nowy w linii, wpisz     :s/stary/nowy/g
     By zamieniæ frazy pomiêdzy dwoma liniami # wpisz      :#,#s/stary/nowy/g
     By zamieniæ wszystkie wyst±pienia w pliku, wpisz       :%s/stary/nowy/g
     By Vim prosi³ Ciê o potwierdzenie, dodaj 'c'	   :%s/stary/nowy/gc
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		 Lekcja 5.1.: JAK WYKONAÆ POLECENIA ZEWNÊTRZNE?


	** Wpisz  :!  a nastêpnie zewnêtrzne polecenie, by je wykonaæ. **

  1. Wpisz znajome polecenie  :  by ustawiæ kursor na dole ekranu. To pozwala
     na wprowadzenie komendy linii poleceñ.

  2. Teraz wstaw  !  (wykrzyknik). To umo¿liwi Ci wykonanie dowolnego
     zewnêtrznego polecenia pow³oki.

  3. Jako przyk³ad wpisz  ls  za  !  a nastêpnie wci¶nij <ENTER>. To polecenie
     poka¿e spis plików w Twoim katalogu, tak jakby¶ by³ przy znaku zachêty
     pow³oki. Mo¿esz te¿ u¿yæ  :!dir  je¶li  ls  nie dzia³a.

Uwaga:  W ten sposób mo¿na wykonaæ wszystkie polecenia pow³oki.
Uwaga:  Wszystkie polecenia  :  musz± byæ zakoñczone <ENTER>.
        Od tego momentu nie zawsze bêdziemy o tym wspominaæ.




~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		    Lekcja 5.2.: WIÊCEJ O ZAPISYWANIU PLIKÓW


	   ** By zachowaæ zmiany w tek¶cie, wpisz :w NAZWA_PLIKU . **

  1. Wpisz  :!dir  lub  :!ls  by zobaczyæ spis plików w katalogu.
     Ju¿ wiesz, ¿e musisz po tym wcisn±æ <ENTER>.

  2. Wybierz nazwê pliku, jaka jeszcze nie istnieje, np. TEST.

  3. Teraz wpisz:   :w TEST   (gdzie TEST jest nazw± pliku jak± wybra³e¶.)

  4. To polecenie zapamiêta ca³y plik (Vim Tutor) pod nazw± TEST.
     By to sprawdziæ, wpisz  :!dir  lub  :!ls  ¿eby znowu zobaczyæ listê plików.

Uwaga: Zauwa¿, ¿e gdyby¶ teraz wyszed³ z Vima, a nastêpnie wszed³ ponownie
       poleceniem  vim TEST , plik by³by dok³adn± kopi± tutoriala, kiedy go
       zapisywa³e¶.

  5. Teraz usuñ plik wpisuj±c (MS-DOS):		   :!del TEST
                          lub (Unix):              :!rm TEST

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		    Lekcja 5.3.: WYBRANIE TEKSTU DO ZAPISU


	  ** By zachowaæ czê¶æ pliku, wpisz  v ruch :w NAZWA_PLIKU **

  1. Przenie¶ kursor do tego wiersza.

  2. Wci¶nij  v  i przenie¶ kursor do punktu 5. Zauwa¿, ¿e tekst zosta³
     pod¶wietlony.

  3. Wci¶nij znak  : . Na dole ekranu pojawi siê  :'<,'> .

  4. Wpisz  w TEST , gdzie TEST to nazwa pliku, który jeszcze nie istnieje.
     Upewnij siê, ¿e widzisz  :'<,'>w TEST zanim wci¶niesz Enter.

  5. Vim zapisze wybrane linie do pliku TEST. U¿yj  :!dir  lub  :!ls , ¿eby to
     zobaczyæ. Jeszcze go nie usuwaj! U¿yjemy go w nastêpnej lekcji.

UWAGA: Wci¶niêcie  v  zaczyna tryb Wizualny. Mo¿esz poruszaæ kursorem, by
       zmieniæ rozmiary zaznaczenia. Mo¿esz te¿ u¿yæ operatora, by zrobiæ co¶
       z tekstem. Na przyk³ad  d  usuwa tekst.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		   Lekcja 5.4.: WSTAWIANIE I £¡CZENIE PLIKÓW


	    ** By wstawiæ zawarto¶æ pliku, wpisz   :r NAZWA_PLIKU **

  1. Umie¶æ kursor tu¿ powy¿ej tej linii.

UWAGA: Po wykonaniu kroku 2. zobaczysz tekst z Lekcji 5.3. Potem przejd¼
       do DO£U, by zobaczyæ ponownie tê lekcjê.

  2. Teraz wczytaj plik TEST u¿ywaj±c polecenia  :r TEST , gdzie TEST
     jest nazw± pliku.
     Wczytany plik jest umieszczony poni¿ej linii z kursorem.

  3. By sprawdziæ czy plik zosta³ wczytany, cofnij kursor i zobacz, ¿e
     teraz s± dwie kopie Lekcji 5.3., orygina³ i kopia z pliku.

UWAGA: Mo¿esz te¿ wczytaæ wyj¶cie zewnêtrznego polecenia. Na przyk³ad
       :r !ls  wczytuje wyj¶cie polecenia ls i umieszcza je pod poni¿ej
       kursora.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			     LEKCJA 5. PODSUMOWANIE


  1.  :!polecenie wykonuje polecenie zewnêtrzne.

      U¿ytecznymi przyk³adami s±:

	  :!dir  -  pokazuje spis plików w katalogu.

	  :!rm NAZWA_PLIKU  -  usuwa plik NAZWA_PLIKU.

  2.  :w NAZWA_PLIKU  zapisuje obecny plik Vima na dysk z nazw± NAZWA_PLIKU.

  3.  v ruch :w NAZWA_PLIKU  zapisuje Wizualnie wybrane linie do NAZWA_PLIKU.

  4.  :r NAZWA_PLIKU  wczytuje z dysku plik NAZWA_PLIKU i wstawia go do
      bie¿±cego pliku poni¿ej kursora.

  5.  :r !dir  wczytuje wyj¶cie polecenia dir i umieszcza je poni¿ej kursora.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		      Lekcja 6.1.: POLECENIE OPEN (otwórz)


      ** Wpisz  o  by otworzyæ liniê poni¿ej kursora i przenie¶æ siê do
	 trybu Insert (wprowadzanie). **

  1. Przenie¶ kursor do linii poni¿ej oznaczonej --->.

  2. Wpisz  o  (ma³e), by otworzyæ liniê PONI¯EJ kursora i przenie¶æ siê
     do trybu Insert (wprowadzanie).

  3. Wpisz trochê tekstu i wci¶nij <ESC> by wyj¶æ z trybu Insert (wprowadzanie).

---> Po wci¶niêciu  o  kursor znajdzie siê w otwartej linii w trybie Insert.

  4. By otworzyæ liniê POWY¯EJ kursora, wci¶nij wielkie  O  zamiast ma³ego
     o . Wypróbuj to na linii poni¿ej.

---> Otwórz liniê powy¿ej wciskaj±c SHIFT-O gdy kursor bêdzie na tej linii.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lekcja 6.2.: POLECENIE APPEND (dodaj)


		  ** Wpisz  a  by dodaæ tekst ZA kursorem. **

  1. Przenie¶ kursor do pocz±tku pierwszej linii poni¿ej oznaczonej --->

  2. Wciskaj  e  dopóki kursor nie bêdzie na koñcu li .

  3. Wpisz  a  (ma³e), aby dodaæ tekst ZA znakiem pod kursorem.

  4. Dokoñcz wyraz tak, jak w linii poni¿ej. Wci¶nij <ESC> aby opu¶ciæ tryb
     Insert.

  5. U¿yj  e  by przej¶æ do kolejnego niedokoñczonego wyrazu i powtarzaj kroki
     3. i 4.

---> Ta li poz Ci æwi dodaw teks do koñ lin
---> Ta linia pozwoli Ci æwiczyæ dodawanie tekstu do koñca linii.

Uwaga:  a ,  i  oraz  A  prowadz± do trybu Insert, jedyn± ró¿nic± jest miejsce,
       gdzie nowe znaki bêd± dodawane.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		   Lekcja 6.3.: INNA WERSJA REPLACE (zamiana)


	   ** Wpisz wielkie  R  by zamieniæ wiêcej ni¿ jeden znak. **

  1. Przenie¶ kursor do pierwszej linii poni¿ej oznaczonej --->. Przenie¶
     kursor do pierwszego  xxx .

  2. Wci¶nij  R  i wpisz numer poni¿ej w drugiej linii, tak, ¿e zast±pi on
     xxx.

  3. Wci¶nij <ESC> by opu¶ciæ tryb Replace. Zauwa¿, ¿e reszta linii pozostaje
     niezmieniona.

  5. Powtarzaj kroki by wymieniæ wszystkie xxx.

---> Dodanie 123 do xxx daje xxx.
---> Dodanie 123 do 456 daje 579.

UWAGA: Tryb Replace jest jak tryb Insert, ale ka¿dy znak usuwa istniej±cy
       znak.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		  Lekcja 6.4.: KOPIOWANIE I WKLEJANIE TEKSTU


       ** u¿yj operatora  y  aby skopiowaæ tekst i  p  aby go wkleiæ **

  1. Przejd¼ do linii oznaczonej ---> i umie¶æ kursor za "a)".

  2. Wejd¼ w tryb Wizualny  v  i przenie¶ kursor na pocz±tek "pierwszy".

  3. Wci¶nij  y  aby kopiowaæ (yankowaæ) pod¶wietlony tekst.

  4. Przenie¶ kursor do koñca nastêpnej linii:  j$

  5. Wci¶nij  p  aby wkleiæ (wpakowaæ) tekst.  Dodaj:  a drugi<ESC> .

  6. U¿yj trybu Wizualnego, aby wybraæ " element.", yankuj go  y , przejd¼ do
     koñca nastêpnej linii  j$  i upakuj tam tekst z  p .

--->  a) to jest pierwszy element.
      b)
Uwaga: mo¿esz u¿yæ  y  jako operatora;  yw  kopiuje jeden wyraz.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			 Lekcja 6.5.: USTAWIANIE OPCJI


** Ustawianie opcji tak, by szukaj lub substytucja ignorowa³y wielko¶æ liter **

  1. Szukaj 'ignore' wpisuj±c:    /ignore<ENTER>
     Powtórz szukanie kilka razy naciskaj±c klawisz  n .

  2. Ustaw opcjê 'ic' (Ignore case -- ignoruj wielko¶æ liter) poprzez
     wpisanie:		:set ic

  3. Teraz szukaj 'ignore' ponownie wciskaj±c:  n
     Zauwa¿, ¿e Ignore i IGNORE tak¿e s± teraz znalezione.

  4. Ustaw opcje 'hlsearch' i 'incsearch':    :set hls is

  5. Teraz wprowad¼ polecenie szukaj ponownie i zobacz co siê zdarzy:
     /ignore<ENTER>

  6. Aby wy³±czyæ ignorowanie wielko¶ci liter:  :set noic

Uwaga: Aby usun±æ pod¶wietlanie dopasowañ, wpisz:   :nohlsearch
Uwaga: Aby ignorowaæ wielko¶æ liter dla jednego wyszukiwania: /ignore\c<ENTER>
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			     LEKCJA 6. PODSUMOWANIE


  1. Wpisanie  o  otwiera liniê PONI¯EJ kursora.
     Wpisanie  O  otwiera liniê POWY¯EJ kursora.

  2. Wpisanie  a  wstawia tekst ZA znakiem, na którym jest kursor.
     Wpisanie  A  dodaje tekst na koñcu linii.

  3. Polecenie  e  przenosi do koñca wyrazu.
  4. Operator  y  yankuje (kopiuje) tekst,  p  pakuje (wkleja) go.
  5. Wpisanie wielkiego  R  wprowadza w tryb Replace (zamiana) dopóki
     nie zostanie wci¶niêty <ESC>.
  6. Wpisanie ":set xxx" ustawia opcjê "xxx". Niektóre opcje:
	'ic'  'ignorecase'	ignoruj wielko¶æ znaków
	'is'  'incsearch'	poka¿ czê¶ciowe dopasowania
	'hls' 'hlsearch'	pod¶wietl wszystkie dopasowania
     Mo¿esz u¿yæ zarówno d³ugiej, jak i krótkiej formy.
  7. Dodaj "no", aby wy³±czyæ opcjê:   :set noic





~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			 LEKCJA 7.1. JAK UZYSKAÆ POMOC?

		      ** U¿ycie systemu pomocy on-line **

  Vim posiada bardzo dobry system pomocy on-line. By zacz±æ, spróbuj jednej
  z trzech mo¿liwo¶ci:
	- wci¶nij klawisz <HELP> (je¶li taki masz)
	- wci¶nij klawisz <F1> (je¶li taki masz)
	- wpisz   :help<ENTER>

  Przeczytaj tekst w oknie pomocy, aby dowiedzieæ siê jak dzia³a pomoc.
  wpisz CTRL-W CTRL-W    aby przeskoczyæ z jednego okna do innego
  wpisz :q<ENTER>        aby zamkn±æ okno pomocy.

  Mo¿esz te¿ znale¼æ pomoc na ka¿dy temat podaj±c argument polecenia ":help".
  Spróbuj tych (nie zapomnij wcisn±æ <ENTER>):

  :help w
  :help c_CTRL-D
  :help insert-index
  :help user-manual
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		   LEKCJA 7.2. TWORZENIE SKRYPTU STARTOWEGO

			  ** W³±cz mo¿liwo¶ci Vima **

  Vim ma o wiele wiêcej mo¿liwo¶ci ni¿ Vi, ale wiêkszo¶æ z nich jest domy¶lnie
  wy³±czona. Je¶li chcesz w³±czyæ te mo¿liwo¶ci na starcie musisz utworzyæ
  plik "vimrc".

  1. Pocz±tek edycji pliku "vimrc" zale¿y od Twojego systemu:
     :edit ~/.vimrc	     dla Uniksa
     :edit $VIM/_vimrc       dla MS-Windows
  2. Teraz wczytaj przyk³adowy plik "vimrc":
     :read $VIMRUNTIME/vimrc_example.vim
  3. Zapisz plik:
     :w

  Nastêpnym razem, gdy zaczniesz pracê w Vimie bêdzie on u¿ywaæ pod¶wietlania
  sk³adni. Mo¿esz dodaæ wszystkie swoje ulubione ustawienia do tego pliku
  "vimrc".
  Aby uzyskaæ wiêcej informacji, wpisz     :help vimrc-intro

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			  Lekcja 7.3.: UZUPE£NIANIE


	      ** Uzupe³nianie linii poleceñ z CTRL-D i <TAB> **

  1. Upewnij siê, ¿e Vim nie jest w trybie kompatybilno¶ci:   :set nocp

  2. Zerknij, jakie pliki s± w bie¿±cym katalogu:   :!ls   lub   :!dir

  3. Wpisz pocz±tek polecenia:   :e

  4. Wci¶nij  CTRL-D  i Vim poka¿e listê poleceñ, jakie zaczynaj± siê na "e".

  5. Wci¶nij  <TAB>  i Vim uzupe³ni polecenie do ":edit".

  6. Dodaj spacjê i zacznij wpisywaæ nazwê istniej±cego pliku:   :edit FIL

  7. Wci¶nij <TAB>. Vim uzupe³ni nazwê (je¶li jest niepowtarzalna).

UWAGA: Uzupe³nianie dzia³a dla wielu poleceñ. Spróbuj wcisn±æ CTRL-D i <TAB>.
       U¿yteczne zw³aszcza przy  :help .
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			    Lekcja 7. PODSUMOWANIE


  1. Wpisz  :help  albo wci¶nij <F1> lub <Help> aby otworzyæ okno pomocy.

  2. Wpisz  :help cmd  aby uzyskaæ pomoc o  cmd .

  3. Wpisz  CTRL-W CTRL-W  aby przeskoczyæ do innego okna.

  4. Wpisz  :q  aby zamkn±æ okno pomocy.

  5. Utwórz plik startowy vimrc aby zachowaæ wybrane ustawienia.

  6. Po poleceniu  : , wci¶nij CTRL-D aby zobaczyæ mo¿liwe uzupe³nienia.
     Wci¶nij <TAB> aby u¿yæ jednego z nich.






~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  Tutaj siê koñczy tutorial Vima. Zosta³ on pomy¶lany tak, aby daæ krótki
  przegl±d jego mo¿liwo¶ci, wystarczaj±cy by¶ móg³ go u¿ywaæ. Jest on
  daleki od kompletno¶ci, poniewa¿ Vim ma o wiele, wiele wiêcej poleceñ.

  Dla dalszej nauki rekomendujemy ksi±¿kê:
	Vim - Vi Improved - autor Steve Oualline
	Wydawca: New Riders
  Pierwsza ksi±¿ka ca³kowicie po¶wiêcona Vimowi. U¿yteczna zw³aszcza dla
  pocz±tkuj±cych. Zawiera wiele przyk³adów i ilustracji.
  Zobacz http://iccf-holland.org./click5.html

  Starsza pozycja i bardziej o Vi ni¿ o Vimie, ale tak¿e warta
  polecenia:
	Learning the Vi Editor - autor Linda Lamb
	Wydawca: O'Reilly & Associates Inc.
  To dobra ksi±¿ka, by dowiedzieæ siê niemal wszystkiego, co chcia³by¶ zrobiæ
  z Vi. Szósta edycja zawiera te¿ informacje o Vimie.

  Po polsku wydano:
	Edytor vi. Leksykon kieszonkowy - autor Arnold Robbins
	Wydawca: Helion 2001 (O'Reilly).
	ISBN: 83-7197-472-8
	http://helion.pl/ksiazki/vilek.htm
  Jest to ksi±¿eczka zawieraj±ca spis poleceñ vi i jego najwa¿niejszych
  klonów (miêdzy innymi Vima).

	Edytor vi - autorzy Linda Lamb i Arnold Robbins
	Wydawca: Helion 2001 (O'Reilly) - wg 6. ang. wydania
	ISBN: 83-7197-539-2
	http://helion.pl/ksiazki/viedyt.htm
  Rozszerzona wersja Learning the Vi Editor w polskim t³umaczeniu.

  Ten tutorial zosta³ napisany przez Michaela C. Pierce'a i Roberta K. Ware'a,
  Colorado School of Mines korzystaj±c z pomocy Charlesa Smitha,
  Colorado State University.
  E-mail: bware@mines.colorado.edu.

  Zmodyfikowane dla Vima przez Brama Moolenaara.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  Przet³umaczone przez Miko³aja Machowskiego,
  Sierpieñ 2001,
  rev. Marzec 2002
  2nd rev. Wrzesieñ 2004
  3rd rev. Marzec 2006
  4th rev. Grudzieñ 2008
  Wszelkie uwagi proszê kierowaæ na: mikmach@wp.pl
