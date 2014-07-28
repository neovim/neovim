===============================================================================
=     B i e n v e n i d o   a l   t u t o r   d e   V I M  -  Versi�n 1.4     =
===============================================================================

     Vim es un editor muy potente que dispone de muchos mandatos, demasiados
     para ser explicados en un tutor como �ste. Este tutor est� dise�ado
     para describir suficientes mandatos para que usted sea capaz de
     aprender f�cilmente a usar Vim como un editor de prop�sito general.

     El tiempo necesario para completar el tutor es aproximadamente de 25-30
     minutos, dependiendo de cuanto tiempo se dedique a la experimentaci�n.

     Los mandatos de estas lecciones modificar�n el texto. Haga una copia de
     este fichero para practicar (con �vimtutor� esto ya es una copia).

     Es importante recordar que este tutor est� pensado para ense�ar con
     la pr�ctica. Esto significa que es necesario ejecutar los mandatos
     para aprenderlos adecuadamente. Si �nicamente se lee el texto, se
     olvidar�n los mandatos.

     Ahora, aseg�rese de que la tecla de bloqueo de may�sculas no est�
     activada y pulse la tecla	j  lo suficiente para mover el cursor
     de forma que la Lecci�n 1.1 ocupe completamente la pantalla.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lecci�n 1.1: MOVIMIENTOS DEL CURSOR

 ** Para mover el cursor, pulse las teclas h,j,k,l de la forma que se indica. **
      ^
      k       Indicaci�n: La tecla h est� a la izquierda y mueve a la izquierda.
 < h	 l >		  La tecla l est� a la derecha y mueve a la derecha.
      j			  La tecla j parece una flecha que apunta hacia abajo.
      v

  1. Mueva el cursor por la pantalla hasta que se sienta c�modo con ello.

  2. Mantenga pulsada la tecla	j  hasta que se repita �autom�gicamente�.
---> Ahora ya sabe como llegar a la lecci�n siguiente.

  3. Utilizando la tecla abajo, vaya a la Lecci�n 1.2.

Nota: Si alguna vez no est� seguro sobre algo que ha tecleado, pulse <ESC>
      para situarse en modo Normal. Luego vuelva a teclear la orden que deseaba.

Nota: Las teclas de movimiento del cursor tambi�n funcionan. Pero usando
      hjkl podr� moverse mucho m�s r�pido una vez que se acostumbre a ello.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		    Lecci�n 1.2: ENTRANDO Y SALIENDO DE VIM

  �� NOTA: Antes de ejecutar alguno de los pasos siguientes lea primero
	   la lecci�n entera!!

  1. Pulse la tecla <ESC> (para asegurarse de que est� en modo Normal).

  2. Escriba:			:q! <INTRO>

---> Esto provoca la salida del editor SIN guardar ning�n cambio que se haya
     hecho. Si quiere guardar los cambios y salir escriba:
				:wq <INTRO>

  3. Cuando vea el s�mbolo del sistema, escriba el mandato que le trajo a este
     tutor. �ste puede haber sido:   vimtutor <INTRO>
     Normalmente se usar�a:	     vim tutor <INTRO>

---> 'vim' significa entrar al editor, 'tutor' es el fichero a editar.

  4. Si ha memorizado estos pasos y se se siente con confianza, ejecute los
     pasos 1 a 3 para salir y volver a entrar al editor. Despu�s mueva el
     cursor hasta la Lecci�n 1.3.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		   Lecci�n 1.3: EDICI�N DE TEXTO - BORRADO

** Estando en modo Normal pulse  x  para borrar el car�cter sobre el cursor. **j


  1. Mueva el cursor a la l�nea de abajo se�alada con --->.

  2. Para corregir los errores, mueva el cursor hasta que est� bajo el
     car�cter que va aser borrado.

  3. Pulse la tecla  x	para borrar el car�cter sobrante.

  4. Repita los pasos 2 a 4 hasta que la frase sea la correcta.

---> La vvaca salt�� soobree laa luuuuna.

  5. Ahora que la l�nea esta correcta, contin�e con la Lecci�n 1.4.


NOTA: A medida que vaya avanzando en este tutor no intente memorizar,
      aprenda practicando.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		   Lecci�n 1.4: EDICI�N DE TEXTO - INSERCI�N

      ** Estando en modo Normal pulse  i  para insertar texto. **


  1. Mueva el cursor a la primera l�nea de abajo se�alada con --->.

  2. Para que la primera l�nea se igual a la segunda mueva el cursor bajo el
     primer car�cter que sigue al texto que ha de ser insertado.

  3. Pulse  i  y escriba los caracteres a a�adir.

  4. A medida que sea corregido cada error pulse <ESC> para volver al modo
     Normal. Repita los pasos 2 a 4 para corregir la frase.

---> Flta texto en esta .
---> Falta algo de texto en esta l�nea.

  5. Cuando se sienta c�modo insertando texto pase al resumen que esta m�s
     abajo.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			    RESUMEN DE LA LECCI�N 1


  1. El cursor se mueve utilizando las teclas de las flechas o las teclas hjkl.
	 h (izquierda)	   j (abajo)	  k (arriba)	  l (derecha)

  2. Para acceder a Vim (desde el s�mbolo del sistema %) escriba:
     vim FILENAME <INTRO>

  3. Para salir de Vim escriba: <ESC> :q! <INTRO> para eliminar todos
     los cambios.

  4. Para borrar un car�cter sobre el cursor en modo Normal pulse:  x

  5. Para insertar texto en la posici�n del cursor estando en modo Normal:
	  pulse   i   escriba el texto	 pulse <ESC>

NOTA: Pulsando <ESC> se vuelve al modo Normal o cancela un mandato no deseado
      o incompleto.

Ahora contin�e con la Lecci�n 2.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lecci�n 2.1:  MANDATOS PARA BORRAR


       ** Escriba dw para borrar hasta el final de una palabra **


  1. Pulse <ESC> para asegurarse de que est� en el modo Normal.

  2. Mueva el cursor a la l�nea de abajo se�alada con --->.

  3. Mueva el cursor al comienzo de una palabra que desee borrar.

  4. Pulse   dw   para hacer que la palabra desaparezca.


  NOTA: Las letras   dw   aparecer�n en la �ltima l�nea de la pantalla cuando
	las escriba. Si escribe algo equivocado pulse <ESC> y comience de nuevo.


---> Hay algunas palabras p�salo bien que no pertenecen papel a esta frase.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		    Lecci�n 2.2: M�S MANDATOS PARA BORRAR


	  ** Escriba  d$  para borrar hasta el final de la l�nea. **


  1. Pulse  <ESC>  para asegurarse de que est� en el modo Normal.

  2. Mueva el cursor a la l�nea de abajo se�alada con --->.

  3. Mueva el cursor al final de la l�nea correcta (DESPU�S del primer . ).

  4. Escriba  d$  para borrar hasta el final de la l�nea.

---> Alguien ha escrito el final de esta l�nea dos veces. esta l�nea dos veces.







~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		    Lecci�n 2.3: SOBRE MANDATOS Y OBJETOS


  El formato del mandato de borrar   d	 es como sigue:

	 [n�mero]   d	objeto	    O	     d	 [n�mero]   objeto
  donde:
   n�mero - es cu�ntas veces se ha de ejecutar el mandato (opcional, defecto=1).
   d - es el mandato para borrar.
   objeto - es sobre lo que el mandato va a operar (lista, abajo).

  Una lista corta de objetos:
   w - desde el cursor hasta el final de la palabra, incluyendo el espacio.
   e - desde el cursor hasta el final de la palabra, SIN incluir el espacio.
   $ - desde el cursor hasta el final de la l�nea.

NOTE: Para los aventureros, pulsando s�lo el objeto estando en modo Normal
      sin un mandato mover� el cursor como se especifica en la lista de objetos.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	       Lecci�n 2.4: UNA EXCEPCI�N AL 'MANDATO-OBJETO'

	   ** Escriba	dd   para borrar una l�nea entera. **

  Debido a la frecuencia con que se borran l�neas enteras, los dise�adores
  de Vim decidieron que ser�a m�s f�cil el escribir simplemente dos des en
  una fila para borrar	una l�nea.

  1. Mueva el cursor a la segunda l�nea de la lista de abajo.
  2. Escriba  dd  para borrar la l�nea.
  3. Mu�vase ahora a la cuarta l�nea.
  4. Escriba   2dd   (recuerde	n�mero-mandato-objeto) para borrar las dos
     l�neas.

      1) Las rosas son rojas,
      2) El barro es divertido,
      3) El cielo es azul,
      4) Yo tengo un coche,
      5) Los relojes marcan la hora,
      6) El azucar es dulce,
      7) Y as� eres tu.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		       Lecci�n 2.5: EL MANDATO DESHACER


   ** Pulse  u	para deshacer los �ltimos mandatos,
	     U	para deshacer una l�nea entera.       **

  1. Mueva el cursor a la l�nea de abajo se�alada con ---> y sit�elo bajo el
     primer error.
  2. Pulse  x  para borrar el primer car�ter err�neo.
  3. Pulse ahora  u  para deshacer el �ltimo mandato ejecutado.
  4. Ahora corrija todos los errores de la l�nea usando el mandato  x.
  5. Pulse ahora  U  may�scula para devolver la l�nea a su estado original.
  6. Pulse ahora  u  unas pocas veces para deshacer lo hecho por  U  y los
     mandatos previos.
  7. Ahora pulse CTRL-R (mantenga pulsada la tecla CTRL y pulse R) unas
     pocas veces para volver a ejecutar los mandatos (deshacer lo deshecho).

---> Corrrija los errores dee esttta l�nea y vuuelva a ponerlos coon deshacer.

  8. Estos mandatos son muy �tiles. Ahora pase al resumen de la Lecci�n 2.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			    RESUMEN DE LA LECCI�N 2

  1. Para borrar desde el cursor hasta el final de una palabra pulse:	dw

  2. Para borrar desde el cursor hasta el final de una l�nea pulse:	d$

  3. Para borrar una l�nea enter pulse:    dd

  4. El formato de un mandato en modo Normal es:

       [n�mero]   mandato   objeto   O	 mandato   [n�mero]   objeto
     donde:
       n�mero - es cu�ntas veces se ha de ejecutar el mandato
       mandato - es lo que hay que hacer, por ejemplo, d para borrar
       objeto - es sobre lo que el mandato va a operar, por ejemplo
		w (palabra), $ (hasta el final de la l�nea), etc.

  5. Para deshacer acciones previas pulse:		 u (u min�scula)
     Para deshacer todos los cambios de una l�nea pulse: U (U may�scula)
     Para deshacer lo deshecho pulse:			 CTRL-R


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			 Lecci�n 3.1: EL MANDATO �PUT� (poner)

  ** Pulse p para poner lo �ltimo que ha borrado despu�s del cursor. **

  1. Mueva el cursor al final de la lista de abajo.

  2. Escriba  dd  para borrar la l�nea y almacenarla en el buffer de Vim.

  3. Mueva el cursor a la l�nea que debe quedar por debajo de la
     l�nea a mover.

  4. Estando en mod Normal, pulse   p	para restituir la l�nea borrada.

  5. Repita los pasos 2 a 4 para poner todas las l�neas en el orden correcto.

     d) �Puedes aprenderla tu?
     b) Las violetas son azules,
     c) La inteligencia se aprende,
     a) Las rosas son rojas,

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		       Lecci�n 3.2: EL MANDATO �REPLACE� (remplazar)


  ** Pulse  r  y un car�cter para sustituir el car�cter sobre el cursor. **


  1. Mueva el cursor a la primera l�nea de abajo se�alada con --->.

  2. Mueva el cursor para situarlo bajo el primer error.

  3. Pulse   r	 y el car�cter que debe sustituir al err�neo.

  4. Repita los pasos 2 y 3 hasta que la primera l�nea est� corregida.

---> �Cuendo esta l�nea fue rscrita alguien pulso algunas teclas equibocadas!
---> �Cuando esta l�nea fue escrita alguien puls� algunas teclas equivocadas!






~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			Lecci�n 3.3: EL MANDATO �CHANGE� (cambiar)


     ** Para cambiar parte de una palabra o toda ella escriba  cw . **


  1. Mueva el cursor a la primera l�nea de abajo se�alada con --->.

  2. Sit�e el cursor en la u de lubrs.

  3. Escriba  cw  y corrija la palabra (en este caso, escriba '�nea').

  4. Pulse <ESC> y mueva el cursor al error siguiente (el primer car�cter
     que deba cambiarse).

  5. Repita los pasos 3 y 4 hasta que la primera frase sea igual a la segunda.

---> Esta lubrs tiene unas pocas pskavtad que corregir usem el mandato change.
---> Esta l�nea tiene unas pocas palabras que corregir usando el mandato change.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		      Lecci�n 3.4: M�S CAMBIOS USANDO c

   ** El mandato change se utiliza con los mismos objetos que delete. **

  1. El mandato change funciona de la misma forma que delete. El formato es:

       [n�mero]   c   objeto	   O	    c	[n�mero]   objeto

  2. Los objetos son tambi�m los mismos, tales como  w (palabra), $ (fin de
     la l�nea), etc.

  3. Mueva el cursor a la primera l�nea de abajo se�alada con --->.

  4. Mueva el cursor al primer error.

  5. Escriba  c$  para hacer que el resto de la l�nea sea como la segunda
     y pulse <ESC>.

---> El final de esta l�nea necesita alguna ayuda para que sea como la segunda.
---> El final de esta l�nea necesita ser corregido usando el mandato  c$.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			    RESUMEN DE LA LECCI�N 3


  1. Para sustituir texto que ha sido borrado, pulse  p . Esto Pone el texto
     borrado DESPU�S del cursor (si lo que se ha borrado es una l�nea se
     situar� sobre la l�nea que est� sobre el cursor).

  2. Para sustituir el car�cter bajo el cursor, pulse	r   y luego el
     car�cter que sustituir� al original.

  3. El mandato change le permite cambiar el objeto especificado desde la
     posici�n del cursor hasta el final del objeto; e.g. Pulse	cw  para
     cambiar desde el cursor hasta el final de la palabra, c$  para cambiar
     hasta el final de la l�nea.

  4. El formato para change es:

	 [n�mero]   c	objeto	      O		c   [n�mero]   objeto

  Pase ahora a la lecci�n siguiente.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	       Lecci�n 4.1: SITUACI�N EN EL FICHERO Y SU ESTADO


 ** Pulse CTRL-g para mostrar su situaci�n en el fichero y su estado.
    Pulse MAYU-G para moverse a una determinada l�nea del fichero. **

  Nota: ��Lea esta lecci�n entera antes de ejecutar alguno de los pasos!!


  1. Mantenga pulsada la tecla Ctrl y pulse  g . Aparece una l�nea de estado
     al final de la pantalla con el nombre del fichero y la l�nea en la que
     est� situado. Recuerde el n�mero de la l�nea para el Paso 3.

  2. Pulse Mayu-G para ir al final del fichero.

  3. Escriba el n�mero de la l�nea en la que estaba y desp�es Mayu-G. Esto
     le volver� a la l�nea en la que estaba cuando puls� Ctrl-g.
     (Cuando escriba los n�meros NO se mostrar�n en la pantalla).

  4. Si se siente confiado en poder hacer esto ejecute los pasos 1 a 3.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			Lecci�n 4.2: EL MANDATO �SEARCH� (buscar)

     ** Escriba  /  seguido de una frase para buscar la frase. **

  1. En modo Normal pulse el car�cter  / . F�jese que tanto el car�cter  /
     como el cursor aparecen en la �ltima l�nea de la pantalla, lo mismo
     que el mandato  : .

  2. Escriba ahora   errroor   <INTRO>. Esta es la palabra que quiere buscar.

  3. Para repetir la b�squeda, simplemente pulse  n .
     Para busacar la misma frase en la direcci�n opuesta, pulse Mayu-N .

  4. Si quiere buscar una frase en la direcci�n opuesta (hacia arriba),
     utilice el mandato  ?  en lugar de  / .

---> Cuando la b�squeda alcanza el final del fichero continuar� desde el
     principio.

  �errroor� no es la forma de deletrear error; errroor es un error.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	       Lecci�n 4.3: B�SQUEDA PARA COMPROBAR PAR�NTESIS

   ** Pulse %  para encontrar el par�ntesis correspondiente a ),] o } . **


  1. Sit�e el cursor en cualquiera de los caracteres ), ] o } en la l�nea de
     abajo se�alada con --->.

  2. Pulse ahora el car�cter  %  .

  3. El cursor deber�a situarse en el par�ntesis (, corchete [ o llave {
     correspondiente.

  4. Pulse  %  para mover de nuevo el cursor al par�ntesis, corchete o llave
     correspondiente.

---> Esto ( es una l�nea de prueba con (, [, ], {, y } en ella. )).

Nota: �Esto es muy �til en la detecci�n de errores en un programa con
      par�ntesis, corchetes o llaves disparejos.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		  Lecci�n 4.4: UNA FORMA DE CAMBIAR ERRORES


    ** Escriba	:s/viejo/nuevo/g para sustituir 'viejo' por 'nuevo'. **


  1. Mueva el cursor a la l�nea de abajo se�alada con --->.

  2. Escriba  :s/laas/las/  <INTRO> . Tenga en cuenta que este mandato cambia
     s�lo la primera aparici�n en la l�nea de la expresi�n a cambiar.

---> Laas mejores �pocas para ver laas flores son laas primaveras.

  4. Para cambiar todas las apariciones de una expresi�n ente dos l�neas
     escriba   :#,#s/viejo/nuevo/g   donde #,# son los n�meros de las dos
     l�neas. Escriba   :%s/viejo/nuevo/g   para hacer los cambios en todo
     el fichero.





~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			    RESUMEN DE LA LECCI�N 4


  1. Ctrl-g  muestra la posici�n del cursor en el fichero y su estado.
     Mayu-G mueve el cursor al final del fichero. Un n�mero de l�nea
     sewguido de Mayu-G mueve el cursor a la l�nea con ese n�mero.

  2. Pulsando  /  seguido de una frase busca la frase hacia ADELANTE.
     Pulsando  ?  seguido de una frase busca la frase hacia ATR�S.
     Despu�s de una b�squeda pulse  n  para encontrar la aparici�n
     siguiente en la misma direcci�n.

  3. Pulsando  %  cuando el cursor esta sobre (,), [,], { o } localiza
     la pareja correspondiente.

  4. Para cambiar viejo por nuevo en una l�nea pulse	      :s/viejo/nuevo
     Para cambiar todos los viejo por nuevo en una l�nea pulse :s/viejo/nuevo/g
     Para cambiar frases entre dos n�meros de l�neas pulse  :#,#s/viejo/nuevo/g
     Para cambiar viejo por nuevo en todo el fichero pulse  :%s/viejo/nuevo/g
     Para pedir confirmaci�n en cada caso a�ada  'c'	    :%s/viejo/nuevo/gc


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		Lecci�n 5.1: C�MO EJECUTAR UN MANDATO EXTERNO


  ** Escriba  :!  seguido de un mandato externo para ejecutar ese mandato. **


  1. Escriba el conocido mandato  :  para situar el cursor al final de la
     pantalla. Esto le permitir� introducir un mandato.

  2. Ahora escriba el car�cter ! (signo de admiraci�n). Esto le permitir�
     ejecutar cualquier mandato del sistema.

  3. Como ejemplo escriba   ls	 despu�s del ! y luego pulse <INTRO>. Esto
     le mostrar� una lista de su directorio, igual que si estuviera en el
     s�mbolo del sistema. Si  ls  no funciona utilice	!:dir	.

--->Nota: De esta manera es posible ejecutar cualquier mandato externo.

--->Nota: Todos los mandatos   :   deben finalizarse pulsando <INTRO>.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lecci�n 5.2: M�S SOBRE GUARDAR FICHEROS


     ** Para guardar los cambios hechos en un fichero,
	escriba  :w NOMBRE_DE_FICHERO. **


  1. Escriba  :!dir  o	:!ls  para ver una lista de su directorio.
     Ya sabe que debe pulsar <INTRO> despu�s de ello.

  2. Elija un nombre de fichero que todav�a no exista, como TEST.

  3. Ahora escriba   :w TEST  (donde TEST es el nombre de fichero elegido).

  4. Esta acci�n guarda todo el fichero  (Vim Tutor)  bajo el nombre TEST.
     Para comprobarlo escriba	:!dir	de nuevo y vea su directorio.

---> Tenga en cuenta que si sale de Vim y  entra de nuevo con el nombre de
     fichero TEST, el fichero ser�a una copia exacta del tutor cuando lo
     ha guardado.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	       Lecci�n 5.3: UN MANDATO DE ESCRITURA SELECTIVO

   ** Para guardar parte del fuchero escriba   :#,# NOMBRE_DEL_FICHERO **


  1. Escriba de nuevo, una vez m�s,  :!dir  o  :!ls  para obtener una lista
     de su directorio y elija nombre de fichero adecuado, como TEST.

  2. Mueva el cursor al principio de la pantalla y pulse  Ctrl-g  para saber
     el n�mero de la l�nea correspondiente. �RECUERDE ESTE N�MERO!

  3. Ahora mueva el cursor a la �ltima l�nea de la pantalla y pulse Ctrl-g
     de nuevo. �RECUERDE TAMBI�N ESTE N�MERO!

  4. Para guardar SOLAMENTE una parte de un fichero, escriba  :#,# w TEST
     donde #,# son los n�meros que usted ha recordado (primera l�nea,
     �ltima l�nea) y TEST es su nombre de dichero.

  5. De nuevo, vea que el fichero esta ah� con	:!dir  pero NO lo borre.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		Lecci�n 5.4: RECUPERANDO Y MEZCLANDO FICHEROS

 ** Para insertar el contenido de un fichero escriba :r NOMBRE_DEL_FICHERO **

  1. Escriba   :!dir   para asegurarse de que su fichero TEST del ejercicio
     anterior est� presente.

  2. Situe el cursor al principio de esta pantalla.

NOTA: Despu�s de ejecutar el paso 3 se ver� la Lecci�n 5.3. Luego mu�vase
      hacia ABAJO para ver esta lecci�n de nuevo.

  3. Ahora recupere el fichero TEST utilizando el mandato  :r TEST  donde
     TEST es el nombre del fichero.

NOTA: El fichero recuperado se sit�a a partir de la posici�n del cursor.

  4. Para verificar que el fichero ha sido recuperado, mueva el cursor hacia
     arriba y vea que hay dos copias de la Lecci�n 5.3, la original y la
     versi�n del fichero.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			   RESUMEN DE LA LECCI�N 5


  1.  :!mandato  ejecuta un mandato externo.

      Algunos ejemplos �tiles son:
	  :!dir - muestra el contenido de un directorio.
	  :!del NOMBRE_DE_FICHERO  -  borra el fichero NOMBRE_DE FICHERO.

  2.  :#,#w NOMBRE_DE _FICHERO  guarda desde las l�neas # hasta la # en el
     fichero NOMBRE_DE_FICHERO.

  3.  :r NOMBRE_DE _FICHERO  recupera el fichero del disco NOMBRE_DE FICHERO
     y lo inserta en el fichero en curso a partir de la posici�n del cursor.







~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			 Lecci�n 6.1: EL MANDATO �OPEN� (abrir)


	 ** Pulse  o  para abrir una l�nea debajo del cursor
	    y situarle en modo Insert **


  1. Mueva el cursor a la l�nea de abajo se�alada con --->.

  2. Pulse  o (min�scula) para abrir una l�nea por DEBAJO del cursor
     y situarle en modo Insert.

  3. Ahora copie la l�nea se�alada con ---> y pulse <ESC> para salir del
     modo Insert.

---> Luego de pulsar  o  el cursor se sit�a en la l�nea abierta en modo Insert.

  4. Para abrir una l�nea por encima del cursor, simplemente pulse una O
     may�scula, en lugar de una o min�scula. Pruebe este en la l�nea siguiente.
Abra una l�nea sobre �sta pulsando Mayu-O cuando el curso est� en esta l�nea.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			Lecci�n 6.2: EL MANDATO �APPEND� (a�adir)

	 ** Pulse  a  para insertar texto DESPU�S del cursor. **


  1. Mueva el cursor al final de la primera l�nea de abajo se�alada con --->
     pulsando  $  en modo Normal.

  2. Escriba una  a  (min�scula) para a�adir texto DESPU�S del car�cter
     que est� sobre el cursor. (A may�scula a�ade texto al final de la l�nea).

Nota: �Esto evita el pulsar  i , el �ltimo car�cter, el texto a insertar,
      <ESC>, cursor a la derecha y, finalmente, x , s�lo para a�adir algo
      al final de una l�nea!

  3. Complete ahora la primera l�nea. N�tese que append es exactamente lo
     mismo que modo Insert, excepto por el lugar donde se inserta el texto.

---> Esta l�nea le permitir� praticar
---> Esta l�nea le permitir� praticar el a�adido de texto al final de una l�nea.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		     Lecci�n 6.3: OTRA VERSI�N DE �REPLACE� (remplazar)

    ** Pulse una  R  may�scula para sustituir m�s de un car�cter. **


  1. Mueva el cursor a la primera l�nea de abajo se�alada con --->.

  2. Sit�e el cursor al comienzo de la primera palabra que sea diferente
     de las de la segunda l�nea marcada con ---> (la palabra 'anterior').

  3. Ahora pulse  R  y sustituya el resto del texto de la primera l�nea
     escribiendo sobre el viejo texto para que la primera l�nea sea igual
     que la primera.

---> Para hacer que esta l�nea sea igual que la anterior use las teclas.
---> Para hacer que esta l�nea sea igual que la siguiente escriba R y el texto.

  4. N�tese que cuando pulse <ESC> para salir, el texto no alterado permanece.



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			 Lecci�n 6.4: FIJAR OPCIONES

 ** Fijar una opci�n de forma que una b�squeda o sustituci�n ignore la caja **
  (Para el concepto de caja de una letra, v�ase la nota al final del fichero)


  1. Busque 'ignorar' introduciendo:
     /ignorar
     Repita varias veces la b�sque pulsando la tecla n

  2. Fije la opci�n 'ic' (Ignorar la caja de la letra) escribiendo:
     :set ic

  3. Ahora busque 'ignorar' de nuevo pulsando n
     Repita la b�squeda varias veces m�s pulsando la tecla n

  4. Fije las opciones 'hlsearch' y 'insearch':
     :set hls is

  5. Ahora introduzca la orden de b�squeda otra vez, y vea qu� pasa:
     /ignore

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			   RESUMEN DE LA LECCI�N 6


  1. Pulsando  o  abre una l�nea por DEBAJO del cursor y sit�a el cursor en
     la l�nea abierta en modo Insert.
     Pulsando una O may�scula se abre una l�nea SOBRE la que est� el cursor.

  2. Pulse una	a  para insertar texto DESPU�S del car�cter sobre el cursor.
     Pulsando una  A  may�scula a�ade autom�ticamente texto al final de la
     l�nea.

  3. Pulsando una  R  may�scula se entra en modo Replace hasta que, para salir,
     se pulse <ESC>.

  4. Escribiendo �:set xxx� fija la opci�n �xxx�







~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		  Lecci�n 7: MANDATOS PARA LA AYUDA EN L�NEA

		 ** Utilice el sistema de ayuda en l�nea **


  Vim dispone de un sistema de ayuda en l�nea. Para activarlo, pruebe una
  de estas tres formas:
	- pulse la tecla <AYUDA> (si dispone de ella)
	- pulse la tecla <F1> (si dispone de ella)
	- escriba   :help <INTRO>

  Escriba   :q <INTRO>	 para cerrar la ventana de ayuda.

  Puede encontrar ayuda en casi cualquier tema a�adiendo un argumento al
  mandato �:help� mandato. Pruebe �stos:

  :help w <INTRO>
  :help c_<T <INTRO>
  :help insert-index <INTRO>


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  Aqu� concluye el tutor de Vim. Est� pensado para dar una visi�n breve del
  editor Vim, lo suficiente para permitirle usar el editor de forma bastante
  sencilla. Est� muy lejos de estar completo pues Vim tiene much�simos m�s
  mandatos.

  Para lecturas y estudios posteriores se recomienda el libro:
	Learning the Vi Editor - por Linda Lamb
	Editorial: O'Reilly & Associates Inc.
  Es un buen libro para llegar a saber casi todo lo que desee hacer con Vi.
  La sexta edici�n incluye tambi�n informaci�n sobre Vim.

  Este tutorial ha sido escrito por Michael C. Pierce y Robert K. Ware,
  Colorado School of Mines utilizando ideas suministradas por Charles Smith,
  Colorado State University.
  E-mail: bware@mines.colorado.edu.

  Modificado para Vim por Bram Moolenaar.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  Traducido del ingl�s por:

  Eduardo F. Amatria
  Correo electr�nico: eferna1@platea.pntic.mec.es

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
