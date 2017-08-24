defmodule Pooly do
  use Application

  def start(_type, _args) do
    pools_config = [
      [name: "Pool1",
       mfa: {SampleWorker, :start_link, []}, 
       size: 2,
       max_overflow: 3],
      [name: "Pool2",
       mfa: {SampleWorker, :start_link, []}, 
       size: 3,
       max_overflow: 0],
      [name: "Pool3",
       mfa: {SampleWorker, :start_link, []}, 
       size: 4,
       max_overflow: 0]
    ]

    start_pool(pools_config)
  end

  def start_pool(pools_config) do
    Pooly.Supervisor.start_link(pools_config)
  end

  def checkout(pool_name) do
    Pooly.Server.checkout(pool_name)
  end

  def checkin(pool_name, worker) do
    Pooly.Server.checkin(pool_name, worker)
  end

  def status(pool_name) do
    Pooly.Server.status(pool_name)
  end
end
