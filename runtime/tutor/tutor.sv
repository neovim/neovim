===============================================================================
= V ä l k o m m e n  t i l l  h a n d l e d n i n g e n  i  V i m  - Ver. 1.5 =
===============================================================================

     Vim är en väldigt kraftfull redigerare som har många kommandon, alltför
     många att förklara i en handledning som denna. Den här handledningen är
     gjord för att förklara tillräckligt många kommandon så att du enkelt ska
     kunna använda Vim som en redigerare för alla ändamål.

     Den beräknade tiden för att slutföra denna handledning är 25-30 minuter,
     beroende på hur mycket tid som läggs ned på experimentering.

     Kommandona i lektionerna kommer att modifiera texten. Gör en kopia av den
     här filen att öva på (om du startade "vimtutor är det här redan en kopia).

     Det är viktigt att komma ihåg att den här handledningen är konstruerad
     att lära vid användning. Det betyder att du måste köra kommandona för att
     lära dig dem ordentligt. Om du bara läser texten så kommer du att glömma
     kommandona!

     Försäkra dig nu om att din Caps-Lock tangent INTE är aktiv och tryck på
     j-tangenten tillräckligt många gånger för att förflytta markören så att
     Lektion 1.1 fyller skärmen helt.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			Lektion 1.1: FLYTTA MARKÖREN


   ** För att flytta markören, tryck på tangenterna h,j,k,l som indikerat. **
	     ^
	     k		Tips:
       < h	 l >	h-tangenten är till vänster och flyttar till vänster.
	     j		l-tangenten är till höger och flyttar till höger.
	     v		j-tangenten ser ut som en pil ned.
  1. Flytta runt markören på skärmen tills du känner dig bekväm.

  2. Håll ned tangenten pil ned (j) tills att den repeterar.
---> Nu vet du hur du tar dig till nästa lektion.

  3. Flytta till Lektion 1.2, med hjälp av ned tangenten.

Notera: Om du är osäker på någonting du skrev, tryck <ESC> för att placera dig
	dig i Normal-läge. Skriv sedan om kommandot.

Notera: Piltangenterna borde också fungera.  Men om du använder hjkl så kommer
	du att kunna flytta omkring mycket snabbare, när du väl vant dig vid
	det.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lektion 1.2: STARTA OCH AVSLUTA VIM


  !! NOTERA: Innan du utför någon av punkterna nedan, läs hela lektionen!!

  1. Tryck <ESC>-tangenten (för att se till att du är i Normal-läge).

  2. Skriv:			:q! <ENTER>.

---> Detta avslutar redigeraren UTAN att spara några ändringar du gjort.
     Om du vill spara ändringarna och avsluta skriv:
				:wq  <ENTER>

  3. När du ser skal-prompten, skriv kommandot som tog dig in i den här
     handledningen.  Det kan vara:	vimtutor <ENTER>
     Normalt vill du använda:		vim tutor <ENTER>

---> 'vim' betyder öppna redigeraren vim, 'tutor' är filen du vill redigera.

  4. Om du har memorerat dessa steg och känner dig självsäker, kör då stegen
     1 till 3 för att avsluta och starta om redigeraren. Flytta sedan ned
     markören till Lektion 1.3.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lektion 1.3: TEXT REDIGERING - BORTTAGNING


** När du är i Normal-läge tryck  x  för att ta bort tecknet under markören. **

  1. Flytta markören till raden nedan med markeringen --->.

  2. För att rätta felen, flytta markören tills den står på tecknet som ska
     tas bort. fix the errors, move the cursor until it is on top of the

  3. Tryck på	x-tangenten för att ta bort det felaktiga tecknet.

  4. Upprepa steg 2 till 4 tills meningen är korrekt.

---> Kkon hoppadee övverr måånen.

  5. Nu när raden är korrekt, gå till Lektion 1.4.

NOTERA: När du går igenom den här handledningen, försök inte att memorera, lär
	genom användning.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lektion 1.4: TEXT REDIGERING - INFOGNING


	 ** När du är i Normal-läge tryck  i  för att infoga text. **

  1. Flytta markören till den första raden nedan med markeringen --->.

  2. För att göra den första raden likadan som den andra, flytta markören till
     det första tecknet EFTER där text ska infogas.

  3. Tryck  i  och skriv in det som saknas.

  4. När du rättat ett fel tryck <ESC> för att återgå till Normal-läge.
     Upprepa steg 2 till 4 för att rätta meningen.

---> Det sakns här .
---> Det saknas lite text från den här raden.

  5. När du känner dig bekväm med att infoga text, gå till sammanfattningen
     nedan.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			       LEKTION 1 SAMMANFATTNING


  1. Markören flyttas genom att använda piltangenterna eller hjkl-tangenterna.
	 h (vänster)	j (ned)       k (upp)	    l (höger)

  2. För att starta Vim (från %-prompten) skriv:  vim FILNAMN <ENTER>

  3. För att avsluta Vim skriv:  <ESC>  :q!  <ENTER>  för att kasta ändringar.
		   ELLER skriv:  <ESC>	:wq  <ENTER>  för att spara ändringar.

  4. För att ta bort tecknet under markören i Normal-läge skriv:  x

  5. För att infoga text vid markören i Normal-läge skriv:
	 i     skriv in text	<ESC>

NOTERA: Genom att trycka <ESC> kommer du att placeras i Normal-läge eller
	avbryta ett delvis färdigskrivet kommando.

Fortsätt nu med Lektion 2.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			Lektion 2.1: BORTTAGNINGSKOMMANDON


	    ** Skriv  dw  för att radera till slutet av ett ord. **

  1. Tryck  <ESC>  för att försäkra dig om att du är i Normal-läge.

  2. Flytta markören till raden nedan markerad --->.

  3. Flytta markören till början av ett ord som måste raderas.

  4. Skriv   dw	 för att radera ordet.

  NOTERA: Bokstäverna dw kommer att synas på den sista raden på skärmen när
	du skriver dem. Om du skrev något fel, tryck  <ESC>  och börja om.

---> Det är ett några ord roliga att som inte hör hemma i den här meningen.

  5. Upprepa stegen 3 och 4 tills meningen är korrekt och gå till Lektion 2.2.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		      Lektion 2.2: FLER BORTTAGNINGSKOMMANDON


	   ** Skriv  d$	för att radera till slutet på raden. **

  1. Tryck  <ESC>  för att försäkra dig om att du är i Normal-läge.

  2. Flytta markören till raden nedan markerad --->.

  3. Flytta markören till slutet på den rätta raden (EFTER den första . ).

  4. Skriv    d$    för att radera till slutet på raden.

---> Någon skrev slutet på den här raden två gånger. den här raden två gånger.


  5. Gå vidare till Lektion 2.3 för att förstå vad det är som händer.





~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lesson 2.3: KOMMANDON OCH OBJEKT


  Syntaxen för  d  raderingskommandot är följande:

	 [nummer]   d	objekt	    ELLER	     d	 [nummer]   objekt
  Var:
    nummer - är antalet upprepningar av kommandot (valfritt, standard=1).
    d - är kommandot för att radera.
    objekt - är vad kommandot kommer att operera på (listade nedan).

  En kort lista över objekt:
    w - från markören till slutet av ordet, inklusive blanksteget.
    e - från markören till slutet av ordet, EJ inklusive blanksteget.
    $ - från markören till slutet på raden.

NOTERA:  För den äventyrslystne, genom att bara trycka på objektet i
	 Normal-läge (utan kommando) så kommer markören att flyttas som
	 angivet i objektlistan.




~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		Lektion 2.4: ETT UNDANTAG TILL 'KOMMANDO-OBJEKT'


	       ** Skriv	 dd   för att radera hela raden. **

  På grund av hur vanligt det är att ta bort hela rader, valde upphovsmannen
  till Vi att det skulle vara enklare att bara trycka d två gånger i rad för
  att ta bort en rad.

  1. Flytta markören till den andra raden i frasen nedan.
  2. Skriv  dd  för att radera raden.
  3. Flytta nu till den fjärde raden.
  4. Skriv   2dd   (kom ihåg:  nummer-kommando-objekt) för att radera de två
     raderna.

      1)  Roses are red,
      2)  Mud is fun,
      3)  Violets are blue,
      4)  I have a car,
      5)  Clocks tell time,
      6)  Sugar is sweet
      7)  And so are you.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			 Lektion 2.5: ÅNGRA-KOMMANDOT


** Skriv  u för att ångra det senaste kommandona,  U för att fixa en hel rad. **

  1. Flytta markören till slutet av raden nedan markerad ---> och placera den
     på det första felet.
  2. Skriv  x  för att radera den första felaktiga tecknet.
  3. Skriv nu  u  för att ångra det senaste körda kommandot.
  4. Rätta den här gången alla felen på raden med  x-kommandot.
  5. Skriv nu  U  för att återställa raden till dess ursprungliga utseende.
  6. Skriv nu  u  några gånger för att ångra  U  och tidigare kommandon.
  7. Tryck nu CTRL-R (håll inne CTRL samtidigt som du trycker R) några gånger
     för att upprepa kommandona (ångra ångringarna).

---> Fiixa felen ppå deen häär meningen och återskapa dem med ångra.

  8. Det här är väldigt användbara kommandon.  Gå nu vidare till
     Lektion 2 Sammanfattning.




~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			       LEKTION 2 SAMMANFATTNING


  1. För att radera från markören till slutet av ett ord skriv:    dw

  2. För att radera från markören till slutet av en rad skriv:    d$

  3. För att radera en hel rad skriv:    dd

  4. Syntaxen för ett kommando i Normal-läge är:

       [nummer]   kommando   objekt   ELLER   kommando   [nummer]   objekt
     där:
       nummer - är hur många gånger kommandot kommandot ska repeteras
       kommando - är vad som ska göras, t.ex.  d  för att radera
       objekt - är vad kommandot ska operera på, som t.ex.  w (ord),
		$ (till slutet av raden), etc.

  5. För att ångra tidigare kommandon, skriv:  u (litet u)
     För att ångra alla tidigare ändringar på en rad skriv:  U (stort U)
     För att ångra ångringar tryck:  CTRL-R

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			 Lektion 3.1: KLISTRA IN-KOMMANDOT


   ** Skriv  p  för att klistra in den senaste raderingen efter markören. **

  1. Flytta markören till den första raden i listan nedan.

  2. Skriv  dd  för att radera raden och lagra den i Vims buffert.

  3. Flytta markören till raden OVANFÖR där den raderade raden borde vara.

  4. När du är i Normal-läge, skriv    p	 för att byta ut raden.

  5. Repetera stegen 2 till 4 för att klistra in alla rader i rätt ordning.

     d) Kan du lära dig också?
     b) Violetter är blå,
     c) Intelligens fås genom lärdom,
     a) Rosor är röda,



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		       Lesson 3.2: ERSÄTT-KOMMANDOT


  ** Skriv  r  och ett tecken för att ersätta tecknet under markören. **

  1. Flytta markören till den första raden nedan markerad --->.

  2. Flytta markören så att den står på det första felet.

  3. Skriv   r	och sedan det tecken som borde ersätta felet.

  4. Repetera steg 2 och 3 tills den första raden är korrekt.

--->  När drn här ruden skrevs, trickte någon på fil knappar!
--->  När den här raden skrevs, tryckte någon på fel knappar!

  5. Gå nu vidare till Lektion 3.2.

NOTERA: Kom ihåg att du skall lära dig genom användning, inte genom memorering.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			Lektion 3.3: ÄNDRA-KOMMANDOT


	   ** För att ändra en del eller ett helt ord, skriv  cw . **

  1. Flytta markören till den första redan nedan markerad --->.

  2. Placera markören på d i rdrtn.

  3. Skriv  cw  och det rätta ordet (i det här fallet, skriv "aden".)

  4. Tryck <ESC> och flytta markören till nästa fel (det första tecknet som
     ska ändras.)

  5. Repetera steg 3 och 4 tills den första raden är likadan som den andra.

---> Den här rdrtn har några otf som brhotrt ändras mrf ändra-komjendit.
---> Den här raden har några ord som behöver ändras med ändra-kommandot.

Notera att  cw  inte bara ändrar ordet, utan även placerar dig i infogningsläge.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		       Lektion 3.4: FLER ÄNDRINGAR MED c


     ** Ändra-kommandot används på samma objekt som radera. **

  1. Ändra-kommandot fungerar på samma sätt som radera. Syntaxen är:

       [nummer]   c   objekt	   ELLER	    c	[nummer]   objekt

  2. Objekten är också de samma, som t.ex.   w (ord), $ (slutet av raden), etc.

  3. Flytta till den första raden nedan markerad -->.

  4. Flytta markören till det första felet.

  5. Skriv  c$  för att göra resten av raden likadan som den andra och tryck
     <ESC>.

---> Slutet på den här raden behöver hjälp med att få den att likna den andra.
---> Slutet på den här raden behöver rättas till med  c$-kommandot.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			       LEKTION 3 SAMMANFATTNING


  1. För att ersätta text som redan har blivit raderad, skriv   p .
     Detta klistrar in den raderade texten EFTER markören (om en rad raderades
     kommer den att hamna på raden under markören.

  2. För att ersätta tecknet under markören, skriv   r   och sedan tecknet som
     kommer att ersätta orginalet.

  3. Ändra-kommandot låter dig ändra det angivna objektet från markören till
     slutet på objektet. eg. Skriv  cw  för att ändra från markören till slutet
     på ordet, c$	för att ändra till slutet på en rad.

  4. Syntaxen för ändra-kommandot är:

	 [nummer]   c	objekt	      ELLER	c   [nummer]   objekt

Gå nu till nästa lektion.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lektion 4.1: POSITION OCH FILSTATUS


  ** Tryck CTRL-g för att visa din position i filen och filstatusen.
     Tryck SHIFT-G för att flytta till en rad i filen. **

  Notera: Läsa hela den lektion innan du utför något av stegen!!

  1. Håll ned Ctrl-tangenten och tryck  g . En statusrad med filnamn och raden
     du befinner dig på kommer att synas. Kom ihåg radnummret till Steg 3.

  2. Tryck shift-G för att flytta markören till slutet på filen.

  3. Skriv in nummret på raden du var på och tryck sedan shift-G. Detta kommer
     att ta dig tillbaka till raden du var på när du först tryckte Ctrl-g.
     (När du skriver in nummren, kommer de INTE att visas på skärmen.)

  4. Om du känner dig säker på det här, utför steg 1 till 3.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			Lektion 4.2: SÖK-KOMMANDOT


     ** Skriv  /  följt av en fras för att söka efter frasen. **

  1. I Normal-läge skriv /-tecknet. Notera att det och markören blir synlig
     längst ned på skärmen precis som med :-kommandot.

  2. Skriv nu "feeel" <ENTER>. Det här är ordet du vill söka efter.

  3. För att söka efter samma fras igen, tryck helt enkelt  n .
     För att söka efter samma fras igen i motsatt riktning, tryck  Shift-N .

  4. Om du vill söka efter en fras bakåt i filen, använd kommandot  ?  istället
     för /.

---> "feeel" är inte rätt sätt att stava fel: feeel är ett fel.

Notera: När sökningen når slutet på filen kommer den att fortsätta vid början.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		   Lektion 4.3: SÖKNING EFTER MATCHANDE PARENTESER


	      ** Skriv  %  för att hitta en matchande ),], or } . **

  1. Placera markören på någon av (, [, or { på raden nedan markerad --->.

  2. Skriv nu %-tecknet.

  3. Markören borde vara på den matchande parentesen eller hakparentesen.

  4. Skriv  %  för att flytta markören tillbaka till den första hakparentesen
     (med matchning).

---> Det ( här är en testrad med (, [ ] och { } i den. ))

Notera: Det här är väldigt användbart vid avlusning av ett program med icke
	matchande parenteser!






~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		      Lektion 4.4: ETT SÄTT ATT ÄNDRA FEL


	** Skriv  :s/gammalt/nytt/g  för att ersätta "gammalt" med "nytt". **

  1. Flytta markören till raden nedan markerad --->.

  2. Skriv  :s/denn/den <ENTER> . Notera att det här kommandot bara ändrar den
     första förekomsten på raden.

  3. Skriv nu	 :s/denn/den/g	   vilket betyder ersätt globalt på raden.
     Det ändrar alla förekomster på raden.

---> denn bästa tiden att se blommor blomma är denn på våren.

  4. För att ändra alla förekomster av en teckensträng mellan två rader,
     skriv  :#,#s/gammalt/nytt/g    där #,# är de två radernas radnummer.
     Skriv  :%s/gammtl/nytt/g    för att ändra varje förekomst i hela filen.




~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			       LEKTION 4 SAMMANFATTNING


  1. Ctrl-g  visar din position i filen och filstatusen.
     Shift-G  flyttar till slutet av filen. Ett radnummer följt  Shift-G
     flyttar till det radnummret.

  2. Skriver man  /	följt av en fras söks det FRAMMÅT efter frasen.
     Skriver man  ?	följt av en fras söks det BAKÅT efter frasen.
     Efter en sökning skriv  n  för att hitta nästa förekomst i samma riktning
     eller  Shift-N  för att söka i den motsatta riktningen.

  3. Skriver man  %	när markören är på ett  (,),[,],{, eller }  hittas dess
     matchande par.

  4. För att ersätta den första gammalt med nytt på en rad skriv  :s/gammlt/nytt
     För att ersätta alla gammlt med nytt på en rad skriv  :s/gammlt/nytt/g
     För att ersätta fraser mellan rad # och rad # skriv  :#,#s/gammlt/nytt/g
     För att ersätta alla förekomster i filen skriv  :%s/gammlt/nytt/g
     För att bekräfta varje gång lägg till "c"  :%s/gammlt/nytt/gc


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		Lektion 5.1: HUR MAN KÖR ETT EXTERNT KOMMANDO


   ** Skriv  :!	följt av ett externt kommando för att köra det kommandot. **

  1. Skriv det välbekanta kommandot	:  för att placera markören längst ned
     på skärmen på skärmen. Detta låter dig skriva in ett kommando.

  2. Skriv nu  !  (utropstecken).  Detta låter dig köra ett godtyckligt externt
     skalkommando.

  3. Som ett exempel skriv   ls   efter ! och tryck sedan <ENTER>. Detta kommer
     att visa dig en listning av din katalog, precis som om du kört det vid
     skalprompten. Använd  :!dir  om ls inte fungerar.

Notera:  Det är möjligt att köra vilket externt kommando som helst på det här
	 sättet.

Notera:  Alla  :-kommandon måste avslutas med att trycka på <ENTER>




~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		      Lektion 5.2: MER OM ATT SPARA FILER


     ** För att spara ändringar gjorda i en fil, skriv  :w FILNAMN. **

  1. Skriv  :!dir  eller  :!ls  för att få en listning av din katalog.
     Du vet redan att du måste trycka <ENTER> efter det här.

  2. Välj ett filnamn som inte redan existerar, som t.ex. TEST.

  3. Skriv nu:	 :w TEST   (där TEST är filnamnet du valt.)

  4. Det här sparar hela filen	(Vim handledningen)  under namnet TEST.
     För att verifiera detta, skriv    :!dir   igen för att se din katalog

Notera: Om du skulle avsluta Vim och sedan öppna igen med filnamnet TEST så
	skulle filen vara en exakt kopia av handledningen när du sparade den.

  5. Ta nu bort filen genom att skriva (MS-DOS):  :!del TEST
				   eller (Unix):  :!rm TEST


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		    Lektion 5.3: ETT SELEKTIVT SPARA-KOMMANDO


	** För att spara en del av en fil, skriv   :#,# w FILNAMN **

  1. Ännu en gång, skriv  :!dir  eller  :!ls  för att få en listning av din
     katalog och välj ett passande filnamn som t.ex. TEST.

  2. Flytta markören högst upp på den här sidan och tryck  Ctrl-g  för att få
     reda på radnumret på den raden. KOM IHÅG DET NUMMRET!

  3. Flytta nu längst ned på sidan och skriv  Ctrl-g igen.
     KOM IHÅG DET RADNUMMRET OCKSÅ!

  4. För att BARA spara en sektion till en fil, skriv   :#,# w TEST
     där #,# är de två nummren du kom ihåg (toppen, botten) och TEST är
     ditt filnamn.

  5. Ännu en gång, kolla så att filen är där med  :!dir  men radera den INTE.




~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		   Lektion 5.4: TA EMOT OCH FÖRENA FILER


       ** För att infoga innehållet av en fil, skriv   :r FILNAMN **

  1. Skriv   :!dir   för att försäkra dig om att TEST-filen från tidigare
     fortfarande är kvar.

  2. Placera markören högst upp på den här sidan.

NOTERA:  Efter att du kört Steg 3 kommer du att se Lektion 5.3.
	 Flytta då NED till den här lektionen igen.

  3. Ta nu emot din TEST-fil med kommandot   :r TEST   där TEST är namnet på
     filen.

NOTERA:  Filen du tar emot placeras där markören är placerad.

  4. För att verifiera att filen togs emot, gå tillbaka och notera att det nu
     finns två kopior av Lektion 5.3, orginalet och filversionen.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			       LEKTION 5 SAMMANFATTNING


  1.  :!kommando  kör ett externt kommando.

      Några användbara exempel är:
	 (MS-DOS)	  (Unix)
	  :!dir		   :!ls		  -  visar en kataloglistning.
	  :!del FILNAMN    :!rm FILNAMN   -  tar bort filen FILNAMN.

  2.  :w FILNAMN  sparar den aktuella Vim-filen med namnet FILNAMN.

  3.  :#,#w FILNAMN  sparar raderna # till #  i filen FILNAMN.

  4.  :r FILNAMN  tar emot filen FILNAMN och infogar den i den aktuella filen
      efter markören.






~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			 Lektion 6.1: ÖPPNA-KOMMANDOT


 ** Skriv  o  för att öppna en rad under markören och placera dig i
    Infoga-läge. **

  1. Flytta markören till raden nedan markerad --->.

  2. Skriv  o (litet o) för att öppna upp en rad NEDANFÖR markören och placera
     dig i Infoga-mode.

  3. Kopiera nu raden markerad ---> och tryck <ESC> för att avsluta
     Infoga-läget.

---> Efter du skrivit  o  placerad markören på en öppen rad i Infoga-läge.

  4. För att öppna upp en rad OVANFÖR markören, skriv ett stort  O , istället
     för ett litet  o. Pröva detta på raden nedan.
Öppna upp en rad ovanför denna genom att trycka Shift-O när markören står här.





~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			Lektion 6.2: LÄGG TILL-KOMMANDOT


	     ** Skriv  a  för att infoga text EFTER markören. **

  1. Flytta markören till slutet av den första raden nedan markerad ---> genom
     att skriv  $	i Normal-läge.

  2. Skriv ett  a  (litet a) för att lägga till text EFTER tecknet under
     markören.  (Stort  A  lägger till i slutet av raden.)

Notera: Detta undviker att behöva skriva  i , det sista tecknet, texten att
	infoga, <ESC>, högerpil, och slutligen, x, bara för att lägga till i
	slutet på en rad!

  3. Gör nu färdigt den första raden. Notera också att lägga till är likadant
      som Infoga-läge, enda skillnaden är positionen där texten blir infogad.

---> Här kan du träna
---> Här kan du träna på att lägga till text i slutet på en rad.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		    Lektion 6.3: EN ANNAN VERSION AV ERSÄTT


      ** Skriv ett stort  R  för att ersätta fler än ett tecken. **

  1. Flytta markören till den första raden nedan markerad --->.

  2. Placera markören vid början av det första ordet som är annorlunda jämfört
     med den andra raden markerad ---> (ordet "sista").

  3. Skriv nu  R  och ersätt resten av texten på den första raden genom att
     skriva över den gamla texten så att den första raden blir likadan som
     den andra.

---> För att få den första raden lika som den sista, använd tangenterna.
---> För att få den första raden lika som den andra, skriv R och den nya texten.

  4. Notera att när du trycker <ESC> för att avsluta, så blir eventuell
     oförändrad text kvar.





~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			    Lektion 6.4: SÄTT FLAGGOR

  ** Sätt en flagga så att en sökning eller ersättning ignorerar storlek **

  1. Sök efter "ignore" genom att skriva:
     /ignore
     Repetera flera gånger genom att trycka på n-tangenten

  2. Sätt 'ic' (Ignore Case) flaggan genom att skriva:
     :set ic

  3. Sök nu efter "ignore" igen genom att trycka: n
     Repeat search several more times by hitting the n key

  4. Sätt 'hlsearch' and 'incsearch' flaggorna:
     :set hls is

  5. Skriv nu in sök-kommandot igen, och se vad som händer:
     /ignore

  6. För att ta bort framhävningen av träffar, skriv
     :nohlsearch
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			       LEKTION 6 SAMMANFATTNING


  1. Genom att skriva  o  öpnnas en rad NEDANFÖR markören och markören placeras
     på den öppna raden i Infoga-läge.
     Genom att skriva ett stort  O  öppnas raden OVANFÖR raden som markören är
     på.

  2. Skriv ett  a  för att infoga text EFTER tecknet som markören står på.
     Genom att skriva ett stort  A  läggs text automatiskt till i slutet på
     raden.

  3. Genom att skriva ett stort  R  hamnar du i Ersätt-läge till  <ESC>  trycks
     för att avsluta.

  4. Genom att skriva ":set xxx" sätts flaggan "xxx"









~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		       LEKTION 7: ON-LINE HJÄLP-KOMMANDON


		      ** Använd on-line hjälpsystemet **

  Vim har ett omfattande on-line hjälpsystem. För att komma igång pröva ett av
  dessa tre:
	- tryck <HELP> tangenten (om du har någon)
	- tryck <F1> tangenten (om du har någon)
	- skriv   :help <ENTER>

  Skriv   :q <ENTER>   för att stränga hjälpfönstret.

  Du kan hitta hjälp om nästan allting, genom att ge ett argument till
  ":help" kommandot. Pröva dessa (glöm inte att trycka <ENTER>):

	:help w
	:help c_<T
	:help insert-index
	:help user-manual


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		       LEKTION 8: SKAPA ETT UPPSTARTSSKRIPT

			  ** Aktivera Vim- funktioner **

  Vim har många fler funktioner än Vi, men de flesta av dem är inaktiverade som
  standard. För att börja använda fler funktioner måste du skapa en "vimrc"-fil.

  1. Börja redigera "vimrc"-filen, detta beror på ditt system:
	:edit ~/.vimrc			för Unix
	:edit $VIM/_vimrc		för MS-Windows

  2. Läs nu texten i exempel "vimrc"-filen:

	:read $VIMRUNTIME/vimrc_example.vim

  3. Spara filen med:

	:write

  Nästa gång du startar Vim kommer den att använda syntaxframhävning.
  Du kan lägga till alla inställningar du föredrar till den här "vimrc"-filen.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  Detta avslutar handledningen i Vim. Den var avsedd att ge en kort översikt av
  redigeraren Vim, bara tillräckligt för att du ska kunna använda redigeraren
  relativt enkelt. Den är långt ifrån komplett eftersom Vim har många många fler
  kommandon. Läs användarmanualen härnäst: ":help user-manual".

  För vidare läsning rekommenderas den här boken:
	Vim - Vi Improved - av Steve Oualline
	Förlag: New Riders
  Den första boken som är endast behandlar Vim. Speciellt användbar för
  nybörjare. Det finns många exempel och bilder.
  Se http://iccf-holland.org/click5.html

  Den här boken är äldre och behandlar mer Vi än Vim, men rekommenderas också:
	Learning the Vi Editor - av Linda Lamb
	Förlag: O'Reilly & Associates Inc.
  Det är en bra bok för att lära sig nästan allt som du vill kunna göra med Vi.
  Den sjätte upplagan inkluderar också information om Vim.

  Den här handledningen är skriven av Michael C. Pierce och Robert K. Ware,
  Colorado School of Mines med idéer från Charles Smith,
  Colorado State University.  E-post: bware@mines.colorado.edu.

  Modifierad för Vim av Bram Moolenaar.
  Översatt av Johan Svedberg <johan@svedberg.com>

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
