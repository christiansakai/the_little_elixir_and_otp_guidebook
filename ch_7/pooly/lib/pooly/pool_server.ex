defmodule Pooly.PoolServer do
  use GenServer
  import Supervisor.Spec

  defmodule State do
    defstruct [
      :pool_supervisor,
      :worker_supervisor,
      :monitors,
      :size,
      :workers,
      :name,
      :mfa
    ]
  end

  #######
  # API #
  #######
  
  def start_link(pool_supervisor, pool_config) do
    GenServer.start_link(__MODULE__, [pool_supervisor, pool_config], name: name(pool_config[:name]))
  end

  def checkout(pool_name) do
    GenServer.call(name(pool_name), :checkout)
  end

  def checkin(pool_name, worker) do
    GenServer.cast(name(pool_name), {:checkin, worker})
  end

  def status(pool_name) do
    GenServer.call(name(pool_name), :status)
  end

  #############
  # Callbacks #
  #############

  def init([pool_supervisor, pool_config]) when is_pid(pool_supervisor) do
    Process.flag(:trap_exit, true)
    monitors = :ets.new(:monitors, [:private])
    init(pool_config, %State{pool_supervisor: pool_supervisor, monitors: monitors})
  end

  def init([{:name, name} | rest], state) do
    init(rest, %{state | name: name})
  end

  def init([{:mfa, mfa} | rest], state) do
    init(rest, %{state | mfa: mfa})
  end

  def init([{:size, size} | rest], state) do
    init(rest, %{state | size: size})
  end

  def init([_ | rest], state) do
    init(rest, state)
  end

  def init([], state) do
    send(self(), :start_worker_supervisor)
    {:ok, state}
  end

  def handle_call(:checkout, {borrower, reference}, %{workers: workers, monitors: monitors} = state) do
    case workers do
      [worker | rest] ->
        reference = Process.monitor(borrower)
        true = :ets.insert(monitors, {worker, reference})
        {:reply, worker, %{state | workers: rest}}

      [] ->
        {:reply, :noproc, state}
    end
  end

  def handle_call(:status, _from, %{workers: workers, monitors: monitors} = state) do
    {:reply, {length(workers), :ets.info(monitors, :size)}, state}
  end

  def handle_cast({:checkin, worker}, %{workers: workers, monitors: monitors} = state) do
    case :ets.lookup(monitors, worker) do
      [{^worker, reference}] ->
        true = Process.demonitor(reference)
        true = :ets.delete(monitors, worker)
        {:noreply, %{state | workers: [worker | workers]}}

      [] ->
        {:noreply, state}
    end
  end

  def handle_info(:start_worker_supervisor, state = %{pool_supervisor: pool_supervisor, name: name, mfa: mfa, size: size}) do
    {:ok, worker_supervisor} = Supervisor.start_child(pool_supervisor, supervisor_spec(name, mfa))
    workers = prepopulate(size, worker_supervisor)
    {:noreply, %{state | worker_supervisor: worker_supervisor, workers: workers}}
  end

  def handle_info({:DOWN, reference, _, _, _}, state = %{monitors: monitors, workers: workers}) do
    case :ets.match(monitors, {:"$1", reference}) do
      [[worker]] ->
        true = :ets.delete(monitors, worker)
        new_state = %{state | workers: [worker | workers]}
        {:noreply, new_state}

      [[]] ->
        {:noreply, state}
    end
  end

  def handle_info({:EXIT, worker, _reason}, state = %{monitors: monitors, workers: workers, pool_supervisor: pool_supervisor}) do
    case :ets.lookup(monitors, worker) do
      [{^worker, reference}] ->
        true = Process.demonitor(reference)
        true = :ets.delete(monitors, worker)
        new_state = %{state | workers: [new_worker(pool_supervisor) | workers]}
        {:noreply, new_state}

      [[]] ->
        {:noreply, state}
    end
  end

  def handle_info({:EXIT, worker_supervisor, reason}, state = %{worker_supervisor: worker_supervisor}) do
    {:stop, reason, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  #####################
  # Private Functions #
  #####################

  defp name(pool_name) do
    :"#{pool_name}Server"
  end

  defp prepopulate(size, worker_supervisor) do
    prepopulate(size, worker_supervisor, [])
  end

  defp prepopulate(size, _worker_supervisor, workers) when size < 1 do
    workers
  end

  defp prepopulate(size, worker_supervisor, workers) do
    prepopulate(size - 1, worker_supervisor, [new_worker(worker_supervisor) | workers])
  end

  defp new_worker(worker_supervisor) do
    {:ok, worker} = Supervisor.start_child(worker_supervisor, [[]])
    worker
  end

  defp supervisor_spec(name, mfa) do
    opts = [id: name <> "WorkerSupervisor", restart: :temporary]
    supervisor(Pooly.WorkerSupervisor, [self(), mfa], opts)
  end

end
