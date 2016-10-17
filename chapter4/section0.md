## 建立测试

通常情况下，我们写的模块的测试只需要执行 mix test 就能跑完所有测试代码。但我们前面写的大多数都是单个文件，那该如何测试呢？其实测试单个文件也一样简单，比如，我们这里就出来测试一下前面实现的 while 宏。建立一个 while_test.exs 文件

```elixir
ExUnit.start
Code.require_file("while.exs", __DIR__)

defmodule WhileTest do
  use ExUnit.Case
  import Loop

  test "Is it really that way?" do
    assert Code.ensure_loaded?(Loop)
  end
end
```

然后我们就可以在命令行跑起来啦

```bash
root>> elixir while_test.exs
warning: unused import Loop
while_test.exs:6

.

Finished in 0.05 seconds (0.04s on load, 0.01s on tests)
1 test, 0 failures

Randomized with seed 836606
```

所以啊，要进行测试是如此的简单，只需要 Exunit.start 然后 use Exunit.Case 然后就可以愉快的写测试代码了。
