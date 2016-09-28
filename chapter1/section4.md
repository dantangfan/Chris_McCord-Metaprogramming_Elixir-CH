## 代码注入和执行上下文

宏以注入的方式为调用者生成代码，下面我们来看这是什么意思。

我们把宏生成代码的地方叫做上下文，上下文的含义自己google。它保证了代码的安全执行

TODO

### 代码注入

因为调用宏实际上就是注入代码，所以，这里包含了两个上下文：调用者的上下文和宏生成代码的上下文。我们需要理解这两个上下文，不然就有可能在错误的地方生成代码。下面我们用一个 definfo 宏来解释这个问题，definfo 宏的功能是打印出当前所在的上下文。我们建立一个 `callers_context.exs` 代码如下

```elixir
defmodule Mod do
  defmacro definfo do
    IO.puts "In macro's context (#{__MODULE__})."

    quote do
      IO.puts "In caller's context (#{__MODULE__})"

      def friendly_info do
        IO.puts """
        My name is #{__MODULE__}
        My functions are #{inspect __info__(:functions)}
        """
      end
    end
  end
end

defmodule MyModule do
  require Mod
  Mod.definfo
end
```

然后我们执行一下

```bash
iex(1)> c "callers_context.exs"
In macro's context (Elixir.Mod).
In caller's context (Elixir.MyModule)
[MyModule, Mod]
iex(2)> MyModule.friendly_info
My name is Elixir.MyModule
My functions are [friendly_info: 0]

:ok
```

从上面我们可以看出，在代码编译的时候，我们同时进入了宏的上下文和调用者的上下文。在宏展开前，我们进入了 definfo 宏的上下文(第三行)，者很容易理解，就好像这里是一个普通的函数调用，这个函数还是属于 Mod 模块的，调用之后，返回了一堆 AST 在 MyModule 中，于是在宏展开的时候进入了 MyModule 模块了(第六行)，然后在展开宏之后生成了一个函数，这个函数就自然是属于 MyModule 的了。

当你看不懂你的宏是的执行上下问的时候，多半就是你的代码写得太复杂了，所以，宏代码一定要短小精干，简明直观。


### Hygiene Protects the Caller’s Context

这个概念暂时不知道怎么解释，我们用例子说明，宏要怎样才能入侵调用者上下文的局部数据。这里我们依然使用 `eval_quoted`

```elixir
iex(3)> ast = quote do
...(3)>   if meaning_to_lift == 42 do
...(3)>     "it's life"
...(3)>   else
...(3)>     "it ramins to be seen"
...(3)>   end
...(3)> end
{:if, [context: Elixir, import: Kernel],
 [{:==, [context: Elixir, import: Kernel],
    [{:meaning_to_lift, [], Elixir}, 42]},
      [do: "it's life", else: "it ramins to be seen"]]}
iex(4)> Code.eval_quoted ast, meaning_to_life: 42
** (CompileError) nofile:1: undefined function meaning_to_lift/0
    (elixir) expanding macro: Kernel.if/2
                 nofile:1: (file)

iex(4)> ast = quote do
...(4)>   if var!(meaning_to_life) == 42 do
...(4)>     "it's life"
...(4)>   else
...(4)>     "it remains to be seen"
...(4)>   end
...(4)> end
{:if, [context: Elixir, import: Kernel],
 [{:==, [context: Elixir, import: Kernel],
    [{:var!, [context: Elixir, import: Kernel],
         [{:meaning_to_life, [], Elixir}]}, 42]},
           [do: "it's life", else: "it remains to be seen"]]}
           iex(5)> Code.eval_quoted ast, meaning_to_life: 42
           {"it's life", [meaning_to_life: 42]}
```

可以看到，默认情况下， quote 后的代码块是不认识自身没有定义过的变量的，但使用了 var! 操作之后，就获取了调用者定义的变量，就跟我们常见语言里的 global 变量类似。

那我们在用模块来试试，建立一个 setter1.exs，然后输入

```elixir
defmodule Setter do
  defmacro bind_name(string) do
    quote do
      name = unquote(string)
    end
  end
end
```

然后跑一遍代码

```elixir
iex(1)> c "setter1.exs"
[Setter]
iex(2)> re
receive/1      recompile/0    rem/2          require/2      reraise/2      
reraise/3      respawn/0      
iex(2)> require Setter 
Setter
iex(3)> name = "Chris"
"Chris"
iex(4)> Setter.bind_name("Max")
"Max"
iex(5)> name
"Chris"
iex(6)> 
```

我们发现调用者定义的 name 变量并没有被改变。然后我们使用 var! 再试试


```elixir
defmodule Setter do
  defmacro bind_name(string) do
    quote do
      var!(name) = unquote(string)
    end
  end
end
```

然后再跑一遍

```elixir
iex(1)> c "setter1.exs"
[Setter]
iex(2)> require Setter 
Setter
iex(3)> name = "Chris"
"Chris"
iex(4)> Set
Set       Setter    
iex(4)> Setter.bind_name("Max")
"Max"
iex(5)> name
"Max"
```

可以看到，现在宏成功的覆盖了调用者的变量。

var! 这个特性也是危险的，我们也应该十分谨慎的使用，一般不到万不得已都不会使用它。
