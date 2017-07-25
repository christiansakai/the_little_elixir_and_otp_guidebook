defmodule ThySupervisor do
  @moduledoc """
  Example on how to implement your own Supervisor module.
  """

  use GenServer

  @type child_spec :: {module(), atom(), term()}
  @type children_map :: %{required(pid()) => child_spec()}

  #########
  ## API ##
  #########

  @doc """
  Start the Supervisor with child specifications.
  """
  @spec start_link([child_spec()]) :: {:ok, children_map()}
  def start_link(child_spec_list) do
    GenServer.start_link(__MODULE__, [child_spec_list])
  end

  @doc """
  Start one Supervisor child.
  """
  @spec start_child(pid(), child_spec()) :: {:ok, pid()} | {:error, String.t}
  def start_child(supervisor, child_spec) do
    GenServer.call(supervisor, {:start_child, child_spec})
  end

  @doc """
  Terminate one Supervisor child.
  """
  @spec terminate_child(pid(), pid()) :: :ok 
  def terminate_child(supervisor, child) when is_pid(child) do
    GenServer.call(supervisor, {:terminate_child, child})
  end

  @doc """
  Restart one Supervisor child.
  """
  @spec restart_child(pid(), pid(), child_spec()) :: {:ok, pid()} | {:error, String.t}
  def restart_child(supervisor, child, child_spec) when is_pid(child) do
    GenServer.call(supervisor, {:restart_child, child, child_spec})
  end

  @doc """
  Count how many children does a Supervisor have.
  """
  @spec count_children(pid()) :: integer()
  def count_children(supervisor) do
    GenServer.call(supervisor, :count_children)
  end

  @doc """
  List all the children a Supervisor has.
  """
  @spec which_children(pid) :: children_map() 
  def which_children(supervisor) do
    GenServer.call(supervisor, :which_children)
  end

  ########################
  ## Callback Functions ##
  ########################
  
  def init([child_spec_list]) do
    Process.flag(:trap_exit, true)
    state =
      child_spec_list
      |> start_children()
      |> Enum.into(Map.new)

    {:ok, state}
  end

  def handle_call({:start_child, child_spec}, _from, state) do
    case do_start_child(child_spec) do
      {:ok, pid} ->
        new_state = Map.put(state, pid, child_spec)
        {:reply, {:ok, pid}, new_state}

      :error ->
        {:reply, {:error, "error starting child"}, state}
    end
  end

  def handle_call({:terminate_child, pid}, _from, state) do
    :ok = do_terminate_child(pid)
    new_state = Map.delete(state, pid)
    {:reply, :ok, new_state}
  end

  def handle_call({:restart_child, old_pid}, _from, state) do
    case Map.fetch(state, old_pid) do
      {:ok, child_spec} ->
        case do_restart_child(old_pid, child_spec) do
          {:ok, {pid, child_spec}} ->
            new_state =
              state
              |> Map.delete(old_pid)
              |> Map.put(pid, child_spec)
          
            {:reply, {:ok, pid}, new_state}

          :error ->
            {:reply, {:error, "error restarting child"}, state}
        end

      _ ->
        {:reply, {:error, "error restarting child"}, state}
    end
  end

  def handle_call(:count_children, _from, state) do
    {:reply, Map.size(state), state}
  end

  def handle_call(:which_children, _from, state) do
    {:reply, state, state}
  end

  def handle_info({:EXIT, from, :normal}, state) do
    new_state = Map.delete(state, from)
    {:noreply, new_state}
  end

  def handle_info({:EXIT, from, :killed}, state) do
    new_state = Map.delete(state, from)
    {:noreply, new_state}
  end

  # Restart child when the child exits abnormally
  def handle_info({:EXIT, old_pid, reason}, state) do
    case Map.fetch(state, old_pid) do
      {:ok, child_spec} ->
        case do_restart_child(old_pid, child_spec) do
          {:ok, {pid, child_spec}} ->
            new_state = 
              state 
              |> Map.delete(old_pid)
              |> Map.put(pid, child_spec)

            {:noreply, new_state}

          :error ->
            {:noreply, state}
        end

      _ ->
        {:noreply, state}
    end
  end

  def terminate(reason, state) do
    do_terminate_children(state)
    :ok
  end

  #######################
  ## Private Functions ##
  #######################

  defp start_children([]), do: []
  defp start_children([child_spec | rest]) do
    case do_start_child(child_spec) do
      {:ok, pid} ->
        [{pid, child_spec} | start_children(rest)]

      :error ->
        :error
    end
  end

  defp do_start_child({mod, fun, args}) do
    case apply(mod, fun, args) do
      pid when is_pid(pid) ->
        Process.link(pid)
        {:ok, pid}
      _ ->
        :error
    end
  end

  defp do_terminate_child(pid) do
    Process.exit(pid, :kill)
    :ok
  end

  defp do_restart_child(pid, child_spec) when is_pid(pid) do
    :ok = do_terminate_child(pid)
    case do_start_child(child_spec) do
      {:ok, new_pid} ->
        {:ok, {new_pid, child_spec}}

      :error ->
        :error
    end
  end

  defp do_terminate_children([]), do: :ok
  defp do_terminate_children(child_specs) do
    child_specs
    |> Enum.each(fn {pid, _} ->
      do_terminate_child(pid)
    end)
  end

end
