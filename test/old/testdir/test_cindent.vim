" Test for cinoptions and cindent
"

func Test_cino_hash()
  " Test that curbuf->b_ind_hash_comment is correctly reset
  new
  setlocal cindent cinoptions=#1
  setlocal cinoptions=
  call setline(1, ["#include <iostream>"])
  call cursor(1, 1)
  norm! o#include
  "call feedkeys("o#include\<esc>", 't')
  call assert_equal(["#include <iostream>", "#include"], getline(1,2))
  bwipe!
endfunc

func Test_cino_extern_c()
  " Test for cino-E

  let without_ind =<< trim [CODE]
    #ifdef __cplusplus
    extern "C" {
    #endif
    int func_a(void);
    #ifdef __cplusplus
    }
    #endif
  [CODE]

  let with_ind =<< trim [CODE]
    #ifdef __cplusplus
    extern "C" {
    #endif
    	int func_a(void);
    #ifdef __cplusplus
    }
    #endif
  [CODE]
  new
  setlocal cindent cinoptions=E0
  call setline(1, without_ind)
  call feedkeys("gg=G", 'tx')
  call assert_equal(with_ind, getline(1, '$'))

  setlocal cinoptions=E-s
  call setline(1, with_ind)
  call feedkeys("gg=G", 'tx')
  call assert_equal(without_ind, getline(1, '$'))

  setlocal cinoptions=Es
  let tests = [
        \ ['recognized', ['extern "C" {'], "\t\t;"],
        \ ['recognized', ['extern "C++" {'], "\t\t;"],
        \ ['recognized', ['extern /* com */ "C"{'], "\t\t;"],
        \ ['recognized', ['extern"C"{'], "\t\t;"],
        \ ['recognized', ['extern "C"', '{'], "\t\t;"],
        \ ['not recognized', ['extern {'], "\t;"],
        \ ['not recognized', ['extern /*"C"*/{'], "\t;"],
        \ ['not recognized', ['extern "C" //{'], ";"],
        \ ['not recognized', ['extern "C" /*{*/'], ";"],
        \ ]

  for pair in tests
    let lines = pair[1]
    call setline(1, lines)
    call feedkeys(len(lines) . "Go;", 'tx')
    call assert_equal(pair[2], getline(len(lines) + 1), 'Failed for "' . string(lines) . '"')
  endfor

  bwipe!
endfunc

func Test_cindent_rawstring()
  new
  setl cindent
  call feedkeys("i" .
          \ "int main() {\<CR>" .
          \ "R\"(\<CR>" .
          \ ")\";\<CR>" .
          \ "statement;\<Esc>", "x")
  call assert_equal("\tstatement;", getline(line('.')))
  bw!
endfunc

func Test_cindent_expr()
  new
  func! MyIndentFunction()
    return v:lnum == 1 ? shiftwidth() : 0
  endfunc
  setl expandtab sw=8 indentkeys+=; indentexpr=MyIndentFunction()
  let testinput =<< trim [CODE]
    var_a = something()
    b = something()
  [CODE]
  call setline(1, testinput)
  call cursor(1, 1)
  call feedkeys("^\<c-v>j$A;\<esc>", 'tnix')
  let expected =<< [CODE]
        var_a = something();
b = something();
[CODE]
  call assert_equal(expected, getline(1, '$'))

  %d
  let testinput =<< [CODE]
                var_a = something()
                b = something()
[CODE]
  call setline(1, testinput)
  call cursor(1, 1)
  call feedkeys("^\<c-v>j$A;\<esc>", 'tnix')
  let expected =<< [CODE]
        var_a = something();
                b = something()
[CODE]
  call assert_equal(expected, getline(1, '$'))
  bw!
endfunc

func Test_cindent_func()
  new
  setlocal cindent
  call setline(1, ['int main(void)', '{', 'return 0;', '}'])
  call assert_equal(-1, cindent(0))
  call assert_equal(&sw, 3->cindent())
  call assert_equal(-1, cindent(line('$')+1))
  bwipe!
endfunc

func Test_cindent_1()
  new
  setl cindent ts=4 sw=4
  setl cino& sts&

  let code =<< trim [CODE]
  /* start of AUTO matically checked vim: set ts=4 : */
  {
  	if (test)
  		cmd1;
  	cmd2;
  }

  {
  	if (test)
  		cmd1;
  	else
  		cmd2;
  }

  {
  	if (test)
  	{
  		cmd1;
  		cmd2;
  	}
  }

  {
  	if (test)
  	{
  		cmd1;
  		else
  	}
  }

  {
  	while (this)
  		if (test)
  			cmd1;
  	cmd2;
  }

  {
  	while (this)
  		if (test)
  			cmd1;
  		else
  			cmd2;
  }

  {
  	if (test)
  	{
  		cmd;
  	}

  	if (test)
  		cmd;
  }

  {
  	if (test) {
  		cmd;
  	}

  	if (test) cmd;
  }

  {
  	cmd1;
  	for (blah)
  		while (this)
  			if (test)
  				cmd2;
  	cmd3;
  }

  {
  	cmd1;
  	for (blah)
  		while (this)
  			if (test)
  				cmd2;
  	cmd3;

  	if (test)
  	{
  		cmd1;
  		cmd2;
  		cmd3;
  	}
  }


  /* Test for 'cindent' do/while mixed with if/else: */

  {
  	do
  		if (asdf)
  			asdfasd;
  	while (cond);

  	do
  		if (asdf)
  			while (asdf)
  				asdf;
  	while (asdf);
  }

  /* Test for 'cindent' with two ) on a continuation line */
  {
  	if (asdfasdf;asldkfj asdlkfj as;ldkfj sal;d
  			aal;sdkjf  ( ;asldfkja;sldfk
  					al;sdjfka ;slkdf ) sa;ldkjfsa dlk;)
  		line up here;
  }


  /* C++ tests: */

  // foo()		these three lines should remain in column 0
  // {
  // }

  /* Test for continuation and unterminated lines: */
  {
  	i = 99 + 14325 +
  		21345 +
  		21345 +
  		21345 + ( 21345 +
  				21345) +
  		2345 +
  		1234;
  	c = 1;
  }

  /*
     testje for indent with empty line

     here */

  {
  	if (testing &&
  			not a joke ||
  			line up here)
  		hay;
  	if (testing &&
  			(not a joke || testing
  			)line up here)
  		hay;
  	if (testing &&
  			(not a joke || testing
  			 line up here))
  		hay;
  }


  {
  	switch (c)
  	{
  		case xx:
  			do
  				if (asdf)
  					do
  						asdfasdf;
  					while (asdf);
  				else
  					asdfasdf;
  			while (cond);
  		case yy:
  		case xx:
  		case zz:
  			testing;
  	}
  }

  {
  	if (cond) {
  		foo;
  	}
  	else
  	{
  		bar;
  	}
  }

  {
  	if (alskdfj ;alsdkfjal;skdjf (;sadlkfsa ;dlkf j;alksdfj ;alskdjf
  			alsdkfj (asldk;fj
  					awith cino=(0 ;lf this one goes to below the paren with ==
  							;laksjfd ;lsakdjf ;alskdf asd)
  					asdfasdf;)))
  		asdfasdf;
  }

  	int
  func(a, b)
  	int a;
  	int c;
  {
  	if (c1 && (c2 ||
  			c3))
  		foo;
  	if (c1 &&
  			(c2 || c3)
  	   )
  }

  {
  	while (asd)
  	{
  		if (asdf)
  			if (test)
  				if (that)
  				{
  					if (asdf)
  						do
  							cdasd;
  						while (as
  								df);
  				}
  				else
  					if (asdf)
  						asdf;
  					else
  						asdf;
  		asdf;
  	}
  }

  {
  	s = "/*"; b = ';'
  		s = "/*"; b = ';';
  	a = b;
  }

  {
  	switch (a)
  	{
  		case a:
  			switch (t)
  			{
  				case 1:
  					cmd;
  					break;
  				case 2:
  					cmd;
  					break;
  			}
  			cmd;
  			break;
  		case b:
  			{
  				int i;
  				cmd;
  			}
  			break;
  		case c: {
  					int i;
  					cmd;
  				}
  		case d: if (cond &&
  						test) {		/* this line doesn't work right */
  					int i;
  					cmd;
  				}
  				break;
  	}
  }

  {
  	if (!(vim_strchr(p_cpo, CPO_BUFOPTGLOB) != NULL && entering) &&
  			(bp_to->b_p_initialized ||
  			 (!entering && vim_strchr(p_cpo, CPO_BUFOPT) != NULL)))
  		return;
  label :
  	asdf = asdf ?
  		asdf : asdf;
  	asdf = asdf ?
  		asdf: asdf;
  }

  /* Special Comments	: This function has the added complexity (compared  */
  /*					: to addtolist) of having to check for a detail     */
  /*					: texture and add that to the list first.	 	    */

  char *(array[100]) = {
  	"testje",
  	"foo",
  	"bar",
  }

  enum soppie
  {
  yes = 0,
  no,
  maybe
  };

  typedef enum soppie
  {
  yes = 0,
  no,
  maybe
  };

  static enum
  {
  yes = 0,
  no,
  maybe
  } soppie;

  public static enum
  {
  yes = 0,
  no,
  maybe
  } soppie;

  static private enum
  {
  yes = 0,
  no,
  maybe
  } soppie;

  {
  	int a,
  		b;
  }

  {
  	struct Type
  	{
  		int i;
  		char *str;
  	} var[] =
  	{
  		0, "zero",
  		1, "one",
  		2, "two",
  		3, "three"
  	};

  	float matrix[3][3] =
  	{
  		{
  			0,
  			1,
  			2
  		},
  		{
  			3,
  			4,
  			5
  		},
  		{
  			6,
  			7,
  			8
  		}
  	};
  }

  {
  	/* blah ( blah */
  	/* where does this go? */

  	/* blah ( blah */
  	cmd;

  	func(arg1,
  			/* comment */
  			arg2);
  	a;
  	{
  		b;
  		{
  			c; /* Hey, NOW it indents?! */
  		}
  	}

  	{
  		func(arg1,
  				arg2,
  				arg3);
  		/* Hey, what am I doing here?  Is this coz of the ","? */
  	}
  }

  main ()
  {
  	if (cond)
  	{
  		a = b;
  	}
  	if (cond) {
  		a = c;
  	}
  	if (cond)
  		a = d;
  	return;
  }

  {
  	case 2: if (asdf &&
  					asdfasdf)
  				aasdf;
  			a = 9;
  	case 3: if (asdf)
  				aasdf;
  			a = 9;
  	case 4:    x = 1;
  			   y = 2;

  label:	if (asdf)
  			here;

  label:  if (asdf &&
  				asdfasdf)
  		{
  		}

  label:  if (asdf &&
  				asdfasdf) {
  			there;
  		}

  label:  if (asdf &&
  				asdfasdf)
  			there;
  }

  {
  	/*
  	   hello with ":set comments= cino=c5"
  	 */

  	/*
  	   hello with ":set comments= cino="
  	 */
  }


  {
  	if (a < b) {
  		a = a + 1;
  	} else
  		a = a + 2;

  	if (a)
  		do {
  			testing;
  		} while (asdfasdf);
  	a = b + 1;
  	asdfasdf
  }

  {
  for ( int i = 0;
  	i < 10; i++ )
  {
  }
  	i = 0;
  }

  class bob
  {
  	int foo() {return 1;}
  		int bar;
  }

  main()
  {
  while(1)
  if (foo)
  {
  bar;
  }
  else {
  asdf;
  }
  misplacedline;
  }

  {
  	if (clipboard.state == SELECT_DONE
  	&& ((row == clipboard.start.lnum
  	&& col >= clipboard.start.col)
  	|| row > clipboard.start.lnum))
  }

  {
  if (1) {i += 4;}
  where_am_i;
  return 0;
  }

  {
  {
  } // sdf(asdf
  if (asdf)
  asd;
  }

  {
  label1:
  label2:
  }

  {
  int fooRet = foo(pBar1, false /*fKB*/,
  	true /*fPTB*/, 3 /*nT*/, false /*fDF*/);
  f() {
  for ( i = 0;
  	i < m;
  	/* c */ i++ ) {
  a = b;
  }
  }
  }

  {
  	f1(/*comment*/);
  	f2();
  }

  {
  do {
  if (foo) {
  } else
  ;
  } while (foo);
  foo();	// was wrong
  }

  int x;	    // no extra indent because of the ;
  void func()
  {
  }

  char *tab[] = {"aaa",
  	"};", /* }; */ NULL}
  	int indented;
  {}

  char *a[] = {"aaa", "bbb",
  	"ccc", NULL};
  // here

  char *tab[] = {"aaa",
  	"xx", /* xx */};    /* asdf */
  int not_indented;

  {
  	do {
  		switch (bla)
  		{
  			case 1: if (foo)
  						bar;
  		}
  	} while (boo);
  					wrong;
  }

  int	foo,
  	bar;
  int foo;

  #if defined(foo) \
  	&& defined(bar)
  char * xx = "asdf\
  	foo\
  	bor";
  int x;

  char    *foo = "asdf\
  	asdf\
  	asdf",
  	*bar;

  void f()
  {
  #if defined(foo) \
  	&& defined(bar)
  char    *foo = "asdf\
  	asdf\
  	asdf",
  	*bar;
  	{
  	int i;
  char    *foo = "asdf\
  	asdf\
  	asdf",
  	*bar;
  	}
  #endif
  }
  #endif

  int y;		// comment
  		// comment

  	// comment

  {
  	Constructor(int a,
  			int b )  : BaseClass(a)
  	{
  	}
  }

  void foo()
  {
  	char one,
  	two;
  	struct bla piet,
  	jan;
  	enum foo kees,
  	jannie;
  	static unsigned sdf,
  	krap;
  	unsigned int piet,
  	jan;
  	int
  	kees,
  	jan;
  }

  {
  	t(int f,
  			int d);		// )
  	d();
  }

  Constructor::Constructor(int a,
                           int b 
                          )  : 
     BaseClass(a,
               b,
               c),
     mMember(b),
  {
  }

  Constructor::Constructor(int a,
                           int b )  : 
     BaseClass(a)
  {
  }

  Constructor::Constructor(int a,
                           int b ) /*x*/ : /*x*/ BaseClass(a),
                                                 member(b)
  {
  }

  A::A(int a, int b)
  : aa(a),
  bb(b),
  cc(c)
  {
  }

  class CAbc :
     public BaseClass1,
     protected BaseClass2
  {
     int Test() { return FALSE; }
     int Test1() { return TRUE; }

     CAbc(int a, int b )  : 
        BaseClass(a)
     { 
        switch(xxx)
        {
           case abc:
              asdf();
              break;

           case 999:
              baer();
              break;
        }
     }

  public: // <-- this was incorrectly indented before!!
     void testfall();
  protected:
     void testfall();
  };

  class CAbc : public BaseClass1,
               protected BaseClass2
  {
  };

  static struct
  {
      int a;
      int b;
  } variable[COUNT] =
  {
      {
          123,
          456
      },
  	{
          123,
          456
      }
  };

  static struct
  {
      int a;
      int b;
  } variable[COUNT] =
  {
      { 123, 456 },
  	{ 123, 456 }
  };

  void asdf()		/* ind_maxparen may cause trouble here */
  {
  	if ((0
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1)) break;
  }

  foo()
  {
  	a = cond ? foo() : asdf
  					   + asdf;

  	a = cond ?
  		foo() : asdf
  				+ asdf;
  }

  int  main(void)
  {
  	if (a)
  		if (b)
  			2;
  		else 3;
  	next_line_of_code();
  }

  barry()
  {
  	Foo::Foo (int one,
  			int two)
  		: something(4)
  	{}
  }

  barry()
  {
  	Foo::Foo (int one, int two)
  		: something(4)
  	{}
  }

  Constructor::Constructor(int a,
  		int b 
  		)  : 
  	BaseClass(a,
  			b,
  			c),
  	mMember(b)
  {
  }
         int main ()
         {
  	 if (lala)
  	   do
  	     ++(*lolo);
  	   while (lili
  		  && lele);
  	   lulu;
         }

  int main ()
  {
  switch (c)
  {
  case 'c': if (cond)
  {
  }
  }
  }

  main()
  {
  	(void) MyFancyFuasdfadsfnction(
  			argument);
  }

  main()
  {
  	char	foo[] = "/*";
  	/* as
  	df */
  		hello
  }

  /* valid namespaces with normal indent */
  namespace
  {
  {
    111111111111;
  }
  }
  namespace /* test */
  {
    11111111111111111;
  }
  namespace // test
  {
    111111111111111111;
  }
  namespace
  {
    111111111111111111;
  }
  namespace test
  {
    111111111111111111;
  }
  namespace{
    111111111111111111;
  }
  namespace test{
    111111111111111111;
  }
  namespace {
    111111111111111111;
  }
  namespace test {
    111111111111111111;
  namespace test2 {
    22222222222222222;
  }
  }
  inline namespace {
    111111111111111111;
  }
  inline /* test */ namespace {
    111111111111111111;
  }
  inline/* test */namespace {
    111111111111111111;
  }

  /* invalid namespaces use block indent */
  namespace test test2 {
    111111111111111111111;
  }
  namespace11111111111 {
    111111111111;
  }
  namespace() {
    1111111111111;
  }
  namespace()
  {
    111111111111111111;
  }
  namespace test test2
  {
    1111111111111111111;
  }
  namespace111111111
  {
    111111111111111111;
  }
  inlinenamespace {
    111111111111111111;
  }

  void getstring() {
  /* Raw strings */
  const char* s = R"(
    test {
      # comment
      field: 123
    }
   )";
       }

  void getstring() {
  const char* s = R"foo(
    test {
      # comment
      field: 123
    }
      )foo";
       }

  {
  int a[4] = {
  [0] = 0,
  [1] = 1,
  [2] = 2,
  [3] = 3,
  };
  }

  {
  a = b[2]
  + 3;
  }

  {
  if (1)
  /* aaaaa
  * bbbbb
  */
  a = 1;
  }

  void func()
  {
  switch (foo)
  {
  case (bar):
  if (baz())
  quux();
  break;
  case (shmoo):
  if (!bar)
  {
  }
  case (foo1):
  switch (bar)
  {
  case baz:
  baz_f();
  break;
  }
  break;
  default:
  baz();
  baz();
  break;
  }
  }

  void foo() {
  float a[5],
  b;
  }

  void func() {
  if (0)
  do
  if (0);
  while (0);
  else;
  }

  void func() {
  if (0)
  do
  if (0)
  do
  if (0)
  a();
  while (0);
  while (0);
  else
  a();
  }

  /* end of AUTO */
  [CODE]

  call append(0, code)
  normal gg
  call search('start of AUTO')
  exe "normal =/end of AUTO\<CR>"

  let expected =<< trim [CODE]
  /* start of AUTO matically checked vim: set ts=4 : */
  {
  	if (test)
  		cmd1;
  	cmd2;
  }

  {
  	if (test)
  		cmd1;
  	else
  		cmd2;
  }

  {
  	if (test)
  	{
  		cmd1;
  		cmd2;
  	}
  }

  {
  	if (test)
  	{
  		cmd1;
  		else
  	}
  }

  {
  	while (this)
  		if (test)
  			cmd1;
  	cmd2;
  }

  {
  	while (this)
  		if (test)
  			cmd1;
  		else
  			cmd2;
  }

  {
  	if (test)
  	{
  		cmd;
  	}

  	if (test)
  		cmd;
  }

  {
  	if (test) {
  		cmd;
  	}

  	if (test) cmd;
  }

  {
  	cmd1;
  	for (blah)
  		while (this)
  			if (test)
  				cmd2;
  	cmd3;
  }

  {
  	cmd1;
  	for (blah)
  		while (this)
  			if (test)
  				cmd2;
  	cmd3;

  	if (test)
  	{
  		cmd1;
  		cmd2;
  		cmd3;
  	}
  }


  /* Test for 'cindent' do/while mixed with if/else: */

  {
  	do
  		if (asdf)
  			asdfasd;
  	while (cond);

  	do
  		if (asdf)
  			while (asdf)
  				asdf;
  	while (asdf);
  }

  /* Test for 'cindent' with two ) on a continuation line */
  {
  	if (asdfasdf;asldkfj asdlkfj as;ldkfj sal;d
  			aal;sdkjf  ( ;asldfkja;sldfk
  				al;sdjfka ;slkdf ) sa;ldkjfsa dlk;)
  		line up here;
  }


  /* C++ tests: */

  // foo()		these three lines should remain in column 0
  // {
  // }

  /* Test for continuation and unterminated lines: */
  {
  	i = 99 + 14325 +
  		21345 +
  		21345 +
  		21345 + ( 21345 +
  				21345) +
  		2345 +
  		1234;
  	c = 1;
  }

  /*
     testje for indent with empty line

     here */

  {
  	if (testing &&
  			not a joke ||
  			line up here)
  		hay;
  	if (testing &&
  			(not a joke || testing
  			)line up here)
  		hay;
  	if (testing &&
  			(not a joke || testing
  			 line up here))
  		hay;
  }


  {
  	switch (c)
  	{
  		case xx:
  			do
  				if (asdf)
  					do
  						asdfasdf;
  					while (asdf);
  				else
  					asdfasdf;
  			while (cond);
  		case yy:
  		case xx:
  		case zz:
  			testing;
  	}
  }

  {
  	if (cond) {
  		foo;
  	}
  	else
  	{
  		bar;
  	}
  }

  {
  	if (alskdfj ;alsdkfjal;skdjf (;sadlkfsa ;dlkf j;alksdfj ;alskdjf
  				alsdkfj (asldk;fj
  					awith cino=(0 ;lf this one goes to below the paren with ==
  						;laksjfd ;lsakdjf ;alskdf asd)
  					asdfasdf;)))
  		asdfasdf;
  }

  	int
  func(a, b)
  	int a;
  	int c;
  {
  	if (c1 && (c2 ||
  				c3))
  		foo;
  	if (c1 &&
  			(c2 || c3)
  	   )
  }

  {
  	while (asd)
  	{
  		if (asdf)
  			if (test)
  				if (that)
  				{
  					if (asdf)
  						do
  							cdasd;
  						while (as
  								df);
  				}
  				else
  					if (asdf)
  						asdf;
  					else
  						asdf;
  		asdf;
  	}
  }

  {
  	s = "/*"; b = ';'
  		s = "/*"; b = ';';
  	a = b;
  }

  {
  	switch (a)
  	{
  		case a:
  			switch (t)
  			{
  				case 1:
  					cmd;
  					break;
  				case 2:
  					cmd;
  					break;
  			}
  			cmd;
  			break;
  		case b:
  			{
  				int i;
  				cmd;
  			}
  			break;
  		case c: {
  					int i;
  					cmd;
  				}
  		case d: if (cond &&
  						test) {		/* this line doesn't work right */
  					int i;
  					cmd;
  				}
  				break;
  	}
  }

  {
  	if (!(vim_strchr(p_cpo, CPO_BUFOPTGLOB) != NULL && entering) &&
  			(bp_to->b_p_initialized ||
  			 (!entering && vim_strchr(p_cpo, CPO_BUFOPT) != NULL)))
  		return;
  label :
  	asdf = asdf ?
  		asdf : asdf;
  	asdf = asdf ?
  		asdf: asdf;
  }

  /* Special Comments	: This function has the added complexity (compared  */
  /*					: to addtolist) of having to check for a detail     */
  /*					: texture and add that to the list first.	 	    */

  char *(array[100]) = {
  	"testje",
  	"foo",
  	"bar",
  }

  enum soppie
  {
  	yes = 0,
  	no,
  	maybe
  };

  typedef enum soppie
  {
  	yes = 0,
  	no,
  	maybe
  };

  static enum
  {
  	yes = 0,
  	no,
  	maybe
  } soppie;

  public static enum
  {
  	yes = 0,
  	no,
  	maybe
  } soppie;

  static private enum
  {
  	yes = 0,
  	no,
  	maybe
  } soppie;

  {
  	int a,
  		b;
  }

  {
  	struct Type
  	{
  		int i;
  		char *str;
  	} var[] =
  	{
  		0, "zero",
  		1, "one",
  		2, "two",
  		3, "three"
  	};

  	float matrix[3][3] =
  	{
  		{
  			0,
  			1,
  			2
  		},
  		{
  			3,
  			4,
  			5
  		},
  		{
  			6,
  			7,
  			8
  		}
  	};
  }

  {
  	/* blah ( blah */
  	/* where does this go? */

  	/* blah ( blah */
  	cmd;

  	func(arg1,
  			/* comment */
  			arg2);
  	a;
  	{
  		b;
  		{
  			c; /* Hey, NOW it indents?! */
  		}
  	}

  	{
  		func(arg1,
  				arg2,
  				arg3);
  		/* Hey, what am I doing here?  Is this coz of the ","? */
  	}
  }

  main ()
  {
  	if (cond)
  	{
  		a = b;
  	}
  	if (cond) {
  		a = c;
  	}
  	if (cond)
  		a = d;
  	return;
  }

  {
  	case 2: if (asdf &&
  					asdfasdf)
  				aasdf;
  			a = 9;
  	case 3: if (asdf)
  				aasdf;
  			a = 9;
  	case 4:    x = 1;
  			   y = 2;

  label:	if (asdf)
  			here;

  label:  if (asdf &&
  				asdfasdf)
  		{
  		}

  label:  if (asdf &&
  				asdfasdf) {
  			there;
  		}

  label:  if (asdf &&
  				asdfasdf)
  			there;
  }

  {
  	/*
  	   hello with ":set comments= cino=c5"
  	 */

  	/*
  	   hello with ":set comments= cino="
  	 */
  }


  {
  	if (a < b) {
  		a = a + 1;
  	} else
  		a = a + 2;

  	if (a)
  		do {
  			testing;
  		} while (asdfasdf);
  	a = b + 1;
  	asdfasdf
  }

  {
  	for ( int i = 0;
  			i < 10; i++ )
  	{
  	}
  	i = 0;
  }

  class bob
  {
  	int foo() {return 1;}
  	int bar;
  }

  main()
  {
  	while(1)
  		if (foo)
  		{
  			bar;
  		}
  		else {
  			asdf;
  		}
  	misplacedline;
  }

  {
  	if (clipboard.state == SELECT_DONE
  			&& ((row == clipboard.start.lnum
  					&& col >= clipboard.start.col)
  				|| row > clipboard.start.lnum))
  }

  {
  	if (1) {i += 4;}
  	where_am_i;
  	return 0;
  }

  {
  	{
  	} // sdf(asdf
  	if (asdf)
  		asd;
  }

  {
  label1:
  label2:
  }

  {
  	int fooRet = foo(pBar1, false /*fKB*/,
  			true /*fPTB*/, 3 /*nT*/, false /*fDF*/);
  	f() {
  		for ( i = 0;
  				i < m;
  				/* c */ i++ ) {
  			a = b;
  		}
  	}
  }

  {
  	f1(/*comment*/);
  	f2();
  }

  {
  	do {
  		if (foo) {
  		} else
  			;
  	} while (foo);
  	foo();	// was wrong
  }

  int x;	    // no extra indent because of the ;
  void func()
  {
  }

  char *tab[] = {"aaa",
  	"};", /* }; */ NULL}
  	int indented;
  {}

  char *a[] = {"aaa", "bbb",
  	"ccc", NULL};
  // here

  char *tab[] = {"aaa",
  	"xx", /* xx */};    /* asdf */
  int not_indented;

  {
  	do {
  		switch (bla)
  		{
  			case 1: if (foo)
  						bar;
  		}
  	} while (boo);
  	wrong;
  }

  int	foo,
  	bar;
  int foo;

  #if defined(foo) \
  	&& defined(bar)
  char * xx = "asdf\
  			 foo\
  			 bor";
  int x;

  char    *foo = "asdf\
  				asdf\
  				asdf",
  		*bar;

  void f()
  {
  #if defined(foo) \
  	&& defined(bar)
  	char    *foo = "asdf\
  					asdf\
  					asdf",
  			*bar;
  	{
  		int i;
  		char    *foo = "asdf\
  						asdf\
  						asdf",
  				*bar;
  	}
  #endif
  }
  #endif

  int y;		// comment
			// comment

			// comment

  {
  	Constructor(int a,
  			int b )  : BaseClass(a)
  	{
  	}
  }

  void foo()
  {
  	char one,
  		 two;
  	struct bla piet,
  			   jan;
  	enum foo kees,
  			 jannie;
  	static unsigned sdf,
  					krap;
  	unsigned int piet,
  				 jan;
  	int
  		kees,
  		jan;
  }

  {
  	t(int f,
  			int d);		// )
  	d();
  }

  Constructor::Constructor(int a,
  		int b 
  		)  : 
  	BaseClass(a,
  			b,
  			c),
  	mMember(b),
  {
  }

  Constructor::Constructor(int a,
  		int b )  : 
  	BaseClass(a)
  {
  }

  Constructor::Constructor(int a,
  		int b ) /*x*/ : /*x*/ BaseClass(a),
  	member(b)
  {
  }

  A::A(int a, int b)
  	: aa(a),
  	bb(b),
  	cc(c)
  {
  }

  class CAbc :
  	public BaseClass1,
  	protected BaseClass2
  {
  	int Test() { return FALSE; }
  	int Test1() { return TRUE; }

  	CAbc(int a, int b )  : 
  		BaseClass(a)
  	{ 
  		switch(xxx)
  		{
  			case abc:
  				asdf();
  				break;

  			case 999:
  				baer();
  				break;
  		}
  	}

  	public: // <-- this was incorrectly indented before!!
  	void testfall();
  	protected:
  	void testfall();
  };

  class CAbc : public BaseClass1,
  	protected BaseClass2
  {
  };

  static struct
  {
  	int a;
  	int b;
  } variable[COUNT] =
  {
  	{
  		123,
  		456
  	},
  	{
  		123,
  		456
  	}
  };

  static struct
  {
  	int a;
  	int b;
  } variable[COUNT] =
  {
  	{ 123, 456 },
  	{ 123, 456 }
  };

  void asdf()		/* ind_maxparen may cause trouble here */
  {
  	if ((0
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1
  				&& 1)) break;
  }

  foo()
  {
  	a = cond ? foo() : asdf
  		+ asdf;

  	a = cond ?
  		foo() : asdf
  		+ asdf;
  }

  int  main(void)
  {
  	if (a)
  		if (b)
  			2;
  		else 3;
  	next_line_of_code();
  }

  barry()
  {
  	Foo::Foo (int one,
  			int two)
  		: something(4)
  	{}
  }

  barry()
  {
  	Foo::Foo (int one, int two)
  		: something(4)
  	{}
  }

  Constructor::Constructor(int a,
  		int b 
  		)  : 
  	BaseClass(a,
  			b,
  			c),
  	mMember(b)
  {
  }
  int main ()
  {
  	if (lala)
  		do
  			++(*lolo);
  		while (lili
  				&& lele);
  	lulu;
  }

  int main ()
  {
  	switch (c)
  	{
  		case 'c': if (cond)
  				  {
  				  }
  	}
  }

  main()
  {
  	(void) MyFancyFuasdfadsfnction(
  			argument);
  }

  main()
  {
  	char	foo[] = "/*";
  	/* as
  	   df */
  	hello
  }

  /* valid namespaces with normal indent */
  namespace
  {
  	{
  		111111111111;
  	}
  }
  namespace /* test */
  {
  	11111111111111111;
  }
  namespace // test
  {
  	111111111111111111;
  }
  namespace
  {
  	111111111111111111;
  }
  namespace test
  {
  	111111111111111111;
  }
  namespace{
  	111111111111111111;
  }
  namespace test{
  	111111111111111111;
  }
  namespace {
  	111111111111111111;
  }
  namespace test {
  	111111111111111111;
  	namespace test2 {
  		22222222222222222;
  	}
  }
  inline namespace {
  	111111111111111111;
  }
  inline /* test */ namespace {
  	111111111111111111;
  }
  inline/* test */namespace {
  	111111111111111111;
  }

  /* invalid namespaces use block indent */
  namespace test test2 {
  	111111111111111111111;
  }
  namespace11111111111 {
  	111111111111;
  }
  namespace() {
  	1111111111111;
  }
  namespace()
  {
  	111111111111111111;
  }
  namespace test test2
  {
  	1111111111111111111;
  }
  namespace111111111
  {
  	111111111111111111;
  }
  inlinenamespace {
  	111111111111111111;
  }

  void getstring() {
  	/* Raw strings */
  	const char* s = R"(
    test {
      # comment
      field: 123
    }
   )";
  }

  void getstring() {
  	const char* s = R"foo(
    test {
      # comment
      field: 123
    }
      )foo";
  }

  {
  	int a[4] = {
  		[0] = 0,
  		[1] = 1,
  		[2] = 2,
  		[3] = 3,
  	};
  }

  {
  	a = b[2]
  		+ 3;
  }

  {
  	if (1)
  		/* aaaaa
  		 * bbbbb
  		 */
  		a = 1;
  }

  void func()
  {
  	switch (foo)
  	{
  		case (bar):
  			if (baz())
  				quux();
  			break;
  		case (shmoo):
  			if (!bar)
  			{
  			}
  		case (foo1):
  			switch (bar)
  			{
  				case baz:
  					baz_f();
  					break;
  			}
  			break;
  		default:
  			baz();
  			baz();
  			break;
  	}
  }

  void foo() {
  	float a[5],
  		  b;
  }

  void func() {
  	if (0)
  		do
  			if (0);
  		while (0);
  	else;
  }

  void func() {
  	if (0)
  		do
  			if (0)
  				do
  					if (0)
  						a();
  				while (0);
  		while (0);
  	else
  		a();
  }

  /* end of AUTO */

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_2()
  new
  setl cindent ts=4 sw=4
  setl tw=0 noai fo=croq
  let &wm = &columns - 20

  let code =<< trim [CODE]
    {
  
    /* this is
     * a real serious important big
     * comment
     */
    	/* insert " about life, the universe, and the rest" after "serious" */
    }
  [CODE]

  call append(0, code)
  normal gg
  call search('serious', 'e')
  normal a about life, the universe, and the rest

  let expected =<< trim [CODE]
  {

  /* this is
   * a real serious
   * about life, the
   * universe, and the
   * rest important big
   * comment
   */
  	/* insert " about life, the universe, and the rest" after "serious" */
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  set wm&
  enew! | close
endfunc

func Test_cindent_3()
  new
  setl nocindent ts=4 sw=4

  let code =<< trim [CODE]
  {
  	/*
  	 * Testing for comments, without 'cin' set
  	 */

  /*
  * what happens here?
  */

  	/*
  	   the end of the comment, try inserting a line below */

  		/* how about
  		                this one */
  }
  [CODE]

  call append(0, code)
  normal gg
  call search('comments')
  normal joabout life
  call search('happens')
  normal jothere
  call search('below')
  normal oline
  call search('this')
  normal Ohello

  let expected =<< trim [CODE]
  {
  	/*
  	 * Testing for comments, without 'cin' set
  	 */
  about life

  /*
  * what happens here?
  */
  there

  	/*
  	   the end of the comment, try inserting a line below */
  line

  		/* how about
  hello
  		                this one */
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_4()
  new
  setl cindent ts=4 sw=4

  let code =<< trim [CODE]
  {
      var = this + that + vec[0] * vec[0]
  				      + vec[1] * vec[1]
  					  + vec2[2] * vec[2];
  }
  [CODE]

  call append(0, code)
  normal gg
  call search('vec2')
  normal ==

  let expected =<< trim [CODE]
  {
      var = this + that + vec[0] * vec[0]
  				      + vec[1] * vec[1]
  					  + vec2[2] * vec[2];
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_5()
  new
  setl cindent ts=4 sw=4
  setl cino=}4

  let code =<< trim [CODE]
  {
  		asdf asdflkajds f;
  	if (tes & ting) {
  		asdf asdf asdf ;
  		asdfa sdf asdf;
  		}
  	testing1;
  	if (tes & ting)
  	{
  		asdf asdf asdf ;
  		asdfa sdf asdf;
  		}
  	testing2;
  }
  [CODE]

  call append(0, code)
  normal gg
  call search('testing1')
  exe "normal k2==/testing2\<CR>"
  normal k2==

  let expected =<< trim [CODE]
  {
  		asdf asdflkajds f;
  	if (tes & ting) {
  		asdf asdf asdf ;
  		asdfa sdf asdf;
  		}
  	testing1;
  	if (tes & ting)
  	{
  		asdf asdf asdf ;
  		asdfa sdf asdf;
  		}
  	testing2;
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_6()
  new
  setl cindent ts=4 sw=4
  setl cino=(0,)20

  let code =<< trim [CODE]
  main ( int first_par, /*
                         * Comment for
                         * first par
                         */
            int second_par /*
                         * Comment for
                         * second par
                         */
       )
  {
  	func( first_par, /*
                        * Comment for
                        * first par
                        */
      second_par /*
                        * Comment for
                        * second par
                        */
          );

  }
  [CODE]

  call append(0, code)
  normal gg
  call search('main')
  normal =][

  let expected =<< trim [CODE]
  main ( int first_par, /*
  					   * Comment for
  					   * first par
  					   */
  	   int second_par /*
  					   * Comment for
  					   * second par
  					   */
  	 )
  {
  	func( first_par, /*
  					  * Comment for
  					  * first par
  					  */
  		  second_par /*
  					  * Comment for
  					  * second par
  					  */
  		);

  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_7()
  new
  setl cindent ts=4 sw=4
  setl cino=es,n0s

  let code =<< trim [CODE]
  main(void)
  {
  	/* Make sure that cino=X0s is not parsed like cino=Xs. */
  	if (cond)
  		foo();
  	else
  	{
  		bar();
  	}
  }
  [CODE]

  call append(0, code)
  normal gg
  call search('main')
  normal =][

  let expected =<< trim [CODE]
  main(void)
  {
  	/* Make sure that cino=X0s is not parsed like cino=Xs. */
  	if (cond)
  		foo();
  	else
  	{
  		bar();
  	}
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_8()
  new
  setl cindent ts=4 sw=4
  setl cino=

  let code =<< trim [CODE]

  {
  	do
  	{
  		if ()
  		{
  			if ()
  				asdf;
  			else
  				asdf;
  		}
  	} while ();
  			cmd;		/* this should go under the } */
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]

  {
  	do
  	{
  		if ()
  		{
  			if ()
  				asdf;
  			else
  				asdf;
  		}
  	} while ();
  	cmd;		/* this should go under the } */
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_9()
  new
  setl cindent ts=4 sw=4

  let code =<< trim [CODE]

  void f()
  {
      if ( k() ) {
          l();

      } else { /* Start (two words) end */
          m();
      }

      n();
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]

  void f()
  {
  	if ( k() ) {
  		l();

  	} else { /* Start (two words) end */
  		m();
  	}

  	n();
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_10()
  new
  setl cindent ts=4 sw=4
  setl cino={s,e-s

  let code =<< trim [CODE]

  void f()
  {
      if ( k() )
  	{
          l();
      } else { /* Start (two words) end */
          m();
      }
  		n();	/* should be under the if () */
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]

  void f()
  {
  	if ( k() )
  		{
  		l();
  		} else { /* Start (two words) end */
  		m();
  		}
  	n();	/* should be under the if () */
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_11()
  new
  setl cindent ts=4 sw=4
  setl cino={s,fs

  let code =<< trim [CODE]
  void bar(void)
  {
  	static array[2][2] =
  	{
  		{ 1, 2 },
  		{ 3, 4 },
  	}

  	while (a)
  	{
  		foo(&a);
  	}

  	{
  		int a;
  		{
  			a = a + 1;
  		}
  	}
  	b = a;
  	}

  void func(void)
  	{
  	a = 1;
  	{
  		b = 2;
  	}
  	c = 3;
  	d = 4;
  	}
  /* foo */
  [CODE]

  call append(0, code)
  normal gg
  exe "normal ]]=/ foo\<CR>"

  let expected =<< trim [CODE]
  void bar(void)
  	{
  	static array[2][2] =
  		{
  			{ 1, 2 },
  			{ 3, 4 },
  		}

  	while (a)
  		{
  		foo(&a);
  		}

  		{
  		int a;
  			{
  			a = a + 1;
  			}
  		}
  	b = a;
  	}

  void func(void)
  	{
  	a = 1;
  		{
  		b = 2;
  		}
  	c = 3;
  	d = 4;
  	}
  /* foo */

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_12()
  new
  setl cindent ts=4 sw=4
  setl cino=

  let code =<< trim [CODE]
  a()
  {
    do {
      a = a +
        a;
    } while ( a );		/* add text under this line */
      if ( a )
        a;
  }
  [CODE]

  call append(0, code)
  normal gg
  call search('while')
  normal ohere

  let expected =<< trim [CODE]
  a()
  {
    do {
      a = a +
        a;
    } while ( a );		/* add text under this line */
    here
      if ( a )
        a;
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_13()
  new
  setl cindent ts=4 sw=4
  setl cino= com=

  let code =<< trim [CODE]
  a()
  {
  label1:
              /* hmm */
              // comment
  }
  [CODE]

  call append(0, code)
  normal gg
  call search('comment')
  exe "normal olabel2: b();\rlabel3 /* post */:\r/* pre */ label4:\r" .
        \ "f(/*com*/);\rif (/*com*/)\rcmd();"

  let expected =<< trim [CODE]
  a()
  {
  label1:
              /* hmm */
              // comment
  label2: b();
  label3 /* post */:
  /* pre */ label4:
  		f(/*com*/);
  		if (/*com*/)
  			cmd();
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_14()
  new
  setl cindent ts=4 sw=4
  setl comments& comments^=s:/*,m:**,ex:*/

  let code =<< trim [CODE]
  /*
    * A simple comment
     */

  /*
    ** A different comment
     */
  [CODE]

  call append(0, code)
  normal gg
  call search('simple')
  normal =5j

  let expected =<< trim [CODE]
  /*
   * A simple comment
   */

  /*
  ** A different comment
  */

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_15()
  new
  setl cindent ts=4 sw=4
  setl cino=c0
  setl comments& comments-=s1:/* comments^=s0:/*

  let code =<< trim [CODE]
  void f()
  {

  	/*********
    A comment.
  *********/
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  void f()
  {

  	/*********
  	  A comment.
  	*********/
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_16()
  new
  setl cindent ts=4 sw=4
  setl cino=c0,C1
  setl comments& comments-=s1:/* comments^=s0:/*

  let code =<< trim [CODE]
  void f()
  {

  	/*********
    A comment.
  *********/
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  void f()
  {

  	/*********
  	A comment.
  	*********/
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_17()
  new
  setl cindent ts=4 sw=4
  setl cino=

  let code =<< trim [CODE]
  void f()
  {
  	c = c1 &&
  	(
  	c2 ||
  	c3
  	) && c4;
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  void f()
  {
  	c = c1 &&
  		(
  		 c2 ||
  		 c3
  		) && c4;
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_18()
  new
  setl cindent ts=4 sw=4
  setl cino=(s

  let code =<< trim [CODE]
  void f()
  {
  	c = c1 &&
  	(
  	c2 ||
  	c3
  	) && c4;
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  void f()
  {
  	c = c1 &&
  		(
  		 c2 ||
  		 c3
  		) && c4;
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_19()
  new
  setl cindent ts=4 sw=4
  set cino=(s,U1

  let code =<< trim [CODE]
  void f()
  {
  	c = c1 &&
  	(
  	c2 ||
  	c3
  	) && c4;
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  void f()
  {
  	c = c1 &&
  		(
  			c2 ||
  			c3
  		) && c4;
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_20()
  new
  setl cindent ts=4 sw=4
  setl cino=(0

  let code =<< trim [CODE]
  void f()
  {
  	if (   c1
  	&& (   c2
  	|| c3))
  	foo;
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  void f()
  {
  	if (   c1
  		   && (   c2
  				  || c3))
  		foo;
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_21()
  new
  setl cindent ts=4 sw=4
  setl cino=(0,w1

  let code =<< trim [CODE]
  void f()
  {
  	if (   c1
  	&& (   c2
  	|| c3))
  	foo;
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  void f()
  {
  	if (   c1
  		&& (   c2
  			|| c3))
  		foo;
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_22()
  new
  setl cindent ts=4 sw=4
  setl cino=(s

  let code =<< trim [CODE]
  void f()
  {
  	c = c1 && (
  	c2 ||
  	c3
  	) && c4;
  	if (
  	c1 && c2
  	)
  	foo;
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  void f()
  {
  	c = c1 && (
  		c2 ||
  		c3
  		) && c4;
  	if (
  		c1 && c2
  	   )
  		foo;
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_23()
  new
  setl cindent ts=4 sw=4
  setl cino=(s,m1

  let code =<< trim [CODE]
  void f()
  {
  	c = c1 && (
  	c2 ||
  	c3
  	) && c4;
  	if (
  	c1 && c2
  	)
  	foo;
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  void f()
  {
  	c = c1 && (
  		c2 ||
  		c3
  	) && c4;
  	if (
  		c1 && c2
  	)
  		foo;
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_24()
  new
  setl cindent ts=4 sw=4
  setl cino=b1

  let code =<< trim [CODE]
  void f()
  {
  	switch (x)
  	{
  		case 1:
  			a = b;
  			break;
  		default:
  			a = 0;
  			break;
  	}
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  void f()
  {
  	switch (x)
  	{
  		case 1:
  			a = b;
  		break;
  		default:
  			a = 0;
  		break;
  	}
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_25()
  new
  setl cindent ts=4 sw=4
  setl cino=(0,W5

  let code =<< trim [CODE]
  void f()
  {
  	invokeme(
  	argu,
  	ment);
  	invokeme(
  	argu,
  	ment
  	);
  	invokeme(argu,
  	ment
  	);
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  void f()
  {
  	invokeme(
  		 argu,
  		 ment);
  	invokeme(
  		 argu,
  		 ment
  		 );
  	invokeme(argu,
  			 ment
  			);
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_26()
  new
  setl cindent ts=4 sw=4
  setl cino=/6

  let code =<< trim [CODE]
  void f()
  {
  	statement;
  		// comment 1
  	// comment 2
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  void f()
  {
  	statement;
  		  // comment 1
  		  // comment 2
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_27()
  new
  setl cindent ts=4 sw=4
  setl cino=

  let code =<< trim [CODE]
  void f()
  {
  	statement;
  	   // comment 1
  	// comment 2
  }
  [CODE]

  call append(0, code)
  normal gg
  exe "normal ]]/comment 1/+1\<CR>=="

  let expected =<< trim [CODE]
  void f()
  {
  	statement;
  	   // comment 1
  	   // comment 2
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_28()
  new
  setl cindent ts=4 sw=4
  setl cino=g0

  let code =<< trim [CODE]
  class CAbc
  {
     int Test() { return FALSE; }

  public: // comment
     void testfall();
  protected:
     void testfall();
  };
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  class CAbc
  {
  	int Test() { return FALSE; }

  public: // comment
  	void testfall();
  protected:
  	void testfall();
  };

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_29()
  new
  setl cindent ts=4 sw=4
  setl cino=(0,gs,hs

  let code =<< trim [CODE]
  class Foo : public Bar
  {
  public:
  virtual void method1(void) = 0;
  virtual void method2(int arg1,
  int arg2,
  int arg3) = 0;
  };
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  class Foo : public Bar
  {
  	public:
  		virtual void method1(void) = 0;
  		virtual void method2(int arg1,
  							 int arg2,
  							 int arg3) = 0;
  };

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_30()
  new
  setl cindent ts=4 sw=4
  setl cino=+20

  let code =<< [CODE]
	void
foo()
{
	if (a)
	{
	} else
		asdf;
}
[CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< [CODE]
	void
foo()
{
	if (a)
	{
	} else
		asdf;
}

[CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_31()
  new
  setl cindent ts=4 sw=4
  setl cino=(0,W2s

  let code =<< trim [CODE]

  {
     averylongfunctionnamelongfunctionnameaverylongfunctionname()->asd(
           asdasdf,
           func(asdf,
                asdfadsf),
           asdfasdf
           );

     /* those are ugly, but consequent */

     func()->asd(asdasdf,
                 averylongfunctionname(
                       abc,
                       dec)->averylongfunctionname(
                             asdfadsf,
                             asdfasdf,
                             asdfasdf,
                             ),
                 func(asdfadf,
                      asdfasdf
                     ),
                 asdasdf
                );

     averylongfunctionnameaverylongfunctionnameavery()->asd(fasdf(
                 abc,
                 dec)->asdfasdfasdf(
                       asdfadsf,
                       asdfasdf,
                       asdfasdf,
                       ),
           func(asdfadf,
                asdfasdf),
           asdasdf
           );
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]

  {
  	averylongfunctionnamelongfunctionnameaverylongfunctionname()->asd(
  			asdasdf,
  			func(asdf,
  				 asdfadsf),
  			asdfasdf
  			);

  	/* those are ugly, but consequent */

  	func()->asd(asdasdf,
  				averylongfunctionname(
  						abc,
  						dec)->averylongfunctionname(
  								asdfadsf,
  								asdfasdf,
  								asdfasdf,
  								),
  				func(asdfadf,
  					 asdfasdf
  					),
  				asdasdf
  			   );

  	averylongfunctionnameaverylongfunctionnameavery()->asd(fasdf(
  					abc,
  					dec)->asdfasdfasdf(
  							asdfadsf,
  							asdfasdf,
  							asdfasdf,
  							),
  			func(asdfadf,
  				 asdfasdf),
  			asdasdf
  			);
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_32()
  new
  setl cindent ts=4 sw=4
  setl cino=M1

  let code =<< trim [CODE]
  int main ()
  {
  	if (cond1 &&
  			cond2
  			)
  		foo;
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  int main ()
  {
  	if (cond1 &&
  			cond2
  			)
  		foo;
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_33()
  new
  setl cindent ts=4 sw=4
  setl cino=(0,ts

  let code =<< trim [CODE]
  void func(int a
  #if defined(FOO)
  		  , int b
  		  , int c
  #endif
  		 )
  {
  }
  [CODE]

  call append(0, code)
  normal gg
  normal 2j=][

  let expected =<< trim [CODE]
  void func(int a
  #if defined(FOO)
  		  , int b
  		  , int c
  #endif
  		 )
  {
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_34()
  new
  setl cindent ts=4 sw=4
  setl cino=(0

  let code =<< trim [CODE]

  void
  func(int a
  #if defined(FOO)
  		  , int b
  		  , int c
  #endif
  		 )
  {
  }
  [CODE]

  call append(0, code)
  normal gg
  normal =][

  let expected =<< trim [CODE]
  
  	void
  func(int a
  #if defined(FOO)
  	 , int b
  	 , int c
  #endif
  	)
  {
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_35()
  new
  setl cindent ts=4 sw=4
  setl cino&

  let code =<< trim [CODE]
  void func(void)
  {
  	if(x==y)
  		if(y==z)
  			foo=1;
  		else { bar=1;
  			baz=2;
  		}
  	printf("Foo!\n");
  }

  void func1(void)
  {
  	char* tab[] = {"foo", "bar",
  		"baz", "quux",
  			"this line used", "to be indented incorrectly"};
  	foo();
  }

  void func2(void)
  {
  	int tab[] =
  	{1, 2,
  		3, 4,
  		5, 6};

  		printf("This line used to be indented incorrectly.\n");
  }

  int foo[]
  #ifdef BAR

  = { 1, 2, 3,
  	4, 5, 6 }

  #endif
  ;
  	int baz;

  void func3(void)
  {
  	int tab[] = {
  	1, 2,
  	3, 4,
  	5, 6};

  printf("Don't you dare indent this line incorrectly!\n");
  }

  void
  func4(a, b,
  		c)
  int a;
  int b;
  int c;
  {
  }

  void
  func5(
  		int a,
  		int b)
  {
  }

  void
  func6(
  		int a)
  {
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=7][

  let expected =<< trim [CODE]
  void func(void)
  {
  	if(x==y)
  		if(y==z)
  			foo=1;
  		else { bar=1;
  			baz=2;
  		}
  	printf("Foo!\n");
  }

  void func1(void)
  {
  	char* tab[] = {"foo", "bar",
  		"baz", "quux",
  		"this line used", "to be indented incorrectly"};
  	foo();
  }

  void func2(void)
  {
  	int tab[] =
  	{1, 2,
  		3, 4,
  		5, 6};

  	printf("This line used to be indented incorrectly.\n");
  }

  int foo[]
  #ifdef BAR

  = { 1, 2, 3,
  	4, 5, 6 }

  #endif
  	;
  int baz;

  void func3(void)
  {
  	int tab[] = {
  		1, 2,
  		3, 4,
  		5, 6};

  	printf("Don't you dare indent this line incorrectly!\n");
  }

  	void
  func4(a, b,
  		c)
  	int a;
  	int b;
  	int c;
  {
  }

  	void
  func5(
  		int a,
  		int b)
  {
  }

  	void
  func6(
  		int a)
  {
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_36()
  new
  setl cindent ts=4 sw=4
  setl cino&
  setl cino+=l1

  let code =<< trim [CODE]
  void func(void)
  {
  	int tab[] =
  	{
  		1, 2, 3,
  		4, 5, 6};

  	printf("Indent this line correctly!\n");

  	switch (foo)
  	{
  		case bar:
  			printf("bar");
  			break;
  		case baz: {
  			printf("baz");
  			break;
  		}
  		case quux:
  printf("But don't break the indentation of this instruction\n");
  break;
  	}
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  void func(void)
  {
  	int tab[] =
  	{
  		1, 2, 3,
  		4, 5, 6};

  	printf("Indent this line correctly!\n");

  	switch (foo)
  	{
  		case bar:
  			printf("bar");
  			break;
  		case baz: {
  			printf("baz");
  			break;
  		}
  		case quux:
  			printf("But don't break the indentation of this instruction\n");
  			break;
  	}
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_37()
  new
  setl cindent ts=4 sw=4
  setl cino&

  let code =<< trim [CODE]
  void func(void)
  {
  	cout << "a"
  	<< "b"
  	<< ") :"
  	<< "c";
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  void func(void)
  {
  	cout << "a"
  		<< "b"
  		<< ") :"
  		<< "c";
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_38()
  new
  setl cindent ts=4 sw=4
  setl com=s1:/*,m:*,ex:*/

  let code =<< trim [CODE]
  void func(void)
  {
  	/*
  	 * This is a comment.
  	 */
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]3jofoo();

  let expected =<< trim [CODE]
  void func(void)
  {
  	/*
  	 * This is a comment.
  	 */
  	foo();
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_39()
  new
  setl cindent ts=4 sw=4
  setl cino&

  let code =<< trim [CODE]
  void func(void)
  {
  	for (int i = 0; i < 10; ++i)
  		if (i & 1) {
  			foo(1);
  		} else
  			foo(0);
  baz();
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  void func(void)
  {
  	for (int i = 0; i < 10; ++i)
  		if (i & 1) {
  			foo(1);
  		} else
  			foo(0);
  	baz();
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_40()
  new
  setl cindent ts=4 sw=4
  setl cino=k2s,(0

  let code =<< trim [CODE]
  void func(void)
  {
  	if (condition1
  	&& condition2)
  	action();
  	function(argument1
  	&& argument2);

  	if (c1 && (c2 ||
  	c3))
  	foo;
  	if (c1 &&
  	(c2 || c3))
  	{
  	}

  	if (   c1
  	&& (      c2
  	|| c3))
  	foo;
  	func( c1
  	&& (     c2
  	|| c3))
  	foo;
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  void func(void)
  {
  	if (condition1
  			&& condition2)
  		action();
  	function(argument1
  			 && argument2);

  	if (c1 && (c2 ||
  				c3))
  		foo;
  	if (c1 &&
  			(c2 || c3))
  	{
  	}

  	if (   c1
  			&& (      c2
  					  || c3))
  		foo;
  	func( c1
  		  && (     c2
  				   || c3))
  		foo;
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_41()
  new
  setl cindent ts=4 sw=4
  setl cino=k2s,(s

  let code =<< trim [CODE]
  void func(void)
  {
  	if (condition1
  	&& condition2)
  	action();
  	function(argument1
  	&& argument2);

  	if (c1 && (c2 ||
  	c3))
  	foo;
  	if (c1 &&
  	(c2 || c3))
  	{
  	}

  	if (   c1
  	&& (      c2
  	|| c3))
  	foo;
  	func(   c1
  	&& (      c2
  	|| c3))
  	foo;
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  void func(void)
  {
  	if (condition1
  			&& condition2)
  		action();
  	function(argument1
  		&& argument2);

  	if (c1 && (c2 ||
  				c3))
  		foo;
  	if (c1 &&
  			(c2 || c3))
  	{
  	}

  	if (   c1
  			&& (      c2
  				|| c3))
  		foo;
  	func(   c1
  		&& (      c2
  			|| c3))
  		foo;
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_42()
  new
  setl cindent ts=4 sw=4
  setl cino=k2s,(s,U1

  let code =<< trim [CODE]
  void func(void)
  {
  	if (condition1
  	&& condition2)
  	action();
  	function(argument1
  	&& argument2);

  	if (c1 && (c2 ||
  	c3))
  	foo;
  	if (c1 &&
  	(c2 || c3))
  	{
  	}
  	if (c123456789
  	&& (c22345
  	|| c3))
  	printf("foo\n");

  	c = c1 &&
  	(
  	c2 ||
  	c3
  	) && c4;
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  void func(void)
  {
  	if (condition1
  			&& condition2)
  		action();
  	function(argument1
  		&& argument2);

  	if (c1 && (c2 ||
  				c3))
  		foo;
  	if (c1 &&
  			(c2 || c3))
  	{
  	}
  	if (c123456789
  			&& (c22345
  				|| c3))
  		printf("foo\n");

  	c = c1 &&
  		(
  			c2 ||
  			c3
  		) && c4;
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_43()
  new
  setl cindent ts=4 sw=4
  setl cino=k2s,(0,W4

  let code =<< trim [CODE]
  void func(void)
  {
  	if (condition1
  	&& condition2)
  	action();
  	function(argument1
  	&& argument2);

  	if (c1 && (c2 ||
  	c3))
  	foo;
  	if (c1 &&
  	(c2 || c3))
  	{
  	}
  	if (c123456789
  	&& (c22345
  	|| c3))
  	printf("foo\n");

  	if (   c1
  	&& (   c2
  	|| c3))
  	foo;

  	a_long_line(
  	argument,
  	argument);
  	a_short_line(argument,
  	argument);
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  void func(void)
  {
  	if (condition1
  			&& condition2)
  		action();
  	function(argument1
  			 && argument2);

  	if (c1 && (c2 ||
  				c3))
  		foo;
  	if (c1 &&
  			(c2 || c3))
  	{
  	}
  	if (c123456789
  			&& (c22345
  				|| c3))
  		printf("foo\n");

  	if (   c1
  			&& (   c2
  				   || c3))
  		foo;

  	a_long_line(
  		argument,
  		argument);
  	a_short_line(argument,
  				 argument);
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_44()
  new
  setl cindent ts=4 sw=4
  setl cino=k2s,u2

  let code =<< trim [CODE]
  void func(void)
  {
  	if (condition1
  	&& condition2)
  	action();
  	function(argument1
  	&& argument2);

  	if (c1 && (c2 ||
  	c3))
  	foo;
  	if (c1 &&
  	(c2 || c3))
  	{
  	}
  	if (c123456789
  	&& (c22345
  	|| c3))
  	printf("foo\n");
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  void func(void)
  {
  	if (condition1
  			&& condition2)
  		action();
  	function(argument1
  			&& argument2);

  	if (c1 && (c2 ||
  			  c3))
  		foo;
  	if (c1 &&
  			(c2 || c3))
  	{
  	}
  	if (c123456789
  			&& (c22345
  			  || c3))
  		printf("foo\n");
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_45()
  new
  setl cindent ts=4 sw=4
  setl cino=k2s,(0,w1

  let code =<< trim [CODE]
  void func(void)
  {
  	if (condition1
  	&& condition2)
  	action();
  	function(argument1
  	&& argument2);

  	if (c1 && (c2 ||
  	c3))
  	foo;
  	if (c1 &&
  	(c2 || c3))
  	{
  	}
  	if (c123456789
  	&& (c22345
  	|| c3))
  	printf("foo\n");

  	if (   c1
  	&& (      c2
  	|| c3))
  	foo;
  	func(   c1
  	&& (      c2
  	|| c3))
  	foo;
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  void func(void)
  {
  	if (condition1
  			&& condition2)
  		action();
  	function(argument1
  			 && argument2);

  	if (c1 && (c2 ||
  				c3))
  		foo;
  	if (c1 &&
  			(c2 || c3))
  	{
  	}
  	if (c123456789
  			&& (c22345
  				|| c3))
  		printf("foo\n");

  	if (   c1
  			&& (      c2
  				|| c3))
  		foo;
  	func(   c1
  		 && (      c2
  			 || c3))
  		foo;
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_46()
  new
  setl cindent ts=4 sw=4
  setl cino=k2,(s

  let code =<< trim [CODE]
  void func(void)
  {
  	if (condition1
  	  && condition2)
  		action();
  	function(argument1
  		&& argument2);

  	if (c1 && (c2 ||
  		  c3))
  		foo;
  	if (c1 &&
  	  (c2 || c3))
  	{
  	}
  }
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  void func(void)
  {
  	if (condition1
  	  && condition2)
  		action();
  	function(argument1
  		&& argument2);

  	if (c1 && (c2 ||
  		  c3))
  		foo;
  	if (c1 &&
  	  (c2 || c3))
  	{
  	}
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_47()
  new
  setl cindent ts=4 sw=4
  setl cino=N-s

  let code =<< trim [CODE]
  NAMESPACESTART
  /* valid namespaces with normal indent */
  namespace
  {
     {
  	111111111111;
  }
  }
  namespace /* test */
  {
    11111111111111111;
  }
  namespace // test
  {
    111111111111111111;
  }
  namespace
  {
    111111111111111111;
  }
  namespace test
  {
    111111111111111111;
  }
  namespace test::cpp17
  {
    111111111111111111;
  }
  namespace ::incorrectcpp17
  {
    111111111111111111;
  }
  namespace test::incorrectcpp17::
  {
    111111111111111111;
  }
  namespace test:incorrectcpp17
  {
    111111111111111111;
  }
  namespace test:::incorrectcpp17
  {
    111111111111111111;
  }
  namespace{
    111111111111111111;
  }
  namespace test{
    111111111111111111;
  }
  namespace {
    111111111111111111;
  }
  namespace test {
    111111111111111111;
  namespace test2 {
    22222222222222222;
  }
  }
  inline namespace {
    111111111111111111;
  }
  inline /* test */ namespace {
    111111111111111111;
  }
  inline/* test */namespace {
    111111111111111111;
  }
  export namespace {
    111111111111111111;
  }
  export inline namespace {
    111111111111111111;
  }
  export/* test */inline namespace {
    111111111111111111;
  }
  inline export namespace {
    111111111111111111;
  }

  /* invalid namespaces use block indent */
  namespace test test2 {
    111111111111111111111;
  }
  namespace11111111111 {
    111111111111;
  }
  namespace() {
    1111111111111;
  }
  namespace()
  {
    111111111111111111;
  }
  namespace test test2
  {
    1111111111111111111;
  }
  namespace111111111
  {
    111111111111111111;
  }
  inlinenamespace {
    111111111111111111;
  }
  NAMESPACEEND
  [CODE]

  call append(0, code)
  normal gg
  call search('^NAMESPACESTART')
  exe "normal =/^NAMESPACEEND\n"

  let expected =<< trim [CODE]
  NAMESPACESTART
  /* valid namespaces with normal indent */
  namespace
  {
  {
  	111111111111;
  }
  }
  namespace /* test */
  {
  11111111111111111;
  }
  namespace // test
  {
  111111111111111111;
  }
  namespace
  {
  111111111111111111;
  }
  namespace test
  {
  111111111111111111;
  }
  namespace test::cpp17
  {
  111111111111111111;
  }
  namespace ::incorrectcpp17
  {
  	111111111111111111;
  }
  namespace test::incorrectcpp17::
  {
  	111111111111111111;
  }
  namespace test:incorrectcpp17
  {
  	111111111111111111;
  }
  namespace test:::incorrectcpp17
  {
  	111111111111111111;
  }
  namespace{
  111111111111111111;
  }
  namespace test{
  111111111111111111;
  }
  namespace {
  111111111111111111;
  }
  namespace test {
  111111111111111111;
  namespace test2 {
  22222222222222222;
  }
  }
  inline namespace {
  111111111111111111;
  }
  inline /* test */ namespace {
  111111111111111111;
  }
  inline/* test */namespace {
  111111111111111111;
  }
  export namespace {
  111111111111111111;
  }
  export inline namespace {
  111111111111111111;
  }
  export/* test */inline namespace {
  111111111111111111;
  }
  inline export namespace {
  111111111111111111;
  }

  /* invalid namespaces use block indent */
  namespace test test2 {
  	111111111111111111111;
  }
  namespace11111111111 {
  	111111111111;
  }
  namespace() {
  	1111111111111;
  }
  namespace()
  {
  	111111111111111111;
  }
  namespace test test2
  {
  	1111111111111111111;
  }
  namespace111111111
  {
  	111111111111111111;
  }
  inlinenamespace {
  	111111111111111111;
  }
  NAMESPACEEND

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_48()
  new
  setl cindent ts=4 sw=4
  setl cino=j1,J1

  let code =<< trim [CODE]
  JSSTART
  var bar = {
  foo: {
  that: this,
  some: ok,
  },
  "bar":{
  a : 2,
  b: "123abc",
  x: 4,
  "y": 5
  }
  }
  JSEND
  [CODE]

  call append(0, code)
  normal gg
  call search('^JSSTART')
  exe "normal =/^JSEND\n"

  let expected =<< trim [CODE]
  JSSTART
  var bar = {
  	foo: {
  		that: this,
  		some: ok,
  	},
  	"bar":{
  		a : 2,
  		b: "123abc",
  		x: 4,
  		"y": 5
  	}
  }
  JSEND

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_49()
  new
  setl cindent ts=4 sw=4
  setl cino=j1,J1

  let code =<< trim [CODE]
  JSSTART
  var foo = [
  1,
  2,
  3
  ];
  JSEND
  [CODE]

  call append(0, code)
  normal gg
  call search('^JSSTART')
  exe "normal =/^JSEND\n"

  let expected =<< trim [CODE]
  JSSTART
  var foo = [
  	1,
  	2,
  	3
  ];
  JSEND

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_50()
  new
  setl cindent ts=4 sw=4
  setl cino=j1,J1

  let code =<< trim [CODE]
  JSSTART
  function bar() {
  var foo = [
  1,
  2,
  3
  ];
  }
  JSEND
  [CODE]

  call append(0, code)
  normal gg
  call search('^JSSTART')
  exe "normal =/^JSEND\n"

  let expected =<< trim [CODE]
  JSSTART
  function bar() {
  	var foo = [
  		1,
  		2,
  		3
  	];
  }
  JSEND

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_51()
  new
  setl cindent ts=4 sw=4
  setl cino=j1,J1

  let code =<< trim [CODE]
  JSSTART
  (function($){

  if (cond &&
  cond) {
  stmt;
  }
  window.something.left =
  (width - 50 + offset) + "px";
  var class_name='myclass';

  function private_method() {
  }

  var public_method={
  method: function(options,args){
  private_method();
  }
  }

  function init(options) {

  $(this).data(class_name+'_public',$.extend({},{
  foo: 'bar',
  bar: 2,
  foobar: [
  1,
  2,
  3
  ],
  callback: function(){
  return true;
  }
  }, options||{}));
  }

  $.fn[class_name]=function() {

  var _arguments=arguments;
  return this.each(function(){

  var options=$(this).data(class_name+'_public');
  if (!options) {
  init.apply(this,_arguments);

  } else {
  var method=public_method[_arguments[0]];

  if (typeof(method)!='function') {
  console.log(class_name+' has no method "'+_arguments[0]+'"');
  return false;
  }
  _arguments[0]=options;
  method.apply(this,_arguments);
  }
  });
  }

  })(jQuery);
  JSEND
  [CODE]

  call append(0, code)
  normal gg
  call search('^JSSTART')
  exe "normal =/^JSEND\n"

  let expected =<< trim [CODE]
  JSSTART
  (function($){

  	if (cond &&
  			cond) {
  		stmt;
  	}
  	window.something.left =
  		(width - 50 + offset) + "px";
  	var class_name='myclass';

  	function private_method() {
  	}

  	var public_method={
  		method: function(options,args){
  			private_method();
  		}
  	}

  	function init(options) {

  		$(this).data(class_name+'_public',$.extend({},{
  			foo: 'bar',
  			bar: 2,
  			foobar: [
  				1,
  				2,
  				3
  			],
  			callback: function(){
  				return true;
  			}
  		}, options||{}));
  	}

  	$.fn[class_name]=function() {

  		var _arguments=arguments;
  		return this.each(function(){

  			var options=$(this).data(class_name+'_public');
  			if (!options) {
  				init.apply(this,_arguments);

  			} else {
  				var method=public_method[_arguments[0]];

  				if (typeof(method)!='function') {
  					console.log(class_name+' has no method "'+_arguments[0]+'"');
  					return false;
  				}
  				_arguments[0]=options;
  				method.apply(this,_arguments);
  			}
  		});
  	}

  })(jQuery);
  JSEND

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_52()
  new
  setl cindent ts=4 sw=4
  setl cino=j1,J1

  let code =<< trim [CODE]
  JSSTART
  function init(options) {
  $(this).data(class_name+'_public',$.extend({},{
  foo: 'bar',
  bar: 2,
  foobar: [
  1,
  2,
  3
  ],
  callback: function(){
  return true;
  }
  }, options||{}));
  }
  JSEND
  [CODE]

  call append(0, code)
  normal gg
  call search('^JSSTART')
  exe "normal =/^JSEND\n"

  let expected =<< trim [CODE]
  JSSTART
  function init(options) {
  	$(this).data(class_name+'_public',$.extend({},{
  		foo: 'bar',
  		bar: 2,
  		foobar: [
  			1,
  			2,
  			3
  		],
  		callback: function(){
  			return true;
  		}
  	}, options||{}));
  }
  JSEND

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_53()
  new
  setl cindent ts=4 sw=4
  setl cino=j1,J1

  let code =<< trim [CODE]
  JSSTART
  (function($){
  function init(options) {
  $(this).data(class_name+'_public',$.extend({},{
  foo: 'bar',
  bar: 2,
  foobar: [
  1,
  2,
  3
  ],
  callback: function(){
  return true;
  }
  }, options||{}));
  }
  })(jQuery);
  JSEND
  [CODE]

  call append(0, code)
  normal gg
  call search('^JSSTART')
  exe "normal =/^JSEND\n"

  let expected =<< trim [CODE]
  JSSTART
  (function($){
  	function init(options) {
  		$(this).data(class_name+'_public',$.extend({},{
  			foo: 'bar',
  			bar: 2,
  			foobar: [
  				1,
  				2,
  				3
  			],
  			callback: function(){
  				return true;
  			}
  		}, options||{}));
  	}
  })(jQuery);
  JSEND

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_54()
  new
  setl cindent ts=4 sw=4
  setl cino=j1,J1,+2

  let code =<< trim [CODE]
  JSSTART
  // Results of JavaScript indent
  // 1
  (function(){
  var a = [
  'a',
  'b',
  'c',
  'd',
  'e',
  'f',
  'g',
  'h',
  'i'
  ];
  }())

  // 2
  (function(){
  var a = [
  0 +
  5 *
  9 *
  'a',
  'b',
  0 +
  5 *
  9 *
  'c',
  'd',
  'e',
  'f',
  'g',
  'h',
  'i'
  ];
  }())

  // 3
  (function(){
  var a = [
  0 +
  // comment 1
  5 *
  /* comment 2 */
  9 *
  'a',
  'b',
  0 +
  5 *
  9 *
  'c',
  'd',
  'e',
  'f',
  'g',
  'h',
  'i'
  ];
  }())

  // 4
  {
  var a = [
  0,
  1
  ];
  var b;
  var c;
  }

  // 5
  {
  var a = [
  [
  0
  ],
  2,
  3
  ];
  }

  // 6
  {
  var a = [
  [
  0,
  1
  ],
  2,
  3
  ];
  }

  // 7
  {
  var a = [
  // [
  0,
  // 1
  // ],
  2,
  3
  ];
  }

  // 8
  var x = [
  (function(){
  var a,
  b,
  c,
  d,
  e,
  f,
  g,
  h,
  i;
  })
  ];

  // 9
  var a = [
  0 +
  5 *
  9 *
  'a',
  'b',
  0 +
  5 *
  9 *
  'c',
  'd',
  'e',
  'f',
  'g',
  'h',
  'i'
  ];

  // 10
  var a,
  b,
  c,
  d,
  e,
  f,
  g,
  h,
  i;
  JSEND
  [CODE]

  call append(0, code)
  normal gg
  call search('^JSSTART')
  exe "normal =/^JSEND\n"

  let expected =<< trim [CODE]
  JSSTART
  // Results of JavaScript indent
  // 1
  (function(){
  	var a = [
  	  'a',
  	  'b',
  	  'c',
  	  'd',
  	  'e',
  	  'f',
  	  'g',
  	  'h',
  	  'i'
  	];
  }())

  // 2
  (function(){
  	var a = [
  	  0 +
  		5 *
  		9 *
  		'a',
  	  'b',
  	  0 +
  		5 *
  		9 *
  		'c',
  	  'd',
  	  'e',
  	  'f',
  	  'g',
  	  'h',
  	  'i'
  	];
  }())

  // 3
  (function(){
  	var a = [
  	  0 +
  		// comment 1
  		5 *
  		/* comment 2 */
  		9 *
  		'a',
  	  'b',
  	  0 +
  		5 *
  		9 *
  		'c',
  	  'd',
  	  'e',
  	  'f',
  	  'g',
  	  'h',
  	  'i'
  	];
  }())

  // 4
  {
  	var a = [
  	  0,
  	  1
  	];
  	var b;
  	var c;
  }

  // 5
  {
  	var a = [
  	  [
  		0
  	  ],
  	  2,
  	  3
  	];
  }

  // 6
  {
  	var a = [
  	  [
  		0,
  		1
  	  ],
  	  2,
  	  3
  	];
  }

  // 7
  {
  	var a = [
  	  // [
  	  0,
  	  // 1
  	  // ],
  	  2,
  	  3
  	];
  }

  // 8
  var x = [
    (function(){
  	  var a,
  	  b,
  	  c,
  	  d,
  	  e,
  	  f,
  	  g,
  	  h,
  	  i;
    })
  ];

  // 9
  var a = [
    0 +
    5 *
    9 *
    'a',
    'b',
    0 +
    5 *
    9 *
    'c',
    'd',
    'e',
    'f',
    'g',
    'h',
    'i'
  ];

  // 10
  var a,
  	b,
  	c,
  	d,
  	e,
  	f,
  	g,
  	h,
  	i;
  JSEND

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_55()
  new
  setl cindent ts=4 sw=4
  setl cino&

  let code =<< trim [CODE]
  /* start of define */
  {
  }
  #define AAA \
  BBB\
  CCC

  #define CNT \
  1 + \
  2 + \
  4
  /* end of define */
  [CODE]

  call append(0, code)
  normal gg
  call search('start of define')
  exe "normal =/end of define\n"

  let expected =<< trim [CODE]
  /* start of define */
  {
  }
  #define AAA \
  	BBB\
  	CCC

  #define CNT \
  	1 + \
  	2 + \
  	4
  /* end of define */

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_56()
  new
  setl cindent ts=4 sw=4
  setl cino&

  let code =<< trim [CODE]
  {
  	a = second/*bug*/*line;
  }
  [CODE]

  call append(0, code)
  normal gg
  call search('a = second')
  normal ox

  let expected =<< trim [CODE]
  {
  	a = second/*bug*/*line;
  	x
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

" this was going beyond the end of the line.
func Test_cindent_case()
  new
  call setline(1, 'case x: // x')
  set cindent
  norm! f:a:
  call assert_equal('case x:: // x', getline(1))
  set cindent&
  bwipe!
endfunc

" Test for changing multiple lines (using c) with cindent
func Test_cindent_change_multline()
  new
  setlocal cindent
  call setline(1, ['if (a)', '{', '    i = 1;', '}'])
  normal! jc3jm = 2;
  call assert_equal("\tm = 2;", getline(2))
  close!
endfunc

" This was reading past the end of the line
func Test_cindent_check_funcdecl()
  new
  sil norm o0('\0=L
  bwipe!
endfunc

func Test_cindent_scopedecls()
  new
  setl cindent ts=4 sw=4
  setl cino=g0
  setl cinsd+=public\ slots,signals

  let code =<< trim [CODE]
  class Foo
  {
  public:
  virtual void foo() = 0;
  public slots:
  void onBar();
  signals:
  void baz();
  private:
  int x;
  };
  [CODE]

  call append(0, code)
  normal gg
  normal ]]=][

  let expected =<< trim [CODE]
  class Foo
  {
  public:
	virtual void foo() = 0;
  public slots:
	void onBar();
  signals:
	void baz();
  private:
	int x;
  };

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_cindent_pragma()
  new
  setl cindent ts=4 sw=4
  setl cino=Ps

  let code =<< trim [CODE]
  {
  #pragma omp parallel
  {
  #pragma omp task
  foo();
  # pragma omp taskwait
  }
  }
  [CODE]

  call append(0, code)
  normal gg
  normal =G

  let expected =<< trim [CODE]
  {
	#pragma omp parallel
	{
		#pragma omp task
		foo();
		# pragma omp taskwait
	}
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

func Test_backslash_at_end_of_line()
  new
  exe "norm v>O'\\\<C-m>-"
  exe "norm \<C-q>="
  bwipe!
endfunc

func Test_find_brace_backwards()
  " this was looking beyond the end of the line
  new
  norm R/*
  norm o0{
  norm o//
  norm V{=
  call assert_equal(['/*', '   0{', '//'], getline(1, 3))
  bwipe!
endfunc


" vim: shiftwidth=2 sts=2 expandtab
