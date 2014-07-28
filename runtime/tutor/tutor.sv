===============================================================================
= V � l k o m m e n  t i l l  h a n d l e d n i n g e n  i  V i m  - Ver. 1.5 =
===============================================================================

     Vim �r en v�ldigt kraftfull redigerare som har m�nga kommandon, alltf�r
     m�nga att f�rklara i en handledning som denna. Den h�r handledningen �r
     gjord f�r att f�rklara tillr�ckligt m�nga kommandon s� att du enkelt ska
     kunna anv�nda Vim som en redigerare f�r alla �ndam�l.

     Den ber�knade tiden f�r att slutf�ra denna handledning �r 25-30 minuter,
     beroende p� hur mycket tid som l�ggs ned p� experimentering.

     Kommandona i lektionerna kommer att modifiera texten. G�r en kopia av den
     h�r filen att �va p� (om du startade "vimtutor �r det h�r redan en kopia).

     Det �r viktigt att komma ih�g att den h�r handledningen �r konstruerad
     att l�ra vid anv�ndning. Det betyder att du m�ste k�ra kommandona f�r att
     l�ra dig dem ordentligt. Om du bara l�ser texten s� kommer du att gl�mma
     kommandona!

     F�rs�kra dig nu om att din Caps-Lock tangent INTE �r aktiv och tryck p�
     j-tangenten tillr�ckligt m�nga g�nger f�r att f�rflytta mark�ren s� att
     Lektion 1.1 fyller sk�rmen helt.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			Lektion 1.1: FLYTTA MARK�REN


   ** F�r att flytta mark�ren, tryck p� tangenterna h,j,k,l som indikerat. **
	     ^
	     k		Tips:
       < h	 l >	h-tangenten �r till v�nster och flyttar till v�nster.
	     j		l-tangenten �r till h�ger och flyttar till h�ger.
	     v		j-tangenten ser ut som en pil ned.
  1. Flytta runt mark�ren p� sk�rmen tills du k�nner dig bekv�m.

  2. H�ll ned tangenten pil ned (j) tills att den repeterar.
---> Nu vet du hur du tar dig till n�sta lektion.

  3. Flytta till Lektion 1.2, med hj�lp av ned tangenten.

Notera: Om du �r os�ker p� n�gonting du skrev, tryck <ESC> f�r att placera dig
	dig i Normal-l�ge. Skriv sedan om kommandot.

Notera: Piltangenterna borde ocks� fungera.  Men om du anv�nder hjkl s� kommer
	du att kunna flytta omkring mycket snabbare, n�r du v�l vant dig vid
	det.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lektion 1.2: STARTA OCH AVSLUTA VIM


  !! NOTERA: Innan du utf�r n�gon av punkterna nedan, l�s hela lektionen!!

  1. Tryck <ESC>-tangenten (f�r att se till att du �r i Normal-l�ge).

  2. Skriv:			:q! <ENTER>.

---> Detta avslutar redigeraren UTAN att spara n�gra �ndringar du gjort.
     Om du vill spara �ndringarna och avsluta skriv:
				:wq  <ENTER>

  3. N�r du ser skal-prompten, skriv kommandot som tog dig in i den h�r
     handledningen.  Det kan vara:	vimtutor <ENTER>
     Normalt vill du anv�nda:		vim tutor <ENTER>

---> 'vim' betyder �ppna redigeraren vim, 'tutor' �r filen du vill redigera.

  4. Om du har memorerat dessa steg och k�nner dig sj�lvs�ker, k�r d� stegen
     1 till 3 f�r att avsluta och starta om redigeraren. Flytta sedan ned
     mark�ren till Lektion 1.3.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lektion 1.3: TEXT REDIGERING - BORTTAGNING


** N�r du �r i Normal-l�ge tryck  x  f�r att ta bort tecknet under mark�ren. **

  1. Flytta mark�ren till raden nedan med markeringen --->.

  2. F�r att r�tta felen, flytta mark�ren tills den st�r p� tecknet som ska
     tas bort. fix the errors, move the cursor until it is on top of the

  3. Tryck p�	x-tangenten f�r att ta bort det felaktiga tecknet.

  4. Upprepa steg 2 till 4 tills meningen �r korrekt.

---> Kkon hoppadee �vverr m��nen.

  5. Nu n�r raden �r korrekt, g� till Lektion 1.4.

NOTERA: N�r du g�r igenom den h�r handledningen, f�rs�k inte att memorera, l�r
	genom anv�ndning.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lektion 1.4: TEXT REDIGERING - INFOGNING


	 ** N�r du �r i Normal-l�ge tryck  i  f�r att infoga text. **

  1. Flytta mark�ren till den f�rsta raden nedan med markeringen --->.

  2. F�r att g�ra den f�rsta raden likadan som den andra, flytta mark�ren till
     det f�rsta tecknet EFTER d�r text ska infogas.

  3. Tryck  i  och skriv in det som saknas.

  4. N�r du r�ttat ett fel tryck <ESC> f�r att �terg� till Normal-l�ge.
     Upprepa steg 2 till 4 f�r att r�tta meningen.

---> Det sakns h�r .
---> Det saknas lite text fr�n den h�r raden.

  5. N�r du k�nner dig bekv�m med att infoga text, g� till sammanfattningen
     nedan.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			       LEKTION 1 SAMMANFATTNING


  1. Mark�ren flyttas genom att anv�nda piltangenterna eller hjkl-tangenterna.
	 h (v�nster)	j (ned)       k (upp)	    l (h�ger)

  2. F�r att starta Vim (fr�n %-prompten) skriv:  vim FILNAMN <ENTER>

  3. F�r att avsluta Vim skriv:  <ESC>  :q!  <ENTER>  f�r att kasta �ndringar.
		   ELLER skriv:  <ESC>	:wq  <ENTER>  f�r att spara �ndringar.

  4. F�r att ta bort tecknet under mark�ren i Normal-l�ge skriv:  x

  5. F�r att infoga text vid mark�ren i Normal-l�ge skriv:
	 i     skriv in text	<ESC>

NOTERA: Genom att trycka <ESC> kommer du att placeras i Normal-l�ge eller
	avbryta ett delvis f�rdigskrivet kommando.

Forts�tt nu med Lektion 2.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			Lektion 2.1: BORTTAGNINGSKOMMANDON


	    ** Skriv  dw  f�r att radera till slutet av ett ord. **

  1. Tryck  <ESC>  f�r att f�rs�kra dig om att du �r i Normal-l�ge.

  2. Flytta mark�ren till raden nedan markerad --->.

  3. Flytta mark�ren till b�rjan av ett ord som m�ste raderas.

  4. Skriv   dw	 f�r att radera ordet.

  NOTERA: Bokst�verna dw kommer att synas p� den sista raden p� sk�rmen n�r
	du skriver dem. Om du skrev n�got fel, tryck  <ESC>  och b�rja om.

---> Det �r ett n�gra ord roliga att som inte h�r hemma i den h�r meningen.

  5. Upprepa stegen 3 och 4 tills meningen �r korrekt och g� till Lektion 2.2.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		      Lektion 2.2: FLER BORTTAGNINGSKOMMANDON


	   ** Skriv  d$	f�r att radera till slutet p� raden. **

  1. Tryck  <ESC>  f�r att f�rs�kra dig om att du �r i Normal-l�ge.

  2. Flytta mark�ren till raden nedan markerad --->.

  3. Flytta mark�ren till slutet p� den r�tta raden (EFTER den f�rsta . ).

  4. Skriv    d$    f�r att radera till slutet p� raden.

---> N�gon skrev slutet p� den h�r raden tv� g�nger. den h�r raden tv� g�nger.


  5. G� vidare till Lektion 2.3 f�r att f�rst� vad det �r som h�nder.





~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lesson 2.3: KOMMANDON OCH OBJEKT


  Syntaxen f�r  d  raderingskommandot �r f�ljande:

	 [nummer]   d	objekt	    ELLER	     d	 [nummer]   objekt
  Var:
    nummer - �r antalet upprepningar av kommandot (valfritt, standard=1).
    d - �r kommandot f�r att radera.
    objekt - �r vad kommandot kommer att operera p� (listade nedan).

  En kort lista �ver objekt:
    w - fr�n mark�ren till slutet av ordet, inklusive blanksteget.
    e - fr�n mark�ren till slutet av ordet, EJ inklusive blanksteget.
    $ - fr�n mark�ren till slutet p� raden.

NOTERA:  F�r den �ventyrslystne, genom att bara trycka p� objektet i
	 Normal-l�ge (utan kommando) s� kommer mark�ren att flyttas som
	 angivet i objektlistan.




~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		Lektion 2.4: ETT UNDANTAG TILL 'KOMMANDO-OBJEKT'


	       ** Skriv	 dd   f�r att radera hela raden. **

  P� grund av hur vanligt det �r att ta bort hela rader, valde upphovsmannen
  till Vi att det skulle vara enklare att bara trycka d tv� g�nger i rad f�r
  att ta bort en rad.

  1. Flytta mark�ren till den andra raden i frasen nedan.
  2. Skriv  dd  f�r att radera raden.
  3. Flytta nu till den fj�rde raden.
  4. Skriv   2dd   (kom ih�g:  nummer-kommando-objekt) f�r att radera de tv�
     raderna.

      1)  Roses are red,
      2)  Mud is fun,
      3)  Violets are blue,
      4)  I have a car,
      5)  Clocks tell time,
      6)  Sugar is sweet
      7)  And so are you.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			 Lektion 2.5: �NGRA-KOMMANDOT


** Skriv  u f�r att �ngra det senaste kommandona,  U f�r att fixa en hel rad. **

  1. Flytta mark�ren till slutet av raden nedan markerad ---> och placera den
     p� det f�rsta felet.
  2. Skriv  x  f�r att radera den f�rsta felaktiga tecknet.
  3. Skriv nu  u  f�r att �ngra det senaste k�rda kommandot.
  4. R�tta den h�r g�ngen alla felen p� raden med  x-kommandot.
  5. Skriv nu  U  f�r att �terst�lla raden till dess ursprungliga utseende.
  6. Skriv nu  u  n�gra g�nger f�r att �ngra  U  och tidigare kommandon.
  7. Tryck nu CTRL-R (h�ll inne CTRL samtidigt som du trycker R) n�gra g�nger
     f�r att upprepa kommandona (�ngra �ngringarna).

---> Fiixa felen pp� deen h��r meningen och �terskapa dem med �ngra.

  8. Det h�r �r v�ldigt anv�ndbara kommandon.  G� nu vidare till
     Lektion 2 Sammanfattning.




~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			       LEKTION 2 SAMMANFATTNING


  1. F�r att radera fr�n mark�ren till slutet av ett ord skriv:    dw

  2. F�r att radera fr�n mark�ren till slutet av en rad skriv:    d$

  3. F�r att radera en hel rad skriv:    dd

  4. Syntaxen f�r ett kommando i Normal-l�ge �r:

       [nummer]   kommando   objekt   ELLER   kommando   [nummer]   objekt
     d�r:
       nummer - �r hur m�nga g�nger kommandot kommandot ska repeteras
       kommando - �r vad som ska g�ras, t.ex.  d  f�r att radera
       objekt - �r vad kommandot ska operera p�, som t.ex.  w (ord),
		$ (till slutet av raden), etc.

  5. F�r att �ngra tidigare kommandon, skriv:  u (litet u)
     F�r att �ngra alla tidigare �ndringar p� en rad skriv:  U (stort U)
     F�r att �ngra �ngringar tryck:  CTRL-R

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			 Lektion 3.1: KLISTRA IN-KOMMANDOT


   ** Skriv  p  f�r att klistra in den senaste raderingen efter mark�ren. **

  1. Flytta mark�ren till den f�rsta raden i listan nedan.

  2. Skriv  dd  f�r att radera raden och lagra den i Vims buffert.

  3. Flytta mark�ren till raden OVANF�R d�r den raderade raden borde vara.

  4. N�r du �r i Normal-l�ge, skriv    p	 f�r att byta ut raden.

  5. Repetera stegen 2 till 4 f�r att klistra in alla rader i r�tt ordning.

     d) Kan du l�ra dig ocks�?
     b) Violetter �r bl�,
     c) Intelligens f�s genom l�rdom,
     a) Rosor �r r�da,



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		       Lesson 3.2: ERS�TT-KOMMANDOT


  ** Skriv  r  och ett tecken f�r att ers�tta tecknet under mark�ren. **

  1. Flytta mark�ren till den f�rsta raden nedan markerad --->.

  2. Flytta mark�ren s� att den st�r p� det f�rsta felet.

  3. Skriv   r	och sedan det tecken som borde ers�tta felet.

  4. Repetera steg 2 och 3 tills den f�rsta raden �r korrekt.

--->  N�r drn h�r ruden skrevs, trickte n�gon p� fil knappar!
--->  N�r den h�r raden skrevs, tryckte n�gon p� fel knappar!

  5. G� nu vidare till Lektion 3.2.

NOTERA: Kom ih�g att du skall l�ra dig genom anv�ndning, inte genom memorering.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			Lektion 3.3: �NDRA-KOMMANDOT


	   ** F�r att �ndra en del eller ett helt ord, skriv  cw . **

  1. Flytta mark�ren till den f�rsta redan nedan markerad --->.

  2. Placera mark�ren p� d i rdrtn.

  3. Skriv  cw  och det r�tta ordet (i det h�r fallet, skriv "aden".)

  4. Tryck <ESC> och flytta mark�ren till n�sta fel (det f�rsta tecknet som
     ska �ndras.)

  5. Repetera steg 3 och 4 tills den f�rsta raden �r likadan som den andra.

---> Den h�r rdrtn har n�gra otf som brhotrt �ndras mrf �ndra-komjendit.
---> Den h�r raden har n�gra ord som beh�ver �ndras med �ndra-kommandot.

Notera att  cw  inte bara �ndrar ordet, utan �ven placerar dig i infogningsl�ge.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		       Lektion 3.4: FLER �NDRINGAR MED c


     ** �ndra-kommandot anv�nds p� samma objekt som radera. **

  1. �ndra-kommandot fungerar p� samma s�tt som radera. Syntaxen �r:

       [nummer]   c   objekt	   ELLER	    c	[nummer]   objekt

  2. Objekten �r ocks� de samma, som t.ex.   w (ord), $ (slutet av raden), etc.

  3. Flytta till den f�rsta raden nedan markerad -->.

  4. Flytta mark�ren till det f�rsta felet.

  5. Skriv  c$  f�r att g�ra resten av raden likadan som den andra och tryck
     <ESC>.

---> Slutet p� den h�r raden beh�ver hj�lp med att f� den att likna den andra.
---> Slutet p� den h�r raden beh�ver r�ttas till med  c$-kommandot.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			       LEKTION 3 SAMMANFATTNING


  1. F�r att ers�tta text som redan har blivit raderad, skriv   p .
     Detta klistrar in den raderade texten EFTER mark�ren (om en rad raderades
     kommer den att hamna p� raden under mark�ren.

  2. F�r att ers�tta tecknet under mark�ren, skriv   r   och sedan tecknet som
     kommer att ers�tta orginalet.

  3. �ndra-kommandot l�ter dig �ndra det angivna objektet fr�n mark�ren till
     slutet p� objektet. eg. Skriv  cw  f�r att �ndra fr�n mark�ren till slutet
     p� ordet, c$	f�r att �ndra till slutet p� en rad.

  4. Syntaxen f�r �ndra-kommandot �r:

	 [nummer]   c	objekt	      ELLER	c   [nummer]   objekt

G� nu till n�sta lektion.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lektion 4.1: POSITION OCH FILSTATUS


  ** Tryck CTRL-g f�r att visa din position i filen och filstatusen.
     Tryck SHIFT-G f�r att flytta till en rad i filen. **

  Notera: L�sa hela den lektion innan du utf�r n�got av stegen!!

  1. H�ll ned Ctrl-tangenten och tryck  g . En statusrad med filnamn och raden
     du befinner dig p� kommer att synas. Kom ih�g radnummret till Steg 3.

  2. Tryck shift-G f�r att flytta mark�ren till slutet p� filen.

  3. Skriv in nummret p� raden du var p� och tryck sedan shift-G. Detta kommer
     att ta dig tillbaka till raden du var p� n�r du f�rst tryckte Ctrl-g.
     (N�r du skriver in nummren, kommer de INTE att visas p� sk�rmen.)

  4. Om du k�nner dig s�ker p� det h�r, utf�r steg 1 till 3.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			Lektion 4.2: S�K-KOMMANDOT


     ** Skriv  /  f�ljt av en fras f�r att s�ka efter frasen. **

  1. I Normal-l�ge skriv /-tecknet. Notera att det och mark�ren blir synlig
     l�ngst ned p� sk�rmen precis som med :-kommandot.

  2. Skriv nu "feeel" <ENTER>. Det h�r �r ordet du vill s�ka efter.

  3. F�r att s�ka efter samma fras igen, tryck helt enkelt  n .
     F�r att s�ka efter samma fras igen i motsatt riktning, tryck  Shift-N .

  4. Om du vill s�ka efter en fras bak�t i filen, anv�nd kommandot  ?  ist�llet
     f�r /.

---> "feeel" �r inte r�tt s�tt att stava fel: feeel �r ett fel.

Notera: N�r s�kningen n�r slutet p� filen kommer den att forts�tta vid b�rjan.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		   Lektion 4.3: S�KNING EFTER MATCHANDE PARENTESER


	      ** Skriv  %  f�r att hitta en matchande ),], or } . **

  1. Placera mark�ren p� n�gon av (, [, or { p� raden nedan markerad --->.

  2. Skriv nu %-tecknet.

  3. Mark�ren borde vara p� den matchande parentesen eller hakparentesen.

  4. Skriv  %  f�r att flytta mark�ren tillbaka till den f�rsta hakparentesen
     (med matchning).

---> Det ( h�r �r en testrad med (, [ ] och { } i den. ))

Notera: Det h�r �r v�ldigt anv�ndbart vid avlusning av ett program med icke
	matchande parenteser!






~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		      Lektion 4.4: ETT S�TT ATT �NDRA FEL


	** Skriv  :s/gammalt/nytt/g  f�r att ers�tta "gammalt" med "nytt". **

  1. Flytta mark�ren till raden nedan markerad --->.

  2. Skriv  :s/denn/den <ENTER> . Notera att det h�r kommandot bara �ndrar den
     f�rsta f�rekomsten p� raden.

  3. Skriv nu	 :s/denn/den/g	   vilket betyder ers�tt globalt p� raden.
     Det �ndrar alla f�rekomster p� raden.

---> denn b�sta tiden att se blommor blomma �r denn p� v�ren.

  4. F�r att �ndra alla f�rekomster av en teckenstr�ng mellan tv� rader,
     skriv  :#,#s/gammalt/nytt/g    d�r #,# �r de tv� radernas radnummer.
     Skriv  :%s/gammtl/nytt/g    f�r att �ndra varje f�rekomst i hela filen.




~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			       LEKTION 4 SAMMANFATTNING


  1. Ctrl-g  visar din position i filen och filstatusen.
     Shift-G  flyttar till slutet av filen. Ett radnummer f�ljt  Shift-G
     flyttar till det radnummret.

  2. Skriver man  /	f�ljt av en fras s�ks det FRAMM�T efter frasen.
     Skriver man  ?	f�ljt av en fras s�ks det BAK�T efter frasen.
     Efter en s�kning skriv  n  f�r att hitta n�sta f�rekomst i samma riktning
     eller  Shift-N  f�r att s�ka i den motsatta riktningen.

  3. Skriver man  %	n�r mark�ren �r p� ett  (,),[,],{, eller }  hittas dess
     matchande par.

  4. F�r att ers�tta den f�rsta gammalt med nytt p� en rad skriv  :s/gammlt/nytt
     F�r att ers�tta alla gammlt med nytt p� en rad skriv  :s/gammlt/nytt/g
     F�r att ers�tta fraser mellan rad # och rad # skriv  :#,#s/gammlt/nytt/g
     F�r att ers�tta alla f�rekomster i filen skriv  :%s/gammlt/nytt/g
     F�r att bekr�fta varje g�ng l�gg till "c"  :%s/gammlt/nytt/gc


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		Lektion 5.1: HUR MAN K�R ETT EXTERNT KOMMANDO


   ** Skriv  :!	f�ljt av ett externt kommando f�r att k�ra det kommandot. **

  1. Skriv det v�lbekanta kommandot	:  f�r att placera mark�ren l�ngst ned
     p� sk�rmen p� sk�rmen. Detta l�ter dig skriva in ett kommando.

  2. Skriv nu  !  (utropstecken).  Detta l�ter dig k�ra ett godtyckligt externt
     skalkommando.

  3. Som ett exempel skriv   ls   efter ! och tryck sedan <ENTER>. Detta kommer
     att visa dig en listning av din katalog, precis som om du k�rt det vid
     skalprompten. Anv�nd  :!dir  om ls inte fungerar.

Notera:  Det �r m�jligt att k�ra vilket externt kommando som helst p� det h�r
	 s�ttet.

Notera:  Alla  :-kommandon m�ste avslutas med att trycka p� <ENTER>




~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		      Lektion 5.2: MER OM ATT SPARA FILER


     ** F�r att spara �ndringar gjorda i en fil, skriv  :w FILNAMN. **

  1. Skriv  :!dir  eller  :!ls  f�r att f� en listning av din katalog.
     Du vet redan att du m�ste trycka <ENTER> efter det h�r.

  2. V�lj ett filnamn som inte redan existerar, som t.ex. TEST.

  3. Skriv nu:	 :w TEST   (d�r TEST �r filnamnet du valt.)

  4. Det h�r sparar hela filen	(Vim handledningen)  under namnet TEST.
     F�r att verifiera detta, skriv    :!dir   igen f�r att se din katalog

Notera: Om du skulle avsluta Vim och sedan �ppna igen med filnamnet TEST s�
	skulle filen vara en exakt kopia av handledningen n�r du sparade den.

  5. Ta nu bort filen genom att skriva (MS-DOS):  :!del TEST
				   eller (Unix):  :!rm TEST


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		    Lektion 5.3: ETT SELEKTIVT SPARA-KOMMANDO


	** F�r att spara en del av en fil, skriv   :#,# w FILNAMN **

  1. �nnu en g�ng, skriv  :!dir  eller  :!ls  f�r att f� en listning av din
     katalog och v�lj ett passande filnamn som t.ex. TEST.

  2. Flytta mark�ren h�gst upp p� den h�r sidan och tryck  Ctrl-g  f�r att f�
     reda p� radnumret p� den raden. KOM IH�G DET NUMMRET!

  3. Flytta nu l�ngst ned p� sidan och skriv  Ctrl-g igen.
     KOM IH�G DET RADNUMMRET OCKS�!

  4. F�r att BARA spara en sektion till en fil, skriv   :#,# w TEST
     d�r #,# �r de tv� nummren du kom ih�g (toppen, botten) och TEST �r
     ditt filnamn.

  5. �nnu en g�ng, kolla s� att filen �r d�r med  :!dir  men radera den INTE.




~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		   Lektion 5.4: TA EMOT OCH F�RENA FILER


       ** F�r att infoga inneh�llet av en fil, skriv   :r FILNAMN **

  1. Skriv   :!dir   f�r att f�rs�kra dig om att TEST-filen fr�n tidigare
     fortfarande �r kvar.

  2. Placera mark�ren h�gst upp p� den h�r sidan.

NOTERA:  Efter att du k�rt Steg 3 kommer du att se Lektion 5.3.
	 Flytta d� NED till den h�r lektionen igen.

  3. Ta nu emot din TEST-fil med kommandot   :r TEST   d�r TEST �r namnet p�
     filen.

NOTERA:  Filen du tar emot placeras d�r mark�ren �r placerad.

  4. F�r att verifiera att filen togs emot, g� tillbaka och notera att det nu
     finns tv� kopior av Lektion 5.3, orginalet och filversionen.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			       LEKTION 5 SAMMANFATTNING


  1.  :!kommando  k�r ett externt kommando.

      N�gra anv�ndbara exempel �r:
	 (MS-DOS)	  (Unix)
	  :!dir		   :!ls		  -  visar en kataloglistning.
	  :!del FILNAMN    :!rm FILNAMN   -  tar bort filen FILNAMN.

  2.  :w FILNAMN  sparar den aktuella Vim-filen med namnet FILNAMN.

  3.  :#,#w FILNAMN  sparar raderna # till #  i filen FILNAMN.

  4.  :r FILNAMN  tar emot filen FILNAMN och infogar den i den aktuella filen
      efter mark�ren.






~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			 Lektion 6.1: �PPNA-KOMMANDOT


 ** Skriv  o  f�r att �ppna en rad under mark�ren och placera dig i
    Infoga-l�ge. **

  1. Flytta mark�ren till raden nedan markerad --->.

  2. Skriv  o (litet o) f�r att �ppna upp en rad NEDANF�R mark�ren och placera
     dig i Infoga-mode.

  3. Kopiera nu raden markerad ---> och tryck <ESC> f�r att avsluta
     Infoga-l�get.

---> Efter du skrivit  o  placerad mark�ren p� en �ppen rad i Infoga-l�ge.

  4. F�r att �ppna upp en rad OVANF�R mark�ren, skriv ett stort  O , ist�llet
     f�r ett litet  o. Pr�va detta p� raden nedan.
�ppna upp en rad ovanf�r denna genom att trycka Shift-O n�r mark�ren st�r h�r.





~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			Lektion 6.2: L�GG TILL-KOMMANDOT


	     ** Skriv  a  f�r att infoga text EFTER mark�ren. **

  1. Flytta mark�ren till slutet av den f�rsta raden nedan markerad ---> genom
     att skriv  $	i Normal-l�ge.

  2. Skriv ett  a  (litet a) f�r att l�gga till text EFTER tecknet under
     mark�ren.  (Stort  A  l�gger till i slutet av raden.)

Notera: Detta undviker att beh�va skriva  i , det sista tecknet, texten att
	infoga, <ESC>, h�gerpil, och slutligen, x, bara f�r att l�gga till i
	slutet p� en rad!

  3. G�r nu f�rdigt den f�rsta raden. Notera ocks� att l�gga till �r likadant
      som Infoga-l�ge, enda skillnaden �r positionen d�r texten blir infogad.

---> H�r kan du tr�na
---> H�r kan du tr�na p� att l�gga till text i slutet p� en rad.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		    Lektion 6.3: EN ANNAN VERSION AV ERS�TT


      ** Skriv ett stort  R  f�r att ers�tta fler �n ett tecken. **

  1. Flytta mark�ren till den f�rsta raden nedan markerad --->.

  2. Placera mark�ren vid b�rjan av det f�rsta ordet som �r annorlunda j�mf�rt
     med den andra raden markerad ---> (ordet "sista").

  3. Skriv nu  R  och ers�tt resten av texten p� den f�rsta raden genom att
     skriva �ver den gamla texten s� att den f�rsta raden blir likadan som
     den andra.

---> F�r att f� den f�rsta raden lika som den sista, anv�nd tangenterna.
---> F�r att f� den f�rsta raden lika som den andra, skriv R och den nya texten.

  4. Notera att n�r du trycker <ESC> f�r att avsluta, s� blir eventuell
     of�r�ndrad text kvar.





~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			    Lektion 6.4: S�TT FLAGGOR

  ** S�tt en flagga s� att en s�kning eller ers�ttning ignorerar storlek **

  1. S�k efter "ignore" genom att skriva:
     /ignore
     Repetera flera g�nger genom att trycka p� n-tangenten

  2. S�tt 'ic' (Ignore Case) flaggan genom att skriva:
     :set ic

  3. S�k nu efter "ignore" igen genom att trycka: n
     Repeat search several more times by hitting the n key

  4. S�tt 'hlsearch' and 'incsearch' flaggorna:
     :set hls is

  5. Skriv nu in s�k-kommandot igen, och se vad som h�nder:
     /ignore

  6. F�r att ta bort framh�vningen av tr�ffar, skriv
     :nohlsearch
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			       LEKTION 6 SAMMANFATTNING


  1. Genom att skriva  o  �pnnas en rad NEDANF�R mark�ren och mark�ren placeras
     p� den �ppna raden i Infoga-l�ge.
     Genom att skriva ett stort  O  �ppnas raden OVANF�R raden som mark�ren �r
     p�.

  2. Skriv ett  a  f�r att infoga text EFTER tecknet som mark�ren st�r p�.
     Genom att skriva ett stort  A  l�ggs text automatiskt till i slutet p�
     raden.

  3. Genom att skriva ett stort  R  hamnar du i Ers�tt-l�ge till  <ESC>  trycks
     f�r att avsluta.

  4. Genom att skriva ":set xxx" s�tts flaggan "xxx"









~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		       LEKTION 7: ON-LINE HJ�LP-KOMMANDON


		      ** Anv�nd on-line hj�lpsystemet **

  Vim har ett omfattande on-line hj�lpsystem. F�r att komma ig�ng pr�va ett av
  dessa tre:
	- tryck <HELP> tangenten (om du har n�gon)
	- tryck <F1> tangenten (om du har n�gon)
	- skriv   :help <ENTER>

  Skriv   :q <ENTER>   f�r att str�nga hj�lpf�nstret.

  Du kan hitta hj�lp om n�stan allting, genom att ge ett argument till
  ":help" kommandot. Pr�va dessa (gl�m inte att trycka <ENTER>):

	:help w
	:help c_<T
	:help insert-index
	:help user-manual


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		       LEKTION 8: SKAPA ETT UPPSTARTSSKRIPT

			  ** Aktivera Vim- funktioner **

  Vim har m�nga fler funktioner �n Vi, men de flesta av dem �r inaktiverade som
  standard. F�r att b�rja anv�nda fler funktioner m�ste du skapa en "vimrc"-fil.

  1. B�rja redigera "vimrc"-filen, detta beror p� ditt system:
	:edit ~/.vimrc			f�r Unix
	:edit $VIM/_vimrc		f�r MS-Windows

  2. L�s nu texten i exempel "vimrc"-filen:

	:read $VIMRUNTIME/vimrc_example.vim

  3. Spara filen med:

	:write

  N�sta g�ng du startar Vim kommer den att anv�nda syntaxframh�vning.
  Du kan l�gga till alla inst�llningar du f�redrar till den h�r "vimrc"-filen.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  Detta avslutar handledningen i Vim. Den var avsedd att ge en kort �versikt av
  redigeraren Vim, bara tillr�ckligt f�r att du ska kunna anv�nda redigeraren
  relativt enkelt. Den �r l�ngt ifr�n komplett eftersom Vim har m�nga m�nga fler
  kommandon. L�s anv�ndarmanualen h�rn�st: ":help user-manual".

  F�r vidare l�sning rekommenderas den h�r boken:
	Vim - Vi Improved - av Steve Oualline
	F�rlag: New Riders
  Den f�rsta boken som �r endast behandlar Vim. Speciellt anv�ndbar f�r
  nyb�rjare. Det finns m�nga exempel och bilder.
  Se http://iccf-holland.org/click5.html

  Den h�r boken �r �ldre och behandlar mer Vi �n Vim, men rekommenderas ocks�:
	Learning the Vi Editor - av Linda Lamb
	F�rlag: O'Reilly & Associates Inc.
  Det �r en bra bok f�r att l�ra sig n�stan allt som du vill kunna g�ra med Vi.
  Den sj�tte upplagan inkluderar ocks� information om Vim.

  Den h�r handledningen �r skriven av Michael C. Pierce och Robert K. Ware,
  Colorado School of Mines med id�er fr�n Charles Smith,
  Colorado State University.  E-post: bware@mines.colorado.edu.

  Modifierad f�r Vim av Bram Moolenaar.
  �versatt av Johan Svedberg <johan@svedberg.com>

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
