===============================================================================
=    V � t e j t e   v  t u t o r i a l u   V I M       -    Verze 1.5        =
===============================================================================

     Vim je velmi v�konn� editor, kter� m� p��li� mnoho p��kaz� na to, aby
     mohly b�t v�echny vysv�tlen� ve v�uce jako tato. Tato v�uka obsahuje
     dostate�n� mno�stv� p��kaz� na to, aby bylo mo�n� pou��vat Vim jako
     v�ce��elov� editor.

     P�ibli�n� �as pot�ebn� ke zvl�dnut� t�to v�uky je 25-30 minut, z�le��
     na tom, kolik �asu str�v�te p�ezku�ov�n�m.

     P��kazy v lekc�ch upravuj� text. Vytvo� kopii tohoto souboru pro
     procvi�ov�n� (p�i startu "vimtutor" je ji� toto kopie).

     Je d�le�it� pamatovat, �e tato v�uka je vytvo�ena pro v�uku pou��v�n�m.
     To znamen�, �e je pot�eba si p��kazy vyzkou�et pro jejich spr�vn�
     nau�en�. Pokud si jen �te� text, p��kazy zapomene�!

     Nyn� se p�esv�d�te, �e Shift-Lock NEN� stla�en� a n�kolikr�t stiskn�te
     kl�vesu  j   aby se kurzor posunul natolik, �e lekce 1.1 zapln� celou
     obrazovku.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			Lekce 1.1:  POHYB KURZORU


   ** Pro pohyb kurzoru pou��vej kl�vesy h,j,k,l jak je zn�zorn�no n�e. **
	     ^
	     k		   Funkce: Kl�vesa h je vlevo a vykon� pohyb vlevo.
       < h	 l >		   Kl�vesa l je vpravo a vykon� pohyb vpravo.
	     j			   Kl�vesa j vypad� na �ipku dolu.
	     v
  1. Pohybuj kurzorem po obrazovce dokud si na to nezvykne�.

  2. Dr� kl�vesu pro pohyb dolu (j), dokud se jej� funkce nezopakuje.
---> Te� v� jak se p�esunout na n�sleduj�c� lekci.

  3. Pou�it�m kl�vesy dolu p�ejdi na lekci 1.2.

Pozn�mka: Pokud si n�kdy nejsi jist n���m, co jsi napsal, stla� <ESC> pro
          p�echod do Norm�ln�ho m�du. Pot� p�epi� po�adovan� p��kaz.

Pozn�mka: Kurzorov� kl�vesy tak� funguj�, av�ak pou��v�n� hjkl je rychlej��
          jakmile si na n�j zvykne�.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lekce 1.2: SPU�T�N� A UKON�EN� VIM


  !! POZN�MKA: P�ed vykon�n�m t�chto krok� si p�e�ti celou lekci!!

  1. Stla� <ESC> (pro uji�t�n�, �e se nach�z� v Norm�ln�m m�du).

  2. Napi�:			:q! <ENTER>.

---> T�mto ukon�� editor BEZ ulo�en� zm�n, kter� si vykonal.
     Pokud chce� ulo�it zm�ny a ukon�it editor napi�:
				:wq  <ENTER>

  3. A� se dostane� na p��kazov� ��dek, napi� p��kaz, kter�m se dostane� zp�t
     do t�to v�uky. To m��e b�t: vimtutor <ENTER>
     B�n� se pou��v�:		 vim tutor <ENTER>

---> 'vim' znamen� spu�t�n� editoru, 'tutor' je soubor k editaci.

  4. Pokud si tyto kroky spolehliv� pamatuje�, vykonej kroky 1 a� 3, ��m�
     ukon�� a znovu spust� editor. Potom p�esu� kurzor dolu na lekci 1.3.
     
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lekce 1.3: �PRAVA TEXTU - MAZ�N�


  ** Stisknut�m kl�vesy  x  v Norm�ln�m m�du sma�e� znak na m�st� kurzoru. **

  1. P�esu� kurzor n�e na ��dek ozna�en� --->.

  2. K odstran�n� chyb p�ejdi kurzorem na znak, kter� chce� smazat.

  3. Stla� kl�vesu  x  k odstran�n� necht�n�ch znak�.

  4. Opakuj kroky 2 a� 4 dokud nen� v�ta spr�vn�.

---> Kr��va sko��illa p�ess m�ss�c.

  5. Pokud je v�ta spr�vn�, p�ejdi na lekci 1.4.

POZN�MKA: Nesna� se pouze zapamatovat p�edv�d�n� p��kazy, u� se je pou��v�n�m.




~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lekce 1.4: �PRAVA TEXTU - VKL�D�N�


      ** Stla�en� kl�vesy  i  v Norm�ln�m m�du umo��uje vkl�d�n� textu. **

  1. P�esu� kurzor na prvn� ��dek ozna�en� --->.

  2. Pro upraven� prvn�ho ��dku do podoby ��dku druh�ho, p�esu� kurzor na
     prvn� znak za m�sto, kde m� b�t text vlo�en�.

  3. Stla�  i  a napi� pot�ebn� dodatek.

  4. Po opraven� ka�d� chyby stla� <ESC> pro n�vrat do Norm�ln�ho m�du.
     Opakuj kroky 2 a� 4 dokud nen� v�ta spr�vn�.

---> N�jak� txt na t�to .
---> N�jak� text chyb� na t�to ��dce.

  5. Pokud ji� ovl�d� vkl�d�n� textu, p�ejdi na n�sleduj�c� shrnut�.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			       SHRNUT� LEKCE 1


  1. Kurzorem se pohybuje pomoc� �ipek nebo kl�vesami hjkl.
	h (vlevo)	j (dolu)	k (nahoru)	l (vpravo)

  2. Pro spu�t�n� Vimu (z p��kazov�ho ��dku) napi�: vim SOUBOR <ENTER>

  3. Pro ukon�en� Vimu napi�: <ESC>  :q!  <ENTER>  bez ulo�en� zm�n.
	     	       anebo: <ESC>  :wq  <ENTER>  pro ulo�en� zm�n.

  4. Pro smaz�n� znaku pod kurzorem napi� v Norm�ln�m m�du:  x

  5. Pro vkl�d�n� textu od m�sta kurzoru napi� v Norm�ln�m m�du:
	 i     vkl�dan� text	<ESC>

POZN�MKA: Stla�en� <ESC> t� p�em�st� do Norm�ln�ho m�du nebo zru�� necht�n�
      a ��ste�n� dokon�en� p��kaz.

Nyn� pokra�uj Lekc� 2.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			Lekce 2.1: P��KAZY MAZ�N�


	       ** P��kaz  dw  sma�e znaky do konce slova. **

  1. Stla�  <ESC>  k ubezpe�en�, �e jsi v Norm�ln�m m�du.

  2. P�esu� kurzor n�e na ��dek ozna�en� --->.

  3. P�esu� kurzor na za��tek slova, kter� je pot�eba smazat.

  4. Napi�   dw	 , aby slovo zmizelo.

POZN�MKA: P�smena dw se zobraz� na posledn�m ��dku obrazovky jakmile je
	  nap�e�. Kdy� nap�e� n�co �patn�, stla�  <ESC>  a za�ni znova.

---> Jsou tu n�jak� slova z�bava, kter� nepat�� list do t�to v�ty.

  5. Opakuj kroky 3 a� 4 dokud nen� v�ta spr�vn� a p�ejdi na lekci 2.2.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		      Lekce 2.2: V�CE P��KAZ� MAZ�N�


	   ** Naps�n� p��kazu  d$  sma�e v�e a� do konce ��dky. **

  1. Stla�  <ESC>  k ubezpe�en�, �e jsi v Norm�ln�m m�du.

  2. P�esu� kurzor n�e na ��dek ozna�en� --->.

  3. P�esu� kurzor na konec spr�vn� v�ty (ZA prvn� te�ku).

  4. Napi�  d$  ,aby jsi smazal znaky a� do konce ��dku.

---> N�kdo napsal konec t�to v�ty dvakr�t. konec t�to v�ty dvakr�t.


  5. P�ejdi na lekci 2.3 pro pochopen� toho, co se stalo.





~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		  Lekce 2.3: ROZ�I�OVAC� P��KAZY A OBJEKTY


  Form�t mazac�ho p��kazu  d  je n�sleduj�c�:

	 [��slo]   d   objekt     NEBO     d   [��slo]   objekt
  Kde:
    ��slo - ud�v� kolikr�t se p��kaz vykon� (voliteln�, v�choz�=1).
    d - je p��kaz maz�n�.
    objekt - ud�v� na �em se p��kaz vykon�v� (vypsan� n�e).

  Kr�tk� v�pis objekt�:
    w - od kurzoru do konce slova, v�etn� mezer.
    e - od kurzoru do konce slova, BEZ mezer.
    $ - od kurzoru do konce ��dku.

POZN�MKA:  Stla�en�m kl�vesy objektu v Norm�ln�m m�du se kurzor p�esune na
           m�sto up�esn�n� ve v�pisu objekt�.




~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lekce 2.4: V�JIMKA Z 'P��KAZ-OBJEKT'


    	          ** Naps�n�m   dd   sma�e� cel� ��dek. **

  Vzhledem k �astosti maz�n� cel�ho ��dku se auto�i Vimu rozhodli, �e bude
  jednodu�� napsat prost� dv� d k smaz�n� cel�ho ��dku.

  1. P�esu� kurzor na druh� ��dek spodn�ho textu.
  2. Napi�  dd  pro smaz�n� ��dku.
  3. P�ejdi na �tvrt� ��dek.
  4. Napi�   2dd   (vzpome� si  ��slo-p��kaz-objekt) pro smaz�n� dvou ��dk�.

      1)  R��e jsou �erven�,
      2)  Bl�to je z�bavn�,
      3)  Fialky jsou modr�,
      4)  M�m auto,
      5)  Hodinky ukazuj� �as,
      6)  Cukr je sladk�,
      7)  A to jsi i ty.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			   Lekce 2.5: P��KAZ UNDO


   ** Stla�  u	pro vr�cen� posledn�ho p��kazu,  U  pro celou ��dku. **

  1. P�esu� kurzor n�e na ��dek ozna�en� ---> a p�em�sti ho na prvn� chybu.
  2. Napi�  x  pro smaz�n� prvn�ho necht�n�ho znaku.
  3. Te� napi�  u  ��m� vr�t� zp�t posledn� vykonan� p��kaz.
  4. Nyn� oprav v�echny chyby na ��dku pomoc� p��kazu  x  .
  5. Napi� velk�  U  ��m� vr�t� ��dek do p�vodn�ho stavu.
  6. Te� napi�  u  n�kolikr�t, ��m� vr�t� zp�t p��kaz  U  .
  7. Stla� CTRL-R (kl�vesu CTRL dr� stla�enou a stiskni R) n�kolikr�t,
     ��m� vr�t� zp�t p�edt�m vr�cen� p��kazy (redo).

---> Opprav chybby nna toomto ��dku a nahra� je pommoc� undo.

  8. Toto jsou velmi u�ite�n� p��kazy. Nyn� p�ejdi na souhrn Lekce 2.

  



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			       SHRNUT� LEKCE 2


  1. Pro smaz�n� znak� od kurzoru do konce slova napi�:    dw

  2. Pro smaz�n� znak� od kurzoru do konce ��dku napi�:    d$

  3. Pro smaz�n� cel�ho ��dku napi�:    dd

  4. Form�t p��kazu v Norm�ln�m m�du je:

       [��slo]   p��kaz   objekt    NEBO    p��kaz     [��slo]   objekt
     kde:
       ��slo - ud�v� po�et opakov�n� p��kazu
       p��kaz - ud�v� co je t�eba vykonat, nap��klad  d  ma�e
       objekt - ud�v� rozsah p��kazu, nap��klad  w  (slovo),
		$ (do konce ��dku), atd.

  5. Pro vr�cen� p�ede�l� �innosti, napi�:	u (mal� u)
     Pro vr�cen� v�ech �prav na ��dku napi�:	U (velk� U)
     Pro vr�cen� vr�cen�ch �prav (redo) napi�:	CTRL-R

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			 Lekce 3.1: P��KAZ VLO�IT


       ** P��ka  p  vlo�� posledn� vymazan� text za kurzor. **

  1. P�esu� kurzor n�e na posledn� ��dek textu.

  2. Napi�  dd  pro smaz�n� ��dku a jeho ulo�en� do bufferu.

  3. P�esu� kurzor VݩE tam, kam smazan� ��dek pat��.

  4. V Norm�ln�m m�du napi�  p  pro op�tn� vlo�en� ��dku.

  5. Opakuj kroky 2 a� 4 dokud ��dky nebudou ve spr�vn�m po�ad�.

     d) Tak� se dok�e� vzd�l�vat?
     b) Fialky jsou modr�,
     c) Inteligence se u��,
     a) R��e jsou �erven�,



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		       Lekce 3.2: P��KAZ NAHRAZEN�


          ** Naps�n�m  r  a znaku se nahrad� znak pod kurzorem. **

  1. P�esu� kurzor n�e na prvn� ��dek ozna�en� --->.

  2. P�esu� kurzor na za��tek prvn� chyby.

  3. Napi�  r  a potom znak, kter� nahrad� chybu.

  4. Opakuj kroky 2 a� 3 dokud nen� prvn� ��dka spr�vn�.

--->  Kdi� byl pz�n tento ��deg, n�kdu stla�il �paqn� kl�vesy!
--->  Kdy� byl ps�n tento ��dek, n�kdo stla��l �patn� kl�vesy!

  5. Nyn� p�ejdi na Lekci 3.2.

POZN�MKA: Zapamatuj si, �e by ses m�l u�it pou��v�n�m, ne zapamatov�n�m.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		           Lekce 3.3: P��KAZ �PRAVY


	  ** Pokud chce� zm�nit ��st nebo cel� slovo, napi�  cw . **

  1. P�esu� kurzor n�e na prvn� ��dek ozna�en� --->.

  2. Um�sti kurzor na p�smeno i v slov� �i�ok.

  3. Napi�  cw  a oprav slovo (v tomto p��pad� napi� '�dek'.)

  4. Stla� <ESC> a p�ejdi na dal�� chybu (prvn� znak, kter� t�eba zm�nit.)

  5. Opakuj kroky 3 a� 4 dokud nen� prvn� v�ta stejn� jako ta druh�.

---> Tento �i�ok m� n�kolik skic, kter� psadoinsa zm�nit pasdgf p��kazu.
---> Tento ��dek m� n�kolik slov, kter� pot�ebuj� zm�nit pomoc� p��kazu.

V�imni si, �e  cw  nejen nahrazuje slovo, ale tak� p�em�st� do vkl�d�n�.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		       Lekce 3.4: V�CE ZM�N POU�IT�M c


   ** P��kaz pro �pravu se dru�� se stejn�mi objekty jako ten pro maz�n�. **

  1. P��kaz pro �pravu pracuje stejn� jako pro maz�n�. Form�t je:

       [��slo]   c   objekt	 NEBO	   c	[��slo]   objekt

  2. Objekty jsou tak� shodn�, jako nap�.: w (slovo), $ (konec ��dku), atd.

  3. P�ejdi n�e na prvn� ��dek ozna�en� --->.

  4. P�esu� kurzor na prvn� rozd�l.

  5. Napi�  c$  pro upraven� zbytku ��dku podle toho druh�ho a stla� <ESC>.

---> Konec tohoto ��dku pot�ebuje pomoc, aby byl jako ten druh�.
---> Konec tohoto ��dku pot�ebuje opravit pou�it�m p��kazu  c$  .



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			       SHRNUT� LEKCE 3


  1. Pro vlo�en� textu, kter� byl smaz�n, napi�  p  . To vlo�� smazan� text
     ZA kurzor (pokud byl ��dek smazan�, p�ejde na ��dek pod kurzorem).

  2. Pro nahrazen� znaku pod kurzorem, napi�  r  a potom znak, kter�m
     chce� p�vodn� znak nahradit.

  3. P��kaz na upravov�n� umo��uje zm�nit specifikovan� objekt od kurzoru
     do konce objektu. Nap��klad: Napi�  cw  ,��m� zm�n� text od pozice
     kurzoru do konce slova,  c$  zm�n� text do konce ��dku.

  4. Form�t pro nahrazov�n� je:

	 [��slo]   c   objekt      NEBO     c   [��slo]   objekt

Nyn� p�ejdi na n�sleduj�c� lekci.




~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		      Lekce 4.1: POZICE A STATUS SOUBORU


  ** Stla� CTRL-g pro zobrazen� sv� pozice v souboru a statusu souboru.
     Stla� SHIFT-G pro p�echod na ��dek v souboru. **

  Pozn�mka: P�e�ti si celou lekci ne� za�ne� vykon�vat kroky!!

  1. Dr� kl�vesu Ctrl stla�enou a stiskni  g  . Vespod obrazovky se zobraz�
     stavov� ��dek s n�zvem souboru a ��dkou na kter� se nach�z�. Zapamatuj
     si ��slo ��dku pro krok 3.

  2. Stla� shift-G pro p�esun na konec souboru.

  3. Napi� ��slo ��dku na kter�m si se nach�zel a stla� shift-G. To t�
     vr�t� na ��dek, na kter�m jsi d��ve stiskl Ctrl-g.
     (Kdy� p�e� ��sla, tak se NEZOBRAZUJ� na obrazovce.)

  4. Pokud se c�t� schopn� vykonat tyto kroky, vykonej je.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			Lekce 4.2: P��KAZ VYHLED�V�N�


     ** Napi�  /  n�sledovan� �et�zcem pro vyhled�n� onoho �et�zce. **

  1. Stiskni / v Norm�ln�m m�du.  V�imni si, �e tento znak se spolu s
     kurzorem zobraz� v doln� ��sti obrazovky jako p��kaz  :  .

  2. Nyn� napi� 'chhybba' <ENTER>.  To je slovo, kter� chce� vyhledat.

  3. Pro vyhled�n� dal��ho v�sledku stejn�ho �et�zce, jednodu�e stla�  n  .
     Pro vyhled�n� dal��ho v�sledku stejn�ho �et�zce opa�n�m sm�rem, stiskni
     Shift-N.

  4. Pokud chce� vyhledat �et�zec v opa�n�m sm�ru, pou�ij p��kaz  ?  m�sto
     p��kazu  /  .

---> "chhybba" nen� zp�sob, jak hl�skovat chyba; chhybba je chyba.

Pozn�mka: Kdy� vyhled�v�n� dos�hne konce souboru, bude pokra�ovat na jeho
          za��tku.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		   Lekce 4.3: VYHLED�V�N� P�ROV� Z�VORKY


	      ** Napi�  %  pro nalezen� p�rov� ),], nebo } . **

  1. P�em�sti kurzor na kteroukoli (, [, nebo { v ��dku ozna�en�m --->.

  2. Nyn� napi� znak  %  .

  3. Kurzor se p�em�st� na odpov�daj�c� z�vorku.

  4. Stla�  %  pro p�esun kurzoru zp�t na otv�raj�c� z�vorku.

---> Toto ( je testovac� ��dek ('s, ['s ] a {'s } v n�m. ))

Pozn�mka: Toto je velmi u�ite�n� p�� lad�n� programu s chyb�j�c�mi
          uzav�rac�mi z�vorkami.





~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		      Lekce 4.4: ZP�SOB JAK ZM�NIT CHYBY
		      

   ** Napi�  :s/star�/nov�/g  pro nahrazen� slova 'nov�' za 'star�'. **

  1. P�esu� kurzor na ��dek ozna�en� --->.

  2. Napi�  :s/dobr��/dobr� <ENTER> .  V�imni si, �e tento p��kaz zm�n� pouze
     prvn� v�skyt v ��dku.

  3. Nyn� napi�	 :s/dobr��/dobr�/g  co� znamen� celkov� nahrazen� v ��dku.
     Toto nahrad� v�echny v�skyty v ��dku.

---> dobr�� suroviny a dobr�� n��in� jsou z�kladem dobr�� kuchyn�.

  4. Pro zm�nu v�ech v�skyt� �et�zce mezi dv�ma ��dky,
     Napi�   :#,#s/star�/nov�/g  kde #,# jsou ��sla on�ch ��dek.
     Napi�   :%s/star�/nov�/g    pro zm�nu v�ech v�skyt� v cel�m souboru.




~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			       SHRNUT� LEKCE 4


  1. Ctrl-g  vyp�e tvou pozici v souboru a status souboru.
     Shift-G  t� p�em�st� na konec souboru.  ��slo n�sledovan�
     Shift-G  t� p�esune na dan� ��slo ��dku.

  2. Naps�n�  /  n�sledovan� �et�zcem vyhled� �et�zec sm�rem DOP�EDU.
     Naps�n�  ?  n�sledovan� �et�zcem vyhled� �et�zec sm�rem DOZADU.
     Naps�n�  n  po vyhled�v�n� najde n�sleduj�c� v�skyt �et�zce ve stejn�m
     sm�ru, Shift-N ve sm�ru opa�n�m.

  3. Stisknut�  %  kdy� je kurzor na (,),[,],{, nebo } najde odpov�daj�c�
     p�rovou z�vorku.

  4. Pro nahrazen� nov�ho za prvn� star� v ��dku napi�     :s/star�/nov�
     Pro nahrazen� nov�ho za v�echny star� v ��dku napi�   :s/star�/nov�/g
     Pro nahrazen� �et�zc� mezi dv�mi ��dkami # napi�      :#,#s/star�/nov�/g
     Pro nahrazen� v�ech v�skyt� v souboru napi�	   :%s/star�/nov�/g
     Pro potvrzen� ka�d�ho nahrazen� p�idej 'c'		   :%s/star�/nov�/gc


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		    Lekce 5.1: JAK VYKONAT VN�J�� P��KAZ


   ** Napi�  :!  n�sledovan� vn�j��m p��kazem pro spu�t�n� p��kazu. **

  1. Napi� obvykl� p��kaz  :  , kter� um�st� kurzor na spodek obrazovky
     To umo�n� napsat p��kaz.

  2. Nyn� stiskni  !  (vyk�i�n�k). To umo�n� vykonat jak�koliv vn�j��
     p��kaz z p��kazov�ho ��dku.

  3. Nap��klad napi�  ls  za ! a stiskni <ENTER>.  Tento p��kaz zobraz�
     obsah tv�ho adres��e jako v p��kazov�m ��dku.
     Vyzkou�ej  :!dir  pokud ls nefunguje.

Pozn�mka:  Takto je mo�n� vykonat jak�koliv p��kaz.

Pozn�mka:  V�echny p��kazy  :  mus� b�t dokon�en� stisknut�m <ENTER>




~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lekce 5.2: V�CE O UKL�D�N� SOUBOR�


	    ** Pro ulo�en� zm�n v souboru napi�  :w SOUBOR. **

  1. Napi�  :!dir  nebo  :!ls  pro v�pis aktu�ln�ho adres��e.
     U� v�, �e za t�mto mus� stisknout <ENTER>.

  2. Vyber si n�zev souboru, kter� je�t� neexistuje, nap��klad TEST.

  3. Nyn� napi�:  :w TEST  (kde TEST je vybran� n�zev souboru.)

  4. To ulo�� cel� soubor  (V�uka Vimu)  pod n�zvem TEST.
     Pro ov��en� napi� znovu :!dir  , ��m� zobraz� obsah adres��e.

Pozn�mka: Jakmile ukon�� Vim a znovu ho spust� s n�zvem souboru TEST,
          soubor bude p�esn� kopie v�uky, kdy� si ji ukl�dal.

  5. Nyn� odstra� soubor naps�n�m (MS-DOS):    :!del TEST
			     nebo (Unix):      :!rm TEST


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lekce 5.3: V�B�ROV� P��KAZ ULO�EN�


	    ** Pro ulo�en� ��sti souboru napi�  :#,# w SOUBOR **

  1. Je�t� jednou napi�  :!dir  nebo  :!ls  pro v�pis aktu�ln�ho adres��e
     a vyber vhodn� n�zev souboru jako nap�. TEST.

  2. P�esu� kurzor na vrch t�to str�nky a stiskni  Ctrl-g  pro zobrazen�
     ��sla ��dku.  ZAPAMATUJ SI TOTO ��SLO!

  3. Nyn� se p�esu� na spodek t�to str�nky a op�t stiskni Ctrl-g.
     ZAPAMATUJ SI I ��SLO TOHOTO ��DKU!

  4. Pro ulo�en� POUZE ��sti souboru, napi�  :#,# w TEST  kde #,# jsou
     ��sla dvou zapamatovan�ch ��dk� (vrch, spodek) a TEST je n�zev souboru.

  5. Znova se ujisti, �e tam ten soubor je pomoc�  :!dir  ale NEODSTRA�UJ ho.




~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		        Lekce 5.4: SLU�OV�N� SOUBOR�


      	   ** K vlo�en� obsahu souboru napi�  :r N�ZEV_SOUBORU **

  1. Napi�  :!dir  pro uji�t�n�, �e soubor TEST st�le existuje.

  2. P�esu� kurzor na vrch t�to str�nky.

POZN�MKA: Po vykon�n� kroku 3 uvid� lekci 5.3.	Potom se op�t p�esu� dol�
          na tuto lekci.

  3. Nyn� vlo� soubor TEST pou�it�m p��kazu  :r TEST  kde TEST je n�zev
     souboru.

POZN�MKA: Soubor, kter� vkl�d� se vlo�� od m�sta, kde se nach�z� kurzor.

  4. Pro potvrzen� vlo�en� souboru, p�esu� kurzor zp�t a v�imni si, �e te�
     m� dv� kopie lekce 5.3, origin�l a souborovou verzi.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			       SHRNUT� LEKCE 5


  1.  :!p��kaz  vykon� vn�j�� p��kaz.

      N�kter� u�ite�n� p��klady jsou:
	 (MS-DOS)	  (Unix)
	  :!dir		   :!ls		   -  zobraz� obsah souboru.
	  :!del SOUBOR     :!rm SOUBOR     -  odstran� SOUBOR.

  2.  :w SOUBOR  ulo�� aktu�ln� text jako SOUBOR na disk.

  3.  :#,#w SOUBOR  ulo�� ��dky od # do # do SOUBORU.

  4.  :r SOUBOR  vybere z disku SOUBOR a vlo�� ho do editovan�ho souboru
      za pozici kurzoru.






~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			  Lekce 6.1: P��KAZ OTEV��T


  ** Napi�  o  pro vlo�en� ��dku pod kurzor a p�epnut� do Vkl�dac�ho m�du. **

  1. P�em�sti kurzor n�e na ��dek ozna�en� --->.

  2. Napi�  o (mal�) pro vlo�en� ��dku POD kurzor a p�epnut� do
     Vkl�dac�ho m�du.

  3. Nyn� zkop�ruj ��dek ozna�en� ---> a stiskni <ESC> pro ukon�en�
     Vkl�dac�ho m�du.
  
---> Po stisknut�  o  se kurzor p�em�st� na vlo�en� ��dek do Vkl�dac�ho
     m�du.

  4. Pro otev�en� ��dku NAD kurzorem jednodu�e napi� velk�  O  , m�sto
     mal�ho o. Vyzkou�ej si to na n�sleduj�c�m ��dku.
Vlo� ��dek nad t�mto naps�n�m Shift-O po um�st�n� kurzoru na tento ��dek.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			  Lekce 6.2: P��KAZ P�IDAT


	     ** Stiskni  a  pro vlo�en� textu ZA kurzor. **

  1. P�esu� kurzor na n�e na konec ��dky ozna�en� --->
     stisknut�m $ v Norm�ln�m m�du.

  2. Stiskni  a  (mal�) pro p�id�n� textu ZA znak, kter� je pod kurzorem.
     (Velk�  A  p�id� na konec ��dku.)

Pozn�mka: T�mto se vyhne� stisknut�  i  , posledn�ho znaku, textu na vlo�en�,
          <ESC>, kurzor doprava, a nakonec  x  na p�id�v�n� na konec ��dku!

  3. Nyn� dokon�� prvn� ��dek. V�imni si, �e p�id�v�n� je vlastn� stejn� jako
     Vkl�dac� m�d, krom� m�sta, kam se text vkl�d�.

---> Tento ��dek ti umo��uje nacvi�it
---> Tento ��dek ti umo��uje nacvi�it p�id�v�n� textu na konec ��dky.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		      Lekce 6.3: JIN� ZP�SOB NAHRAZOV�N�


         ** Napi� velk�  R  pro nahrazen� v�c ne� jednoho znaku. **

  1. P�esu� kurzor na prvn� ��dek ozna�en� --->.

  2. Um�sti kurzor na za��tek prvn�ho slova, kter� je odli�n� od druh�ho
     ��dku ozna�en�ho ---> (slovo 'posledn�').

  3. Nyn� stiskni  R  a nahra� zbytek textu na prvn�m ��dku p�eps�n�m
     star�ho textu tak, aby byl prvn� ��dek stejn� jako ten druh�.

---> Pro upraven� prvn�ho ��dku do tvaru toho posledn� na stran� pou�ij kl.
---> Pro upraven� prvn�ho ��dku do tvaru toho druh�ho, napi� R a nov� text.

  4. V�imni si, �e jakmile stiskne� <ESC> v�echen nezm�n�n� text z�st�v�.





~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		         Lekce 6.4: NASTAVEN� MO�NOST�

  ** Nastav mo�nost, �e vyhled�v�n� anebo nahrazov�n� nedb� velikosti p�smen **

  1. Vyhledej �et�zec 'ignore' naps�n�m:
     /ignore
     Zopakuj n�kolikr�t stisknut� kl�vesy n.

  2. Nastav mo�nost 'ic' (Ignore case) naps�n�m p��kazu:
     :set ic

  3. Nyn� znovu vyhledej 'ignore' stisknut�m: n
     N�kolikr�t hled�n� zopakuj stisknut�m kl�vesy n.

  4. Nastav mo�nosti 'hlsearch' a 'incsearch':
     :set hls is

  5. Nyn� znovu vykonej vyhled�vac� p��kaz a sleduj, co se stane:
     /ignore

  6. Pro vypnut� zv�raz�ov�n� v�sledk� napi�:
     :nohlsearch
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			       SHRHNUT� LEKCE 6


  1. Stisknut�  o  otev�e nov� ��dek POD kurzorem a um�st� kurzor na vlo�en�
     ��dek do Vkl�dac�ho m�du.
     Naps�n� velk�ho  O  otev�e ��dek NAD ��dkem, na kter�m je kurzor.

  2. Stiskni  a  pro vlo�en� textu ZA znak na pozici kurzoru.
     Naps�n� velk�ho  A  automaticky p�id� text na konec ��dku.

  3. Stisknut� velk�ho  R  p�epne do Nahrazovac�ho m�du, dokud
     nestiskne� <ESC> pro jeho ukon�en�.

  4. Naps�n� ":set xxx" nastav� mo�nosti "xxx".








~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		      LEKCE 7: P��KAZY ON-LINE N�POV�DY


		   ** Pou��vej on-line syst�m n�pov�dy **

  Vim m� obs�hl� on-line syst�m n�pov�dy. Pro za��tek vyzkou�ej jeden z
  n�sleduj�c�ch:
	- stiskni kl�vesu <HELP> (pokud ji m�)
	- stiskni kl�vesu <F1>  (pokud ji m�)
	- napi�  :help <ENTER>

  Napi�  :q <ENTER>  pro uzav�en� okna n�pov�dy.

  M��e� naj�t n�pov�du k jak�mukoliv t�matu p�id�n�m argumentu k
  p��kazu ":help". Zkus tyto (nezapome� stisknout <ENTER>):

	:help w
	:help c_<T
	:help insert-index
	:help user-manual


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		  LEKCE 8: VYTVO�EN� INICIALIZA�N�HO SKRIPTU

		        ** Zapni funkce editoru Vim **

  Vim m� daleko v�ce funkc� ne� Vi, ale v�t�ina z nich je vypnuta ve v�choz�m
  nastaven�. Pro zapnut� n�kter�ch vytvo� soubor "vimrc".

  1. Za�ni upravovat soubor "vimrc". Toto z�vis� na pou�it�m syst�mu:
	:edit ~/.vimrc			pro Unix
	:edit $VIM/_vimrc		pro MS-Windows

  2. Nyn� �ti uk�zkov� "vimrc" soubor:

	:read $VIMRUNTIME/vimrc_example.vim

  3. Ulo� soubor pomoc�:

	:write

  Po p��t�m startu Vim se zapne zv�raz�ov�n� syntaxe.
  Do souboru "vimrc" m��e� p�idat v�echny svoje up�ednost�ovan� nastaven�.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  Toto ukon�uje v�uku Vim, kter� byla my�len� jako stru�n� p�ehled
  editoru Vim, tak akor�t posta�uj�c� pro lehk� a obstojn� pou��v�n� editoru.
  Tato v�uka m� daleko od �plnosti, proto�e Vim obsahuje podstatn� v�ce
  p��kaz�. D�le si p�e�ti u�ivatelsk� manu�l: ":help user-manual".

  Pro dal�� studium je doporu�en� kniha:
	Vim - Vi Improved - od Steve Oualline
	Nakladatel: New Riders
  Prvn� kniha ur�en� pro Vim. Obzvl�t� vhodn� pro za��te�n�ky.
  Obsahuje mno�stv� p��klad� a obr�zk�.
  viz http://iccf-holland.org/click5.html

  Tato kniha je star�� a v�ce v�novan� Vi ne� Vim, ale tak� doporu�en�:
	Learning the Vi Editor - od Linda Lamb
	Nakladatel: O'Reilly & Associates Inc.
  Je to dobr� kniha pro z�sk�n� v�domost� t�m�� o v�em, co m��ete s Vi d�lat.
  �est� vyd�n� obsahuje t� informace o Vim.

  Tato v�uka byla napsan� autory Michael C. Pierce a Robert K. Ware,
  Colorado School of Mines s pou�it�m my�lenek od: Charles Smith,
  Colorado State University.  E-mail: bware@mines.colorado.edu.

  Upravil pro Vim: Bram Moolenaar.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  P�eklad do �e�tiny: Lubo� Turek
  E-Mail: lubos.turek@gmail.com
  2007 Feb 28 
