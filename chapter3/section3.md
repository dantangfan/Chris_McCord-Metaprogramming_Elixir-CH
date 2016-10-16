## 从远程 API 生成代码

前面的代码让我们精力高度集中，下面我们来点好玩儿的来放松一下我们的心情。前面我们知道，我们可以根据外部文件 txt 等来生成代码，实际上不仅如此，Elixir 还允许我们根据其他方式来生成代码，不如说 Github 的 public API 。

下面，我们会根据 GitHub API 来建立一个 Hub 模块，这个模块嵌入了我们的 public repositories 并且可以通过函数调用来启动浏览器访问指定模块！

### 建立 mix 项目

首先我们来建立一个 mix 项目

```bash
mix new hub
cd hub
```

然后定制我们的 mix.exs，这里我们需要 Poison 和 HTTPotion 来解析 JSON 文件和发送 HTTP 请求

```elixir
defmodule Hub.Mixfile do
  use Mix.Project

  def project do
    [app: :hub,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      {:ibrowse, github: "cmullaparthi/ibrowse", tag: "v4.1.0"},
      {:posion, "~> 1.3.0"},
      {:httpotion, "~> 1.0.0"}
    ]
  end
end
```

然后我们下载依赖文件

```bash
mix deps.get
```

### 远程代码生成

下面，就让我们在 hub.ex 文件里通过远程 API 来生成代码吧。

我们将会获取所有 username 下面的公开项目，把这个 JSON 文件解码成一个 Elixir map。然后，我们为每个键值对生成一个函数，函数名就是项目名，函数体就是 JSON 文件中返回的项目描述。最后，我们定义一个 go 函数，它接收一个项目名作为参数，然后通过浏览器打开这个项目。代码如下

```elixir
defmodule Hub do
  HTTPotion.start
  @username dantangfan

  "https://api.github.com/users/#{@username}/repos"
  |> HTTPotion.get(["User-Agent": "Elixir"])
  |> Posion.decode!
  |> Enum.each(fn repo ->
    def unquote(String.to_atom(repo["name"]))() do
      unquote(Macro.escape(repo))
    end
  end)

  def go(repo) do
    url = apply(__MODULE__, repo, [])["html_url"]
    IO.puts "Launching browser to #{url}"
    System.cmd("open", [url])
  end
end
```

我们的代码会在编译时去获取所需的 JSON 文件，并根据键值对编译出来一组函数，最后的 go 函数就直接启动了一个浏览器。

值得一提的是，我们这里第一次使用了 Macro.escape

### Macro.escape

Macro.escape 被用来把 Elixir 的表达式地柜的解析并，解析之后的结果可以用来注入到 AST 树中。最常用的地方是：当我们需要把一个 Elixir 的值插入到一个已经被 quote 的表达式中，并且这个值不是一个 AST 样式的合法值。对于 Hub 模块来说，我们需要把 JSON Map 注入到函数体中，但是 def 宏早就将接收到的代码块(包括函数名和后面的 do) quote 了，所以我们使用了 escape 来将 map 转换成 AST 形式来包含在被 quote 的代码中。

比如我们试试下面例子

```bash
iex(1)> Macro.escape(123)
123
iex(2)> Macro.escape([1,2,3])
[1, 2, 3]
iex(3)> Macro.escape(%{watchers: 33, name: "linguist"})
{:%{}, [], [name: "linguist", watchers: 33]}
iex(4)> defmodule MyModule do
...(4)>   map = %{name: "Elixir"}
...(4)>   def value do
...(4)>     unquote(map)
...(4)>   end
...(4)> end
** (CompileError) iex: invalid quoted expression: %{name: "Elixir"}

iex(4)> defmodule MyModule do
...(4)>   map = Macro.escape %{name: "Elixir"}
...(4)>   def value do
...(4)>     unquote(map)
...(4)>   end
...(4)> end
{:module, MyModule,
 <<70, 79, 82, 49, 0, 0, 4, 248, 66, 69, 65, 77, 69, 120, 68, 99, 0, 0, 0, 128,
    131, 104, 2, 100, 0, 14, 101, 108, 105, 120, 105, 114, 95, 100, 111, 99, 115,
    95, 118, 49, 108, 0, 0, 0, 4, 104, 2, ...>>, {:value, 0}}
iex(5)> MyModule.value
%{name: "Elixir"}
```

在我们第一个 MyModule 的定义中，我们发生了 CompileError，因为 Map 不是一个合法的 quote 表达式，当我们使用 Macro.excape 之后，就可以将其转换成一个可以注入的 AST 了。因此，每当你遇到了这种 `invalid quoted expression error` 的报错的二十号，就该去检查一下是不是有地方注入错了，这是一个十分常见的错误。
