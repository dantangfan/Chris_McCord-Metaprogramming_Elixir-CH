## 使用模块属性来注入代码

到现在，我们依然不能实现我们的 Assertion 模块，因为调用者会写多个 test 测试代码，我们没办法在 run/0 函数中一个个的把这个测试函数都包括进来，因为我们不知道这个测试的名字叫啥。Elixir 提供了自己的解决办法，那就是使用模块属性。

模块属性允许在编译时将数据存储到模块中，下面我们就来看看如何使用。

再次修改我们的 assertion.exs

```elixir
defmodule Assertion do
  defmacro __using__ do
    quote do
      import unquote(__MODULE__)

      Module.register_attribute __MODULE__, :tests, accumulate: true

      def run do
        IO.puts "Running tests (#{inspect @tests})"
      end
    end
  end

  defmacro test(description, do: test_block) do
    test_func = String.to_atom(description)
    quote do
      @test {unquote(test_func), unquote(description)}
      def unquote(test_func)(), do: unquote(test_block)
    end
  end
end
```

这里我们使用了 **Module.register_attribute __MODULE__, :tests, accumulate: true** ，他的作用是在 __MODULE__ 上产生一个 :tests 属性，accumulate: true 确保这是一个可以扩展的list， 当后面使用 **@tests {}** 的时候，会不断的向 tests 属性里面 append 数据。这里只是生成了一个属性和一堆的 test_func ，那到底我们该怎么样把这些函数放到 run/0 里面去自动启动测试函数呢？这就要归功于我们的编译时处理了。
