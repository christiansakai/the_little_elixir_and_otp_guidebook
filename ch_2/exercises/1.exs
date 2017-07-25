defmodule Sum do
  def sum([h | t]), do: h + sum(t)
  def sum([]), do: 0
end
