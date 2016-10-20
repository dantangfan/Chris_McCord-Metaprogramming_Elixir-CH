## 特定领域

撸代码之前，我们先来看看什么是 DSL，为什么宏编程会让 DSL 变得简单。在 Elixir 中，DSL 就是用宏来定义的新语言，简单说就是在一门语言里造另一特定领域的门语言。在我们的例子中，我们的特定领域就是生成 HTML。

可能在其他语言中，你已经见过了 HTML 生成了。多数都是通过在代码中标记、解析文件等等最终生成 HTML 字符串。这样做的坏处是在模板语法改变的时候，原来的代码就要很大的改动了。

想象一下，我们不解析外部文件，而是通过标准的 Elixir 代码来表示 HTML 会怎样？这样以来，运行 Elixir 代码就能产生一个完整的 HTML 字符串。我们来看看这样的 DSL 会长得啥样

```elixir
markup do
  div class: "row" do
    h1 do
      text title
    end
    article do
      p do: text "Welcome!"
    end
  end
  if logged_in? do
    a href: "edit.html" do
      text "Edit"
    end
  end
end

"<div class\"row\"><h1>Domain Specific Languages</h1><article><p>Welcome!</p>
</article><a href=\"edit.html\">Edit</a></div>"
```

由于宏是一阶特性，我们可以为每个 HTML tag 都用一个宏来表示。上面这个示例就是一个完整的 DSL。我们可以通过看代码很清楚的知道要生成什么样的 HTML，这样的模块就能让写 HTML 和 Elixir 代码同时进行(同样的上下文)，这样会又一些十分有趣的特性～
