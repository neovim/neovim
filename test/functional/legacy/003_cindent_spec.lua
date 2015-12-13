-- Test for 'cindent'.
--
-- There are 50+ test command blocks (the stuff between STARTTEST and ENDTEST)
-- in the original test. These have been converted to "it" test cases here.

local helpers = require('test.functional.helpers')
local feed, insert = helpers.feed, helpers.insert
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

-- Inserts text as usual, and additionally positions the cursor on line 1 and
-- sets 'cindent' and tab settings. (In the original "test3.in" the modeline at
-- the top of the file takes care of this.)
local function insert_(content)
  insert(content)
  execute('1', 'set cin ts=4 sw=4')
end

describe('cindent', function()
  before_each(clear)

  it('1 is working', function()
    insert_([=[
      
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
      
      public: // <-- this was incoreectly indented before!!
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
      
      /* end of AUTO */
      ]=])

    execute('/start of AUTO')
    feed('=/end of AUTO<cr>')

    expect([=[
      
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
      
      	public: // <-- this was incoreectly indented before!!
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
      
      /* end of AUTO */
      ]=])
  end)

  it('2 is working', function()
    insert_([=[
      
      {
      
      /* this is
       * a real serious important big
       * comment
       */
      	/* insert " about life, the universe, and the rest" after "serious" */
      }
      ]=])

    execute('set tw=0 wm=60 columns=80 noai fo=croq')
    execute('/serious/e')
    feed('a about life, the universe, and the rest<esc>')

    expect([=[
      
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
      ]=])
  end)

  it('3 is working', function()
    insert_([=[
      
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
      ]=])

    execute('set nocin')
    execute('/comments')
    feed('joabout life<esc>/happens<cr>')
    feed('jothere<esc>/below<cr>')
    feed('oline<esc>/this<cr>')
    feed('Ohello<esc>')

    expect([=[
      
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
      ]=])
  end)

  it('4 is working', function()
    insert_([=[
      
      {
          var = this + that + vec[0] * vec[0]
      				      + vec[1] * vec[1]
      					  + vec2[2] * vec[2];
      }
      ]=])
    execute('set cin')
    execute('/vec2')
    feed('==<cr>')

    expect([=[
      
      {
          var = this + that + vec[0] * vec[0]
      				      + vec[1] * vec[1]
      					  + vec2[2] * vec[2];
      }
      ]=])
  end)

  it('5 is working', function()
    insert_([=[
      
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
      ]=])

    execute('set cin')
    execute('set cino=}4')
    execute('/testing1')
    feed('k2==/testing2<cr>')
    feed('k2==<cr>')

    expect([=[
      
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
      ]=])
  end)

  it('6 is working', function()
    insert_([=[
      
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
      ]=])

    execute('set cin')
    execute('set cino=(0,)20')
    execute('/main')
    feed('=][<cr>')

    expect([=[
      
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
      ]=])
  end)

  it('7 is working', function()
    insert_([=[
      
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
      ]=])

    execute('set cin')
    execute('set cino=es,n0s')
    execute('/main')
    feed('=][<cr>')

    expect([=[
      
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
      ]=])
  end)

  it('8 is working', function()
    insert_([=[
      
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
      ]=])

    execute('set cin')
    execute('set cino=')
    feed(']]=][<cr>')

    expect([=[
      
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
      ]=])
  end)

  it('9 is working', function()
    insert_([=[
      
      void f()
      {
          if ( k() ) {
              l();
      
          } else { /* Start (two words) end */
              m();
          }
      
          n();
      }
      ]=])

    feed(']]=][<cr>')

    expect([=[
      
      void f()
      {
      	if ( k() ) {
      		l();
      
      	} else { /* Start (two words) end */
      		m();
      	}
      
      	n();
      }
      ]=])
  end)

  it('10 is working', function()
    -- This is nasty. This is the only test case where the buffer content
    -- differs from the original. Why? Proper behaviour of this test depends on
    -- the fact that the setup code contains an (unbalanced) opening curly
    -- bracket in "set cino={s,e-s". This bracket actually affects the outcome
    -- of the test: without it the curly bracket under "void f()" would not be
    -- indented properly. And that's why we've had to add one explicitly.
    insert_([=[
      { <= THIS IS THE CURLY BRACKET EXPLAINED IN THE COMMENT.
      
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
      ]=])

    execute('set cino={s,e-s')
    feed(']]=][<cr>')

    expect([=[
      { <= THIS IS THE CURLY BRACKET EXPLAINED IN THE COMMENT.
      
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
      ]=])
  end)

  it('11 is working', function()
    insert_([=[
      
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
      ]=])

    execute('set cino={s,fs')
    feed(']]=/ foo<cr>')

    expect([=[
      
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
      ]=])
  end)

  it('12 is working', function()
    insert_([=[
      
      a()
      {
        do {
          a = a +
            a;
        } while ( a );		/* add text under this line */
          if ( a )
            a;
      }
      ]=])

    execute('set cino=')
    execute('/while')
    feed('ohere<esc>')

    expect([=[
      
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
      ]=])
  end)

  it('13 is working', function()
    insert_([=[
      
      a()
      {
      label1:
                  /* hmm */
                  // comment
      }
      ]=])

    execute('set cino= com=')
    execute('/comment')
    feed('olabel2: b();<cr>label3 /* post */:<cr>/* pre */ label4:<cr>f(/*com*/);<cr>if (/*com*/)<cr>cmd();<esc>')

    expect([=[
      
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
      ]=])
  end)

  it('14 is working', function()
    insert_([=[
      
      /*
        * A simple comment
         */
      
      /*
        ** A different comment
         */
      ]=])

    execute('set comments& comments^=s:/*,m:**,ex:*/')
    execute('/simple')
    feed('=5j<cr>')

    expect([=[
      
      /*
       * A simple comment
       */
      
      /*
      ** A different comment
      */
      ]=])
  end)

  it('15 is working', function()
    insert_([=[
      
      
      void f()
      {
      
      	/*********
        A comment.
      *********/
      }
      ]=])

    execute('set cino=c0')
    execute('set comments& comments-=s1:/* comments^=s0:/*')
    feed('2kdd]]=][<cr>')

    expect([=[
      
      void f()
      {
      
      	/*********
      	  A comment.
      	*********/
      }
      ]=])
  end)

  it('16 is working', function()
    insert_([=[
      
      
      void f()
      {
      
      	/*********
        A comment.
      *********/
      }
      ]=])

    execute('set cino=c0,C1')
    execute('set comments& comments-=s1:/* comments^=s0:/*')
    feed('2kdd]]=][<cr>')

    expect([=[
      
      void f()
      {
      
      	/*********
      	A comment.
      	*********/
      }
      ]=])
  end)

  it('17 is working', function()
    insert_([=[
      
      void f()
      {
      	c = c1 &&
      	(
      	c2 ||
      	c3
      	) && c4;
      }
      ]=])

    execute('set cino=')
    feed(']]=][<cr>')

    expect([=[
      
      void f()
      {
      	c = c1 &&
      		(
      		 c2 ||
      		 c3
      		) && c4;
      }
      ]=])
  end)

  it('18 is working', function()
    insert_([=[
      
      
      void f()
      {
      	c = c1 &&
      	(
      	c2 ||
      	c3
      	) && c4;
      }
      ]=])

    execute('set cino=(s')
    feed('2kdd]]=][<cr>')

    expect([=[
      
      void f()
      {
      	c = c1 &&
      		(
      		 c2 ||
      		 c3
      		) && c4;
      }
      ]=])
  end)

  it('19 is working', function()
    insert_([=[
      
      
      void f()
      {
      	c = c1 &&
      	(
      	c2 ||
      	c3
      	) && c4;
      }
      ]=])

    execute('set cino=(s,U1  ')
    feed('2kdd]]=][<cr>')

    expect([=[
      
      void f()
      {
      	c = c1 &&
      		(
      			c2 ||
      			c3
      		) && c4;
      }
      ]=])
  end)

  it('20 is working', function()
    insert_([=[
      
      
      void f()
      {
      	if (   c1
      	&& (   c2
      	|| c3))
      	foo;
      }
      ]=])

    execute('set cino=(0')
    feed('2kdd]]=][<cr>')

    expect([=[
      
      void f()
      {
      	if (   c1
      		   && (   c2
      				  || c3))
      		foo;
      }
      ]=])
  end)

  it('21 is working', function()
    insert_([=[
      
      
      void f()
      {
      	if (   c1
      	&& (   c2
      	|| c3))
      	foo;
      }
      ]=])

    execute('set cino=(0,w1  ')
    feed('2kdd]]=][<cr>')

    expect([=[
      
      void f()
      {
      	if (   c1
      		&& (   c2
      			|| c3))
      		foo;
      }
      ]=])
  end)

  it('22 is working', function()
    insert_([=[
      
      
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
      ]=])

    execute('set cino=(s')
    feed('2kdd]]=][<cr>')

    expect([=[
      
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
      ]=])
  end)

  it('23 is working', function()
    insert_([=[
      
      
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
      ]=])

    execute('set cino=(s,m1  ')
    feed('2kdd]]=][<cr>')

    expect([=[
      
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
      ]=])
  end)

  it('24 is working', function()
    insert_([=[
      
      
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
      ]=])

    execute('set cino=b1')
    feed('2kdd]]=][<cr>')

    expect([=[
      
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
      ]=])
  end)

  it('25 is working', function()
    insert_([=[
      
      
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
      ]=])

    execute('set cino=(0,W5')
    feed('2kdd]]=][<cr>')

    expect([=[
      
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
      ]=])
  end)

  it('26 is working', function()
    insert_([=[
      
      
      void f()
      {
      	statement;
      		// comment 1
      	// comment 2
      }
      ]=])

    execute('set cino=/6')
    feed('2kdd]]=][<cr>')

    expect([=[
      
      void f()
      {
      	statement;
      		  // comment 1
      		  // comment 2
      }
      ]=])
  end)

  it('27 is working', function()
    insert_([=[
      
      
      void f()
      {
      	statement;
      	   // comment 1
      	// comment 2
      }
      ]=])

    execute('set cino=')
    feed('2kdd]]/comment 1/+1<cr>')
    feed('==<cr>')

    expect([=[
      
      void f()
      {
      	statement;
      	   // comment 1
      	   // comment 2
      }
      ]=])
  end)

  it('28 is working', function()
    insert_([=[
      
      
      class CAbc
      {
         int Test() { return FALSE; }
      
      public: // comment
         void testfall();
      protected:
         void testfall();
      };
      ]=])

    execute('set cino=g0')
    feed('2kdd]]=][<cr>')

    expect([=[
      
      class CAbc
      {
      	int Test() { return FALSE; }
      
      public: // comment
      	void testfall();
      protected:
      	void testfall();
      };
      ]=])
  end)

  it('29 is working', function()
    insert_([=[
      
      
      class Foo : public Bar
      {
      public:
      virtual void method1(void) = 0;
      virtual void method2(int arg1,
      int arg2,
      int arg3) = 0;
      };
      ]=])

    execute('set cino=(0,gs,hs')
    feed('2kdd]]=][<cr>')

    expect([=[
      
      class Foo : public Bar
      {
      	public:
      		virtual void method1(void) = 0;
      		virtual void method2(int arg1,
      							 int arg2,
      							 int arg3) = 0;
      };
      ]=])
  end)

  it('30 is working', function()
    insert_([=[
      
      
      	void
      foo()
      {
      	if (a)
      	{
      	} else
      		asdf;
      }
      ]=])

    execute('set cino=+20')
    feed('2kdd]]=][<cr>')

    expect([=[
      
      	void
      foo()
      {
      	if (a)
      	{
      	} else
      		asdf;
      }
      ]=])
  end)

  it('31 is working', function()
    insert_([=[
      
      
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
      ]=])

    execute('set cino=(0,W2s')
    feed('2kdd]]=][<cr>')

    expect([=[
      
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
      ]=])
  end)

  it('32 is working', function()
    insert_([=[
      
      
      int main ()
      {
      	if (cond1 &&
      			cond2
      			)
      		foo;
      }
      ]=])

    execute('set cino=M1')
    feed('2kdd]]=][<cr>')

    expect([=[
      
      int main ()
      {
      	if (cond1 &&
      			cond2
      			)
      		foo;
      }
      ]=])
  end)

  it('33 is working', function()
    insert_([=[
      
      
      void func(int a
      #if defined(FOO)
      		  , int b
      		  , int c
      #endif
      		 )
      {
      }
      ]=])

    execute('set cino=(0,ts')
    feed('2kdd2j=][<cr>')

    expect([=[
      
      void func(int a
      #if defined(FOO)
      		  , int b
      		  , int c
      #endif
      		 )
      {
      }
      ]=])
  end)

  it('34 is working', function()
    insert_([=[
      
      
      
      void
      func(int a
      #if defined(FOO)
      		  , int b
      		  , int c
      #endif
      		 )
      {
      }
      ]=])

    execute('set cino=(0')
    feed('2kdd2j=][<cr>')

    expect([=[
      
      
      	void
      func(int a
      #if defined(FOO)
      	 , int b
      	 , int c
      #endif
      	)
      {
      }
      ]=])
  end)

  it('35 is working', function()
    insert_([=[
      
      
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
      ]=])

    execute('set cino&')
    feed('2kdd2j=7][<cr>')

    expect([=[
      
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
      ]=])
  end)

  it('36 is working', function()
    insert_([=[
      
      
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
      ]=])

    execute('set cino&')
    execute('set cino+=l1')
    feed('2kdd2j=][<cr>')

    expect([=[
      
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
      ]=])
  end)

  it('37 is working', function()
    insert_([=[
      
      
      void func(void)
      {
      	cout << "a"
      	<< "b"
      	<< ") :"
      	<< "c";
      }
      ]=])

    execute('set cino&')
    feed('2kdd2j=][<cr>')

    expect([=[
      
      void func(void)
      {
      	cout << "a"
      		<< "b"
      		<< ") :"
      		<< "c";
      }
      ]=])
  end)

  it('38 is working', function()
    insert_([=[
      
      void func(void)
      {
      	/*
      	 * This is a comment.
      	 */
      }
      ]=])

    execute('set com=s1:/*,m:*,ex:*/')
    feed(']]3jofoo();<esc>')

    expect([=[
      
      void func(void)
      {
      	/*
      	 * This is a comment.
      	 */
      	foo();
      }
      ]=])
  end)

  it('39 is working', function()
    insert_([=[
      
      
      void func(void)
      {
      	for (int i = 0; i < 10; ++i)
      		if (i & 1) {
      			foo(1);
      		} else
      			foo(0);
      baz();
      }
      ]=])

    execute('set cino&')
    feed('2kdd2j=][<cr>')

    expect([=[
      
      void func(void)
      {
      	for (int i = 0; i < 10; ++i)
      		if (i & 1) {
      			foo(1);
      		} else
      			foo(0);
      	baz();
      }
      ]=])
  end)

  it('40 is working', function()
    insert_([=[
      
      
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
      ]=])

    execute('set cino=k2s,(0')
    feed('2kdd3j=][<cr>')

    expect([=[
      
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
      ]=])
  end)

  it('41 is working', function()
    insert_([=[
      
      
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
      ]=])

    execute('set cino=k2s,(s')
    feed('2kdd3j=][<cr>')

    expect([=[
      
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
      ]=])
  end)

  it('42 is working', function()
    insert_([=[
      
      
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
      ]=])

    execute('set cino=k2s,(s,U1')
    feed('2kdd3j=][<cr>')

    expect([=[
      
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
      ]=])
  end)

  it('43 is working', function()
    insert_([=[
      
      
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
      ]=])

    execute('set cino=k2s,(0,W4')
    feed('2kdd3j=][<cr>')

    expect([=[
      
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
      ]=])
  end)

  it('44 is working', function()
    insert_([=[
      
      
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
      ]=])

    execute('set cino=k2s,u2')
    feed('2kdd3j=][<cr>')

    expect([=[
      
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
      ]=])
  end)

  it('45 is working', function()
    insert_([=[
      
      
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
      ]=])

    execute('set cino=k2s,(0,w1')
    feed('2kdd3j=][<cr>')

    expect([=[
      
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
      ]=])
  end)

  it('46 is working', function()
    insert_([=[
      
      
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
      ]=])

    execute('set cino=k2,(s')
    feed('2kdd3j=][<cr>')

    expect([=[
      
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
      ]=])
  end)

  it('47 is working', function()
    insert_([=[
      
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
      NAMESPACEEND
      ]=])

    execute('set cino=N-s')
    execute('/^NAMESPACESTART')
    feed('=/^NAMESPACEEND<cr>')

    expect([=[
      
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
      NAMESPACEEND
      ]=])
  end)

  it('48 is working', function()
    insert_([=[
      
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
      ]=])

    execute('set cino=j1,J1')
    execute('/^JSSTART')
    feed('=/^JSEND<cr>')

    expect([=[
      
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
      ]=])
  end)

  it('49 is working', function()
    insert_([=[
      
      JSSTART
      var foo = [
      1,
      2,
      3
      ];
      JSEND
      ]=])

    execute('set cino=j1,J1')
    execute('/^JSSTART')
    feed('=/^JSEND<cr>')

    expect([=[
      
      JSSTART
      var foo = [
      	1,
      	2,
      	3
      ];
      JSEND
      ]=])
  end)

  it('50 is working', function()
    insert_([=[
      
      JSSTART
      function bar() {
      var foo = [
      1,
      2,
      3
      ];
      }
      JSEND
      ]=])

    execute('set cino=j1,J1')
    execute('/^JSSTART')
    feed('=/^JSEND<cr>')

    expect([=[
      
      JSSTART
      function bar() {
      	var foo = [
      		1,
      		2,
      		3
      	];
      }
      JSEND
      ]=])
  end)

  it('51 is working', function()
    insert_([=[
      
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
      ]=])

    execute('set cino=j1,J1')
    execute('/^JSSTART')
    feed('=/^JSEND<cr>')

    expect([=[
      
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
      ]=])
  end)

  it('52 is working', function()
    insert_([=[
      
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
      ]=])

    execute('set cino=j1,J1')
    execute('/^JSSTART')
    feed('=/^JSEND<cr>')

    expect([=[
      
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
      ]=])
  end)

  it('53 is working', function()
    insert_([=[
      
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
      ]=])

    execute('set cino=j1,J1')
    execute('/^JSSTART')
    feed('=/^JSEND<cr>')

    expect([=[
      
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
      ]=])
  end)

  it('javascript indent / vim-patch 7.4.670', function()
    insert_([=[
      
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
      ]=])

    -- :set cino=j1,J1,+2
    execute('set cino=j1,J1,+2')
    execute('/^JSSTART')
    feed('=/^JSEND<cr>')

    expect([=[
      
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
      ]=])
  end)
end)
