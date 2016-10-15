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
    compile(Module.get_attrubute(env.module, :locales))
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
