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
      :mfa,
      :overflow,
      :max_overflow,
      :waiting
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

  def init([{:max_overflow, max_overflow} | rest], state) do
    init(rest, %{state | max_overflow: max_overflow})
  end

  def init([_ | rest], state) do
    init(rest, state)
  end

  def init([], state) do
    send(self(), :start_worker_supervisor)
    {:ok, state}
  end

  def handle_call({:checkout, block}, {borrower, _reference} = from, state) do
    %{worker_supervisor: worker_supervisor,
      workers: workers,
      monitors: monitors,
      overflow: overflow,
      max_overflow: max_overflow} = state

    case workers do
      [worker | rest] ->
        reference = Process.monitor(borrower)
        true = :ets.insert(monitors, {worker, reference})
        {:reply, worker, %{state | workers: rest}}

      [] when max_overflow > 0 and overflow < max_overflow ->
        {worker, ref} = new_worker(worker_supervisor, borrower)
        true = :ets.insert(monitors, {worker, ref})
        {:reply, worker, %{state | overflow: overflow + 1}}

      [] ->
        {:reply, :noproc, state}
    end
  end

  def handle_call(:status, _from, %{workers: workers, monitors: monitors} = state) do
    {:reply, {state_name(state), length(workers), :ets.info(monitors, :size)}, state}
  end

  def handle_cast({:checkin, worker}, %{workers: workers, monitors: monitors} = state) do
    case :ets.lookup(monitors, worker) do
      [{^worker, reference}] ->
        true = Process.demonitor(reference)
        true = :ets.delete(monitors, worker)
        new_state = handle_checkin(worker, state)
        {:noreply, new_state}

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
        new_state = handle_worker_exit(worker, state)
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

  defp handle_checkin(worker, state) do
    %{worker_supervisor: worker_supervisor,
      workers: workers,
      monitors: monitors,
      overflow: overflow} = state

    if overflow > 0 do
      :ok = dismiss_worker(worker_supervisor, pid)
      %{state | waiting: empty, overflow: overflow - 1}
    else
      %{state | waiting: empty, workers: [pid | workers], overflow: 0}
    else
    end
  end

  defp dismiss_worker(worker_supervisor, worker) do
    true = Process.unlink(worker)
    Supervisor.terminate_child(worker_supervisor, worker)
  end

  defp handle_worker_exit(worker, state) do
    %{worker_supervisor: worker_supervisor,
      workers: workers,
      monitors: monitors,
      overflow: overflow} = state

    if overflow > 0 do
      %{state | overflow: overflow - 1}
    else
      %{state | workers: [new_worker(worker_supervisor) | workers]}
    end
  end

  defp state_name(%State{overflow: overflow, max_overflow: max_overflow, workers: workers}) when overflow < 1 do
    case length(workers) == 0 do
      true ->
        if max_overflow < 1 do
          :full
        else
          :overflow
        end

      false ->
        :ready
    end
  end

  defp state_name(%State{overflow: max_overflow, max_overflow: max_overflow}) do
    :full
  end

  defp state_name(_state) do
    :overflow
  end

end
