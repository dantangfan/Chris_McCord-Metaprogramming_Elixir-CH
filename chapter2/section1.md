## 灵活地测试宏

写过测试代码的同学都知道，写测试的时候我们需要学习不同的测试框架，和不同的 asser 语法，下面我们就看看常见的语言的基本测试代码跟 Elixir 的有什么区别。

JavaScript

```javascript
expect(value).toBe(true);
expect(value).toEqual(12);
expect(value).toBeGreaterThan(100);
```

Ruby

```ruby
assert value
assert_equal value, 12
assert_operator value, :<=, 100
```

Elixir

```elixir
assert value
assert value == 12
assert value <= 100
```

常见语言有这么的 assert 声明形式，是为了让每种测试不通过的时候都会有自己直观的错误提示。那么，下面我们就一起来看看 Elixir 是如何用宏构造一个简单的关键词来实现这种功能。

### assert 增强

我们的 assert 宏的目标是接收一个 left-hand 表达式和一个 right-hand 表达式，中间用 Elixir 的操作符隔开，比如 `assert 1 > 0`，一旦测试失败，将会根据所测试的语句提供相应的出错信息。下面是一个简单的例子

```elixir
defmodule Test do
  import Assertion
  def run do
    assert 5 == 5
    assert 2 > 0
    assret 10 < 1
  end
end
```

```bash
iex> Test.run
..
FAILURE:
  Expected: 10
  to be less than: 1
```

下面，我们依然像前面一样，现在 iex 中做实验，一步一步来

```bash
iex(1)> quote do: 5 == 5
{:==, [context: Elixir, import: Kernel], [5, 5]}
iex(2)> quote do: 2 < 10
{:<, [context: Elixir, import: Kernel], [2, 10]}
}
```

简单的数字比较会生成一个直观的 AST ，有了这个 AST 表达式，我们就能做些有趣的事情了。建立一个 assertion.exs 文件 然后键入

```elixir
defmodule Assertion do

  # {:==, [context: Elixir, import: Kernel], [5, 5]}
  defmacro assert({operator, _, [lhs, rhs]}) do
    quote bind_quoted: [operator: operator, lhs: lhs, rhs: rhs] do
      Assertion.Test.assert(operator, lhs, rhs)
    end
  end
end
```

在继续撸之前，先介绍一下 bind_quoted

### bind_quoted

bind_quoted 确保了 quote 外部的变量在 quote 内部引用时只会被 unquote 一次，用代码来解释，比如说下面两组代码是等价的。

```elixir
quote bind_quoted: [operator: operator, lhs: lhs, rhs: rhs] do
  Assertion.Test.assert(operator, lhs, rhs)
end

quote do
  Assertion.Test.assert(unquote(operator), unquote(lhs), unquote(rhs))
end
```

这里还没有看到 bind_quoted 的具体作用，下面这个例子我们就可以看出 bind_quoted 的好处：比如说，我们要实现一个 Debugger.log ，它只在 debug 模式下会调用 IO.inspect 打印出结果。

建立一个 debugger.exs ，然后键入

```elixir
defmodule Debugger do
  defmacro log(expression) do
    if Application.get_env(:debugger, :log_level) == :debug do
      quote do
        IO.puts "======================"
        IO.inspect unquote(expression)
        IO.puts "======================"
        unquote(expression)
      end
    else
      expression
    end
  end
```

然后执行一下

```bash
iex> c "debugger.exs"
[Debugger]
iex> require Debugger
nil
iex> Application.put_env(:debugger, :log_level, :debug)
:ok
iex> remote_api_call = fn -> IO.puts("calling remote API...") end
#Function<20.90072148/0 in :erl_eval.expr/5>
iex> Debugger.log(remote_api_call.())
=================
calling remote API...
:ok
=================
calling remote API...
:ok
```

我们发现 remote_api_call 被执行了两次，然后我们用 bind_quoted 再来一次

```
defmodule Debugger do
  defmacro log(expression) do
    if Application.get_env(:debugger, :log_level) == :debug do
      quote bind_quoted: [expression: expression] do
        IO.puts "======================"
        IO.inspect expression
        IO.puts "======================"
        expression
      end
    else
      expression
    end
  end
end
```

再来执行一次

```bash
iex> c "debugger_fixed.exs"
[Debugger]
iex> Debugger.log(remote_api_call.())
calling remote API...
=================
:ok
=================
:ok
iex>
```

这次就只被执行了一次，而且是在 bind_quoted 那里就被执行了！

需要注意的是，在 bind_quoted 中，unquote 是被警用了的，如果要开启，需要加入参数 unquote: true

所以想清楚我们是否需要 bind_quoted

下面，我们继续前面的assert

### 充分利用模式匹配写代码

下面我们就来实现 Assertion.Test ,这才是真正执行我们测试代码的地方，看我来利用模式匹配让代码更简单，修改 assertion.exs

```elixir
defmodule Assertion do

  # {:==, [context: Elixir, import: Kernel], [5, 5]}
  defmacro assert({operator, _, [lhs, rhs]}) do
    quote bind_quoted: [operator: operator, lhs: lhs, rhs: rhs] do
      Assertion.Test.assert(operator, lhs, rhs)
    end
  end
end


defmodule Assertion.Test do
  def assert(:==, lhs, rhs) when lhs == rhs do
    IO.write "."
  end
  def assert(:==, lhs, rhs) do
    IO.puts """
    FAILURE:
    Expected:         #{lhs}
    to be equal to:   #{rhs}
    """
  end

  def assert(:>, lhs, rhs) when lhs > rhs do
    IO.write "."
  end
  def assert(:>, lhs, rhs) do
    IO.puts """
    FAILURE:
    Expected:         #{lhs}
    to be greater than:   #{rhs}
    """
  end
end
```

我们把 Assertion.Test 独立成一个模块，避免了调用者对 asser 的混淆，也避免了import 引入过多的无用函数，Assertion.Test.assert 的模式匹配就搞定一切

执行一下

```bash
iex> c "assertion.exs"
[Assertion.Test, Assertion]
iex> import Assertion
nil
iex> assert 1 > 2
FAILURE:
Expected:
1
to be greater than: 2
:ok
iex> assert 5 == 5
.:ok
report erratum • discussExtending Modules
• 33
iex> assert 10 * 10 == 100
.:ok
```

很好，就是我们想要的

但是，跟有个不好的地方就是，在写完测试之后，需要调用者自己写 run 启动函数，二不能一次自动执行所有test。接下来我们就来提供这样的功能。
