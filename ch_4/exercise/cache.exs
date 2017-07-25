defmodule Cache do
  use GenServer

  ## Client API

  def start_link do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init(_) do
    {:ok, %{}}
  end

  def write(key, term) do
    GenServer.cast(__MODULE__, {:write, {key, term}})
  end

  def read(key) do
    GenServer.call(__MODULE__, {:read, key})
  end

  def delete(key) do
    GenServer.cast(__MODULE__, {:delete, key})
  end

  def clear do
    GenServer.cast(__MODULE__, :clear)
  end

  def exist?(key) do
    GenServer.call(__MODULE__, {:exist?, key})
  end

  ## Callback API

  def handle_cast({:write, {key, term}}, state) do
    {:noreply, Map.put(state, key, term)} 
  end

  def handle_cast({:delete, key}, state) do
    {:noreply, Map.delete(state, key)}
  end

  def handle_cast(:clear, state) do
    {:noreply, %{}}
  end

  def handle_call({:read, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end

  def handle_call({:exist?, key}, _from, state) do
    {:reply, Map.has_key?(state, key), state}
  end
end
