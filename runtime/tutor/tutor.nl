  ==========================================================================
  =    W e l k o m   b i j   d e   V I M   l e s s e n   -   Versie 1.7    =
  ==========================================================================

  Vim is een krachtige editor met veel commando's, te veel om uit te leggen
  in lessen zoals deze. Deze lessen zijn bedoeld om voldoende commando's te
  behandelen om je in staat te stellen met Vim te werken als een editor voor
  algemeen gebruik.

  Deze lessen zullen 25 tot 30 minuten in beslag nemen, afhankelijk van de
  tijd die wordt besteed aan het uitproberen van de commando's.

  LET OP:
  Door de commando's in deze lessen verandert de tekst. Maak een kopie van
  dit bestand om mee te oefenen (als je "vimtutor" uitvoerde, is dit al een
  kopie).

  Deze lessen zijn bedoeld om al doende te leren. Dat betekent dat je de
  commando's moet uitvoeren om ze goed te leren kennen. Als je de tekst
  alleen maar doorleest, zal je de commando's niet leren!

  Zorg ervoor dat de <Caps Lock> toets NIET is ingedrukt en druk vaak genoeg
  op de j-toets om de cursor zo te bewegen dat les 1.1 volledig op het
  scherm staat.

  LET OP: In deze lessen worden omwille van de duidelijkheid vaak spaties
  gebruikt binnen een commando (bv. "40 G" of "operator [getal] beweging").
  Tik deze spaties echter NIET. Ze verstoren de werking.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 1.1:  VERPLAATS DE CURSOR

  ** De cursor wordt verplaatst met de toetsen h, j, k, l zoals aangegeven. **
          ^
          k       Hint:  De h is de meest linkse en beweegt naar links.
      < h   l >          De l is de meest rechtse en beweegt naar rechts.
          j              De j lijkt op een pijl naar beneden.
          v

  1. Beweeg de cursor over het scherm om er vertrouwd mee te raken.

  2. Druk de omlaag-toets (j) tot hij repeteert.
     Nu weet je hoe je de volgende les bereikt.

  3. Gebruik de omlaag-toets om naar les 1.2 te gaan.

  OPMERKING: Als je twijfelt aan wat je tikte, druk <ESC> om in de opdracht-
             modus te komen. Tik daarna het commando dat bedoeld wordt.

  OPMERKING: Pijltjes-toetsen werken ook. Met de hjkl-toetsen kan je sneller
             rondbewegen, als je er eenmaal aan gewend bent. Echt waar!

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 1.2: VIM AFSLUITEN

      !! LET OP: Lees deze les goed door voordat je iets uitvoert!!

  1. Druk de <ESC> toets (om zeker in de opdrachtmodus te zitten).

  2. Tik   :q! <ENTER>
     Hiermee wordt de editor afgesloten. Alle veranderingen gaan VERLOREN.

  3. Nu zie je de shell-prompt. Tik het commando waarmee je deze lessen
     hebt opgeroepen. Dat is normaal gesproken:  vimtutor <ENTER>

  4. Als je deze stappen goed hebt doorgelezen, voer dan de stappen 1 tot 3
     uit om de editor te verlaten en weer op te starten.

  LET OP: :q! <ENTER> verwerpt alle veranderingen die je aanbracht. Een paar
          lessen verder zal je leren hoe veranderingen worden opgeslagen in
          een bestand.

  5. Beweeg de cursor omlaag naar les 1.3.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 1.3: TEKST BEWERKEN - WISSEN

          ** Tik  x  om het teken onder de cursor te wissen. **

  1. Ga met de cursor naar de regel verderop met --->.

  2. Zet de cursor op een teken dat moet worden gewist om een fout te
     herstellen.

  3. Tik  x  om het ongewenste teken te wissen.

  4. Herhaal deze stappen tot de regel goed is.

  ---> Vi kkent eenn opdracccchtmodus en een invooegmmmmodus.

  5. Nu de regel gecorrigeerd is kan je naar les 1.4 gaan.

  LET OP: Probeer de lessen niet uit je hoofd te leren. Leer al doende.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 1.4: TEKST BEWERKEN - INVOEGEN

              ** Tik  i  ('insert') om tekst in te voegen. **

  1. Ga met de cursor naar de eerste regel verderop met --->.

  2. Maak de eerste regel gelijk aan de tweede. Zet daarvoor de cursor op
     de plaats waar tekst moet worden ingevoegd.

  3. Tik  i  en daarna de nodige aanvullingen.

  4. Tik <ESC> na elke herstelde fout om terug te keren in de opdrachtmodus.
     Herhaal de stappen 2 tot 4 om de zin te verbeteren.

  ---> Aan regel ontekt wat .
  ---> Aan deze regel ontbreekt wat tekst.

  5. Ga naar les 1.5 als je gewend bent aan het invoegen van tekst.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 1.5: TEKST BEWERKEN - TOEVOEGEN

             ** Tik  A  ('append') om tekst toe te voegen. **

  1. Ga met de cursor naar de eerste regel verderop met --->.
     Het maakt niet uit waar de cursor in deze regel staat.

  2. Tik hoofdletter  A  en tik de nodige aanvullingen.

  3. Tik <ESC> nadat de tekst is aangevuld. Zo keer je terug in de
     opdrachtmodus.

  4. Ga naar de tweede regel verderop met ---> en herhaal stap 2 en 3
     om deze zin te corrigeren.

  ---> Er ontbreekt wat tekst aan de
       Er ontbreekt wat tekst aan deze regel.
  ---> Hier ontbreekt ook w
       Hier ontbreekt ook wat tekst.

  5. Ga naar les 1.6 als je vertrouwd bent geraakt aan het toevoegen
     van tekst.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 1.6: EEN BESTAND EDITTEN

    ** Gebruik  :wq  om een bestand op te slaan en de editor te verlaten. **

  !! LET OP: Lees deze les helemaal door voordat je een van de volgende
             stappen uitvoert!!

  1. Verlaat deze les zoals je in les 1.2 deed:  :q!
     Of gebruik een andere terminal als je daar de beschikking over hebt. Doe
     daar het volgende.

  2. Tik het volgende commando na de shell-prompt:  vim les <ENTER>
     'vim' (vaak ook 'vi') is het commando om de Vim-editor te starten,
     'les' is de naam van het bestand, dat je gaat bewerken. Kies een andere
     naam als er al een bestand 'les' bestaat, dat niet veranderd mag worden.

  3. Voeg naar eigen keus tekst toe, zoals je geleerd hebt in eerdere lessen.

  4. Sla het bestand met de wijzigingen op en verlaat Vim met  :wq <ENTER>

  5. Herstart vimtutor als je deze bij stap 1 hebt verlaten en ga verder met
     de volgende samenvatting.

  6. Voer deze stappen uit nadat je ze hebt gelezen en begrepen.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   SAMENVATTING Les 1

  1. De cursor wordt bewogen met de pijltjestoetsen of de hjkl-toetsen.
       h (links)   j (omlaag)  k (omhoog)  l (rechts)

  2. Start Vim van de shell-prompt. Tik:  vim BESTANDSNAAM <ENTER>

  3. Sluit Vim af met  <ESC> :q! <ENTER>  om de veranderingen weg te gooien.
               OF tik  <ESC> :wq <ENTER>  om de veranderingen te bewaren.

  4. Wis het teken onder de cursor met:  x

  5. Invoegen of toevoegen van tekst, tik:
     i  en daarna de in te voegen tekst  <ESC>   voeg in vanaf de cursor
     A  en daarna de toe te voegen tekst  <ESC>  voeg toe achter de regel

  OPMERKING: Met <ESC> kom je terug in opdrachtmodus en wordt een ongewenst
             of gedeeltelijk uitgevoerd commando afgebroken.

  Ga nu verder met les 2.1.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 2.1: WIS-COMMANDO'S

       ** Tik  dw  ('delete word') om een woord te wissen. **

  1. Druk op <ESC> om zeker in de opdrachtmodus te zijn.

  2. Ga naar de regel hieronder, die met ---> begint.

  3. Ga met de cursor naar het begin van een woord dat moet worden gewist.

  4. Met het tikken van  dw  verdwijnt het woord.

  OPMERKING: De letter  d  verschijnt op de laatste regel van het scherm
             zodra je hem tikt. Vim is aan het wachten tot je de  w  tikt.
             Als je een ander teken dan  d  ziet, heb je iets verkeerds
             getikt. Druk op <ESC> en begin opnieuw.

  NOG EEN OPMERKING: Dit werkt alleen als de optie 'showcmd' is ingeschakeld.
                     Dat gebeurt met  :set showcmd <ENTER>

  ---> Er zijn een het paar ggg woorden, die niet in deze len zin thuishoren.

  5. Herhaal de stappen 3 en 4 tot de zin goed is en ga naar les 2.2.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 2.2: MEER WIS-COMMANDO'S

        ** Tik  d$  om te wissen tot het einde van de regel. **

  1. Druk op <ESC> om zeker in de opdrachtmodus te zijn.

  2. Ga naar de regel hieronder, die met ---> begint.

  3. Ga met de cursor naar het einde van de correcte regel (NA de eerste  . ).

  4. Tik  d$  om te wissen tot het einde van de regel.

  ---> Iemand heeft het einde van deze regel dubbel getikt. dubbel getikt.

  5. Ga naar les 2.3 voor uitleg.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 2.3: OVER OPERATOREN EN BEWEGINGEN

  Veel commando's die de tekst veranderen, bestaan uit een operator en een
  beweging. De samenstelling van een wis-commando met de operator  d  is:
    d  beweging

  Daarbij is:
    d        - de wis-operator
    beweging - het bereik waarop de operator werkt (zie het lijstje hieronder)

  Een korte lijst van bewegingen vanaf de cursor:
    w - tot het begin van het volgende woord, ZONDER het eerste teken daarvan.
    e - tot het einde van het huidige woord, INCLUSIEF het laatste teken.
    $ - tot het einde van de regel, INCLUSIEF het laatste teken.

  Het tikken van  de  wist tekst vanaf de cursor tot het eind van het woord.

  OPMERKING: Het intikken van alleen maar de beweging, zonder een operator,
             in de opdrachtmodus beweegt de cursor (respectievelijk naar het
             volgende woord, naar het eind van het huidige woord en naar het
             eind van de regel).

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 2.4: GEBRUIK VAN EEN TELLER BIJ EEN BEWEGING

   ** Een getal voor een beweging herhaalt het zoveel keer. **

  1. Ga naar de regel hieronder, die met ---> begint.

  2. Tik  2w  zodat de cursor twee woorden vooruit gaat.

  3. Tik  3e  zodat de cursor naar het einde van het derde woord gaat.

  4. Tik  0  (nul) om naar het begin van de regel te gaan.

  5. Herhaal de stappen 2 en 3 met andere getallen.

  ---> Dit is een regel met woorden waarin je heen en weer kan bewegen.

  6. Ga verder met les 2.5.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 2.5: GEBRUIK EEN TELLER OM MEER TE WISSEN

  ** Een getal met een operator zorgt dat deze zoveel keer wordt herhaald. **

  Bij de combinatie van wis-operator en beweging kan je voor de beweging een
  teller zetten om meer te wissen:
         d  [teller]  beweging

  1. Ga naar het eerste woord in HOOFDLETTERS in de regel na --->.

  2. Met  d2w  worden twee woorden (in dit voorbeeld in hoofdletters) gewist.

  3. Herhaal de stappen 1 en 2 met verschillende tellers om de verschillende
     woorden in hoofdletters met één commando te wissen.

  ---> deze ABC DE regel FGHI JK LMN OP is QZ RS ontdaan van rommel.

  OPMERKING: De teller kan ook aan het begin staan: d2w en 2dw werken allebei.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 2.6: BEWERKING VAN HELE REGELS

               ** Tik  dd  om een hele regel te wissen. **

  Omdat het wissen van een hele regel vaak voorkomt, besloten de ontwerpers
  van Vi dat met het tikken van  dd  simpelweg een hele regel gewist wordt.

  1. Ga met de cursor naar de tweede regel van de zinnetjes hieronder.

  2. Tik  dd  om de regel te wissen.

  3. Ga nu naar de vierde regel.

  4. Tik  2dd  om twee regels te wissen.

  --->  1)  Rozen zijn rood.
  --->  2)  Modder is leuk.
  --->  3)  Viooltjes zijn blauw.
  --->  4)  Ik heb een auto.
  --->  5)  De klok slaat de tijd.
  --->  6)  Suiker is zoet.
  --->  7)  En dat ben jij ook.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 2.7: HET COMMANDO HERSTEL

  ** u  maakt het laatste commando ongedaan,  U  herstelt een hele regel. **

  1. Ga met de cursor naar de regel hieronder met ---> en zet hem
     op de eerste fout.

  2. Tik  x  om het eerste ongewenste teken te wissen.

  3. Tik nu  u  en maak daarmee het vorige commando ongedaan.

  4. Herstel nu alle fouten in de regel met het  x  commando.

  5. Tik een hoofdletter  U  om de regel in z'n oorspronkelijke staat terug
     te brengen.

  6. Tik nu een paar keer  u  en herstel daarmee de  U  en eerdere commando's.

  7. Tik nu een paar keer CTRL-R (Ctrl-toets ingedrukt houden en R tikken) en
     voer daarmee de commando's opnieuw uit: 'redo' oftewel 'undo de undo's'. 

  ---> Heerstel de fouten inn deeze regel en brenng ze weer terugg met undo.

  8. Dit zijn heel nuttige commando's. Ga verder met samenvatting van les 2.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   SAMENVATTING Les 2

  1. Wis van de cursor tot het volgende woord met    dw

  2. Wis van de cursor tot het eind van de regel met d$

  3. Wis de hele regel met                           dd

  4. Herhaal een beweging door er een getal voor te zetten:  2w

  5. De opbouw van een wijzigingscommando is:
       operator  [getal]  beweging
     daarbij is:
       operator - wat er moet gebeuren, bijvoorbeeld  d  om te wissen
       [getal]  - een (niet-verplichte) teller om 'beweging' te herhalen
       beweging - een beweging door de te wijzigen tekst zoals w (woord)
                  of $ (tot het einde van de regel) enz.

  6. Ga naar het begin van de regel met nul:  0

  7. Undo de voorgaande actie met              u (kleine letter)
     Undo alle veranderingen in een regel met  U (hoofdletter)
     Undo de undo's met                        CTRL-R

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 3.1: HET COMMANDO PLAK

  ** Tik  p  ('put') en plak daarmee zojuist gewiste tekst na te cursor. **

  1. Ga met de cursor naar de eerste regel met ---> hierna.

  2. Wis de regel met  dd  en bewaar hem zodoende in een Vim-register.

  3. Ga naar de c-regel, waar de gewiste regel ONDER moet komen.

  4. Tik  p  om de regel terug te zetten onder de regel met de cursor.

  5. Herhaal de stappen 2 tot 4 om de regels in de goede volgorde te zetten.

---> d) Krijg je het ook onder de knie?
---> b) Viooltjes zijn blauw,
---> c) Begrip is te leren,
---> a) Rozen zijn rood,

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 3.2: HET COMMANDO VERVANG

  ** Tik rx ('replace') om het teken onder de cursor te vervangen door x. **

  1. Ga naar de eerste regel hieronder met --->.

  2. Zet de cursor op de eerste fout.

  3. Tik  r  en dan het teken dat er hoort te staan.

  4. Herhaal de stappen 2 en 3 tot de eerste regel gelijk is aan de tweede.

  --->  Bij het tokken van dezf hegel heeft iemamd verklerde letters getikt.
  --->  Bij het tikken van deze regel heeft iemand verkeerde letters getikt.

  5. Ga nu naar les 3.3.

  LET OP: Door het te doen, leer je beter dan door het uit je hoofd te leren.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 3.3: HET COMMANDO VERANDER

     ** Tik  ce  om te veranderen tot het einde van een woord. **

  1. Ga met de cursor naar de eerste regel hieronder met --->.

  2. Zet de cursor op de  u  van ruch.

  3. Tik  ce  en de juiste letters (in dit geval "egel").

  4. Druk <ESC> en ga naar het volgende teken dat moet worden veranderd.

  5. Herhaal de stappen 3 en 4 tot de eerste regel gelijk is aan de tweede.

  ---> In deze ruch staan een paar weedrim die veranderd moud worden.
  ---> In deze regel staan een paar woorden die veranderd moeten worden.

  LET OP: Met  ce  wordt (het laatste deel van) een woord gewist en kom je
          in de invoegmodus.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 3.4: MEER VERANDERINGEN MET c

  1. Het commando verander ('change') werkt op dezelfde manier als wis. De
     opbouw is:
         c  [teller]  beweging

  2. De bewegingen zijn hetzelfde, zoals  w  (woord) en  $  (einde regel).

  3. Ga naar de eerste regel hieronder met --->.

  4. Zet de cursor op de eerste fout.

  5. Tik  c$  en tik de rest van de regel zodat hij gelijk wordt aan de
     tweede en sluit af met <ESC>.

  ---> Het einde van deze regel moet precies zo worden als de tweede regel.
  ---> Het einde van deze regel moet gecorrigeerd worden met het commando c$.

  OPMERKING: Je kan de toets <BACKSPACE> gebruiken om tikfouten te herstellen.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   SAMENVATTING Les 3 

  1. Tik  p  om tekst terug te plakken, die zojuist is gewist. Dit zet de
     gewiste tekst ACHTER de cursor (als een hele regel is gewist komt deze
     op de regel ONDER de cursor.

  2. Het teken waarop de cursor staat wordt vervangen met  r  gevolgd door
     het teken dat je daar wilt hebben.

  3. Het commando 'verander' stelt je in staat om tekst te veranderen vanaf
     de cursor tot waar de 'beweging' je brengt. Dat wil zeggen: tik  ce  om
     te veranderen vanaf de cursor tot het einde van het woord,  c$  om te
     veranderen tot het einde van de regel.

  4. De opbouw van het commando verander is:
         c  [teller]  beweging

  Ga nu naar de volgende les.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 4.1: PLAATS VAN DE CURSOR EN STATUS VAN HET BESTAND

  ** CTRL-G laat zien waar (regelnummer) je je bevindt en wat de status van
     het bestand is. Met [nummer] G  ga je naar een bepaalde regel. **

  LET OP: Lees de hele les voordat je een stap uitvoert!!

  1. Hou de Ctrl-toets ingedrukt en tik  g . Dit noemen we CTRL-G.
     Onderaan de pagina verschijnt een boodschap met de bestandsnaam en de
     positie in het bestand. Onthou het regelnummer voor stap 3.

  OPMERKING: Als de optie 'ruler' aan staat, wordt de positie van de cursor
             (regelnummer, kolom) steeds in de rechter-onderhoek van het
             scherm vermeld. In dit geval vermeldt CTRL-G geen regelnummer.
             CTRL-G geeft ook de status aan, namelijk of de tekst veranderd
             is ('modified') sinds het de laatste keer is opgeslagen.  

  2. Tik hoofdletter  G  om naar het einde van het bestand te gaan.
     Tik  gg  om naar het begin van het bestand te gaan.

  3. Tik het regelnummer waar je bij stap 1 was en daarna  G . Dit brengt je
     terug naar de regel waar je was toen je de eerste keer CTRL-G tikte.

  4. Voer de stappen 1 tot 3 uit als je dit goed hebt gelezen.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 4.2: HET COMMANDO ZOEKEN

  ** Met  /ZOEK  wordt naar de zoekterm (één of meer woorden) gezocht. **

  1. Tik in de opdrachtmodus het teken  / . Je ziet dat het met de cursor
     aan de onderkant van het scherm verschijnt, zoals bij het :-commando.

  2. Tik nu 'ffouut' <ENTER>. Dit is het woord waarnaar gezocht wordt.

  3. Tik  n  om verder te zoeken met dezelfde zoekterm.
     Zoek met  N  met dezelfde zoekterm in de tegenovergestelde richting.

  4. Zoek in achterwaartse richting met ?zoekterm in plaats van  / .

  5. Keer terug naar de vorige hit met CTRL-O (hou Ctrl-toets ingedrukt en
     tik letter o). Herhaal om verder terug te gaan. CTRL-I gaat vooruit.

  ---> "ffouut" is niet de juiste spelling van fout, ffouut is een fout.

  OPMERKING: Als zoeken het einde van het bestand bereikt, wordt vanaf het
             begin doorgezocht, tenzij de optie 'wrapscan' is uitgeschakeld.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 4.3: GA NAAR CORRESPONDERENDE HAAKJES

            ** Tik  %  om naar corresponderende ), ] of } te gaan. **

  1. Zet de cursor op een (, [ of { in de regel hieronder met --->.

  2. Tik dan het teken  % .

  3. De cursor gaan naar het overeenkomstige haakje.

  4. Met opnieuw  %  gaat de cursor terug naar het eerste haakje.

  5. Plaats de cursor op een ander haakje en bekijk wat  %  doet.

  ---> Dit ( is een testregel met  ('s, ['s ] en {'s } erin. ))

  OPMERKING: Dit is nuttig bij het debuggen van een programma waarin haakjes
             niet corresponderen. Met de optie 'showmatch' wordt ook
             aangegeven of haakjes corresponderen, maar de cursor wordt niet
             (blijvend) verplaatst.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 4.4: HET VERVANG COMMANDO

      ** Tik  :s/oud/nieuw/g  om 'oud' door 'nieuw' te vervangen. **

  1. Ga met de cursor naar de regel hieronder met --->.

  2. Tik  :s/dee/de <ENTER>. Zoals je ziet, vervangt ('substitute') dit
     commando alleen de eerste "dee" in de regel.

  3. Tik nu  :s/dee/de/g . Met de g-vlag ('global') wordt elke "dee" in de
     regel vervangen.

  ---> dee beste tijd om dee bloemen te zien is in dee lente.

  4. Om in (een deel van) een tekst elk 'oud' te vervangen door 'nieuw':
     tik   :#,#s/oud/nieuw/g   waar #,# de regelnummers zijn die het gebied
                               begrenzen waarin wordt vervangen.
     tik   :%s/oud/nieuw/g     om alles te vervangen in het hele bestand.
     tik   :%s/oud/nieuw/gc    om elke 'oud' in het hele bestand te vinden
                               en te vragen of er vervangen moet worden.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   SAMENVATTING Les 4

  1. CTRL-G   laat positie in het bestand zien en de status van het bestand.
     G        verplaatst je naar het einde van het bestand.
     nummer G verplaatst je naar regelnummer.
     gg       verplaatst je naar de eerste regel.

  2. Met  /  en een zoekterm wordt VOORWAARTS gezocht naar de term.
     Met  ?  en een zoekterm wordt ACHTERWAARTS gezocht naar de term.
     Tik  n  na een zoekopdracht om de volgende hit te vinden,
     of tik  N  om in de andere richting te zoeken.
     CTRL-O  brengt je naar eerdere hit,  CTRL-I naar nieuwere.

  3. Tik  %  terwijl de cursor op een haakje ([{}]) staat, om naar het
     corresponderende haakje te gaan.

  4. :s/oud/nieuw      vervangt het eerste 'oud' in een regel door 'nieuw'.
     :s/oud/nieuw/g    vervangt elk 'oud' in een regel door 'nieuw'.
     :#,#s/oud/nieuw/g vervangt elk 'oud' door 'nieuw' tussen de regelnummers.
     :%s/oud/nieuw/g    vervangt elk 'oud' door 'nieuw' in het hele bestand.
     Voeg  c  toe (:%s/oud/nieuw/gc) om elke keer om bevestiging
     ('confirmation') te vragen.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 5.1: HOE EEN EXTERN COMMANDO WORDT UITGEVOERD

     ** Tik  :!  gevolgd door een extern commando om dat uit te voeren. **

  1. Tik het commando  :  waarmee de cursor op de onderste regel van het
     scherm komt te staan. Nu kan je een opdracht geven via de commando-regel.

  2. Tik een  !  (uitroepteken). Dit stelt je in staat om elk shell-commando
     uit te voeren.

  3. Tik bijvoorbeeld  ls  na het uitroepteken en daarna <ENTER>. Hiermee
     krijg je de inhoud van je map te zien, net alsof je de opdracht gaf
     vanaf de shell-prompt. Probeer  :!dir  als het niet werkt.

  OPMERKING: Elk extern commando kan op deze manier uitgevoerd worden, ook
             met argumenten.

  OPMERKING: Alle commando's na  :  moeten worden afgesloten met <ENTER>.
             Vanaf nu zullen we dat niet meer altijd vermelden.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 5.2: MEER OVER HET OPSLAAN VAN BESTANDEN

     ** Tik :w BESTANDSNAAM om de tekst mèt veranderingen op te slaan. **

  1. Tik  :!dir  of  :!ls  om de inhoud van je map te tonen. Je weet
     inmiddels dat je daarna een <ENTER> moet tikken.

  2. Kies een bestandsnaam die nog niet bestaat, bijvoorbeeld TEST.

  3. Tik nu:  :w TEST  (als je de naam TEST hebt gekozen).

  4. Hierdoor wordt het hele bestand (de VIM lessen) opgeslagen onder de
     naam TEST. Tik weer  :!dir  of  :!ls  om dit te controleren.

  OPMERKING: Als je Vim zou verlaten en opnieuw zou starten met  vim TEST  is
             het bestand een exacte kopie van de lessen, zoals je ze opsloeg.

  5. Wis het bestand nu met de opdracht (MS-DOS)  :!del TEST
                                       of (Unix)  :!rm TEST

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 5.3: EEN DEEL VAN DE TEKST OPSLAAN

     ** Sla een deel van het bestand op met  v beweging :w BESTANDSNAAM **

  1. Ga naar deze regel.

  2. Tik  v  en ga met de cursor naar stap 5 hieronder. Je ziet dat de
     tekst oplicht.

  3. Tik  : . Onderaan het scherm zal  :'<,'>  verschijnen.

  4. Tik  w TEST  , waar TEST een bestandsnaam is, die nog niet bestaat.
     Controleer dat je  :'<,'>w TEST  ziet staan voordat je <ENTER> tikt.

  5. Vim slaat nu de geselecteerde regels op in het bestand TEST. Met
     :!dir  of  !ls  kan je dat zien. Wis het nog niet! We zullen het in
     de volgende les gebruiken.

  OPMERKING: Het tikken van  v  zet zichtbare modus ('visual selection') aan.
             Je kan de cursor rondbewegen om de selectie groter of kleiner
             te maken. Vervolgens kan je een commando gebruiken om iets met
             de tekst te doen. Met  d  bijvoorbeeld wis je de tekst.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 5.4: OPHALEN EN SAMENVOEGEN VAN BESTANDEN

     ** Tik  :r BESTANDSNAAM om de inhoud van een bestand in te voegen. **

  1. Zet de cursor precies boven deze regel.

  OPMERKING: Na het uitvoeren van stap 2 zie je tekst van les 5.3. Scrol
             daarna naar beneden om deze les weer te zien.

  2. Haal nu het bestand TEST op met het commando  :r TEST .
     Het bestand dat je ophaalt komt onder de regel waarin de cursor staat.

  3. Controleer dat er een bestand is opgehaald. Ga met de cursor omhoog.
     Dan zie je de tekst van les 5.3 dubbel, het origineel en de versie uit
     het bestand.

  OPMERKING: Je kan ook de uitvoer van een extern commando inlezen. Om een
             voorbeeld te geven:  :r !ls  leest de uitvoer van het commando
             ls en zet dat onder de regel waarin de cursor staat.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   SAMENVATTING Les 5

  1. :!COMMANDO  voert een extern commando uit.
     Enkele bruikbare voorbeelden zijn:
        (MS-DOS)         (Unix)
         :!dir            :!ls          - laat de inhoud van een map zien
         :!del BESTAND    :!rm BESTAND  - wist bestand BESTAND

  2. :w BESTANDSNAAM  schrijft het huidige Vim-bestand naar disk met de
     naam BESTANDSNAAM.

  3. v beweging :w BESTANDSNAAM  laat je in zichtbare modus een fragment
     selecteren, dat wordt opgeslagen in het bestand BESTANDSNAAM.

  4. :r BESTANDSNAAM  haalt het bestand BESTANDSNAAM op en voegt het onder
     de cursor-positie in de tekst in.

  5. :r !dir  leest de uitvoer van het externe commando dir en zet het onder
     de cursor-positie.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 6.1: HET COMMANDO OPEN

     ** Tik  o  om een regel onder de cursor te openen in invoegmodus. **

  1. Ga naar de eerste regel beneden met --->.

  2. Tik de kleine letter  o  en open daarmee een regel ONDER de cursor en
     ga naar de invoegmodus.

  3. Tik wat tekst in en sluit af met <ESC> om de invoegmodus te verlaten.

  ---> Als je  o  tikt, komt de cursor in een nieuwe regel in invoegmodus.

  4. Om een regel BOVEN de cursor te openen, moet je gewoon een hoofdletter
     O  tikken in plaats van een kleine letter. Probeer dat vanaf de volgende
     regel.

  ---> Open een regel hierboven. Tik een O terwijl de cursor hier staat.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 6.2: HET COMMANDO TOEVOEGEN

        ** Tik  a  om tekst toe te voegen ACHTER de cursor. **

  1. Ga naar het begin van de regel beneden met --->.
 
  2. Tik  e  tot de cursor op het einde van  "ste"  staat.

  3. Tik een (kleine letter)  a  ('append') om toe te voegen ACHTER de cursor.

  4. Vul het woord aan zoals in de volgende regel. Druk <ESC> om de
     invoegmodus te verlaten.

  5. Ga met  e  naar het einde van het volgende onvolledige woord en herhaal
     de stappen 3 en 4.

  ---> Deze regel ste je in staat om te oef in het toevo van tekst. 
       Deze regel stelt je in staat om te oefenen in het toevoegen van tekst. 

  OPMERKING: a, i en A openen allemaal dezelfde invoegmodus, het enige
             verschil is waar tekens worden ingevoegd.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 6.3: VERVANGEN OP EEN ANDERE MANIER

      ** Tik een hoofdletter  R  om meer dan één teken te vervangen. **

  1. Ga naar de eerste regel beneden met --->. Ga met de cursor naar het
     begin van de eerste  "xxx" .

  2. Tik nu  R  en daarna het getal eronder in de tweede regel, zodat  xxx
     wordt vervangen.

  3. Druk <ESC> om de vervangmodus te verlaten. Je ziet dat de rest van de
     regel ongewijzigd blijft.

  4. Herhaal de stappen om de overgebleven  xxx  te vervangen.

  ---> Optellen van 123 en xxx geeft je xxx.
  ---> Optellen van 123 en 456 geeft je 579.

  OPMERKING: Vervangmodus lijkt op invoegmodus, maar elk teken dat je tikt,
             vervangt een bestaand teken.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 6.4: TEKST KOPIËREN EN PLAKKEN

        ** Gebruik  y  om tekst te kopiëren en  p  om te plakken. **

  1. Ga naar de regel beneden met ---> en zet de cursor achter "a)".

  2. Zet zichtbare modus aan met  v  en zet de cursor juist voor "eerste".

  3. Tik  y  ('yank') om de opgelichte tekst ("dit is het") te kopiëren.

  4. Ga met  j$  met de cursor naar het einde van de volgende regel.

  5. Plak de gekopieerde tekst met  p  en tik  a tweede <ESC>.

  6. Selecteer in zichtbare modus "onderdeel", kopieer het met  y  en
     ga met  j$  naar het einde van de tweede regel. Plak de tekst daar
     met  p .

  --->  a) dit is het eerste onderdeel
        b)

  OPMERKING: Je kan  y  ook als operator gebruiken;  yw  kopieert een woord,
             yy  een hele regel.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 6.5: OPTIES GEBRUIKEN

     ** Gebruik een optie voor al dan niet hoofdlettergevoelig zoeken. **

  1. Zoek naar 'hoofdlettergevoelig' met  /hoofdlettergevoelig <ENTER>
     Herhaal het zoeken enkele keren door  n  te tikken.
 
  2. Schakel de optie 'ic' ('ignore case', niet-hoofdlettergevoelig) in
     met  :set ic

  3. Zoek met  n  opnieuw naar 'hoofdlettergevoelig'. Je ziet dat
     Hoofdlettergevoelig en HOOFDLETTERGEVOELIG nu ook gevonden worden.

  4. Schakel de opties 'hlsearch' (treffers oplichten) en 'incsearch' (toon
     gedeeltelijke treffers bij intikken) in met  :set hls is

  5. Tik weer /hoofdlettergevoelig <ENTER> en kijk wat er gebeurt.

  6. Schakel 'hoofdlettergevoelig' weer in met  :set noic

  OPMERKING: Schakel het oplichten van treffers uit met  :nohlsearch

  OPMERKING: Om bij een enkel zoek-commando de hoofdlettergevoeligheid om
             te draaien kan  \c  worden gebruikt na de zoekterm:
             /hoofdlettergevoelig\c <ENTER>.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   SAMENVATTING Les 6

  1. Tik  o  om een regel te openen ONDER de cursor en invoegmodus te starten.
     Tik  O  om een regel te openen BOVEN de cursor.

  2. Tik  a  om tekst toe te voegen NA de cursor.
     Tik  A  om tekst toe te voegen aan het einde van de regel.

  3. Het commando  e  beweegt de cursor naar het einde van een woord.

  4. De operator  y  yankt (kopieert) tekst,  p  zet het terug (plakt).

  5. Met hoofdletter  R  wordt de vervangmodus geopend, met <ESC> afgesloten.

  6. Met  :set xxx  wordt optie 'xxx' ingeschakeld. Opties zijn bijvoorbeeld:
       ic   ignorecase  geen verschil hoofdletters/kleine letters bij zoeken
       is   incsearch   toon gedeeltelijke treffers tijdens intikken zoekterm 
       hls  hlsearch    laat alle treffers oplichten
     Je kan zowel de lange als de korte naam van een optie gebruiken.
  
  7. Zet 'no' voor de naam om een optie uit te schakelen:  :set noic
     schakelt 'ic' uit.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 7.1: HULP INROEPEN

           ** Het gebruik van ingebouwde hulp. **

  Vim heeft een uitgebreid ingebouwd hulpsysteem. Probeer, om te beginnen,
  één van deze drie:
    - druk de <HELP> toets (als je die hebt)
    - druk de <F1> toets (als je die hebt)
    - tik  :help <ENTER>

  Lees de tekst in het help-venster om te leren hoe 'help' werkt.
  Tik  CTRL-W CTRL-W  om van het ene venster naar het andere te gaan.
  Met  :q <ENTER>  wordt het help-venster gesloten.

  Je kan hulp vinden over nagenoeg elk onderwerp door een argument aan het
  commando  :help  toe te voegen. Probeer deze (en vergeet <ENTER> niet):
    :help w
    :help c_CTRL-D
    :help insert-index
    :help user-manual

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 7.2: SCHRIJF EEN CONFIGURATIEBESTAND

                    ** Mogelijkheden van Vim uitbreiden. **

  Vim kent veel meer mogelijkheden dan Vi, maar de meeste zijn standaard
  uitgeschakeld. Om meer functies te gebruiken moet je een 'vimrc'-bestand
  schrijven.

  1. Bewerk het bestand 'vimrc'. Hoe dat moet hangt af van je systeem:
      :e ~/.vimrc		voor Unix
      :e $VIM/_vimrc		voor MS-Windows

  2. Lees de inhoud van het voorbeeld-bestand:
      :r $VIMRUNTIME/vimrc_example.vim

  3. Sla het bestand op met  :w

  De volgende keer dat je Vim start wordt 'syntaxiskleuring' gebruiken.
  Je kan al je voorkeursinstellingen toevoegen aan dit 'vimrc'-bestand.
  Tik  :help vimrc-intro  voor meer informatie.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   Les 7.3: AANVULLEN

      ** Aanvullen van de 'command line' met CTRL-D en <TAB>. **

  1. Zorg dat Vim niet in 'compatible mode' is met  :set nocp

  2. Kijk welke bestanden zich in de map bevinden met  :!ls  of  :!dir

  3. Tik het begin van een commando:  :e

  4. Met  CTRL-D  toont Vim een lijst commando's, die met "e" beginnen.

  5. Druk enkele keren <TAB>. Vim laat aanvullingen zien, zoals ":edit",
     dat we hier gebruiken.

  6. Voeg een spatie toe en de eerste letter(s) van een bestaande
     bestandsnaam:  :edit BESTAND

  7. Druk <TAB>. Vim vult de naam aan (als hij uniek is).

  OPMERKING: Aanvullen werkt bij tal van commando's. Probeer gewoon CTRL-D
             en <TAB>. Het is bijzonder nuttig bij  :help .

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   SAMENVATTING Les 7

  1. Tik  :help  of druk <F1> of <Help>  om een help-venster te openen.

  2. Tik  :help CMD  voor hulp over  CMD .

  3. Tik  CTRL-W CTRL-W  om naar een ander venster te gaan.

  4. Tik  :q  om het help-venster te sluiten.

  5. Maak een bestand met de naam 'vimrc' voor je voorkeursinstellingen.

  6. Druk CTRL-D tijdens het intikken van een :-commando om mogelijke
     aanvullingen te zien. Druk <TAB> om aanvullen te gebruiken.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  Hiermee komen de Vim-lessen tot een einde. Ze waren bedoeld om een kort
  overzicht te geven van de Vim-editor, juist voldoende om de editor
  redelijk makkelijk te gebruiken. Deze lessen zijn verre van volledig. Vim
  kent veel meer commando's. Lees hierna de handleiding voor gebruikers:
  ":help user-manual".

  Voor verdere studie wordt aanbevolen:
      Vim - Vi Improved - door Steve Oualline
      Uitgever: New Riders
  Dit is het eerste boek dat geheel aan Vim is gewijd. Speciaal geschikt
  voor beginners. Met veel voorbeelden en afbeeldingen.
  Zie http://iccf-holland.org/click5.html

  Het volgende boek is ouder en gaat meer over Vi dan Vim, maar het wordt
  toch aanbevolen:
      Learning the Vi Editor - door Linda Lamb
      Uitgever: O'Reilly & Associates Inc.
  Het is een goed boek om nagenoeg alles te weten te komen dat je met Vi
  zou willen doen. De zesde en vooral de nieuwe zevende druk (onder de
  titel Learning the Vi and Vim Editors door Arnold Robbins, Elbert Hannah
  & Linda Lamb) bevat ook informatie over Vim.

  Deze lessen zijn geschreven door Michael C. Pierce en Robert K. Ware,
  Colorado School of Mines met gebruikmaking van ideeën van Charles Smith
  van de Colorado State University. E-mail: bware@mines.colorado.edu.

  Aangepast voor Vim door Bram Moolenaar.

  Nederlandse vertaling door Rob Bishoff, april 2012
  e-mail: rob.bishoff@hccnet.nl)

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
