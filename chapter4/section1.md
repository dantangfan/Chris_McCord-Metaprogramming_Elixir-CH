## 决定要测试什么

要测试什么不是三言两语能说完的，完全取决于你代码的功能和目标。也并不是测试要达到 100% 覆盖度才是好的测试，而且要实现每行都测试到有时候会让人很烦。

那我们的 while 宏需要测试什么东西呢？我们稍微列举一下

- 当表达式为 true 的时候，能够重复的执行代码块，直到跳出循环

- 遇到 break 的时候，可以自觉地结束循环

恩，差不多就这么多了。所以我们一个一个的来实现吧

```elixir
  test "while/2 loop as long as the expression is truely" do
    pid = spawn(fn -> :timer.sleep(:infinity) end)

    send self, :one
    while Process.alive?(pid) do
      receive do
        :one -> send self, :two
        :two -> send self, :three
        three ->
          Process.exit(pid, :kill)
          send self, :done
      end
    end
    assert_received :done
  end
```

然后再来跑一遍我们的代码，当然是没问题的，测试能通过。


然后再来实现一下 break 的测试

```elixir
  test "break/0 terminates execution" do
    send self, :one
    while true do
      receive do
        :one -> send self, :two
        :two -> send self, :three
        three ->
          send self, :done
          break
      end
    end
    assert_received :done
  end
```

当然，测试也是能通过的。代码很简单，根本不需要解释就能看懂
