## 10行代码实现 MIME-type 转换

如果你写过 web server，那么你应该知道，我们有时候需要根据 MIME 类型处理文件拓展名，比如说服务器收到一个 application/javascript 的 header，我们必须知道如何处理这个 MIME 类型并返回一个 js 文件。在大多数语言里，我们都是直接将 MIME 和文件后缀名对应起来直接放在一个 map 里面，手动处理大量这种类型的数据是很繁琐的，但 Elixir 的宏为我们提供了便利。

### 合理利用现有数据

首先，我们需要找到一个 MIME-type 数据集来作为我们生成代码的基础，比如这 [mime.txt](http://www.iana.org/assignments/media-types/media-types.xhtml)，我们看他的结构长这样

```bash
application/javascript .js
application/json .json
image/jpeg .jpeg, .jpg
video/jpeg .jpgv
```

我们把整个文件下载下来保存为 mimes.txt，然后就可以开始干活了。新建一个 mime.exs 然后写代码。

```elixir
defmodule Mime do
  for line <- File.stream!(Path.join([__DIR__, "mimes.txt"]), [], :line) do
    [type, rest] = line |> String.split("\t") |> Enum.map(&String.strip(&1))
    extensions = String.split(rest, ~r/,\s?/)

    def exts_from_type(unquote(type)), do: unquote(extensions)
    def type_from_ext(ext) when ext in unquote(extensions), do: unquote(type)
  end

  def exts_from_type(_type), do: []
  def type_from_ext(_ext), do: nil
  def valid_type?(type), do: exts_from_type(type) |> Enum.any?
end
```

你没有看错，我们用10行代码就是先了 MIME 文件的判断和转换

在 for 循环中，我们逐行读取 mimes.txt 文件，并为每行都生成了两个模式匹配的函数，然后在循环外面添加模式匹配失败的函数，这样，就完成了一个模块。

这里需要注意的是，我们在没有 quote 的情况下使用了 unquote，这也是 Elixir 的一种写法。

### 监听外部文件并重编译

万一外部文件有变化我们怎么知道呢？所以，Elixir 提供了 @external_resource 模块属性来监听外部文件的功能，每当被监听的文件发生变化，模块就会重新编译

@external_resource 是一个可以自动的模块属性，可以接受任意多个外部文件。

```elixir
defmodule Mime do
  @external_resource mimes_path=Path.join([__DIR__, "mimes.txt"])

  for line <- File.stream!(mimes_path, [], :line) do
      ...
  end
  ...
end
```


