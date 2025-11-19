# 欢迎来到 Neovim 教程

# 第 2 章

  此处有龙（拉丁语 Hic Sunt Dracones，表示有危险）：如果这是您第一次接触 vim，并
  且您希望从入门章节开始，请在 Vim 编辑器的命令行中输入：
~~~ cmd
        :Tutor vim-01-beginner
~~~
  或者直接点击链接打开教程的[第一章](@tutor:vim-01-beginner)。

  完成本章大约需要 8-10 分钟，具体取决于您在实践探索上花费的时间。


# 第 2.1.1 课：命名寄存器

** 同时复制两个单词，然后分别粘贴它们 **

  1. 将光标移动到下面标有 ✓ 的那一行。

  2. 导航到 'Edward' 单词的任意位置，然后输入 `"ayiw`{normal}

**助记**：*将 (i)nner (w)ord（内部单词）(y)ank（复制）到名为 (a) 的寄存器（"）中*

  3. 向前导航到 'cookie' 单词（可以使用 `fk`{normal} 或 `2fc`{normal}
     或 `$2b`{normal} 或 `/co`{normal} `<Enter>`{normal}），然后输入 `"byiw`{normal}

  4. 导航到 'Vince' 单词的任意位置，然后输入 `ciw<CTRL-r>a<ESC>`{normal}

**助记**：*用名为 (a) 的寄存器（<contents of (r)egister>）的内容 (c)hange (i)
nner (w)ord（修改内部单词）*

  5. 导航到 'cake' 单词的任意位置，然后输入 `ciw<CTRL-r>b<ESC>`{normal}

a) Edward will henceforth be in charge of the cookie rations
b) In this capacity, Vince will have sole cake discretionary powers

NOTE: 删除操作同样可以存入寄存器，例如 `"sdiw`{normal} 会将被光标下的单词删除并存入寄存器 s。

参考：[寄存器](registers)
      [命名寄存器](quotea)
      [移动与文本对象](text-objects)
      [CTRL-R](i_CTRL-R)


# 第 2.1.2 课：表达式寄存器

** 即时插入计算结果 **

  1. 将光标移动到下面标有 ✗ 的那一行。

  2. 导航到所给数字的任意位置。

  3. 输入 `ciw<CTRL-r>=`{normal}60\*60\*24 `<Enter>`{normal}

  4. 在下一行，进入插入模式，并使用
     `<CTRL-r>=`{normal}`system('date')`{vim} `<Enter>`{normal} 来添加今天的日期。

NOTE: 所有对 `system` 的调用都依赖于操作系统，例如在 Windows 上应使用
      `system('date /t')`{vim}   或  `:r!date /t`{vim}

I have forgotten the exact number of seconds in a day, is it 84600?
Today's date is: 

NOTE: 同样效果也可以通过 `:pu=`{normal}`system('date')`{vim} 实现，
      或者用更少的按键 `:r!date`{vim}

参考：[表达式寄存器](quote=)


# 第 2.1.3 课：数字寄存器

** 按下 `yy`{normal} 和 `dd`{normal} 来观察它们对寄存器的影响 **

  1. 将光标移动到下面标有 ✓ 的那一行。

  2. 复制（yank）第 0 行，然后用 `:reg`{vim} `<Enter>`{normal} 查看寄存器。

  3. 用 `"cdd`{normal} 删除第 0 行，然后再次查看寄存器。
     (你觉得第 0 行的内容会出现在哪里？)

  4. 继续删除后续的每一行，并在每次删除后用 `:reg`{vim} 查看寄存器。

NOTE: 你应该会发现，当新的整行删除内容被添加进来时，之前删除的内容会在寄存器列
表中依次下移。

  5. 现在，按顺序 (p)aste（粘贴）以下寄存器中的内容：c, 7, 4, 8, 2。例如，使用 `"7p`{normal}

0. This
9. wobble
8. secret
7. is
6. on
5. axis
4. a
3. war
2. message
1. tribute


NOTE: 在数字寄存器中，整行删除（`dd`{normal}）的内容比整行复制或涉及更小范围移动
的删除操作“存活”得更久。

参考：[数字寄存器](quote0)


# 第 2.1.4 课：标记之美

** 避免“码农式”的行号计算 **

NOTE: 在写代码时，一个常见的难题是移动大块的代码。
      下面的技巧可以帮助你避免进行行号计算，比如 `"a147d`{normal} 或 `:945,1091d a`{vim}，
      甚至是更麻烦的先用 `i<CTRL-r>=`{normal}1091-945 `<Enter>`{normal} 计算行数。

  1. 将光标移动到下面标有 ✓ 的那一行。

  2. 跳转到函数的第一行，并用 `ma`{normal} 将其标记为 a。

NOTE: 光标在该行的确切位置并不重要！

  3. 使用 `$%`{normal} 导航到行尾，然后再到代码块的末尾。

  4. 使用 `"ad'a`{normal} 将该代码块删除并存入寄存器 a。

**助记**：*将从光标位置到包含标记（'）(a) 的那一行的内容 (d)elete（删除）到名为 (a) 的寄存器（"）中*

  5. 在 BBB 和 CCC 之间用 `"ap`{normal} 粘贴该代码块。

NOTE: 多次练习这个操作以达到熟练：`ma$%"ad'a`{normal}

~~~ cmd
AAA
function itGotRealBigRealFast() {
  if ( somethingIsTrue ) {
    doIt()
  }
  // the taxonomy of our function has changed and it
  // no longer makes alphabetical sense in its current position

  // imagine hundreds of lines of code

  // naively you could navigate to the start and end and record or
  // remember each line number
}
BBB
CCC
~~~

NOTE: 标记和寄存器不共享命名空间，因此寄存器 a 和标记 a 是完全独立的。
      但寄存器和宏并非如此。

参考：[标记](marks)
      [标记移动](mark-motions)（' 和 \` 的区别）


# 第 2.1 课总结

  1. 将文本 存储（复制、删除）到 26 个寄存器（a-z）中，并从中提取（粘贴）出来。
  2. 从单词内的任意位置复制整个单词：`yiw`{normal}
  3. 从单词内的任意位置更改整个单词：`ciw`{normal}
  4. 在插入模式下直接从寄存器插入文本：`<CTRL-r>a`{normal}

  5. 插入简单算术运算的结果：
     在插入模式下使用 `<CTRL-r>=`{normal}60\*60 `<Enter>`{normal}
  6. 插入系统调用的结果：
     在插入模式下使用 `<CTRL-r>=`{normal}`system('ls -1')`{vim}

  7. 使用 `:reg`{vim} 查看寄存器。
  8. 了解整行删除 (`dd`{normal}) 的最终去向：在数字寄存器中，即从寄存器 1 到 9
     依次向下存放。要理解整行删除的内容在数字寄存器中比任何其他操作都保存得更久。
  9. 了解所有复制操作在数字寄存器中的最终去向，以及它们是多么“短暂易逝”。

 10. 在普通模式下设置标记：`m[a-zA-Z0-9]`{normal}
 11. 按行移动到标记位置：`'`{normal}


# 结语

  Neovim 教程第二章到此结束。本教程仍在不断完善中。

  本章由 Paul D. Parker 编写。

  由 Restorer 为 vim-tutor-mode 修改。

  简体中文翻译版由 PilgrimLyieu <pilgrimlyieu@outlook.com> 译制并校对。

  变更记录：
  - 2025-07-07 PilgrimLyieu <pilgrimlyieu@outlook.com>
      译制并校对
