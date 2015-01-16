-- /* vim: set cin ts=4 sw=4 : */
-- Test for 'cindent'

local helpers = require('test.functional.helpers')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

describe('cindent', function()
  setup(clear)

  it('is working', function()
    insert([[
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
      ]])

    execute('set cin')
    execute('set cino=')
    feed(']]=][<cr>')
    insert([[
      void f()
      {
          if ( k() ) {
              l();
      
          } else { /* Start (two words) end */
              m();
          }
      
          n();
      }
      ]])

    feed(']]=][<cr>')
    insert([[
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
      ]])

    execute('set cino={s,e-s')
    feed(']]=][<cr>')
    insert([[
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
      ]])

    execute('set cino={s,fs')
    feed(']]=/ foo<cr>')
    insert([[
      a()
      {
        do {
          a = a +
            a;
        } while ( a );		/* add text under this line */
          if ( a )
            a;
      }
      ]])

    execute('set cino=')
    execute('/while')
    feed('ohere<esc>')
    insert([[
      a()
      {
      label1:
                  /* hmm */
                  // comment
      }
      ]])

    execute('set cino= com=')
    execute('/comment')
    feed('olabel2: b();label3 /* post */:/* pre */ label4:f(/*com*/);if (/*com*/)cmd();<esc>')
    insert([[
      /*
        * A simple comment
         */
      
      /*
        ** A different comment
         */
      ]])

    execute('set comments& comments^=s:/*,m:**,ex:*/')
    execute('/simple')
    feed('=5j<cr>')
    insert([[
      void f()
      {
      
      	/*********
        A comment.
      *********/
      }
      ]])

    execute('set cino=c0')
    execute('set comments& comments-=s1:/* comments^=s0:/*')
    feed('2kdd]]=][<cr>')
    insert([[
      void f()
      {
      
      	/*********
        A comment.
      *********/
      }
      ]])

    execute('set cino=c0,C1')
    execute('set comments& comments-=s1:/* comments^=s0:/*')
    feed('2kdd]]=][<cr>')
    insert([[
      void f()
      {
      	c = c1 &&
      	(
      	c2 ||
      	c3
      	) && c4;
      }
      ]])

    execute('set cino=')
    feed(']]=][<cr>')
    insert([[
      void f()
      {
      	c = c1 &&
      	(
      	c2 ||
      	c3
      	) && c4;
      }
      ]])

    execute('set cino=(s')
    feed('2kdd]]=][<cr>')
    insert([[
      void f()
      {
      	c = c1 &&
      	(
      	c2 ||
      	c3
      	) && c4;
      }
      ]])

    execute('set cino=(s,U1  ')
    feed('2kdd]]=][<cr>')
    insert([[
      void f()
      {
      	if (   c1
      	&& (   c2
      	|| c3))
      	foo;
      }
      ]])

    execute('set cino=(0')
    feed('2kdd]]=][<cr>')
    insert([[
      void f()
      {
      	if (   c1
      	&& (   c2
      	|| c3))
      	foo;
      }
      ]])

    execute('set cino=(0,w1  ')
    feed('2kdd]]=][<cr>')
    insert([[
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
      ]])

    execute('set cino=(s')
    feed('2kdd]]=][<cr>')
    insert([[
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
      ]])

    execute('set cino=(s,m1  ')
    feed('2kdd]]=][<cr>')
    insert([[
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
      ]])

    execute('set cino=b1')
    feed('2kdd]]=][<cr>')
    insert([[
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
      ]])

    execute('set cino=(0,W5')
    feed('2kdd]]=][<cr>')
    insert([[
      void f()
      {
      	statement;
      		// comment 1
      	// comment 2
      }
      ]])

    execute('set cino=/6')
    feed('2kdd]]=][<cr>')
    insert([[
      void f()
      {
      	statement;
      	   // comment 1
      	// comment 2
      }
      ]])

    execute('set cino=')
    feed('2kdd]]/comment 1/+1<cr>')
    feed('==<cr>')
    insert([[
      class CAbc
      {
         int Test() { return FALSE; }
      
      public: // comment
         void testfall();
      protected:
         void testfall();
      };
      ]])

    execute('set cino=g0')
    feed('2kdd]]=][<cr>')
    insert([[
      class Foo : public Bar
      {
      public:
      virtual void method1(void) = 0;
      virtual void method2(int arg1,
      int arg2,
      int arg3) = 0;
      };
      ]])

    execute('set cino=(0,gs,hs')
    feed('2kdd]]=][<cr>')
    insert([[
      	void
      foo()
      {
      	if (a)
      	{
      	} else
      		asdf;
      }
      ]])

    execute('set cino=+20')
    feed('2kdd]]=][<cr>')
    insert([[
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
      ]])

    execute('set cino=(0,W2s')
    feed('2kdd]]=][<cr>')
    insert([[
      int main ()
      {
      	if (cond1 &&
      			cond2
      			)
      		foo;
      }
      ]])

    execute('set cino=M1')
    feed('2kdd]]=][<cr>')
    insert([[
      void func(int a
      #if defined(FOO)
      		  , int b
      		  , int c
      #endif
      		 )
      {
      }
      ]])

    execute('set cino=(0,ts')
    feed('2kdd=][<cr>')
    insert([[
      void
      func(int a
      #if defined(FOO)
      		  , int b
      		  , int c
      #endif
      		 )
      {
      }
      ]])

    execute('set cino=(0')
    feed('2kdd=][<cr>')
    insert([[
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
      ]])

    execute('set cino&')
    feed('2kdd=7][<cr>')
    insert([[
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
      ]])

    execute('set cino&')
    execute('set cino+=l1')
    feed('2kdd=][<cr>')
    insert([[
      void func(void)
      {
      	cout << "a"
      	<< "b"
      	<< ") :"
      	<< "c";
      }
      ]])

    execute('set cino&')
    feed('2kdd=][<cr>')
    insert([[
      void func(void)
      {
      	/*
      	 * This is a comment.
      	 */
      }
      ]])

    execute('set com=s1:/*,m:*,ex:*/')
    feed(']]3jofoo();<esc>')
    insert([[
      void func(void)
      {
      	for (int i = 0; i < 10; ++i)
      		if (i & 1) {
      			foo(1);
      		} else
      			foo(0);
      baz();
      }
      ]])

    execute('set cino&')
    feed('2kdd=][<cr>')
    insert([[
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
      ]])

    execute('set cino=k2s,(0')
    feed('2kdd3j=][<cr>')
    insert([[
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
      ]])

    execute('set cino=k2s,(s')
    feed('2kdd3j=][<cr>')
    insert([[
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
      ]])

    execute('set cino=k2s,(s,U1')
    feed('2kdd3j=][<cr>')
    insert([[
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
      ]])

    execute('set cino=k2s,(0,W4')
    feed('2kdd3j=][<cr>')
    insert([[
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
      ]])

    execute('set cino=k2s,u2')
    feed('2kdd3j=][<cr>')
    insert([[
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
      ]])

    execute('set cino=k2s,(0,w1')
    feed('2kdd3j=][<cr>')
    insert([[
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
      ]])

    execute('set cino=k2,(s')
    feed('2kdd3j=][<cr>')
    insert([[
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
      
      ]])

    execute('set cino=N-s')
    execute('/^NAMESPACESTART')
    feed('=/^NAMESPACEEND<cr>')
    insert([[
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
      ]])

    execute('set cino=j1,J1')
    execute('/^JSSTART')
    feed('=/^JSEND<cr>')
    insert([[
      JSSTART
      var foo = [
      1,  // indent 8 more
      2,
      3
      ];  // indent 8 less
      JSEND
      ]])

    execute('set cino=j1,J1')
    execute('/^JSSTART')
    feed('=/^JSEND<cr>')
    insert([[
      JSSTART
      function bar() {
      var foo = [
      1,
      2,
      3
      ];  // indent 16 less
      }
      JSEND
      ]])

    execute('set cino=j1,J1')
    execute('/^JSSTART')
    feed('=/^JSEND<cr>')
    insert([[
      JSSTART
      (function($){
      
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
      bar: 2,  // indent 8 more
      foobar: [  // indent 8 more
      1,  // indent 8 more
      2,  // indent 16 more
      3   // indent 16 more
      ],
      callback: function(){  // indent 8 more
      return true;  // indent 8 more
      }  // indent 8 more
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
      ]])

    execute('set cino=j1,J1')
    execute('/^JSSTART')
    feed('=/^JSEND<cr>')
    insert([[
      JSSTART
      function init(options) {
      $(this).data(class_name+'_public',$.extend({},{
      foo: 'bar',
      bar: 2,
      foobar: [
      1,  // indent 8 more
      2,  // indent 8 more
      3   // indent 8 more
      ],
      callback: function(){
      return true;
      }
      }, options||{}));
      }
      JSEND
      ]])

    execute('set cino=j1,J1')
    execute('/^JSSTART')
    feed('=/^JSEND<cr>')
    insert([[
      JSSTART
      (function($){
      function init(options) {
      $(this).data(class_name+'_public',$.extend({},{
      foo: 'bar',
      bar: 2,  // indent 8 more
      foobar: [  // indent 8 more
      1,  // indent 8 more
      2,  // indent 16 more
      3  // indent 16 more
      ],
      callback: function(){  // indent 8 more
      return true;  // indent 8 more
      }  // indent 8 more
      }, options||{}));
      }
      })(jQuery);
      JSEND
      ]])

    execute('set cino=j1,J1')
    execute('/^JSSTART')
    feed('=/^JSEND<cr>')

    -- Assert buffer contents.
    expect([[
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
      
      
      void f()
      {
      	if ( k() ) {
      		l();
      
      	} else { /* Start (two words) end */
      		m();
      	}
      
      	n();
      }
      
      
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
      
      
      /*
       * A simple comment
       */
      
      /*
      ** A different comment
      */
      
      
      void f()
      {
      
      	/*********
      	  A comment.
      	*********/
      }
      
      
      void f()
      {
      
      	/*********
      	A comment.
      	*********/
      }
      
      
      void f()
      {
      	c = c1 &&
      		(
      		 c2 ||
      		 c3
      		) && c4;
      }
      
      
      void f()
      {
      	c = c1 &&
      		(
      		 c2 ||
      		 c3
      		) && c4;
      }
      
      
      void f()
      {
      	c = c1 &&
      		(
      			c2 ||
      			c3
      		) && c4;
      }
      
      
      void f()
      {
      	if (   c1
      		   && (   c2
      				  || c3))
      		foo;
      }
      
      
      void f()
      {
      	if (   c1
      		&& (   c2
      			|| c3))
      		foo;
      }
      
      
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
      
      
      void f()
      {
      	statement;
      		  // comment 1
      		  // comment 2
      }
      
      
      void f()
      {
      	statement;
      	   // comment 1
      	   // comment 2
      }
      
      
      class CAbc
      {
      	int Test() { return FALSE; }
      
      public: // comment
      	void testfall();
      protected:
      	void testfall();
      };
      
      
      class Foo : public Bar
      {
      	public:
      		virtual void method1(void) = 0;
      		virtual void method2(int arg1,
      							 int arg2,
      							 int arg3) = 0;
      };
      
      
      	void
      foo()
      {
      	if (a)
      	{
      	} else
      		asdf;
      }
      
      
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
      
      
      int main ()
      {
      	if (cond1 &&
      			cond2
      			)
      		foo;
      }
      
      
      void func(int a
      #if defined(FOO)
      		  , int b
      		  , int c
      #endif
      		 )
      {
      }
      
      
      	void
      func(int a
      #if defined(FOO)
      	 , int b
      	 , int c
      #endif
      	)
      {
      }
      
      
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
      
      
      void func(void)
      {
      	cout << "a"
      		<< "b"
      		<< ") :"
      		<< "c";
      }
      
      
      void func(void)
      {
      	/*
      	 * This is a comment.
      	 */
      	foo();
      }
      
      
      void func(void)
      {
      	for (int i = 0; i < 10; ++i)
      		if (i & 1) {
      			foo(1);
      		} else
      			foo(0);
      	baz();
      }
      
      
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
      
      
      JSSTART
      var foo = [
      1,  // indent 8 more
      	2,
      	3
      	];  // indent 8 less
      JSEND
      
      
      JSSTART
      function bar() {
      	var foo = [
      		1,
      		2,
      		3
      			];  // indent 16 less
      }
      JSEND
      
      
      JSSTART
      (function($){
      
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
      		bar: 2,  // indent 8 more
      		foobar: [  // indent 8 more
      			1,  // indent 8 more
      		2,  // indent 16 more
      		3   // indent 16 more
      			],
      		callback: function(){  // indent 8 more
      			return true;  // indent 8 more
      		}  // indent 8 more
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
      
      
      JSSTART
      function init(options) {
      	$(this).data(class_name+'_public',$.extend({},{
      		foo: 'bar',
      		bar: 2,
      		foobar: [
      		1,  // indent 8 more
      		2,  // indent 8 more
      		3   // indent 8 more
      		],
      		callback: function(){
      			return true;
      		}
      	}, options||{}));
      }
      JSEND
      
      
      JSSTART
      (function($){
      	function init(options) {
      		$(this).data(class_name+'_public',$.extend({},{
      			foo: 'bar',
      		bar: 2,  // indent 8 more
      		foobar: [  // indent 8 more
      			1,  // indent 8 more
      		2,  // indent 16 more
      		3  // indent 16 more
      			],
      		callback: function(){  // indent 8 more
      			return true;  // indent 8 more
      		}  // indent 8 more
      		}, options||{}));
      	}
      })(jQuery);
      JSEND
      ]])
  end)
end)
