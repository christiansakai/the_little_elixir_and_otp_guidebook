Code.require_file "./test_helper.exs", __DIR__

defmodule PingPong.ConcurrencyTest do
  import PingPong

  def test do
    ping_id = spawn fn -> ping end
    spawn fn ->
      pong(ping_id)
    end
  end
end
