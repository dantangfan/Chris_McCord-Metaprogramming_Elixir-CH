## 支持标签属性

跟写 HTML 一样，当我们的标签需要属性的时候，应该显示的声明出来，就像下面这样

```elixir
div id: "main" do
  h1 class: "title", do: text("Welcome")
  div class: "row" do
    div class: "colum" do
      p "hello"
    end
  end
  button onclick: "javascript: history.go(-1);" do
    text "Back"
  end
end
```

所以，很明显，我们需要重写我们的 Html 模块，来让所有标签都支持属性，不用说也能想到属性 attr 参数肯定是个 Keyword 啦，所以我们来重新实现一次，其实也就修改了 for 和 tag 宏的内容其他都都不动

```elixir
defmodule Html do

  @external_resource tags_path = Path.join([__DIR__, "tags.txt"])
  @tags (for line <- File.stream!(tags_path, [], :line) do
    line |> String.strip |> String.to_atom
  end)

  for tag <- @tags do
    defmacro unquote(tag)(attrs, do: inner) do
      tag = unquote(tag)
      quote do: tag(unquote(tag), unquote(attrs), do: unquote(inner))
    end
    defmacro unquote(tag)(attrs \\ []) do
      tag = unquote(tag)
      quote do: tag(unquote(tag), unquote(attrs))
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

  defmacro tag(name, attrs \\ []) do
    {inner, attrs} = Dict.pop(attrs, :do)
    quote do: tag(unquote(name), unquote(attrs), do: unquote(inner))
  end
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

可以看到，我们对每个标签都定义了两个宏，分别对应有属性值和没属性值，同样，tag 宏也就需要定义两个。然后定义了一个 open_tag 函数来展开属性值，这也很简单。


这里我们第一次用到了 unquote_splicing，它跟 unquote 很像，不同的是，他会注入一个包含参数的 list 到 quoted 的代码中，而 unquote 只会注入单个参数，所以下面两种写法是等价的

```elixir
quote do
  put_buffer var!(buffer, Html), open_tag(unquote_splicing([name, attrs]))
end

quote do
  put_buffer var!(buffer, Html), open_tag(unquote(name), unquote(attrs))
end
```

unquote_splicing 的实用之处在于你可以注入一个列表的变量，尤其是当这个列表的长度是在编译的时候才能决定的情况。

下面又到了测试的时间了，我们实用 TemplateAttrs

```elixir
defmodule TemplateAttrs do
  import Html
  import Kernel, except: [div: 2]

  def render do
    markup do
      div id: "main" do
        h1 class: "title" do
          text "Welcome"
        end
      end
      div class: "row" do
        div do
          p do: text "Hello"
        end
      end
    end
  end
end
```

然而，这里就出问题了，因为 Kernel 也又 div/2 函数(除法函数)，这个时候的我们的 Templateattrs 就不知道该使用那个了，所以，我们这里将 Kernel 中的 div/2 去掉 `import Kernel, except: [div: 2]`

这样就能愉快的跑起来了

```bash
iex(2)> TemplateAttrs.render
"<div id=\"main\"><h1 class=\"title\">Welcome</h1></div><div class=\"row\"><div><p>Hello</p></div></div>"
```
