## 模块扩展

宏的一个核心目标就是注入到其他模块中，实现模块扩展。至于我们的 Assertion 框架的目标，就是让其他的模块拥有 test 这个宏，这个宏接收一个描述性的字符串，后面紧接包含 assertion 的代码块，测试失败的信息前缀就是我们传入给 test 宏的字符串。同事，我们还要定义一个 run/0 函数来自动启动所有的测试。

我们的目标就是能像下面这样写测试代码

```elixir
defmodule MathTest do
  use Assertion

  test "integers can be added and subtracted" do
    assert 1 + 1 == 2
    assert 2 + 3 == 5
    assert 6 - 5 == 10
  end

  test "integers can be multiplied and divided" do
    assert 5 * 5 == 25
    assert 10 / 2 == 5
  end
end
```

执行之后，可以达到这样的输出效果

```bash
iex> MathTest.run
..
===============================================
FAILURE: integers can be added and subtracted
===============================================
Expected:
0
to be equal to: 10
..:ok
```

事不宜迟，我们下面就动起手来吧

### 模块扩展就是简单的代码注入

下面我们就来看看代码到底是怎么注入的。我们写一个 extend 宏，它可以将定义的 run 函数注入到另一个模块中，在 module_extention.exs 中键入。

```elixir
defmodule Assertion do
  defmacro extend(options \\ []) do
    quote do
      import unquote(__MODULE__)

      def run do
        IO.puts "Running the tests"
      end
    end
  end
end

defmodule MathTest do
  require Assertion
  Assertion.extend
end
```

之后，我们可以直接执行 `MathTest.run` 这个函数会打印出 `Running the tests`


我们在模块中直接调用了 Assertion.extend ，他在编译的时候就会被展开，返回一个包含了 run/0 的宏，这样，我们就仅仅使用了 quote 和 unqoute 就将 run/0 函数注入到了其他模块。

### use：模块扩展的通用 API

你可能已经注意到了，标注库的很多地方都使用了 use，我们在写代码的时候也经常使用 use。`use module` 会自动的调用 `module.__using__` 宏。有了 use 宏，就不用我们自己一个个的到其他模块中写类似 `Assertion.extend` 的直接调用了。把刚刚的代码改一改，下面的代码和上面的代码也是等价的


```elixir
defmodule Assertion do
  defmacro __using__(_options) do
    quote do
      import unquote(__MODULE__)

      def run do
        IO.puts "Running the tests"
      end
    end
  end
end
defmodule MathTest do
  use Assertion
end
```

