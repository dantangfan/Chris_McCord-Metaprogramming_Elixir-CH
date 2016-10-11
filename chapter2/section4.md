TODO 在最初就应该解释编译时的执行顺序，比如为什么要用 import unquote(__MODULE__)
## 编译时处理

Elixir 允许我们使用一个特殊的模块变量 @before_compile ，这个变量可以用来告诉编译器，在编译结束前还需要执行什么操作。@before_compile 接收一个模块名作为参数，并且还必须定义一个 __before_compile__ 宏。这个宏就会在编译完成前(生成目标代码前)的最后一步被调用，看看代码比如我们继续修改前面的 assertion 代码。

```elixir
defmodule Assertion do
  defmacro __using__ do
    quote do
      import unquote(__MODULE__)

      Module.register_attribute __MODULE__, :tests, accumulate: true
      @becore_compile unquote(__MODULE__)

    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def run do
        IO.puts "Running tests (#{inspect @tests})"
      end
    end
  end

  defmacro test(description, do: test_block) do
    test_func = String.to_atom(description)
    quote do
      @tests {unquote(test_func), unquote(description)}
      def unquote(test_func)(), do: unquote(test_block)
    end
  end
end
```

简直完美，这样的效果就跟前面的是一样的。

**IO.puts "Running tests (#{inspect @tests})"** 这句之所以能将 @tests 执行成功，是因为他是定义在 run 内，在真正执行这行代码的时候，早就是运行时了，@tests 也已经被静态替换成了一堆数据了

那最后一步，就是完成我们的 Assertion.Test 模块了。其实这种代码拆分的技巧学着学着就知道该啥时候怎么拆分比较合理了。

```elixir
defmodule Assertion do
  defmacro __using__(_env) do
    quote do
      import unquote(__MODULE__)

      Module.register_attribute __MODULE__, :tests, accumulate: true
      @before_compile unquote(__MODULE__)

    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def run do
        Assertion.Test.run(@tests, __MODULE__)
      end
    end
  end

  defmacro test(description, do: test_block) do
    test_func = String.to_atom(description)
    quote do
      @tests {unquote(test_func), unquote(description)}
      def unquote(test_func)(), do: unquote(test_block)
    end
  end

  # {:==, [context: Elixir, import: Kernel], [5, 5]}
  defmacro assert({operator, _, [lhs, rhs]}) do
    quote bind_quoted: [operator: operator, lhs: lhs, rhs: rhs] do
      Assertion.Test.assert(operator, lhs, rhs)
    end
  end
end


defmodule Assertion.Test do
  def run(tests, module) do
    Enum.each tests, fn {test_func, description} ->
      case apply(module, test_func, []) do
        :ok -> IO.write "."
        {:fail, reason} -> IO.puts """
        ==================================
        Failure: #{description}
        ==================================
        #{reason}
        """
      end
    end
  end

  def assert(:==, lhs, rhs) when lhs == rhs do
    :ok
  end
  def assert(:==, lhs, rhs) do
    {:fail, """
    FAILURE:
    Expected:         #{lhs}
    to be equal to:   #{rhs}
    """}
  end

  def assert(:>, lhs, rhs) when lhs > rhs do
    :ok
  end
  def assert(:>, lhs, rhs) do
    {:fail, """
    FAILURE:
    Expected:         #{lhs}
    to be greater than:   #{rhs}
    """}
  end
end
```

然后我们在尝试我们的测试代码

```elixir
defmodule MathTest do
  use Assertion

  test "integers can be added and subtracted" do
    assert 2 + 3 == 5
    assert 5 - 5 == 10
  end

  test "integers can be multiplied and divided" do
    assert 5 * 5 == 25
    assert 10 / 2 == 5
  end
end
```

吓哭几次之后，终于跑起来了

```bash
iex(1)> c "assertion.exs"
[Assertion.Test, Assertion]
iex(2)> c "math_test.exs"
[MathTest]
iex(3)> MathTest.run
.==================================
Failure: integers can be added and subtracted
==================================
FAILURE:
Expected:         0
to be equal to:   10


:ok
```

我们最小的测试框架就这么完工了
