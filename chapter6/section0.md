## 什么时候需要使用宏

这个没办法细说，最好的做法是可以不使用宏的时候尽量不使用。但有些情况，使用宏是必须的，比如实现一个控制流操作如 if 这样的关键字，就需要使用宏。因为它以代码块作为参数，如果不使用宏，参数将在函数调用传参的时候就被执行。

## 几个需要避免的问题

1. 能使用 import 的时候就不要使用 use，也就是能使用函数调用的时候就不要使用函数注入

2. 避免注入大量代码，因为大量的代码注入会导致 debug 非常困难，有时候一不小心就破坏了调用者上下文

## Kernel.SpecialForms: 了解你的运行环境和限制

Elixir 也有不可覆盖的区域(函数，关键字，变量等)。

Kernel.SpecialForms 模块定义了一系列不能被用户重写的结构，它们是构成 Elixir 语言的基石。同时，这个模块还包含了一些预定义的变量，这些变量记录了代码编译时的环境，比如 `__ENV__` `__MODULE__` `__DIR__` 等等。下面是那些被 SepcialForms 预定义并且不能被用户重定义和覆盖的变量

- `__EVN__`: 返回一个 Macro.ENV 结构体，包含了当前运行环境信息

- `__MODULE__`: 返回当前模块名字，同 `__EVN__.module`

- `__DIR__`: 返回当前运行的文件目录

- `__CALLER__`: 返回一个 Macro.EVN ，包含调用者的运行环境

`__ENV__` 随时都可以访问，但是 `__CALLER__` 只有在宏里面可以访问。我们前面说的的 `__before_compile__` 宏就是以 `__EVN__` 作为唯一参数的。

`__EVN__` 还有一些有趣的属性，我们打开 iex 来看看


```bash
iex(1)> __ENV__.file
"iex"
iex(2)> __ENV__.line
2
iex(3)> __ENV__.vars
[]
iex(4)> name = "Elixir"
"Elixir"
iex(5)> version = "~> 1.0"
"~> 1.0"
iex(6)> __ENV__.vars
[name: nil, version: nil]
iex(7)> binding
[name: "Elixir", version: "~> 1.0"]
iex(8)>
```

上面我们看到， Elixir 可以追踪到文件和行号。还可以看到，Elixir 还追踪了变量绑定。跟 binding 宏略有不同的是，binding 宏返回了所有绑定的变量和他们的值，vars 只返回了变量名字。这是因为 Elixir 中的变量在运行时是动态变化的，环境变量就只能知道变量在哪里被绑定了，和哪些变量被绑定了，但他们的值是什么，就不一定了。

## 打破成规

遵守规则总是好的，但是有时候，打破规则，会让我们发现新世界。

### 滥用合法的 Elixir 表达式

Elixir 有个出名的库 Ecto，他是用来操作数据库的。我们来看看他的一个合法的表达式

```elixir
query = from user in User,
      where: user.age > 21 and usre.enrolled == true,
      select: user
```

Ecto 会把上面这句话翻译成 SQL 语句。可以看出，它使用了 > in == 等 Elixir 本身包含的合法表达式，这是一种十分巧妙的用法。我们可以用宏来将常规的 Elixir 表达式转换成 SQL 表达式。然我们看看前面那个表达式 quote 之后是怎样的，或许，你已经联想到了我们前面使用过的 Macro.postwalk 了

```bash
iex(8)> quote do
...(8)>   from user in User,
...(8)>     where: user.age > 21 and user.enrolled == true,
...(8)>   select: user
...(8)> end
{:from, [],
 [{:in, [context: Elixir, import: Kernel],
    [{:user, [], Elixir}, {:__aliases__, [alias: false], [:User]}]},
   [where: {:and, [context: Elixir, import: Kernel],
     [{:>, [context: Elixir, import: Kernel],
       [{{:., [], [{:user, [], Elixir}, :age]}, [], []}, 21]},
      {:==, [context: Elixir, import: Kernel],
       [{{:., [], [{:user, [], Elixir}, :enrolled]}, [], []}, true]}]},
    select: {:user, [], Elixir}]]}
```


### 性能优化

另外一个可以适度打破宏编程规则的就是性能优化。有时候，我们需要注入大量的代码来提升性能，比如前面我们实现的 Translator 和 Unicode 模块。Translator 模块在编译时就决定了字符串的插入规则，就不需要运行时再来判断了。当然，无法避免的是，这增加了代码的复杂度。

### 边干边学

学到这里，不知道你有没有被 Elixir 强大的扩展功能折服。比如，有没有想过用它来实现一门可以用自然语言写代码的语言？就像这样

```elixir
the answer should be between 3 and 5
the list should contain 10
the user name should resemble "Max"
```

然后 quote 之后，看看能翻译成啥样

```bash
iex(9)> quote do
...(9)>   the answer should be between 3 and 5
...(9)>   the list shoule contain 10
...(9)>   the user name should resumble "Max"
...(9)> end |> Macro.to_string |> IO.puts
(
  the(answer(should(be(between(3 and 5)))))
  the(list(shoule(contain(10))))
  the(user(name(should(resumble("Max")))))
)
:ok
```

单词都成了普通函数，如果能够解释这些词语以及词组，是不是就可以让机器完全理解自然语言呢？当然，这任重而道远，需要聪明的你来完成了

