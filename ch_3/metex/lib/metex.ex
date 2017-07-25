defmodule Metex do
  alias Metex.Coordinator
  alias Metex.Worker

  def temperatures_of(cities) do
    coordinator = spawn(Coordinator, :loop, [[], Enum.count(cities)])

    Enum.each(cities, fn city ->
      worker = spawn(Worker, :loop, [])
      send(worker, {coordinator, city})
    end)
  end
end
