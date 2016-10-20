## 最小化的可行 API

我们知道我们要实现什么样的 DSL 了，下面就需要设计 API 了。HTML 又 117 个标签，不过我们只需要其中一小部分就能表示一个简单的网页，这小部分就是我们首先要实现的了。我们最小化的 API 里面会包含一个 tag 宏用来处理标签，一个 text 宏用来注入原始字符串，一个 markup 宏用来包裹整个生成 HTML 的代码块。

假如我们已经实现了这几个宏，那么前一节里面的例子就可以这样写了

```elixir
markup do
  tag :div, class: "row" do
    tag :h1 do
      text title
    end
    tag :article do
      tag :p, do: text "Welcome"
    end
  end
  if logged_in? do
    tag :a, href: "edit.html" do
      text "Edit"
    end
  end
end
```

虽然看起来很简陋，但是我们这个最小化 API 已经能够表达简单的 HTML 了，实际上可以看出，如果 tag 宏实现良好，让他支持所有 117 个标签也就是堆代码的事情了。

我们来简单的罗列一下，我们这个最小化的 API 到底有些什么需求。首选，要支持 markup, tag, text 宏这是肯定的。然后，有个不太明显的需求，就是要保持输出数据的状态，因为我们的输出数据是不断的拼凑出来的，而且实现的 DSL 中肯定夹杂着 Elixir 的表达式，所以我们必须在运行时存储生成数据(HTML)的中间状态。

为了解释为什么输出数据会有中间状态需要保存，我们用个小例子说明，buff 就是输出数据

```elixir
markup do             # buff = ""
  div do              # buff = buff <> "<div>"
    h1 do             # buff = buff <> "<h1>"
      text "hello"    # buff = buff <> "hello"
    end               # buff = buff <> "</h1>"
  end                 # buff = buff <> "</div>"
end                   # buff
```

这样不断的更新 buff 值看起来很简单，并且可靠；不过稍微复杂点的会怎样呢？比如我们再来看看一个存在 for 循环的

```elixir
markup do              # buff = ""
  tag :table do        # buff = buff <> "<table>"
    tag :tr do         # buff = buff <> "<tr>"
      for i <- 0..3 do # buff = buff
        tag :td do     # buff = buff <> "<td>"
          text "#{i}"  # buff = buff <> "#{i}"
        end            # buff = buff <> "</td>"
      end              # buff = buff
    end                # buff = buff <> "</tr>"
  end                  # buff = buff <> "</div>"
end                    # buff
```

看起来很美好，但实际上并不那么美好。注意，当我们碰到 for 循环的时候，内部的 buff 作为变量，作用域只在 for 循环内部，也就是说，当跳出循环的时候， td 标签都搞没了。用代码来作解释就是这么回事

```bash
iex(1)> buff = ""
""
iex(2)> for i <- 1..3 do
...(2)>   buff = buff <> "#{i}"
...(2)>   IO.inspect buff
...(2)> end
"1"
"2"
"3"
["1", "2", "3"]
iex(3)> buff
""
```

看起来清晰明了，大家都能理解。所以，我们的 buff 需要每个 tag 都能作用到的，而不管它处于哪个作用域，看起来就好像是一个全局变量～然而 Elixir 并没有。幸运的是 Agent 模块就能很好的处理这件事，不用费心自己去写个单独的进程了。

### 把状态值保存在 Agent 中

我们看看 Agent 是如何保持状态值的

```bash
iex(6)> {:ok, buffer} = Agent.start_link fn -> [] end
{:ok, #PID<0.91.0>}
iex(7)> Agent.get(buffer, fn state -> state end)
[]
iex(8)> Agent.update(buffer, &["<h1>Hello</h1>"| &1])
:ok
iex(9)> Agent.get(buffer, &(&1))
["<h1>Hello</h1>"]
iex(10)> for i <- 1..3, do: Agent.update(buffer, &["<td>#{i}</td>"| &1])
[:ok, :ok, :ok]
iex(11)> Agent.get(buffer, &(&1))
["<td>3</td>", "<td>2</td>", "<td>1</td>", "<h1>Hello</h1>"]
```

Agent 自身能保证 buffer 数据的快速存取。上面的例子中，我们以 [] 作为 buffer 的初始值，然后每次都在前面追加需要插入的值。现在我们就可以动手来实现我们的模块了，建立一个 html.exs。

```elixir
defmodule Html do
  defmacro markup(do: block) do
    quote do
      {:ok, var!(buffer, Html)} = start_buffer([])
      unquote(block)
      result = render(var!(buffer, Html))
      :ok = stop_buffer(var!(buffer, Html))
      result
    end
  end

  def start_buffer(state), do: Agent.start_link(fn -> state end)

  def stop_buffer(buff), do: Agent.stop(buff)

  def put_buffer(buff, content), do: Agent.update(buff, &[content| &1])

  def render(buff), do: Agent.get(buff, &(&1) |> Enum.reverse |> Enum.join(""))

  defmacro tag(name, do: inner) do
    quote do
      put_buffer var!(buffer, Html), "<#{unquote(name)}>"
      unquote(inner)
      put_buffer var!(buffer, Html), "</#{unquote(name)}>"
    end
  end

  defmacro text(string) do
    quote do: put_buffer(var!(buffer, Html), to_string(unquote(string)))
  end
end
```

这里的代码都很容易看懂，除了一个地方 var!(buffer, Html)。我们知道，使用了 var! 的参数可以访问和修改 quote 外部的数据，但同时，这个数据也能被 quote 外部访问。但加入了第二个参数后，就不一样了，这就使得当前参数 bugger 只能被 Html 这个作用域访问到，caller 是访问不到的。这样的使用方法并不多见，如果可以，应该尽可能的避免使用 var!，以免造成难以调试的 bug

我们可以这样使用它

```elixir
defmodule Template do
  import Html

  def render do
    markup do
      tag :table do
        tag :tr do
          for i <- 1..5 do
            tag :td, do: text("Cell #{i}")
          end
        end
      end
      tag :div do
        text "Some Nested Content"
      end
    end
  end
end
```

然后我们测试一下

```bash
iex(2)> c "html.exs"   
[Template, Html]
iex(3)> Template.render
"<table><tr><td>Cell 1</td><td>Cell 2</td><td>Cell 3</td><td>Cell 4</td><td>Cell 5</td></tr></table><div>Some Nested Content</div>"
```
不错，既然这里都成功了，那我们是不是应该来支持所有标签了呢？聪明的你肯定想到办法了，我们前面用过的。
