defmodule EQCGen do
  use EQC.ExUnit

  def string_with_fixed_lenght(len) do
    vector(len, char)
  end

  def string_with_variable_length do
    let len <- choose(1, 10) do
      vector(len, char)
    end
  end

  def string_with_commas do
    let len <- choose(1, 10) do
      vector(len, frequency([{3, oneof(:lists.seq(?a, ?z))}, {1, ?,}]))
    end
  end

  def nested_list(gen) do
    sized size do
      nested_list(size, gen)
    end
  end

  defp nested_list(0, _gen) do
    []
  end

  defp nested_list(n, gen) do
    lazy do
      oneof [[gen | nested_list(n - 1, gen)],
             [nested_list(n - 1, gen)]]
    end
  end

  def balanced_tree(gen) do
    sized size do
      balanced_tree(size, gen)
    end
  end

  def balanced_tree(0, gen) do
    {:leaf, gen}
  end

  def balanced_tree(n, gen) do
    lazy do
      {:node,
        gen,
        balanced_tree(div(n, 2), gen),
        balanced_tree(div(n, 2), gen)}
    end
  end


end
