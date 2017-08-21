defmodule Hexy do
  @type rgb() :: {0..255, 0..255, 0..255}
  @type hex() :: binary

  @spec rgb_to_hex(rgb) :: hex | {:error, :invalid}
  def rgb_to_hex(rgb)

  def rgb_to_hex({r, g, b}) do
    [r, g, b]
    |> Enum.map(fn x ->
      x
      |> Integer.to_string(16)
      |> String.rjust(2, ?0)
    end)
    |> Enum.join()
  end

  def rgb_to_hex(_) do
    {:error, :invalid}
  end
end
