" Vim syntax file
" Language:    Lisp
" Maintainer:  Charles E. Campbell <NcampObell@SdrPchip.AorgM-NOSPAM>
" Last Change: Jul 11, 2019
" Version:     30
" URL:	http://www.drchip.org/astronaut/vim/index.html#SYNTAX_LISP
"
"  Thanks to F Xavier Noria for a list of 978 Common Lisp symbols taken from HyperSpec
"  Clisp additions courtesy of http://clisp.cvs.sourceforge.net/*checkout*/clisp/clisp/emacs/lisp.vim

" ---------------------------------------------------------------------
"  Load Once: {{{1
if exists("b:current_syntax")
 finish
endif

if exists("g:lisp_isk")
 exe "setl isk=".g:lisp_isk
elseif (v:version == 704 && has("patch-7.4.1142")) || v:version > 704
 syn iskeyword 38,42,43,45,47-58,60-62,64-90,97-122,_
else
 setl isk=38,42,43,45,47-58,60-62,64-90,97-122,_
endif

if exists("g:lispsyntax_ignorecase") || exists("g:lispsyntax_clisp")
 set ignorecase
endif

" ---------------------------------------------------------------------
" Clusters: {{{1
syn cluster			lispAtomCluster		contains=lispAtomBarSymbol,lispAtomList,lispAtomNmbr0,lispComment,lispDecl,lispFunc,lispLeadWhite
syn cluster			lispBaseListCluster	contains=lispAtom,lispAtomBarSymbol,lispAtomMark,lispBQList,lispBarSymbol,lispComment,lispConcat,lispDecl,lispFunc,lispKey,lispList,lispNumber,lispEscapeSpecial,lispSymbol,lispVar,lispLeadWhite
if exists("g:lisp_instring")
 syn cluster			lispListCluster		contains=@lispBaseListCluster,lispString,lispInString,lispInStringString
else
 syn cluster			lispListCluster		contains=@lispBaseListCluster,lispString
endif

syn case ignore

" ---------------------------------------------------------------------
" Lists: {{{1
syn match lispSymbol	contained	![^()'`,"; \t]\+!
syn match lispBarSymbol	contained	!|..\{-}|!
if exists("g:lisp_rainbow") && g:lisp_rainbow != 0
 syn region lispParen0           matchgroup=hlLevel0 start="`\=(" end=")" skip="|.\{-}|" contains=@lispListCluster,lispParen1
 syn region lispParen1 contained matchgroup=hlLevel1 start="`\=(" end=")" skip="|.\{-}|" contains=@lispListCluster,lispParen2
 syn region lispParen2 contained matchgroup=hlLevel2 start="`\=(" end=")" skip="|.\{-}|" contains=@lispListCluster,lispParen3
 syn region lispParen3 contained matchgroup=hlLevel3 start="`\=(" end=")" skip="|.\{-}|" contains=@lispListCluster,lispParen4
 syn region lispParen4 contained matchgroup=hlLevel4 start="`\=(" end=")" skip="|.\{-}|" contains=@lispListCluster,lispParen5
 syn region lispParen5 contained matchgroup=hlLevel5 start="`\=(" end=")" skip="|.\{-}|" contains=@lispListCluster,lispParen6
 syn region lispParen6 contained matchgroup=hlLevel6 start="`\=(" end=")" skip="|.\{-}|" contains=@lispListCluster,lispParen7
 syn region lispParen7 contained matchgroup=hlLevel7 start="`\=(" end=")" skip="|.\{-}|" contains=@lispListCluster,lispParen8
 syn region lispParen8 contained matchgroup=hlLevel8 start="`\=(" end=")" skip="|.\{-}|" contains=@lispListCluster,lispParen9
 syn region lispParen9 contained matchgroup=hlLevel9 start="`\=(" end=")" skip="|.\{-}|" contains=@lispListCluster,lispParen0
else
 syn region lispList			matchgroup=lispParen start="("   skip="|.\{-}|"			matchgroup=lispParen end=")"	contains=@lispListCluster
 syn region lispBQList			matchgroup=PreProc   start="`("  skip="|.\{-}|"			matchgroup=PreProc   end=")"		contains=@lispListCluster
endif

" ---------------------------------------------------------------------
" Atoms: {{{1
syn match lispAtomMark			"'"
syn match lispAtom			"'("me=e-1			contains=lispAtomMark	nextgroup=lispAtomList
syn match lispAtom			"'[^ \t()]\+"			contains=lispAtomMark
syn match lispAtomBarSymbol		!'|..\{-}|!			contains=lispAtomMark
syn region lispAtom			start=+'"+			skip=+\\"+ end=+"+
syn region lispAtomList			contained			matchgroup=Special start="("	skip="|.\{-}|" matchgroup=Special end=")"	contains=@lispAtomCluster,lispString,lispEscapeSpecial
syn match lispAtomNmbr			contained			"\<\d\+"
syn match lispLeadWhite			contained			"^\s\+"

" ---------------------------------------------------------------------
" Standard Lisp Functions and Macros: {{{1
syn keyword lispFunc		<				find-method				pprint-indent
syn keyword lispFunc		<=				find-package				pprint-linear
syn keyword lispFunc		=				find-restart				pprint-logical-block
syn keyword lispFunc		>				find-symbol				pprint-newline
syn keyword lispFunc		>=				finish-output				pprint-pop
syn keyword lispFunc		-				first					pprint-tab
syn keyword lispFunc		/				fixnum					pprint-tabular
syn keyword lispFunc		/=				flet					prin1
syn keyword lispFunc		//				float					prin1-to-string
syn keyword lispFunc		///				float-digits				princ
syn keyword lispFunc		*				floating-point-inexact			princ-to-string
syn keyword lispFunc		**				floating-point-invalid-operation	print
syn keyword lispFunc		***				floating-point-overflow			print-not-readable
syn keyword lispFunc		+				floating-point-underflow		print-not-readable-object
syn keyword lispFunc		++				floatp					print-object
syn keyword lispFunc		+++				float-precision				print-unreadable-object
syn keyword lispFunc		1-				float-radix				probe-file
syn keyword lispFunc		1+				float-sign				proclaim
syn keyword lispFunc		abort				floor					prog
syn keyword lispFunc		abs				fmakunbound				prog*
syn keyword lispFunc		access				force-output				prog1
syn keyword lispFunc		acons				format					prog2
syn keyword lispFunc		acos				formatter				progn
syn keyword lispFunc		acosh				fourth					program-error
syn keyword lispFunc		add-method			fresh-line				progv
syn keyword lispFunc		adjoin				fround					provide
syn keyword lispFunc		adjustable-array-p		ftruncate				psetf
syn keyword lispFunc		adjust-array			ftype					psetq
syn keyword lispFunc		allocate-instance		funcall					push
syn keyword lispFunc		alpha-char-p			function				pushnew
syn keyword lispFunc		alphanumericp			function-keywords			putprop
syn keyword lispFunc		and				function-lambda-expression		quote
syn keyword lispFunc		append				functionp				random
syn keyword lispFunc		apply				gbitp					random-state
syn keyword lispFunc		applyhook			gcd					random-state-p
syn keyword lispFunc		apropos				generic-function			rassoc
syn keyword lispFunc		apropos-list			gensym					rassoc-if
syn keyword lispFunc		aref				gentemp					rassoc-if-not
syn keyword lispFunc		arithmetic-error		get					ratio
syn keyword lispFunc		arithmetic-error-operands	get-decoded-time			rational
syn keyword lispFunc		arithmetic-error-operation	get-dispatch-macro-character		rationalize
syn keyword lispFunc		array				getf					rationalp
syn keyword lispFunc		array-dimension			gethash					read
syn keyword lispFunc		array-dimension-limit		get-internal-real-time			read-byte
syn keyword lispFunc		array-dimensions		get-internal-run-time			read-char
syn keyword lispFunc		array-displacement		get-macro-character			read-char-no-hang
syn keyword lispFunc		array-element-type		get-output-stream-string		read-delimited-list
syn keyword lispFunc		array-has-fill-pointer-p	get-properties				reader-error
syn keyword lispFunc		array-in-bounds-p		get-setf-expansion			read-eval-print
syn keyword lispFunc		arrayp				get-setf-method				read-from-string
syn keyword lispFunc		array-rank			get-universal-time			read-line
syn keyword lispFunc		array-rank-limit		go					read-preserving-whitespace
syn keyword lispFunc		array-row-major-index		graphic-char-p				read-sequence
syn keyword lispFunc		array-total-size		handler-bind				readtable
syn keyword lispFunc		array-total-size-limit		handler-case				readtable-case
syn keyword lispFunc		ash				hash-table				readtablep
syn keyword lispFunc		asin				hash-table-count			real
syn keyword lispFunc		asinh				hash-table-p				realp
syn keyword lispFunc		assert				hash-table-rehash-size			realpart
syn keyword lispFunc		assoc				hash-table-rehash-threshold		reduce
syn keyword lispFunc		assoc-if			hash-table-size				reinitialize-instance
syn keyword lispFunc		assoc-if-not			hash-table-test				rem
syn keyword lispFunc		atan				host-namestring				remf
syn keyword lispFunc		atanh				identity				remhash
syn keyword lispFunc		atom				if					remove
syn keyword lispFunc		base-char			if-exists				remove-duplicates
syn keyword lispFunc		base-string			ignorable				remove-if
syn keyword lispFunc		bignum				ignore					remove-if-not
syn keyword lispFunc		bit				ignore-errors				remove-method
syn keyword lispFunc		bit-and				imagpart				remprop
syn keyword lispFunc		bit-andc1			import					rename-file
syn keyword lispFunc		bit-andc2			incf					rename-package
syn keyword lispFunc		bit-eqv				initialize-instance			replace
syn keyword lispFunc		bit-ior				inline					require
syn keyword lispFunc		bit-nand			in-package				rest
syn keyword lispFunc		bit-nor				in-package				restart
syn keyword lispFunc		bit-not				input-stream-p				restart-bind
syn keyword lispFunc		bit-orc1			inspect					restart-case
syn keyword lispFunc		bit-orc2			int-char				restart-name
syn keyword lispFunc		bit-vector			integer					return
syn keyword lispFunc		bit-vector-p			integer-decode-float			return-from
syn keyword lispFunc		bit-xor				integer-length				revappend
syn keyword lispFunc		block				integerp				reverse
syn keyword lispFunc		boole				interactive-stream-p			room
syn keyword lispFunc		boole-1				intern					rotatef
syn keyword lispFunc		boole-2				internal-time-units-per-second		round
syn keyword lispFunc		boolean				intersection				row-major-aref
syn keyword lispFunc		boole-and			invalid-method-error			rplaca
syn keyword lispFunc		boole-andc1			invoke-debugger				rplacd
syn keyword lispFunc		boole-andc2			invoke-restart				safety
syn keyword lispFunc		boole-c1			invoke-restart-interactively		satisfies
syn keyword lispFunc		boole-c2			isqrt					sbit
syn keyword lispFunc		boole-clr			keyword					scale-float
syn keyword lispFunc		boole-eqv			keywordp				schar
syn keyword lispFunc		boole-ior			labels					search
syn keyword lispFunc		boole-nand			lambda					second
syn keyword lispFunc		boole-nor			lambda-list-keywords			sequence
syn keyword lispFunc		boole-orc1			lambda-parameters-limit			serious-condition
syn keyword lispFunc		boole-orc2			last					set
syn keyword lispFunc		boole-set			lcm					set-char-bit
syn keyword lispFunc		boole-xor			ldb					set-difference
syn keyword lispFunc		both-case-p			ldb-test				set-dispatch-macro-character
syn keyword lispFunc		boundp				ldiff					set-exclusive-or
syn keyword lispFunc		break				least-negative-double-float		setf
syn keyword lispFunc		broadcast-stream		least-negative-long-float		set-macro-character
syn keyword lispFunc		broadcast-stream-streams	least-negative-normalized-double-float	set-pprint-dispatch
syn keyword lispFunc		built-in-class			least-negative-normalized-long-float	setq
syn keyword lispFunc		butlast				least-negative-normalized-short-float	set-syntax-from-char
syn keyword lispFunc		byte				least-negative-normalized-single-float	seventh
syn keyword lispFunc		byte-position			least-negative-short-float		shadow
syn keyword lispFunc		byte-size			least-negative-single-float		shadowing-import
syn keyword lispFunc		call-arguments-limit		least-positive-double-float		shared-initialize
syn keyword lispFunc		call-method			least-positive-long-float		shiftf
syn keyword lispFunc		call-next-method		least-positive-normalized-double-float	short-float
syn keyword lispFunc		capitalize			least-positive-normalized-long-float	short-float-epsilon
syn keyword lispFunc		car				least-positive-normalized-short-float	short-float-negative-epsilon
syn keyword lispFunc		case				least-positive-normalized-single-float	short-site-name
syn keyword lispFunc		catch				least-positive-short-float		signal
syn keyword lispFunc		ccase				least-positive-single-float		signed-byte
syn keyword lispFunc		cdr				length					signum
syn keyword lispFunc		ceiling				let					simple-array
syn keyword lispFunc		cell-error			let*					simple-base-string
syn keyword lispFunc		cell-error-name			lisp					simple-bit-vector
syn keyword lispFunc		cerror				lisp-implementation-type		simple-bit-vector-p
syn keyword lispFunc		change-class			lisp-implementation-version		simple-condition
syn keyword lispFunc		char				list					simple-condition-format-arguments
syn keyword lispFunc		char<				list*					simple-condition-format-control
syn keyword lispFunc		char<=				list-all-packages			simple-error
syn keyword lispFunc		char=				listen					simple-string
syn keyword lispFunc		char>				list-length				simple-string-p
syn keyword lispFunc		char>=				listp					simple-type-error
syn keyword lispFunc		char/=				load					simple-vector
syn keyword lispFunc		character			load-logical-pathname-translations	simple-vector-p
syn keyword lispFunc		characterp			load-time-value				simple-warning
syn keyword lispFunc		char-bit			locally					sin
syn keyword lispFunc		char-bits			log					single-flaot-epsilon
syn keyword lispFunc		char-bits-limit			logand					single-float
syn keyword lispFunc		char-code			logandc1				single-float-epsilon
syn keyword lispFunc		char-code-limit			logandc2				single-float-negative-epsilon
syn keyword lispFunc		char-control-bit		logbitp					sinh
syn keyword lispFunc		char-downcase			logcount				sixth
syn keyword lispFunc		char-equal			logeqv					sleep
syn keyword lispFunc		char-font			logical-pathname			slot-boundp
syn keyword lispFunc		char-font-limit			logical-pathname-translations		slot-exists-p
syn keyword lispFunc		char-greaterp			logior					slot-makunbound
syn keyword lispFunc		char-hyper-bit			lognand					slot-missing
syn keyword lispFunc		char-int			lognor					slot-unbound
syn keyword lispFunc		char-lessp			lognot					slot-value
syn keyword lispFunc		char-meta-bit			logorc1					software-type
syn keyword lispFunc		char-name			logorc2					software-version
syn keyword lispFunc		char-not-equal			logtest					some
syn keyword lispFunc		char-not-greaterp		logxor					sort
syn keyword lispFunc		char-not-lessp			long-float				space
syn keyword lispFunc		char-super-bit			long-float-epsilon			special
syn keyword lispFunc		char-upcase			long-float-negative-epsilon		special-form-p
syn keyword lispFunc		check-type			long-site-name				special-operator-p
syn keyword lispFunc		cis				loop					speed
syn keyword lispFunc		class				loop-finish				sqrt
syn keyword lispFunc		class-name			lower-case-p				stable-sort
syn keyword lispFunc		class-of			machine-instance			standard
syn keyword lispFunc		clear-input			machine-type				standard-char
syn keyword lispFunc		clear-output			machine-version				standard-char-p
syn keyword lispFunc		close				macroexpand				standard-class
syn keyword lispFunc		clrhash				macroexpand-1				standard-generic-function
syn keyword lispFunc		code-char			macroexpand-l				standard-method
syn keyword lispFunc		coerce				macro-function				standard-object
syn keyword lispFunc		commonp				macrolet				step
syn keyword lispFunc		compilation-speed		make-array				storage-condition
syn keyword lispFunc		compile				make-array				store-value
syn keyword lispFunc		compiled-function		make-broadcast-stream			stream
syn keyword lispFunc		compiled-function-p		make-char				stream-element-type
syn keyword lispFunc		compile-file			make-concatenated-stream		stream-error
syn keyword lispFunc		compile-file-pathname		make-condition				stream-error-stream
syn keyword lispFunc		compiler-let			make-dispatch-macro-character		stream-external-format
syn keyword lispFunc		compiler-macro			make-echo-stream			streamp
syn keyword lispFunc		compiler-macro-function		make-hash-table				streamup
syn keyword lispFunc		complement			make-instance				string
syn keyword lispFunc		complex				make-instances-obsolete			string<
syn keyword lispFunc		complexp			make-list				string<=
syn keyword lispFunc		compute-applicable-methods	make-load-form				string=
syn keyword lispFunc		compute-restarts		make-load-form-saving-slots		string>
syn keyword lispFunc		concatenate			make-method				string>=
syn keyword lispFunc		concatenated-stream		make-package				string/=
syn keyword lispFunc		concatenated-stream-streams	make-pathname				string-capitalize
syn keyword lispFunc		cond				make-random-state			string-char
syn keyword lispFunc		condition			make-sequence				string-char-p
syn keyword lispFunc		conjugate			make-string				string-downcase
syn keyword lispFunc		cons				make-string-input-stream		string-equal
syn keyword lispFunc		consp				make-string-output-stream		string-greaterp
syn keyword lispFunc		constantly			make-symbol				string-left-trim
syn keyword lispFunc		constantp			make-synonym-stream			string-lessp
syn keyword lispFunc		continue			make-two-way-stream			string-not-equal
syn keyword lispFunc		control-error			makunbound				string-not-greaterp
syn keyword lispFunc		copy-alist			map					string-not-lessp
syn keyword lispFunc		copy-list			mapc					stringp
syn keyword lispFunc		copy-pprint-dispatch		mapcan					string-right-strim
syn keyword lispFunc		copy-readtable			mapcar					string-right-trim
syn keyword lispFunc		copy-seq			mapcon					string-stream
syn keyword lispFunc		copy-structure			maphash					string-trim
syn keyword lispFunc		copy-symbol			map-into				string-upcase
syn keyword lispFunc		copy-tree			mapl					structure
syn keyword lispFunc		cos				maplist					structure-class
syn keyword lispFunc		cosh				mask-field				structure-object
syn keyword lispFunc		count				max					style-warning
syn keyword lispFunc		count-if			member					sublim
syn keyword lispFunc		count-if-not			member-if				sublis
syn keyword lispFunc		ctypecase			member-if-not				subseq
syn keyword lispFunc		debug				merge					subsetp
syn keyword lispFunc		decf				merge-pathname				subst
syn keyword lispFunc		declaim				merge-pathnames				subst-if
syn keyword lispFunc		declaration			method					subst-if-not
syn keyword lispFunc		declare				method-combination			substitute
syn keyword lispFunc		decode-float			method-combination-error		substitute-if
syn keyword lispFunc		decode-universal-time		method-qualifiers			substitute-if-not
syn keyword lispFunc		defclass			min					subtypep
syn keyword lispFunc		defconstant			minusp					svref
syn keyword lispFunc		defgeneric			mismatch				sxhash
syn keyword lispFunc		define-compiler-macro		mod					symbol
syn keyword lispFunc		define-condition		most-negative-double-float		symbol-function
syn keyword lispFunc		define-method-combination	most-negative-fixnum			symbol-macrolet
syn keyword lispFunc		define-modify-macro		most-negative-long-float		symbol-name
syn keyword lispFunc		define-setf-expander		most-negative-short-float		symbolp
syn keyword lispFunc		define-setf-method		most-negative-single-float		symbol-package
syn keyword lispFunc		define-symbol-macro		most-positive-double-float		symbol-plist
syn keyword lispFunc		defmacro			most-positive-fixnum			symbol-value
syn keyword lispFunc		defmethod			most-positive-long-float		synonym-stream
syn keyword lispFunc		defpackage			most-positive-short-float		synonym-stream-symbol
syn keyword lispFunc		defparameter			most-positive-single-float		sys
syn keyword lispFunc		defsetf				muffle-warning				system
syn keyword lispFunc		defstruct			multiple-value-bind			t
syn keyword lispFunc		deftype				multiple-value-call			tagbody
syn keyword lispFunc		defun				multiple-value-list			tailp
syn keyword lispFunc		defvar				multiple-value-prog1			tan
syn keyword lispFunc		delete				multiple-value-seteq			tanh
syn keyword lispFunc		delete-duplicates		multiple-value-setq			tenth
syn keyword lispFunc		delete-file			multiple-values-limit			terpri
syn keyword lispFunc		delete-if			name-char				the
syn keyword lispFunc		delete-if-not			namestring				third
syn keyword lispFunc		delete-package			nbutlast				throw
syn keyword lispFunc		denominator			nconc					time
syn keyword lispFunc		deposit-field			next-method-p				trace
syn keyword lispFunc		describe			nil					translate-logical-pathname
syn keyword lispFunc		describe-object			nintersection				translate-pathname
syn keyword lispFunc		destructuring-bind		ninth					tree-equal
syn keyword lispFunc		digit-char			no-applicable-method			truename
syn keyword lispFunc		digit-char-p			no-next-method				truncase
syn keyword lispFunc		directory			not					truncate
syn keyword lispFunc		directory-namestring		notany					two-way-stream
syn keyword lispFunc		disassemble			notevery				two-way-stream-input-stream
syn keyword lispFunc		division-by-zero		notinline				two-way-stream-output-stream
syn keyword lispFunc		do				nreconc					type
syn keyword lispFunc		do*				nreverse				typecase
syn keyword lispFunc		do-all-symbols			nset-difference				type-error
syn keyword lispFunc		documentation			nset-exclusive-or			type-error-datum
syn keyword lispFunc		do-exeternal-symbols		nstring					type-error-expected-type
syn keyword lispFunc		do-external-symbols		nstring-capitalize			type-of
syn keyword lispFunc		dolist				nstring-downcase			typep
syn keyword lispFunc		do-symbols			nstring-upcase				unbound-slot
syn keyword lispFunc		dotimes				nsublis					unbound-slot-instance
syn keyword lispFunc		double-float			nsubst					unbound-variable
syn keyword lispFunc		double-float-epsilon		nsubst-if				undefined-function
syn keyword lispFunc		double-float-negative-epsilon	nsubst-if-not				unexport
syn keyword lispFunc		dpb				nsubstitute				unintern
syn keyword lispFunc		dribble				nsubstitute-if				union
syn keyword lispFunc		dynamic-extent			nsubstitute-if-not			unless
syn keyword lispFunc		ecase				nth					unread
syn keyword lispFunc		echo-stream			nthcdr					unread-char
syn keyword lispFunc		echo-stream-input-stream	nth-value				unsigned-byte
syn keyword lispFunc		echo-stream-output-stream	null					untrace
syn keyword lispFunc		ed				number					unuse-package
syn keyword lispFunc		eighth				numberp					unwind-protect
syn keyword lispFunc		elt				numerator				update-instance-for-different-class
syn keyword lispFunc		encode-universal-time		nunion					update-instance-for-redefined-class
syn keyword lispFunc		end-of-file			oddp					upgraded-array-element-type
syn keyword lispFunc		endp				open					upgraded-complex-part-type
syn keyword lispFunc		enough-namestring		open-stream-p				upper-case-p
syn keyword lispFunc		ensure-directories-exist	optimize				use-package
syn keyword lispFunc		ensure-generic-function		or					user
syn keyword lispFunc		eq				otherwise				user-homedir-pathname
syn keyword lispFunc		eql				output-stream-p				use-value
syn keyword lispFunc		equal				package					values
syn keyword lispFunc		equalp				package-error				values-list
syn keyword lispFunc		error				package-error-package			variable
syn keyword lispFunc		etypecase			package-name				vector
syn keyword lispFunc		eval				package-nicknames			vectorp
syn keyword lispFunc		evalhook			packagep				vector-pop
syn keyword lispFunc		eval-when			package-shadowing-symbols		vector-push
syn keyword lispFunc		evenp				package-used-by-list			vector-push-extend
syn keyword lispFunc		every				package-use-list			warn
syn keyword lispFunc		exp				pairlis					warning
syn keyword lispFunc		export				parse-error				when
syn keyword lispFunc		expt				parse-integer				wild-pathname-p
syn keyword lispFunc		extended-char			parse-namestring			with-accessors
syn keyword lispFunc		fboundp				pathname				with-compilation-unit
syn keyword lispFunc		fceiling			pathname-device				with-condition-restarts
syn keyword lispFunc		fdefinition			pathname-directory			with-hash-table-iterator
syn keyword lispFunc		ffloor				pathname-host				with-input-from-string
syn keyword lispFunc		fifth				pathname-match-p			with-open-file
syn keyword lispFunc		file-author			pathname-name				with-open-stream
syn keyword lispFunc		file-error			pathnamep				with-output-to-string
syn keyword lispFunc		file-error-pathname		pathname-type				with-package-iterator
syn keyword lispFunc		file-length			pathname-version			with-simple-restart
syn keyword lispFunc		file-namestring			peek-char				with-slots
syn keyword lispFunc		file-position			phase					with-standard-io-syntax
syn keyword lispFunc		file-stream			pi					write
syn keyword lispFunc		file-string-length		plusp					write-byte
syn keyword lispFunc		file-write-date			pop					write-char
syn keyword lispFunc		fill				position				write-line
syn keyword lispFunc		fill-pointer			position-if				write-sequence
syn keyword lispFunc		find				position-if-not				write-string
syn keyword lispFunc		find-all-symbols		pprint					write-to-string
syn keyword lispFunc		find-class			pprint-dispatch				yes-or-no-p
syn keyword lispFunc		find-if				pprint-exit-if-list-exhausted		y-or-n-p
syn keyword lispFunc		find-if-not			pprint-fill				zerop

syn match   lispFunc		"\<c[ad]\+r\>"
if exists("g:lispsyntax_clisp")
  " CLISP FFI:
  syn match lispFunc	"\<\(ffi:\)\?with-c-\(place\|var\)\>"
  syn match lispFunc	"\<\(ffi:\)\?with-foreign-\(object\|string\)\>"
  syn match lispFunc	"\<\(ffi:\)\?default-foreign-\(language\|library\)\>"
  syn match lispFunc	"\<\([us]_\?\)\?\(element\|deref\|cast\|slot\|validp\)\>"
  syn match lispFunc	"\<\(ffi:\)\?set-foreign-pointer\>"
  syn match lispFunc	"\<\(ffi:\)\?allocate-\(deep\|shallow\)\>"
  syn match lispFunc	"\<\(ffi:\)\?c-lines\>"
  syn match lispFunc	"\<\(ffi:\)\?foreign-\(value\|free\|variable\|function\|object\)\>"
  syn match lispFunc	"\<\(ffi:\)\?foreign-address\(-null\|unsigned\)\?\>"
  syn match lispFunc	"\<\(ffi:\)\?undigned-foreign-address\>"
  syn match lispFunc	"\<\(ffi:\)\?c-var-\(address\|object\)\>"
  syn match lispFunc	"\<\(ffi:\)\?typeof\>"
  syn match lispFunc	"\<\(ffi:\)\?\(bit\)\?sizeof\>"
" CLISP Macros, functions et al:
  syn match lispFunc	"\<\(ext:\)\?with-collect\>"
  syn match lispFunc	"\<\(ext:\)\?letf\*\?\>"
  syn match lispFunc	"\<\(ext:\)\?finalize\>\>"
  syn match lispFunc	"\<\(ext:\)\?memoized\>"
  syn match lispFunc	"\<\(ext:\)\?getenv\>"
  syn match lispFunc	"\<\(ext:\)\?convert-string-\(to\|from\)-bytes\>"
  syn match lispFunc	"\<\(ext:\)\?ethe\>"
  syn match lispFunc	"\<\(ext:\)\?with-gensyms\>"
  syn match lispFunc	"\<\(ext:\)\?open-http\>"
  syn match lispFunc	"\<\(ext:\)\?string-concat\>"
  syn match lispFunc	"\<\(ext:\)\?with-http-\(in\|out\)put\>"
  syn match lispFunc	"\<\(ext:\)\?with-html-output\>"
  syn match lispFunc	"\<\(ext:\)\?expand-form\>"
  syn match lispFunc	"\<\(ext:\)\?\(without-\)\?package-lock\>"
  syn match lispFunc	"\<\(ext:\)\?re-export\>"
  syn match lispFunc	"\<\(ext:\)\?saveinitmem\>"
  syn match lispFunc	"\<\(ext:\)\?\(read\|write\)-\(integer\|float\)\>"
  syn match lispFunc	"\<\(ext:\)\?\(read\|write\)-\(char\|byte\)-sequence\>"
  syn match lispFunc	"\<\(custom:\)\?\*system-package-list\*\>"
  syn match lispFunc	"\<\(custom:\)\?\*ansi\*\>"
endif

" ---------------------------------------------------------------------
" Lisp Keywords (modifiers): {{{1
syn keyword lispKey		:abort				:from-end			:overwrite
syn keyword lispKey		:adjustable			:gensym				:predicate
syn keyword lispKey		:append				:host				:preserve-whitespace
syn keyword lispKey		:array				:if-does-not-exist		:pretty
syn keyword lispKey		:base				:if-exists			:print
syn keyword lispKey		:case				:include			:print-function
syn keyword lispKey		:circle				:index				:probe
syn keyword lispKey		:conc-name			:inherited			:radix
syn keyword lispKey		:constructor			:initial-contents		:read-only
syn keyword lispKey		:copier				:initial-element		:rehash-size
syn keyword lispKey		:count				:initial-offset			:rehash-threshold
syn keyword lispKey		:create				:initial-value			:rename
syn keyword lispKey		:default			:input				:rename-and-delete
syn keyword lispKey		:defaults			:internal			:size
syn keyword lispKey		:device				:io				:start
syn keyword lispKey		:direction			:junk-allowed			:start1
syn keyword lispKey		:directory			:key				:start2
syn keyword lispKey		:displaced-index-offset		:length				:stream
syn keyword lispKey		:displaced-to			:level				:supersede
syn keyword lispKey		:element-type			:name				:test
syn keyword lispKey		:end				:named				:test-not
syn keyword lispKey		:end1				:new-version			:type
syn keyword lispKey		:end2				:nicknames			:use
syn keyword lispKey		:error				:output				:verbose
syn keyword lispKey		:escape				:output-file			:version
syn keyword lispKey		:external
" defpackage arguments
syn keyword lispKey	:documentation	:shadowing-import-from	:modern		:export
syn keyword lispKey	:case-sensitive	:case-inverted		:shadow		:import-from	:intern
" lambda list keywords
syn keyword lispKey	&allow-other-keys	&aux		&body
syn keyword lispKey	&environment	&key			&optional	&rest		&whole
" make-array argument
syn keyword lispKey	:fill-pointer
" readtable-case values
syn keyword lispKey	:upcase		:downcase		:preserve	:invert
" eval-when situations
syn keyword lispKey	:load-toplevel	:compile-toplevel	:execute
" ANSI Extended LOOP:
syn keyword lispKey	:while      :until       :for         :do       :if          :then         :else     :when      :unless :in
syn keyword lispKey	:across     :finally     :collect     :nconc    :maximize    :minimize     :sum
syn keyword lispKey	:and        :with        :initially   :append   :into        :count        :end      :repeat
syn keyword lispKey	:always     :never       :thereis     :from     :to          :upto         :downto   :below
syn keyword lispKey	:above      :by          :on          :being    :each        :the          :hash-key :hash-keys
syn keyword lispKey	:hash-value :hash-values :using       :of-type  :upfrom      :downfrom
if exists("g:lispsyntax_clisp")
  " CLISP FFI:
  syn keyword lispKey	:arguments  :return-type :library     :full     :malloc-free
  syn keyword lispKey	:none       :alloca      :in          :out      :in-out      :stdc-stdcall :stdc     :c
  syn keyword lispKey	:language   :built-in    :typedef     :external
  syn keyword lispKey	:fini       :init-once   :init-always
endif

" ---------------------------------------------------------------------
" Standard Lisp Variables: {{{1
syn keyword lispVar		*applyhook*			*load-pathname*			*print-pprint-dispatch*
syn keyword lispVar		*break-on-signals*		*load-print*			*print-pprint-dispatch*
syn keyword lispVar		*break-on-signals*		*load-truename*			*print-pretty*
syn keyword lispVar		*break-on-warnings*		*load-verbose*			*print-radix*
syn keyword lispVar		*compile-file-pathname*		*macroexpand-hook*		*print-readably*
syn keyword lispVar		*compile-file-pathname*		*modules*			*print-right-margin*
syn keyword lispVar		*compile-file-truename*		*package*			*print-right-margin*
syn keyword lispVar		*compile-file-truename*		*print-array*			*query-io*
syn keyword lispVar		*compile-print*			*print-base*			*random-state*
syn keyword lispVar		*compile-verbose*		*print-case*			*read-base*
syn keyword lispVar		*compile-verbose*		*print-circle*			*read-default-float-format*
syn keyword lispVar		*debug-io*			*print-escape*			*read-eval*
syn keyword lispVar		*debugger-hook*			*print-gensym*			*read-suppress*
syn keyword lispVar		*default-pathname-defaults*	*print-length*			*readtable*
syn keyword lispVar		*error-output*			*print-level*			*standard-input*
syn keyword lispVar		*evalhook*			*print-lines*			*standard-output*
syn keyword lispVar		*features*			*print-miser-width*		*terminal-io*
syn keyword lispVar		*gensym-counter*		*print-miser-width*		*trace-output*

" ---------------------------------------------------------------------
" Strings: {{{1
syn region			lispString			start=+"+ skip=+\\\\\|\\"+ end=+"+	contains=@Spell
if exists("g:lisp_instring")
 syn region			lispInString			keepend matchgroup=Delimiter start=+"(+rs=s+1 skip=+|.\{-}|+ matchgroup=Delimiter end=+)"+ contains=@lispBaseListCluster,lispInStringString
 syn region			lispInStringString		start=+\\"+ skip=+\\\\+ end=+\\"+ contained
endif

" ---------------------------------------------------------------------
" Shared with Xlisp, Declarations, Macros, Functions: {{{1
syn keyword lispDecl		defmacro			do-all-symbols		labels
syn keyword lispDecl		defsetf				do-external-symbols	let
syn keyword lispDecl		deftype				do-symbols		locally
syn keyword lispDecl		defun				dotimes			macrolet
syn keyword lispDecl		do*				flet			multiple-value-bind
if exists("g:lispsyntax_clisp")
  " CLISP FFI:
  syn match lispDecl	"\<\(ffi:\)\?def-c-\(var\|const\|enum\|type\|struct\)\>"
  syn match lispDecl	"\<\(ffi:\)\?def-call-\(out\|in\)\>"
  syn match lispDecl	"\<\(ffi:\)\?c-\(function\|struct\|pointer\|string\)\>"
  syn match lispDecl	"\<\(ffi:\)\?c-ptr\(-null\)\?\>"
  syn match lispDecl	"\<\(ffi:\)\?c-array\(-ptr\|-max\)\?\>"
  syn match lispDecl	"\<\(ffi:\)\?[us]\?\(char\|short\|int\|long\)\>"
  syn match lispDecl	"\<\(win32:\|w32\)\?d\?word\>"
  syn match lispDecl	"\<\([us]_\?\)\?int\(8\|16\|32\|64\)\(_t\)\?\>"
  syn keyword lispDecl	size_t off_t time_t handle
endif

" ---------------------------------------------------------------------
" Numbers: supporting integers and floating point numbers {{{1
syn match lispNumber		"-\=\(\.\d\+\|\d\+\(\.\d*\)\=\)\([dDeEfFlL][-+]\=\d\+\)\="
syn match lispNumber		"-\=\(\d\+/\d\+\)"

syn match lispEscapeSpecial		"\*\w[a-z_0-9-]*\*"
syn match lispEscapeSpecial		!#|[^()'`,"; \t]\+|#!
syn match lispEscapeSpecial		!#x\x\+!
syn match lispEscapeSpecial		!#o\o\+!
syn match lispEscapeSpecial		!#b[01]\+!
syn match lispEscapeSpecial		!#\\[ -}\~]!
syn match lispEscapeSpecial		!#[':][^()'`,"; \t]\+!
syn match lispEscapeSpecial		!#([^()'`,"; \t]\+)!
syn match lispEscapeSpecial		!#\\\%(Space\|Newline\|Tab\|Page\|Rubout\|Linefeed\|Return\|Backspace\)!
syn match lispEscapeSpecial		"\<+[a-zA-Z_][a-zA-Z_0-9-]*+\>"

syn match lispConcat		"\s\.\s"
syn match lispParenError	")"

" ---------------------------------------------------------------------
" Comments: {{{1
syn cluster lispCommentGroup	contains=lispTodo,@Spell
syn match   lispComment		";.*$"				contains=@lispCommentGroup
syn region  lispCommentRegion	start="#|" end="|#"		contains=lispCommentRegion,@lispCommentGroup
syn keyword lispTodo		contained			combak			combak:			todo			todo:

" ---------------------------------------------------------------------
" Synchronization: {{{1
syn sync lines=100

" ---------------------------------------------------------------------
" Define Highlighting: {{{1
if !exists("skip_lisp_syntax_inits")

  hi def link lispCommentRegion		lispComment
  hi def link lispAtomNmbr		lispNumber
  hi def link lispAtomMark		lispMark
  hi def link lispInStringString	lispString

  hi def link lispAtom			Identifier
  hi def link lispAtomBarSymbol		Special
  hi def link lispBarSymbol		Special
  hi def link lispComment		Comment
  hi def link lispConcat		Statement
  hi def link lispDecl			Statement
  hi def link lispFunc			Statement
  hi def link lispKey			Type
  hi def link lispMark			Delimiter
  hi def link lispNumber		Number
  hi def link lispParenError		Error
  hi def link lispEscapeSpecial		Type
  hi def link lispString		String
  hi def link lispTodo			Todo
  hi def link lispVar			Statement

  if exists("g:lisp_rainbow") && g:lisp_rainbow != 0
   if &bg == "dark"
    hi def hlLevel0 ctermfg=red		guifg=red1
    hi def hlLevel1 ctermfg=yellow	guifg=orange1
    hi def hlLevel2 ctermfg=green	guifg=yellow1
    hi def hlLevel3 ctermfg=cyan	guifg=greenyellow
    hi def hlLevel4 ctermfg=magenta	guifg=green1
    hi def hlLevel5 ctermfg=red		guifg=springgreen1
    hi def hlLevel6 ctermfg=yellow	guifg=cyan1
    hi def hlLevel7 ctermfg=green	guifg=slateblue1
    hi def hlLevel8 ctermfg=cyan	guifg=magenta1
    hi def hlLevel9 ctermfg=magenta	guifg=purple1
   else
    hi def hlLevel0 ctermfg=red		guifg=red3
    hi def hlLevel1 ctermfg=darkyellow	guifg=orangered3
    hi def hlLevel2 ctermfg=darkgreen	guifg=orange2
    hi def hlLevel3 ctermfg=blue	guifg=yellow3
    hi def hlLevel4 ctermfg=darkmagenta	guifg=olivedrab4
    hi def hlLevel5 ctermfg=red		guifg=green4
    hi def hlLevel6 ctermfg=darkyellow	guifg=paleturquoise3
    hi def hlLevel7 ctermfg=darkgreen	guifg=deepskyblue4
    hi def hlLevel8 ctermfg=blue	guifg=darkslateblue
    hi def hlLevel9 ctermfg=darkmagenta	guifg=darkviolet
   endif
  else
    hi def link lispParen Delimiter
  endif

endif

let b:current_syntax = "lisp"

" ---------------------------------------------------------------------
" vim: ts=8 nowrap fdm=marker
