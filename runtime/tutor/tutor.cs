===============================================================================
=    V í t e j t e   v  t u t o r i a l u   V I M       -    Verze 1.5        =
===============================================================================

     Vim je velmi výkonný editor, který má pøíli¹ mnoho pøíkazù na to, aby
     mohly být v¹echny vysvìtlené ve výuce jako tato. Tato výuka obsahuje
     dostateèné mno¾ství pøíkazù na to, aby bylo mo¾né pou¾ívat Vim jako
     víceúèelový editor.

     Pøibli¾ný èas potøebný ke zvládnutí této výuky je 25-30 minut, zále¾í
     na tom, kolik èasu strávíte pøezku¹ováním.

     Pøíkazy v lekcích upravují text. Vytvoø kopii tohoto souboru pro
     procvièování (pøi startu "vimtutor" je ji¾ toto kopie).

     Je dùle¾ité pamatovat, ¾e tato výuka je vytvoøena pro výuku pou¾íváním.
     To znamená, ¾e je potøeba si pøíkazy vyzkou¹et pro jejich správné
     nauèení. Pokud si jen ète¹ text, pøíkazy zapomene¹!

     Nyní se pøesvìdète, ¾e Shift-Lock NENÍ stlaèený a nìkolikrát stisknìte
     klávesu  j   aby se kurzor posunul natolik, ¾e lekce 1.1 zaplní celou
     obrazovku.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			Lekce 1.1:  POHYB KURZORU


   ** Pro pohyb kurzoru pou¾ívej klávesy h,j,k,l jak je znázornìno ní¾e. **
	     ^
	     k		   Funkce: Klávesa h je vlevo a vykoná pohyb vlevo.
       < h	 l >		   Klávesa l je vpravo a vykoná pohyb vpravo.
	     j			   Klávesa j vypadá na ¹ipku dolu.
	     v
  1. Pohybuj kurzorem po obrazovce dokud si na to nezvykne¹.

  2. Dr¾ klávesu pro pohyb dolu (j), dokud se její funkce nezopakuje.
---> Teï ví¹ jak se pøesunout na následující lekci.

  3. Pou¾itím klávesy dolu pøejdi na lekci 1.2.

Poznámka: Pokud si nìkdy nejsi jist nìèím, co jsi napsal, stlaè <ESC> pro
          pøechod do Normálního módu. Poté pøepi¹ po¾adovaný pøíkaz.

Poznámka: Kurzorové klávesy také fungují, av¹ak pou¾ívání hjkl je rychlej¹í
          jakmile si na nìj zvykne¹.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lekce 1.2: SPU©TÌNÍ A UKONÈENÍ VIM


  !! POZNÁMKA: Pøed vykonáním tìchto krokù si pøeèti celou lekci!!

  1. Stlaè <ESC> (pro uji¹tìní, ¾e se nachází¹ v Normálním módu).

  2. Napi¹:			:q! <ENTER>.

---> Tímto ukonèí¹ editor BEZ ulo¾ení zmìn, které si vykonal.
     Pokud chce¹ ulo¾it zmìny a ukonèit editor napi¹:
				:wq  <ENTER>

  3. A¾ se dostane¹ na pøíkazový øádek, napi¹ pøíkaz, kterým se dostane¹ zpìt
     do této výuky. To mù¾e být: vimtutor <ENTER>
     Bì¾nì se pou¾ívá:		 vim tutor <ENTER>

---> 'vim' znamená spu¹tìní editoru, 'tutor' je soubor k editaci.

  4. Pokud si tyto kroky spolehlivì pamatuje¹, vykonej kroky 1 a¾ 3, èím¾
     ukonèí¹ a znovu spustí¹ editor. Potom pøesuò kurzor dolu na lekci 1.3.
     
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lekce 1.3: ÚPRAVA TEXTU - MAZÁNÍ


  ** Stisknutím klávesy  x  v Normálním módu sma¾e¹ znak na místì kurzoru. **

  1. Pøesuò kurzor ní¾e na øádek oznaèený --->.

  2. K odstranìní chyb pøejdi kurzorem na znak, který chce¹ smazat.

  3. Stlaè klávesu  x  k odstranìní nechtìných znakù.

  4. Opakuj kroky 2 a¾ 4 dokud není vìta správnì.

---> Krááva skoèèilla pøess mìssíc.

  5. Pokud je vìta správnì, pøejdi na lekci 1.4.

POZNÁMKA: Nesna¾ se pouze zapamatovat pøedvádìné pøíkazy, uè se je pou¾íváním.




~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lekce 1.4: ÚPRAVA TEXTU - VKLÁDÁNÍ


      ** Stlaèení klávesy  i  v Normálním módu umo¾òuje vkládání textu. **

  1. Pøesuò kurzor na první øádek oznaèený --->.

  2. Pro upravení prvního øádku do podoby øádku druhého, pøesuò kurzor na
     první znak za místo, kde má být text vlo¾ený.

  3. Stlaè  i  a napi¹ potøebný dodatek.

  4. Po opravení ka¾dé chyby stlaè <ESC> pro návrat do Normálního módu.
     Opakuj kroky 2 a¾ 4 dokud není vìta správnì.

---> Nìjaký txt na této .
---> Nìjaký text chybí na této øádce.

  5. Pokud ji¾ ovládá¹ vkládání textu, pøejdi na následující shrnutí.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			       SHRNUTÍ LEKCE 1


  1. Kurzorem se pohybuje pomocí ¹ipek nebo klávesami hjkl.
	h (vlevo)	j (dolu)	k (nahoru)	l (vpravo)

  2. Pro spu¹tìní Vimu (z pøíkazového øádku) napi¹: vim SOUBOR <ENTER>

  3. Pro ukonèení Vimu napi¹: <ESC>  :q!  <ENTER>  bez ulo¾ení zmìn.
	     	       anebo: <ESC>  :wq  <ENTER>  pro ulo¾ení zmìn.

  4. Pro smazání znaku pod kurzorem napi¹ v Normálním módu:  x

  5. Pro vkládání textu od místa kurzoru napi¹ v Normálním módu:
	 i     vkládaný text	<ESC>

POZNÁMKA: Stlaèení <ESC> tì pøemístí do Normálního módu nebo zru¹í nechtìný
      a èásteènì dokonèený pøíkaz.

Nyní pokraèuj Lekcí 2.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			Lekce 2.1: PØÍKAZY MAZÁNÍ


	       ** Pøíkaz  dw  sma¾e znaky do konce slova. **

  1. Stlaè  <ESC>  k ubezpeèení, ¾e jsi v Normálním módu.

  2. Pøesuò kurzor ní¾e na øádek oznaèený --->.

  3. Pøesuò kurzor na zaèátek slova, které je potøeba smazat.

  4. Napi¹   dw	 , aby slovo zmizelo.

POZNÁMKA: Písmena dw se zobrazí na posledním øádku obrazovky jakmile je
	  napí¹e¹. Kdy¾ napí¹e¹ nìco ¹patnì, stlaè  <ESC>  a zaèni znova.

---> Jsou tu nìjaká slova zábava, která nepatøí list do této vìty.

  5. Opakuj kroky 3 a¾ 4 dokud není vìta správnì a pøejdi na lekci 2.2.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		      Lekce 2.2: VÍCE PØÍKAZÙ MAZÁNÍ


	   ** Napsání pøíkazu  d$  sma¾e v¹e a¾ do konce øádky. **

  1. Stlaè  <ESC>  k ubezpeèení, ¾e jsi v Normálním módu.

  2. Pøesuò kurzor ní¾e na øádek oznaèený --->.

  3. Pøesuò kurzor na konec správné vìty (ZA první teèku).

  4. Napi¹  d$  ,aby jsi smazal znaky a¾ do konce øádku.

---> Nìkdo napsal konec této vìty dvakrát. konec této vìty dvakrát.


  5. Pøejdi na lekci 2.3 pro pochopení toho, co se stalo.





~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		  Lekce 2.3: ROZ©IØOVACÍ PØÍKAZY A OBJEKTY


  Formát mazacího pøíkazu  d  je následující:

	 [èíslo]   d   objekt     NEBO     d   [èíslo]   objekt
  Kde:
    èíslo - udává kolikrát se pøíkaz vykoná (volitelné, výchozí=1).
    d - je pøíkaz mazání.
    objekt - udává na èem se pøíkaz vykonává (vypsané ní¾e).

  Krátký výpis objektù:
    w - od kurzoru do konce slova, vèetnì mezer.
    e - od kurzoru do konce slova, BEZ mezer.
    $ - od kurzoru do konce øádku.

POZNÁMKA:  Stlaèením klávesy objektu v Normálním módu se kurzor pøesune na
           místo upøesnìné ve výpisu objektù.




~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lekce 2.4: VÝJIMKA Z 'PØÍKAZ-OBJEKT'


    	          ** Napsáním   dd   sma¾e¹ celý øádek. **

  Vzhledem k èastosti mazání celého øádku se autoøi Vimu rozhodli, ¾e bude
  jednodu¹í napsat prostì dvì d k smazání celého øádku.

  1. Pøesuò kurzor na druhý øádek spodního textu.
  2. Napi¹  dd  pro smazání øádku.
  3. Pøejdi na ètvrtý øádek.
  4. Napi¹   2dd   (vzpomeò si  èíslo-pøíkaz-objekt) pro smazání dvou øádkù.

      1)  Rù¾e jsou èervené,
      2)  Bláto je zábavné,
      3)  Fialky jsou modré,
      4)  Mám auto,
      5)  Hodinky ukazují èas,
      6)  Cukr je sladký,
      7)  A to jsi i ty.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			   Lekce 2.5: PØÍKAZ UNDO


   ** Stlaè  u	pro vrácení posledního pøíkazu,  U  pro celou øádku. **

  1. Pøesuò kurzor ní¾e na øádek oznaèený ---> a pøemísti ho na první chybu.
  2. Napi¹  x  pro smazání prvního nechtìného znaku.
  3. Teï napi¹  u  èím¾ vrátí¹ zpìt poslední vykonaný pøíkaz.
  4. Nyní oprav v¹echny chyby na øádku pomocí pøíkazu  x  .
  5. Napi¹ velké  U  èím¾ vrátí¹ øádek do pùvodního stavu.
  6. Teï napi¹  u  nìkolikrát, èím¾ vrátí¹ zpìt pøíkaz  U  .
  7. Stlaè CTRL-R (klávesu CTRL dr¾ stlaèenou a stiskni R) nìkolikrát,
     èím¾ vrátí¹ zpìt pøedtím vrácené pøíkazy (redo).

---> Opprav chybby nna toomto øádku a nahraï je pommocí undo.

  8. Toto jsou velmi u¾iteèné pøíkazy. Nyní pøejdi na souhrn Lekce 2.

  



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			       SHRNUTÍ LEKCE 2


  1. Pro smazání znakù od kurzoru do konce slova napi¹:    dw

  2. Pro smazání znakù od kurzoru do konce øádku napi¹:    d$

  3. Pro smazání celého øádku napi¹:    dd

  4. Formát pøíkazu v Normálním módu je:

       [èíslo]   pøíkaz   objekt    NEBO    pøíkaz     [èíslo]   objekt
     kde:
       èíslo - udává poèet opakování pøíkazu
       pøíkaz - udává co je tøeba vykonat, napøíklad  d  ma¾e
       objekt - udává rozsah pøíkazu, napøíklad  w  (slovo),
		$ (do konce øádku), atd.

  5. Pro vrácení pøede¹lé èinnosti, napi¹:	u (malé u)
     Pro vrácení v¹ech úprav na øádku napi¹:	U (velké U)
     Pro vrácení vrácených úprav (redo) napi¹:	CTRL-R

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			 Lekce 3.1: PØÍKAZ VLO®IT


       ** Pøíka  p  vlo¾í poslední vymazaný text za kurzor. **

  1. Pøesuò kurzor ní¾e na poslední øádek textu.

  2. Napi¹  dd  pro smazání øádku a jeho ulo¾ení do bufferu.

  3. Pøesuò kurzor VÝ©E tam, kam smazaný øádek patøí.

  4. V Normálním módu napi¹  p  pro opìtné vlo¾ení øádku.

  5. Opakuj kroky 2 a¾ 4 dokud øádky nebudou ve správném poøadí.

     d) Také se doká¾e¹ vzdìlávat?
     b) Fialky jsou modré,
     c) Inteligence se uèí,
     a) Rù¾e jsou èervené,



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		       Lekce 3.2: PØÍKAZ NAHRAZENÍ


          ** Napsáním  r  a znaku se nahradí znak pod kurzorem. **

  1. Pøesuò kurzor ní¾e na první øádek oznaèený --->.

  2. Pøesuò kurzor na zaèátek první chyby.

  3. Napi¹  r  a potom znak, který nahradí chybu.

  4. Opakuj kroky 2 a¾ 3 dokud není první øádka správnì.

--->  Kdi¾ byl pzán tento øádeg, nìkdu stla¾il ¹paqné klávesy!
--->  Kdy¾ byl psán tento øádek, nìkdo stlaèíl ¹patné klávesy!

  5. Nyní pøejdi na Lekci 3.2.

POZNÁMKA: Zapamatuj si, ¾e by ses mìl uèit pou¾íváním, ne zapamatováním.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		           Lekce 3.3: PØÍKAZ ÚPRAVY


	  ** Pokud chce¹ zmìnit èást nebo celé slovo, napi¹  cw . **

  1. Pøesuò kurzor ní¾e na první øádek oznaèený --->.

  2. Umísti kurzor na písmeno i v slovì øi»ok.

  3. Napi¹  cw  a oprav slovo (v tomto pøípadì napi¹ 'ádek'.)

  4. Stlaè <ESC> a pøejdi na dal¹í chybu (první znak, který tøeba zmìnit.)

  5. Opakuj kroky 3 a¾ 4 dokud není první vìta stejná jako ta druhá.

---> Tento øi»ok má nìkolik skic, které psadoinsa zmìnit pasdgf pøíkazu.
---> Tento øádek má nìkolik slov, které potøebují zmìnit pomocí pøíkazu.

V¹imni si, ¾e  cw  nejen nahrazuje slovo, ale také pøemístí do vkládání.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		       Lekce 3.4: VÍCE ZMÌN POU®ITÍM c


   ** Pøíkaz pro úpravu se dru¾í se stejnými objekty jako ten pro mazání. **

  1. Pøíkaz pro úpravu pracuje stejnì jako pro mazání. Formát je:

       [èíslo]   c   objekt	 NEBO	   c	[èíslo]   objekt

  2. Objekty jsou také shodné, jako napø.: w (slovo), $ (konec øádku), atd.

  3. Pøejdi ní¾e na první øádek oznaèený --->.

  4. Pøesuò kurzor na první rozdíl.

  5. Napi¹  c$  pro upravení zbytku øádku podle toho druhého a stlaè <ESC>.

---> Konec tohoto øádku potøebuje pomoc, aby byl jako ten druhý.
---> Konec tohoto øádku potøebuje opravit pou¾itím pøíkazu  c$  .



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			       SHRNUTÍ LEKCE 3


  1. Pro vlo¾ení textu, který byl smazán, napi¹  p  . To vlo¾í smazaný text
     ZA kurzor (pokud byl øádek smazaný, pøejde na øádek pod kurzorem).

  2. Pro nahrazení znaku pod kurzorem, napi¹  r  a potom znak, kterým
     chce¹ pùvodní znak nahradit.

  3. Pøíkaz na upravování umo¾òuje zmìnit specifikovaný objekt od kurzoru
     do konce objektu. Napøíklad: Napi¹  cw  ,èím¾ zmìní¹ text od pozice
     kurzoru do konce slova,  c$  zmìní text do konce øádku.

  4. Formát pro nahrazování je:

	 [èíslo]   c   objekt      NEBO     c   [èíslo]   objekt

Nyní pøejdi na následující lekci.




~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		      Lekce 4.1: POZICE A STATUS SOUBORU


  ** Stlaè CTRL-g pro zobrazení své pozice v souboru a statusu souboru.
     Stlaè SHIFT-G pro pøechod na øádek v souboru. **

  Poznámka: Pøeèti si celou lekci ne¾ zaène¹ vykonávat kroky!!

  1. Dr¾ klávesu Ctrl stlaèenou a stiskni  g  . Vespod obrazovky se zobrazí
     stavový øádek s názvem souboru a øádkou na které se nachází¹. Zapamatuj
     si èíslo øádku pro krok 3.

  2. Stlaè shift-G pro pøesun na konec souboru.

  3. Napi¹ èíslo øádku na kterém si se nacházel a stlaè shift-G. To tì
     vrátí na øádek, na kterém jsi døíve stiskl Ctrl-g.
     (Kdy¾ pí¹e¹ èísla, tak se NEZOBRAZUJÍ na obrazovce.)

  4. Pokud se cítí¹ schopný vykonat tyto kroky, vykonej je.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			Lekce 4.2: PØÍKAZ VYHLEDÁVÁNÍ


     ** Napi¹  /  následované øetìzcem pro vyhledání onoho øetìzce. **

  1. Stiskni / v Normálním módu.  V¹imni si, ¾e tento znak se spolu s
     kurzorem zobrazí v dolní èásti obrazovky jako pøíkaz  :  .

  2. Nyní napi¹ 'chhybba' <ENTER>.  To je slovo, které chce¹ vyhledat.

  3. Pro vyhledání dal¹ího výsledku stejného øetìzce, jednodu¹e stlaè  n  .
     Pro vyhledání dal¹ího výsledku stejného øetìzce opaèným smìrem, stiskni
     Shift-N.

  4. Pokud chce¹ vyhledat øetìzec v opaèném smìru, pou¾ij pøíkaz  ?  místo
     pøíkazu  /  .

---> "chhybba" není zpùsob, jak hláskovat chyba; chhybba je chyba.

Poznámka: Kdy¾ vyhledávání dosáhne konce souboru, bude pokraèovat na jeho
          zaèátku.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		   Lekce 4.3: VYHLEDÁVÁNÍ PÁROVÉ ZÁVORKY


	      ** Napi¹  %  pro nalezení párové ),], nebo } . **

  1. Pøemísti kurzor na kteroukoli (, [, nebo { v øádku oznaèeném --->.

  2. Nyní napi¹ znak  %  .

  3. Kurzor se pøemístí na odpovídající závorku.

  4. Stlaè  %  pro pøesun kurzoru zpìt na otvírající závorku.

---> Toto ( je testovací øádek ('s, ['s ] a {'s } v nìm. ))

Poznámka: Toto je velmi u¾iteèné pøí ladìní programu s chybìjícími
          uzavíracími závorkami.





~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		      Lekce 4.4: ZPÙSOB JAK ZMÌNIT CHYBY
		      

   ** Napi¹  :s/staré/nové/g  pro nahrazení slova 'nové' za 'staré'. **

  1. Pøesuò kurzor na øádek oznaèený --->.

  2. Napi¹  :s/dobréé/dobré <ENTER> .  V¹imni si, ¾e tento pøíkaz zmìní pouze
     první výskyt v øádku.

  3. Nyní napi¹	 :s/dobréé/dobré/g  co¾ znamená celkové nahrazení v øádku.
     Toto nahradí v¹echny výskyty v øádku.

---> dobréé suroviny a dobréé náèiní jsou základem dobréé kuchynì.

  4. Pro zmìnu v¹ech výskytù øetìzce mezi dvìma øádky,
     Napi¹   :#,#s/staré/nové/g  kde #,# jsou èísla onìch øádek.
     Napi¹   :%s/staré/nové/g    pro zmìnu v¹ech výskytù v celém souboru.




~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			       SHRNUTÍ LEKCE 4


  1. Ctrl-g  vypí¹e tvou pozici v souboru a status souboru.
     Shift-G  tì pøemístí na konec souboru.  Èíslo následované
     Shift-G  tì pøesune na dané èíslo øádku.

  2. Napsání  /  následované øetìzcem vyhledá øetìzec smìrem DOPØEDU.
     Napsání  ?  následované øetìzcem vyhledá øetìzec smìrem DOZADU.
     Napsání  n  po vyhledávání najde následující výskyt øetìzce ve stejném
     smìru, Shift-N ve smìru opaèném.

  3. Stisknutí  %  kdy¾ je kurzor na (,),[,],{, nebo } najde odpovídající
     párovou závorku.

  4. Pro nahrazení nového za první starý v øádku napi¹     :s/staré/nové
     Pro nahrazení nového za v¹echny staré v øádku napi¹   :s/staré/nové/g
     Pro nahrazení øetìzcù mezi dvìmi øádkami # napi¹      :#,#s/staré/nové/g
     Pro nahrazení v¹ech výskytù v souboru napi¹	   :%s/staré/nové/g
     Pro potvrzení ka¾dého nahrazení pøidej 'c'		   :%s/staré/nové/gc


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		    Lekce 5.1: JAK VYKONAT VNÌJ©Í PØÍKAZ


   ** Napi¹  :!  následované vnìj¹ím pøíkazem pro spu¹tìní pøíkazu. **

  1. Napi¹ obvyklý pøíkaz  :  , který umístí kurzor na spodek obrazovky
     To umo¾ní napsat pøíkaz.

  2. Nyní stiskni  !  (vykøièník). To umo¾ní vykonat jakýkoliv vnìj¹í
     pøíkaz z pøíkazového øádku.

  3. Napøíklad napi¹  ls  za ! a stiskni <ENTER>.  Tento pøíkaz zobrazí
     obsah tvého adresáøe jako v pøíkazovém øádku.
     Vyzkou¹ej  :!dir  pokud ls nefunguje.

Poznámka:  Takto je mo¾né vykonat jakýkoliv pøíkaz.

Poznámka:  V¹echny pøíkazy  :  musí být dokonèené stisknutím <ENTER>




~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lekce 5.2: VÍCE O UKLÁDÁNÍ SOUBORÙ


	    ** Pro ulo¾ení zmìn v souboru napi¹  :w SOUBOR. **

  1. Napi¹  :!dir  nebo  :!ls  pro výpis aktuálního adresáøe.
     U¾ ví¹, ¾e za tímto musí¹ stisknout <ENTER>.

  2. Vyber si název souboru, který je¹tì neexistuje, napøíklad TEST.

  3. Nyní napi¹:  :w TEST  (kde TEST je vybraný název souboru.)

  4. To ulo¾í celý soubor  (Výuka Vimu)  pod názvem TEST.
     Pro ovìøení napi¹ znovu :!dir  , èím¾ zobrazí¹ obsah adresáøe.

Poznámka: Jakmile ukonèí¹ Vim a znovu ho spustí¹ s názvem souboru TEST,
          soubor bude pøesná kopie výuky, kdy¾ si ji ukládal.

  5. Nyní odstraò soubor napsáním (MS-DOS):    :!del TEST
			     nebo (Unix):      :!rm TEST


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lekce 5.3: VÝBÌROVÝ PØÍKAZ ULO®ENÍ


	    ** Pro ulo¾ení èásti souboru napi¹  :#,# w SOUBOR **

  1. Je¹tì jednou napi¹  :!dir  nebo  :!ls  pro výpis aktuálního adresáøe
     a vyber vhodný název souboru jako napø. TEST.

  2. Pøesuò kurzor na vrch této stránky a stiskni  Ctrl-g  pro zobrazení
     èísla øádku.  ZAPAMATUJ SI TOTO ÈÍSLO!

  3. Nyní se pøesuò na spodek této stránky a opìt stiskni Ctrl-g.
     ZAPAMATUJ SI I ÈÍSLO TOHOTO ØÁDKU!

  4. Pro ulo¾ení POUZE èásti souboru, napi¹  :#,# w TEST  kde #,# jsou
     èísla dvou zapamatovaných øádkù (vrch, spodek) a TEST je název souboru.

  5. Znova se ujisti, ¾e tam ten soubor je pomocí  :!dir  ale NEODSTRAÒUJ ho.




~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		        Lekce 5.4: SLUÈOVÁNÍ SOUBORÙ


      	   ** K vlo¾ení obsahu souboru napi¹  :r NÁZEV_SOUBORU **

  1. Napi¹  :!dir  pro uji¹tìní, ¾e soubor TEST stále existuje.

  2. Pøesuò kurzor na vrch této stránky.

POZNÁMKA: Po vykonání kroku 3 uvidí¹ lekci 5.3.	Potom se opìt pøesuò dolù
          na tuto lekci.

  3. Nyní vlo¾ soubor TEST pou¾itím pøíkazu  :r TEST  kde TEST je název
     souboru.

POZNÁMKA: Soubor, který vkládá¹ se vlo¾í od místa, kde se nachází kurzor.

  4. Pro potvrzení vlo¾ení souboru, pøesuò kurzor zpìt a v¹imni si, ¾e teï
     má¹ dvì kopie lekce 5.3, originál a souborovou verzi.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			       SHRNUTÍ LEKCE 5


  1.  :!pøíkaz  vykoná vnìj¹í pøíkaz.

      Nìkteré u¾iteèné pøíklady jsou:
	 (MS-DOS)	  (Unix)
	  :!dir		   :!ls		   -  zobrazí obsah souboru.
	  :!del SOUBOR     :!rm SOUBOR     -  odstraní SOUBOR.

  2.  :w SOUBOR  ulo¾í aktuální text jako SOUBOR na disk.

  3.  :#,#w SOUBOR  ulo¾í øádky od # do # do SOUBORU.

  4.  :r SOUBOR  vybere z disku SOUBOR a vlo¾í ho do editovaného souboru
      za pozici kurzoru.






~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			  Lekce 6.1: PØÍKAZ OTEVØÍT


  ** Napi¹  o  pro vlo¾ení øádku pod kurzor a pøepnutí do Vkládacího módu. **

  1. Pøemísti kurzor ní¾e na øádek oznaèený --->.

  2. Napi¹  o (malé) pro vlo¾ení øádku POD kurzor a pøepnutí do
     Vkládacího módu.

  3. Nyní zkopíruj øádek oznaèený ---> a stiskni <ESC> pro ukonèení
     Vkládacího módu.
  
---> Po stisknutí  o  se kurzor pøemístí na vlo¾ený øádek do Vkládacího
     módu.

  4. Pro otevøení øádku NAD kurzorem jednodu¹e napi¹ velké  O  , místo
     malého o. Vyzkou¹ej si to na následujícím øádku.
Vlo¾ øádek nad tímto napsáním Shift-O po umístìní kurzoru na tento øádek.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			  Lekce 6.2: PØÍKAZ PØIDAT


	     ** Stiskni  a  pro vlo¾ení textu ZA kurzor. **

  1. Pøesuò kurzor na ní¾e na konec øádky oznaèené --->
     stisknutím $ v Normálním módu.

  2. Stiskni  a  (malé) pro pøidání textu ZA znak, který je pod kurzorem.
     (Velké  A  pøidá na konec øádku.)

Poznámka: Tímto se vyhne¹ stisknutí  i  , posledního znaku, textu na vlo¾ení,
          <ESC>, kurzor doprava, a nakonec  x  na pøidávání na konec øádku!

  3. Nyní dokonèí první øádek. V¹imni si, ¾e pøidávání je vlastnì stejné jako
     Vkládací mód, kromì místa, kam se text vkládá.

---> Tento øádek ti umo¾òuje nacvièit
---> Tento øádek ti umo¾òuje nacvièit pøidávání textu na konec øádky.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		      Lekce 6.3: JINÝ ZPÙSOB NAHRAZOVÁNÍ


         ** Napi¹ velké  R  pro nahrazení víc ne¾ jednoho znaku. **

  1. Pøesuò kurzor na první øádek oznaèený --->.

  2. Umísti kurzor na zaèátek prvního slova, které je odli¹né od druhého
     øádku oznaèeného ---> (slovo 'poslední').

  3. Nyní stiskni  R  a nahraï zbytek textu na prvním øádku pøepsáním
     starého textu tak, aby byl první øádek stejný jako ten druhý.

---> Pro upravení prvního øádku do tvaru toho poslední na stranì pou¾ij kl.
---> Pro upravení prvního øádku do tvaru toho druhého, napi¹ R a nový text.

  4. V¹imni si, ¾e jakmile stiskne¹ <ESC> v¹echen nezmìnìný text zùstává.





~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		         Lekce 6.4: NASTAVENÍ MO®NOSTÍ

  ** Nastav mo¾nost, ¾e vyhledávání anebo nahrazování nedbá velikosti písmen **

  1. Vyhledej øetìzec 'ignore' napsáním:
     /ignore
     Zopakuj nìkolikrát stisknutí klávesy n.

  2. Nastav mo¾nost 'ic' (Ignore case) napsáním pøíkazu:
     :set ic

  3. Nyní znovu vyhledej 'ignore' stisknutím: n
     Nìkolikrát hledání zopakuj stisknutím klávesy n.

  4. Nastav mo¾nosti 'hlsearch' a 'incsearch':
     :set hls is

  5. Nyní znovu vykonej vyhledávací pøíkaz a sleduj, co se stane:
     /ignore

  6. Pro vypnutí zvýrazòování výsledkù napi¹:
     :nohlsearch
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			       SHRHNUTÍ LEKCE 6


  1. Stisknutí  o  otevøe nový øádek POD kurzorem a umístí kurzor na vlo¾ený
     øádek do Vkládacího módu.
     Napsání velkého  O  otevøe øádek NAD øádkem, na kterém je kurzor.

  2. Stiskni  a  pro vlo¾ení textu ZA znak na pozici kurzoru.
     Napsání velkého  A  automaticky pøidá text na konec øádku.

  3. Stisknutí velkého  R  pøepne do Nahrazovacího módu, dokud
     nestiskne¹ <ESC> pro jeho ukonèení.

  4. Napsání ":set xxx" nastaví mo¾nosti "xxx".








~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		      LEKCE 7: PØÍKAZY ON-LINE NÁPOVÌDY


		   ** Pou¾ívej on-line systém nápovìdy **

  Vim má obsáhlý on-line systém nápovìdy. Pro zaèátek vyzkou¹ej jeden z
  následujících:
	- stiskni klávesu <HELP> (pokud ji má¹)
	- stiskni klávesu <F1>  (pokud ji má¹)
	- napi¹  :help <ENTER>

  Napi¹  :q <ENTER>  pro uzavøení okna nápovìdy.

  Mù¾e¹ najít nápovìdu k jakémukoliv tématu pøidáním argumentu k
  pøíkazu ":help". Zkus tyto (nezapomeò stisknout <ENTER>):

	:help w
	:help c_<T
	:help insert-index
	:help user-manual


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		  LEKCE 8: VYTVOØENÍ INICIALIZAÈNÍHO SKRIPTU

		        ** Zapni funkce editoru Vim **

  Vim má daleko více funkcí ne¾ Vi, ale vìt¹ina z nich je vypnuta ve výchozím
  nastavení. Pro zapnutí nìkterých vytvoø soubor "vimrc".

  1. Zaèni upravovat soubor "vimrc". Toto závisí na pou¾itém systému:
	:edit ~/.vimrc			pro Unix
	:edit $VIM/_vimrc		pro MS-Windows

  2. Nyní èti ukázkový "vimrc" soubor:

	:read $VIMRUNTIME/vimrc_example.vim

  3. Ulo¾ soubor pomocí:

	:write

  Po pøí¹tím startu Vim se zapne zvýrazòování syntaxe.
  Do souboru "vimrc" mù¾e¹ pøidat v¹echny svoje upøednostòované nastavení.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  Toto ukonèuje výuku Vim, která byla my¹lená jako struèný pøehled
  editoru Vim, tak akorát postaèující pro lehké a obstojné pou¾ívání editoru.
  Tato výuka má daleko od úplnosti, proto¾e Vim obsahuje podstatnì více
  pøíkazù. Dále si pøeèti u¾ivatelský manuál: ":help user-manual".

  Pro dal¹í studium je doporuèená kniha:
	Vim - Vi Improved - od Steve Oualline
	Nakladatel: New Riders
  První kniha urèená pro Vim. Obzvlá¹tì vhodná pro zaèáteèníky.
  Obsahuje mno¾ství pøíkladù a obrázkù.
  viz http://iccf-holland.org/click5.html

  Tato kniha je star¹í a více vìnovaná Vi ne¾ Vim, ale také doporuèená:
	Learning the Vi Editor - od Linda Lamb
	Nakladatel: O'Reilly & Associates Inc.
  Je to dobrá kniha pro získání vìdomostí témìø o v¹em, co mù¾ete s Vi dìlat.
  ©esté vydání obsahuje té¾ informace o Vim.

  Tato výuka byla napsaná autory Michael C. Pierce a Robert K. Ware,
  Colorado School of Mines s pou¾itím my¹lenek od: Charles Smith,
  Colorado State University.  E-mail: bware@mines.colorado.edu.

  Upravil pro Vim: Bram Moolenaar.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  Pøeklad do èe¹tiny: Lubo¹ Turek
  E-Mail: lubos.turek@gmail.com
  2007 Feb 28 
