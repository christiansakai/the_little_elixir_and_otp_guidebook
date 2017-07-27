defmodule Pooly.Server do
  use GenServer
  import Supervisor.Spec

  defmodule State do
    defstruct supervisor: nil,
              monitors: nil,
              worker_supervisor: nil,
              workers: nil,
              size: nil,
              mfa: nil
  end

  #######
  # API #
  #######

  def start_link(supervisor, pool_config) do
    GenServer.start_link(
      __MODULE__, 
      [supervisor, pool_config],
      name: __MODULE__
    )
  end

  def init([supervisor, pool_config]) when is_pid(supervisor) do
    monitors = :ets.new(:monitors, [:private])

    init(pool_config, %State{
      supervisor: supervisor, 
      monitors: monitors
    })
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

  ## Borrow a worker
  def checkout do
    GenServer.call(__MODULE__, :checkout)
  end

  ## Return back a worker
  def checkin(worker) do
    GenServer.cast(__MODULE__, {:checkin, worker})
  end

  def status do
    GenServer.call(__MODULE__, :status)
  end

  #############
  # Callbacks #
  #############
  
  def handle_info(:start_worker_supervisor, state = %State{
    supervisor: supervisor,
    mfa: mfa,
    size: size
  }) do
    {:ok, worker_supervisor} = Supervisor.start_child(supervisor, worker_supervisor_spec(mfa))
    workers = prepopulate(size, worker_supervisor)

    {:noreply, %{state | worker_supervisor: worker_supervisor,
                         workers: workers}}
  end

  def handle_call(:checkout, {borrower, _ref}, %State{
    workers: workers,
    monitors: monitors
  } = state) do
    case workers do
      [worker | idle_workers] ->
        borrower_monitor = Process.monitor(borrower)

        true = :ets.insert(monitors, {worker, borrower_monitor})
        {:reply, worker, %{state | workers: idle_workers}}

      [] ->
        {:reply, :noproc, state}
    end
  end

  def handle_call({:checkin, worker}, %{
    workers: workers,
    monitors: monitors
  } = state) do
    case :ets.lookup(monitors, worker) do
      [{^worker, borrower_monitor}] ->
        true = Process.demonitor(borrower_monitor)
        true = :ets.delete(monitors, worker)
        {:noreply, %{state | workers: [worker | workers]}}

      [] ->
        {:noreply, state}
    end
  end

  def handle_call(:status, _from, %{
    workers: workers,
    monitors: monitors
  } = state) do
    {:reply, {length(workers), :ets.info(monitors, :size)}, state}
  end

  #####################
  # Private Functions #
  #####################

  defp worker_supervisor_spec(mfa) do
    opts = [restart: :temporary]
    supervisor(Pooly.WorkerSupervisor, [mfa], opts)
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

end
