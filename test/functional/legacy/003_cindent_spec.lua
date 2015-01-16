-- /* vim: set cin ts=4 sw=4 : */
-- Test for 'cindent'

local helpers = require('test.functional.helpers')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

describe('cindent', function()
  before_each(clear)
  
  before_each(function ()
      execute("set ts=4 sw=4")
  end)

  it('indents blocks correctly', function()
      insert([[
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
      
      /* end of AUTO */
      ]])

      execute('set cin ts=4 sw=4')
      execute('set nocompatible viminfo+=nviminfo modeline')
      execute('edit                " read modeline')

      -- Read modeline.
      execute('edit')
      execute('/start of AUTO')
      feed('=/end of AUTO<cr>')


      expect([[
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
      
      /* end of AUTO */
      ]])

  end)

  it('indents comments correctly', function()
      insert([[
      {
      
      /* this is
       * a real serious important big
       * comment
       */
      	/* insert " about life, the universe, and the rest" after "serious" */
      }
      ]])

      execute('set tw=0 wm=60 columns=80 noai fo=croq')
      feed('/serious/e<cr>')
      feed('a about life, the universe, and the rest<esc>')

      expect([[
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
      ]])
  end)

  it("indents comments correctly without 'cin' set", function ()
      insert([[
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
      ]])

      execute('set nocin')
      feed('/comments<cr>')
      feed('joabout life<esc>/happens<cr>')
      feed('jothere<esc>/below<cr>')
      feed('oline<esc>/this<cr>')
      feed('Ohello<esc>')

      expect([[
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
      ]])
  end)

  it('indents variable assignments correctly', function()
      insert([[
      {
          var = this + that + vec[0] * vec[0]
      				      + vec[1] * vec[1]
      					  + vec2[2] * vec[2];
      }
      ]])

      execute('set cin')
      feed('/vec2<cr>')
      feed('==')

      expect([[
      {
          var = this + that + vec[0] * vec[0]
      				      + vec[1] * vec[1]
      					  + vec2[2] * vec[2];
      }
      ]])
  end)

  it('indents erroneous mixed statements correctly', function()
      insert([[
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
      ]])

      execute('set cin')
      execute('set cino=}4')
      execute('/testing1')
      feed('k2==/testing2<cr>')
      feed('k2==<cr>')

      expect([[
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
      ]])
  end)

  it('indents multi-line parameter comments correctly', function()
      insert([[
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
      ]])

      execute('set cin')
      execute('set cino=(0,)20')
      feed('/main<cr>')
      feed('=][<cr>')
    
      expect([[
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
      ]])
  end)

  it('parses cino=X0s differently from cino=Xs', function()
      insert([[
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
      ]])

      execute('set cin')
      execute('set cino=es,n0s')
      feed('/main<cr>')
      feed('=][<cr>')

      expect([[
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
      ]])
  end)

end)
