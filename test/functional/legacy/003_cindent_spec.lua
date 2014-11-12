-- /* vim: set cin ts=4 sw=4 : */
-- Test for 'cindent'

local helpers = require('test.functional.helpers')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

describe('cindent', function()
  setup(clear)

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
      
      /* end of AUTO */
      ]])

      execute('so small.vim')
      execute('set nocompatible viminfo+=nviminfo modeline')
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
      
      /* end of AUTO */
      ]])

  end)

end)
