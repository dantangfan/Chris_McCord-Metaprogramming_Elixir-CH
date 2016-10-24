## 精简我们的代码

本来，我们的代码就算写完了。不过，我们生成了大量的代码，而且这些代码还是宏，宏还会继续生成代码。下面我们就来改造一下，看如何生成更少的代码照样能完成我们的使命。

可能现在看来，不为每个宏生成一个宏(函数)好像不太可能，然而 Elixir 就是能做到。我们来观察一下，我们使用的 HTML 标签宏，比如 div 的 AST 树是咋样的

```bash
iex(1)> ast = quote do
...(1)>   div do
...(1)>     h1 do
...(1)>       test "Hello"
...(1)>     end
...(1)>   end
...(1)> end
{:div, [], [[do: {:h1, [], [[do: {:test, [], ["Hello"]}]]}]]}
```

十分简单吧。看这个结构，实际上就是把宏包裹在其他宏内嘛，那我们是不是可以不用为每个标签生成一个完整的宏，而是直接操作 AST 树。

Elixir 有几个函数可以让帮助我们通过广度优先或者深度优先的方式来遍历 AST 树，他们是 Macro.prewalk/2 Macro.postwalk/2 。我们来使用 IO.inspect 看看遍历效果

```bash
iex(2)> Macro.postwalk ast, fn segment -> IO.inspect(segment) end
:do
:do
"Hello"
{:test, [], ["Hello"]}
{:do, {:test, [], ["Hello"]}}
[do: {:test, [], ["Hello"]}]
{:h1, [], [[do: {:test, [], ["Hello"]}]]}
{:do, {:h1, [], [[do: {:test, [], ["Hello"]}]]}}
[do: {:h1, [], [[do: {:test, [], ["Hello"]}]]}]
{:div, [], [[do: {:h1, [], [[do: {:test, [], ["Hello"]}]]}]]}
{:div, [], [[do: {:h1, [], [[do: {:test, [], ["Hello"]}]]}]]}

iex(3)> Macro.prewalk ast, fn segment -> IO.inspect(segment) end 
{:div, [], [[do: {:h1, [], [[do: {:test, [], ["Hello"]}]]}]]}
[do: {:h1, [], [[do: {:test, [], ["Hello"]}]]}]
{:do, {:h1, [], [[do: {:test, [], ["Hello"]}]]}}
:do
{:h1, [], [[do: {:test, [], ["Hello"]}]]}
[do: {:test, [], ["Hello"]}]
{:do, {:test, [], ["Hello"]}}
:do
{:test, [], ["Hello"]}
"Hello"
{:div, [], [[do: {:h1, [], [[do: {:test, [], ["Hello"]}]]}]]}
```

乍得一看，我们可以发现 Macro.prewalk 和 Macro.postwalk 遍历了我们的 AST 并且把每个三元组都转换成了函数病执行返回结果。下面我们就来感受这个神奇的魔法，看他如何重新实现我们的 HTML DSL 的。

```elixir
defmodule Html do

  @external_resource tags_path = Path.join([__DIR__, "tags.txt"])
  @tags (for line <- File.stream!(tags_path, [], :line) do
    line |> String.strip |> String.to_atom
  end)

  defmacro markup(do: block) do
    quote do
      {:ok, var!(buffer, Html)} = start_buffer([])
      unquote(Macro.postwalk(block, &postwalk/1))
      result = render(var!(buffer, Html))
      :ok = stop_buffer(var!(buffer, Html))
      result
    end
  end

  def postwalk({:text, _meta, [string]}) do
    quote do: put_buffer(var!(buffer, Html), to_string(unquote(string)))
  end
  def postwalk({tag_name, _meta, [[do: inner]]}) when tag_name in @tags do
    quote do: tag(unquote(tag_name), [], do: unquote(inner))
  end
  def postwalk({tag_name, _meta, [attrs, [do: inner]]}) when tag_name in @tags do
    quote do: tag(unquote(tag_name), unquote(attrs), do: unquote(inner))
  end
  def postwalk(ast) do
    ast
  end

  def start_buffer(state), do: Agent.start_link(fn -> state end)

  def stop_buffer(buff), do: Agent.stop(buff)

  def put_buffer(buff, content), do: Agent.update(buff, &[content| &1])

  def render(buff), do: Agent.get(buff, &(&1) |> Enum.reverse |> Enum.join(""))

  defmacro tag(name, attrs, do: inner) do
    quote do
      put_buffer var!(buffer, Html), open_tag(unquote_splicing([name, attrs]))
      unquote(inner)
      put_buffer var!(buffer, Html), "</#{unquote(name)}>"
    end
  end

  def open_tag(name, []), do: "<#{name}>"
  def open_tag(name, attrs) do
    attr_html = for {key, val} <- attrs, into: "", do: " #{key}=\"#{val}\""
    "<#{name}#{attr_html}>"
  end

  defmacro text(string) do
    quote do: put_buffer(var!(buffer, Html), to_string(unquote(string)))
  end
end

```

我们首先改造了 markup 宏，里面调用了 Macro.postwalk，它以后面定义的 postwalk/1 作为处理参数，代替了原有用于生成大量标签宏的 for 循环。实际上，就是把生成标签宏的中间过程省略了，直接将原来标签宏调用时要生成的代码在调用 markup 的时候注入到了 markup 中。下面我们来分析，这些个函数和宏是如何工作的。

第一个 postwalk 宏，处理了 text 类型的宏然后返回了一哥 put_buffer 的 AST，参数被转换成了一个 string，我们原来的 text 宏也是这样做的！然后下面一个 postwalk 宏，我们就直接匹配了所有的 HTML 标签，用了 when 表达式，不是 HTML 标签的就直接返回，是的就按照 tag 展开。比如我们来感受下，展开后是怎样的。

```bash
iex(1)> c "html_macro_walks.exs"
warning: redefining module Html (current version loaded from Elixir.Html.beam)
html_macro_walks.exs:1

[Html]
iex(2)> import Html
Html
iex(3)> ast = quote do
...(3)>   markup do
...(3)>     div do
...(3)>       text "Some text"
...(3)>     end
...(3)>   end
...(3)> end
{:markup, [context: Elixir, import: Html],
 [[do: {:div, [],
     [[do: {:h1, [],
            [[do: {:text, [context: Elixir, import: Html], ["Some text"]}]]}]]}]]}
iex(4)> ast |> Macro.expand(__ENV__) |> Macro.to_string |> IO.puts
(
  {:ok, var!(buffer, Html)} = start_buffer([])
  tag(:div, []) do
    put_buffer(var!(buffer, Html), to_string("some text"))
  end
  result = render(var!(buffer, Html))
  :ok = stop_buffer(var!(buffer, Html))
  result
)
:ok
iex(5)> 
```

这里，理解 postwalk 是如何工作的需要花点时间，但这是值得的。尽管我们很少会用到这个操作，但有时候知道这个特性能让我们事半功倍
