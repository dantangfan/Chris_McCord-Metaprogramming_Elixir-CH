## 集成测试

集成测试其实就是在代码的顶部进行功能测试，就拿我们前面实现的 translator 模块来说，我们只需要指定输入然后鉴别输出是否符合预期，就能判断代码是否正确。多数情况下，我们都会做集成测试，因为宏生成的代码确实是很难独立测试的。我们可以退而求其次，看他功能是否实现正确。

同样，我们先要决定我们需要测试什么

- Generate t/3 functions while recursively walking all translations

- Allow multiple locales to be registered

- Handle nested translations

- Handle translations at the root level of the tree

- Support binding interpolation

- Raise an error unless all bindings have been provided for interpolation

- Return {:error, :no_translation} when no translation exists for the given input

- Convert any interpolation binding to string for proper concatenation


### 嵌入模块让测试更简单

我们知道，要使用 translator 就必须要使用 use Translator 将代码注入到调用者里面，为了方便测试，我们直接在测试代码中嵌入一个模块，这个模块使用了 use Translator，下面是测试代码 translator_test.exs

```elixir
ExUnit.start
Code.require_file("translator.exs", __DIR__)

defmodule TranslatorTest do
  use ExUnit.Case

  defmodule I18n do
    use Translator

    locale "en", [
      foo: "bar",
      flash: [
        notice: [
          alert: "Alert!",
          hello: "hello %{first} %{last}"
        ]
      ],
      users: [
        title: "Users",
        profile: [
          title: "Profiles",
        ]
      ]
    ]

    locale "fr",
      flash: [
        notice: [
          hello: "salut %{first} %{last}"
        ]
      ]
  end

  test "it recursively walks translations tree" do
    assert I18n.t("en", "users.title") === "Users"
    assert I18n.t("en", "users.profile.title") === "Profiles"
  end

  test "it handles translations at root level" do
    assert I18n.t("en", "foo") === "bar"
  end

  test "it allows mutiple locales to be registered" do
    assert I18n.t("fr", "flash.notice.hello", first: "Jaclyn", last: "M") === "salut Jaclyn M"
  end

  test "it interpolates bindings" do
    assert I18n.t("en", "flash.notice.hello", first: "Jason", last: "S") === "hello Jason S"
  end

  test "t/3 raises KeyError when bindings not provided" do
    assert_raise KeyError, fn -> I18n.t("en", "flash.notice.hello") end
  end

  test "t/3 returns {:error, :no_translation} when translation is missing" do
    assert I18n.t("en", "flash.not_exists") === {:error, :no_translation}
  end

  test "converts interpolatation values to string" do
    assert I18n.t("fr", "flash.notice.hello", first: 123, last: 456) === "salut 123 456"
  end
end
```

当然，测试也是完美通过的。

测试其实也就说的差不多了，不过，真正复杂的宏代的测试还是要靠单元测试(Unit Test)
