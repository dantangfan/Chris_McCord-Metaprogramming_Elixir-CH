Elixir 的宏编程实际上就是编程语言的扩展。比如，你有没有盼望过你喜欢的语言加入某个你想要的特性？运气好的话，三五几年也是可能梦想成真的，但通常这是不可能的。但在 Elixir 中，你可以加入任何你想要的特性。比如说，我们常见的语言都有 while 循环，但是 Elixir 却没有，不过你可以自己实现一个 while 语法，可能你的循环写起来会像这样：

```elixir
while Process.alive?(pid) do
  send pid, {self, :ping}
  receive do
    {^pid, :pong} -> IO.puts "Got pong"
  after 2000 -> break
  end
end
```

下一章，我们将实现这么一个 while 循环。不仅如此，我们还可以用 Elixir 来定义任意代码语法来解决现实生活中可能遇到的各种问题。比如下面代码可以是一个合法的 Elixir 代码：


```elixir
div do
  h1 class: "title" do
    text "hello"
  end
  p do
    text "Metaprogramming Elixir"
  end
end

"<div><h1 class=\"title\">Hello</h1><p>Metaprogramming Elixir</p></div>"
```

Elixir 使得实现诸如 HTML 的 DSL 成为可能，事实上，我们将在后面的某些章节里实现这个 DSL。元编程比较难掌握，并且使用的时候也需要十分谨慎。步入元编程之旅前，我们首先复习两个 Elixir 的基本概念，这是后面章节的必要基础知识。

### AST 树
要掌握元编程，首先必须理解 Elixir 内部是如何用 AST 树来表示代码的。源代码在编译、解释代码时，会首先将代码翻译成树形结构，然后再生成二进代码或机器码。通常情况下，生成树形结构这个过程是透明的，程序员不用去关心到底做了啥。但 Elixir 却截然不同，它的 AST 树可以用 Elixir 自己的基本数据结构裸露出来，并且可以跟代码交互。

你可以使用 `quote` 宏来和任意的 Elixir 代码交互。本书所讲解的代码生成十分依赖 quote 宏，本书的大部分列子都会使用它。首先，我们进入 iex 一步一步的来：


```elixir
ex(1)> quote do: 1+2
{:+, [context: Elixir, import: Kernel], [1, 2]}
iex(2)> quote do: div(10, 2)
{:div, [context: Elixir, import: Kernel], [10, 2]}
```

我们可以看到 1+1 和 div 操作的 AST 树都可以用简单的 Elixir 结构表示。实际上，你的任何代码都可以用简单的 Elixir 结构表示出来。

既然我们都能操作 AST 树了，那我们就能在编译器做点有趣的事情了。比如 Elixir 标准库中的 Logging 模块，可以通过删除某些表达式来优化 logging 操作，如下示例：


```
def write(path, contents) do
  Logger.debug "Writing contents to file #{path}"
  File.write!(path, contents)
end
```

在测试环境的时候，这句 log 会打印出来，但是在生产环境中不会。因为在生产环境中，debug 语句会被移除，这完全归功于我们能跟编译器的 AST 树交互，比如这里我们移除了环境相关的 debug 语句。对于这种 debug 需求，绝大多数语言都是在执行的时候来判断操作是否需要，这毫无疑问浪费了宝贵的 CPU。

下面，我们就来讲解 Logging.debug 是如何使用宏来实现这种功能。

### 宏

简而言之，宏是能生成代码的代码。他得唯一作用就是用 Elixir 的高阶表达式跟 AST 树交互，Logging.debug 就是利用这个特性来实现其功能的。从 Elixir 的标注库到普通的 Web 框架，宏渗透了 Elixir 编程的方方面面，它让程序员从一个语言的使用者进化成了语言的创作者。

可能你觉得你在书写 Elixir 代码时基本没有用到过宏，但事实却非如此，比如下面代码：


```
defmodule Notifier do
  def ping(pid) do
    if Process.alive?(pid) do
      Logger.debug "Sending ping!"
      send pid, :ping
    end
  end
end
```

这么一段不起眼的代码，里面就包含了四个宏： defmodule, def, if, Logger.debug 。不信你可以自己去看帮助文档


```
iex(3)> h if
* defmacro if(condition, clauses)

Provides an `if/2` macro.
...
```

可能你会迷惑 Elixir 用宏来实现自己的基本语法结构到底有什么好处，其他常见的语言好像都没有这样做。事实上，宏最大的黑魔法在于你可以使用宏来定义自己想要的关键字，从而实现语言的拓展。理解 Elixir 宏编程最好的办法是扔掉刚需关键字和那些不透明的语言内部概念。Elixir 设计的初衷就是拓展，让你能自由的定制需要的特性，这就使得宏编程在 Elixir 中显得非常自然。


### 简单总结一下
