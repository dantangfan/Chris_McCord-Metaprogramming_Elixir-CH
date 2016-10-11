## Custom Language Constructs

### 重写 if 宏

前面，我们已经实现了 if 宏，下面，我们再来将 Elixir 里面的 if 宏完整的实现一遍，这样我们对宏变成就有了更直观的了解。

建立一个 if_recreated.exs，然后键入

```elixir
defmodule ControlFlow do
  defmacro my_if(expr, do: if_block) do
    if(expr, do: if_block, else: nil)
  end
  defmacro my_if(expr, do: if_block, else: else_block) do
    quote do
      case unquote(expr) do
        result when result in [false, nil] -> unquote(else_block)
        _ -> unquote(if_block)
      end
    end
  end
end
```

然后运行一遍

```bash
iex(1)> c "if_recreated.exs"
[ControlFlow]
iex(2)> require ControlFlow 
ControlFlow
iex(3)> ControlFlow.my_if 1 == 1 do
...(3)>   "correct"
...(3)> else
...(3)>   "incorrect"
...(3)> end
"correct"
iex(4)> 
```

几行代码，我们又实现了 Elixir 中的 if..else 语法。下面可以做点更有趣的事情了，我们来用 Elixir 中已经存在的宏来实现一个全新的关键字 loop。

### 实现loop关键字

你可能也发现了，Elixir 是没有 while 循环语法的，虽然没有，但是我们可以自己实现一个啊，因为我觉得有时候 while 循环还是很有必要的，比如下面这种情况

```elixir
while Process.alive?(pid) do
  send pid, {self, :ping}
  receive do
    {^pid, :pong} -> IO.puts "Got pong"
  after 2000 -> break
  end
end
```

当我们要实现一个这样的宏的时候，第一步是决定使用哪些内置元素来实现我们的高阶目标。这里，我们的需求是实现一个无限循环，那么我们在没有 while 的时候，应该怎么处理一个无限循环呢？这里，我们可以作弊：我们可以使用生成一个无限长的 stream 给 for 循环。

下面我们就一步一步的实现这个 while 无限循环

建立一个 while_step1.exs 文件，然后输入

```elixir
defmodule Loop do
  defmacro while(expression, do: block) do
    quote do
      for _ <- Stream.cycle([:ok]) do
        if unquote(expression) do
          unquote(block)
        else
          # break out of loop
        end
      end
    end
  end
end
```

然后执行一下

```bash
iex(1)> c "while.exs"
[Loop]
iex(2)> import Loop
Loop
iex(3)> while true do
...(3)>  IO.puts "looping"
...(3)> end
looping
looping
looping
...
```

可以看到，我们成功的无限循环下来了，但是这里没有办法停下来，因为内置 for 并没有能让循环中断的语句(break语句)，但是，我们可以利用一个 try/catch 来让抛出一个异常来中断循环，于是我们的代码又成了这个样子

```elixir
defmodule Loop do
  defmacro while(expression, do: block) do
    quote do
      try do
        for _ <- Stream.cycle([:ok]) do
          if unquote(expression) do
            unquote(block)
          else
            throw :break
          end
        end
      catch
        :break -> :ok
      end
    end
  end
end
```

然后我们再来跑一遍

```bash
iex(1)> c "while.exs"
[Loop]
iex(2)> import Loop
Loop
iex(3)> run_loop = fn ->
...(3)>   pid = spawn(fn -> :timer.sleep(4000) end)
...(3)>   while Process.alive?(pid) do
...(3)>     IO.puts "#{inspect :erlang.time} Staying' alive"
...(3)>     :timer.sleep 1000
...(3)>   end
...(3)> end
#Function<20.52032458/0 in :erl_eval.expr/5>
iex(4)> run_loop.()
{23, 25, 40} Staying' alive
{23, 25, 41} Staying' alive
{23, 25, 42} Staying' alive
{23, 25, 43} Staying' alive
:ok
```

看起来效果不错，然后，我们再把 break 隔离出来，这样我们就可以在任何地方来中断循环了，最终我们的代码是这样的

```elixir
defmodule Loop do
  defmacro while(expression, do: block) do
    quote do
      try do
        for _ <- Stream.cycle([:ok]) do
          if unquote(expression) do
            unquote(block)
          else
            Loop.break
          end
        end
      catch
        :break -> :ok
      end
    end
  end

  def break, do: throw :break
end
```

然后再来测试一下

```bash
iex(1)> c "while.exs"
[Loop]
iex(2)> import Loop
Loop
iex(3)> pid = spawn fn ->
...(3)>   while true do
...(3)>     receive do
...(3)> 
...(3)>       :stop -> 
...(3)>         IO.puts "stop"
...(3)>         break
...(3)>       message -> IO.puts "Got #{inspect message}"
...(3)>     end
...(3)>   end
...(3)> end
#PID<0.100.0>
iex(4)> send pid, :hello
Got :hello
:hello
iex(5)> send pid, :stop 
stop
:stop
iex(6)> Process.alive? pid
false
```

大功告成
