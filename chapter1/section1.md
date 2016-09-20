Elixir 的宏编程实际上就是编程语言的扩展。比如，你有没有盼望过你喜欢的语言加入某个你想要的特性？运气好的话，三五几年也是可能梦想成真的，但通常这是不可能的。但在 Elixir 中，你可以加入任何你想要的特性。比如说，我们常见的语言都有 while 循环，但是 Elixir 却没有，不过你可以自己实现一个 while 语法，可能你的循环写起来会像这样：

```
while Process.alive?(pid) do
  send pid, {self, :ping}
  receive do
    {^pid, :pong} -> IO.puts "Got pong"
  after 2000 -> break
  end
end
```

下一章，我们将实现这么一个 while 循环。不仅如此，我们还可以用 Elixir 来定义任意代码语法来解决现实生活中可能遇到的各种问题。比如下面代码可以是一个合法的 Elixir 代码：


```
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

你可以使用 `quote` 表达式来和任意的 Elixir 代码交互
