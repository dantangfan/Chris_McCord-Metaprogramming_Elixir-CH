# 建立一个国际化模块

几乎所有直面用户的 APP 都需要一个国际化处理流程，这样可以在展示的时候自动的显示相应的语言，下面我们就来使用少量的代码来实现这个模块。

## 第一步：设计 API

实现 Translator 的第一步就是先要搞清楚我们的最终目标是什么，该如何使用这个库，通常，这些描述都会写在 README 文件中。比如，我们的最终目标是实现下面这样的 API，放在 i18n.exs

```elixir
defmodule I18n do
  use Translator

  locale "en",
    flash: [
      hello: "Hello %{first} %{last}!",
      bye: "Bye, %{name}"
    ],
    users: [
      title: "Users",
    ]

  locale "fr",
    flash: [
      hello: "Salut %{first} %{last}",
      title: "Utilisateurs"
    ]
end
```

最终，我们希望这样调用我们的模块

```bash
iex> I18n.t("en", "flash.hello", first: "Chris", last: "McCord")
"Hello Chris Mccord!"

iex> I18n.t("fr", "flash.hello", first: "Chris", last: "McCord")
"Salut Chris McCord!"

iex> I18n.t("en", "users.title")
"Users"
```

我们将可以使用 `use Translator` 来让任何库都包含翻译功能，并注入 t/3 函数实现翻译。一起动手吧

### 第二步：构建代码基本框架

首先，我们肯定需要 __using__ 和 __before_compile__ 和 local 宏，这个从上面的 API 就可以看出。所以我们先弄个简单框架出来，新建 translator.exs 文件

```elixir
defmodule Translator do
  
  defmacro __using__(_options) do
    quote do
      Module.register_attribute __MODULE__, :locales, accumulate: true, persist: false

      import unquote(__MODULE__), only: [locale: 2]
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    compile(Module.get_attribute(env.module, :locales))
  end

  defmacro locale(name, mappings) do
    quote bind_quoted: [name: name, mappings: mappings] do
      @locales {name, mappings}
    end
  end

  def compile(translations) do
    # TBD: Return AST for all translation function definitions
  end
end
```

### 第三步：用模块属性生成代码

我们的目标是将第二步手机到的 translations 生成用 t/3 函数表示的代码，当然，我们依然需要一个全局 t/3 代码来捕获所有未被定义的 translations，下面修改 compile 函数

```elixir
  def compile(translations) do
    translations_ast = for {locale, mappings} <- translations do
      deftranslations(locale, "", mappings)
    end

    quote do
      def t(locale, path, bindings \\ [])
      unquote(translations_ast)
      def t(_locale, _path, _bindings), do: {:error, :no_translation}
    end
  end

  defp deftranslations(locales, current_path, mappings) do
    #TBD: Return an AST of the t/3 function defs for the given locale
  end
```

这里，我们又用了另一个函数 deftranslations 来根据 locales 生成 t/3，在实现这个函数之前我们先来检查一下我们目前的代码是否正确

```bash
iex> c "translator.exs"
[Translator]
iex> c "i18n.exs"
[I18n]
iex> I18n.t("en", "flash.hello", first: "Chris", last: "McCord")
{:error, :no_translation}
iex> I18n.t("en", "flash.hello")
{:error, :no_translation}
```

看起来没什么问题，那么我们就可以继续来实现我们的 deftranslations 函数了。

```elixir
  defp deftranslations(locale, current_path, mappings) do
    for {key, val} <- mappings do
      path = append_path(current_path, key)
      if Keyword.keyword?(val) do
        deftranslations(locale, path, val)
      else
        quote do
          def t(unquote(locale), unquote(path), bindings) do
            unquote(interpolate(val))
          end
        end
      end
    end
  end

  defp interpolate(string) do
    string # TBD interpolate bindings within string
  end

  defp append_path("", next), do: to_string(next)
  defp append_path(current, next), do: "#{current}.#{next}"
```

接下来我们才正式开始了 key-world 的映射工作，首先第4行我们判断 val 是否是一个 Keyword，如果是的话，我们会继续递归的取出每个 key 来 append 到 current_path 上，比如这个 `flash: [hello: "Hello %{first} %{last}", bye: "Bye, %{name}"]` ，后面，我们就生成了梦寐以求的 t/3 函数，t/3 函数里，我们调用了一个新的函数来将 bindings 映射到指定字符串中。不过，我们还是先来验证一下我们当前代码是否正确

```bash
iex> c "translator.exs"
[Translator]
iex> c "i18n.exs"
[I18n]
iex> I18n.t("en", "flash.hello", first: "Chris", last: "McCord")
"Hello %{first} %{last}!"
```

很好，跟预想的一样，除了 mapping 之外，都正常了。于是下面我们就要来实现 interpolate 函数了。不过在这之前，为了保证我们生成的代码都是正确的，我们应该来看看我们到底生成了什么代码！

### 使用 Macro.to_string 来查看生成的代码

Macro.to_string 可以把 AST 用我们能看懂的代码表示出来，当然，是字符串形式的。这对我们编写和调试宏代码真是大大滴有利，比如我们稍微改一点 translator.exs 代码，来看看我们到底生成了生么代码

```elixir
  def compile(translations) do
    translations_ast = for {locale, mappings} <- translations do
      deftranslations(locale, "", mappings)
    end

    final_ast = quote do
      def t(locale, path, bindings \\ [])
      unquote(translations_ast)
      def t(_locale, _path, _bindings), do: {:error, :no_translation}
    end

    IO.puts Macro.to_string(final_ast)
    final_ast
  end
```

下面再编译一次就能看到代码了

```bash
iex> c "translator.exs"
[Translator]
iex> c "i18n.exs"
(
    def(t(locale, path, bindings \\ []))
    [[[def(t("fr", "flash.hello", bindings)) do
      "Salut %{first} %{last}!"
    end, def(t("fr", "flash.bye", bindings)) do
      "Au revoir, %{name}!"
    end], [def(t("fr", "users.title", bindings)) do
      "Utilisateurs"
    end]], [[def(t("en", "flash.hello", bindings)) do
      "Hello %{first} %{last}!"
    end, def(t("en", "flash.bye", bindings)) do
      "Bye, %{name}!"
    end], [def(t("en", "users.title", bindings)) do
      "Users"
    end]]]
    def(t(_locale, _path, _bindings)) do
      {:error, :no_translation}
    end
)
[I18n]
iex>
```

### 最后一步：实现值的插入

前面我们可以看到，我们只差一步就可以实现 translator 了，那就是用值去替换占位符，比如 "Bye, %{name}"，最简单的办法自然是直接在运行时使用正则表达式去匹配，不过这里，我们决定使用更优化的方法来解决这个问题。我们会实现一个函数，在编译时决定匹配条件，运行时是字符串连接，继续修改代码

```elixir
  defp interpolate(string) do
    ~r/(?<head>)%{[^}]+}(?<tail>)/
    |> Regex.split(string, on: [:head, :tail])
    |> Enum.reduce("", fn
      <<"%{" <> rest>>, acc ->
        key = String.to_atom(String.rstrip(rest, ?}))
        quote do
          unquote(acc) <> to_string(Dict.fetch!(bindings, unquote(key)))
        end
      segment, acc -> quote do: (unquote(acc) <> unquote(segment))
    end)
  end
```

最后我们再测试一遍

```bash
iex> c "i18n.exs"
(
    def(t(locale, path, binding \\ []))
    [[[def(t("fr", "flash.hello", bindings)) do
        (((("" <> "Salut ") <> to_string(Dict.fetch!(bindings, :first))) <> " ") <>
            to_string(Dict.fetch!(bindings, :last))) <> "!"
    end, def(t("fr", "flash.bye", bindings)) do
        (("" <> "Au revoir, ") <> to_string(Dict.fetch!(bindings, :name))) <> "!"
    end], [def(t("fr", "users.title", bindings)) do
        "" <> "Utilisateurs"
    end]], [[def(t("en", "flash.hello", bindings)) do
        (((("" <> "Hello ") <> to_string(Dict.fetch!(bindings, :first))) <> " ") <>
        to_string(Dict.fetch!(bindings, :last))) <> "!"
    end, def(t("en", "flash.bye", bindings)) do
        (("" <> "Bye, ") <> to_string(Dict.fetch!(bindings, :name))) <> "!"
    end], [def(t("en", "users.title", bindings)) do
        "" <> "Users"
    end]]]
    def(t(_locale, _path, _bindings)) do
        {:error, :no_translation}
    end
)
[I18n]
iex> I18n.t("en", "flash.hello", first: "Chris", last: "McCord")
"Hello Chris Mccord!"
iex> I18n.t("fr", "flash.hello", first: "Chris", last: "McCord")
"Salut Chris McCord!"
iex> I18n.t("en", "users.title")
"Users"
```

看起来大功告成。

### 成品代码

简单一看，我们的 translator.exs 模块一共就只有几十行代码


```elixir
defmodule Translator do
  
  defmacro __using__(_options) do
    quote do
      Module.register_attribute __MODULE__, :locales, accumulate: true, persist: false

      import unquote(__MODULE__), only: [locale: 2]
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    compile(Module.get_attribute(env.module, :locales))
  end

  defmacro locale(name, mappings) do
    quote bind_quoted: [name: name, mappings: mappings] do
      @locales {name, mappings}
    end
  end

  def compile(translations) do
    translations_ast = for {locale, mappings} <- translations do
      deftranslations(locale, "", mappings)
    end

    final_ast = quote do
      def t(locale, path, bindings \\ [])
      unquote(translations_ast)
      def t(_locale, _path, _bindings), do: {:error, :no_translation}
    end

    IO.puts Macro.to_string(final_ast)
    final_ast
  end

  defp deftranslations(locale, current_path, mappings) do
    for {key, val} <- mappings do
      path = append_path(current_path, key)
      if Keyword.keyword?(val) do
        deftranslations(locale, path, val)
      else
        quote do
          def t(unquote(locale), unquote(path), bindings) do
            unquote(interpolate(val))
          end
        end
      end
    end
  end

  defp interpolate(string) do
    ~r/(?<head>)%{[^}]+}(?<tail>)/
    |> Regex.split(string, on: [:head, :tail])
    |> Enum.reduce("", fn
      <<"%{" <> rest>>, acc ->
        key = String.to_atom(String.rstrip(rest, ?}))
        quote do
          unquote(acc) <> to_string(Dict.fetch!(bindings, unquote(key)))
        end
      segment, acc -> quote do: (unquote(acc) <> unquote(segment))
    end)
  end

  defp append_path("", next), do: to_string(next)
  defp append_path(current, next), do: "#{current}.#{next}"
end
```

