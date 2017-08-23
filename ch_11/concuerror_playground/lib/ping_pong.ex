defmodule PingPong do
  def ping do
    receive do
      :pong -> :ok
    end
  end

  def pong(ping_id) do
    send(ping_id, :pong)
    receive do
      :ping -> :ok
    end
  end
end
