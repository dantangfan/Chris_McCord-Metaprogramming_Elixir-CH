defmodule MathTest do
  use Assertion
  Assertion.extend

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
