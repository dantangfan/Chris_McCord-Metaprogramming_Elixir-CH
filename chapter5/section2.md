## 支持全部的 HTML 标签

想必你已经想到了，既然我们的标签结构都是一样的，那我们就可以使用第三章 Unicode 库的方法———引用外部文件来生成一批代码。我们包含所有 HTML 标签的文件为 tags.txt，里面一行一个标签，就像这样

```
html
head
body
div
```

所以下面我们就来修改原来的 html.exs 来支持所有标签

```elixir
defmodule Html do

  @external_resource tags_path = Path.join([__DIR__, "tags.txt"])
  @tags (for line <- File.stream!(tags_path, [], :line) do
    line |> String.strip |> String.to_atom
  end)

  for tag <- @tags do
    defmacro unquote(tag)(do: inner) do
      tag = unquote(tag)
      quote do: tag(unquote(tag), do: unquote(inner))
    end
  end
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

这里，我们先把所有的标签都放到 @tags 属性里面，然后 for 循环中为每个标签都定义一个宏，这个宏其实就是引用了我们的 tag 宏。不要被这些重复的 tag 名字给迷惑了，不习惯的话，可以为每个变量都取个不同的名字，这样不容易混淆。

既然 Html 都重写了，那我们的 Template 也来chong新实现一遍

```elixir
defmodule Template do
  import Html

  def render do
    markup do
      table do
        tr do
          for i <- 1..5 do
            td do: text("Cell #{i}")
          end
        end
      end
      div do
        text "Some Nested Content"
      end
    end
  end
end
```

然后执行一次，也是跟刚刚得到的结果是一样的

```bash
iex(3)> c "html.exs"
[Template, Html]
iex(4)> Template.render
"<table><tr><td>Cell 1</td><td>Cell 2</td><td>Cell 3</td><td>Cell 4</td><td>Cell 5</td></tr></table><div>Some Nested Content</div>"
```

好了，标签的都支持了，很明显，下一步就该是支持标签属性了

