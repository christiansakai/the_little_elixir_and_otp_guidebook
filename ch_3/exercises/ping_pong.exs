defmodule PP do
  def ping_pong do
    ping = spawn(__MODULE__, :ping, [])
    pong = spawn(__MODULE__, :pong, [])

    IO.puts Process.alive?(ping)
    IO.puts Process.alive?(pong)

    send(ping, {pong, :start})
  end

  def ping do
    receive do
      {pong, :start} ->
        IO.puts "Start"
        send(pong, {self(), :ping})
      {pong, :pong} -> 
        IO.puts "ping"
        send(pong, {self(), :ping})
    end

    ping()
  end

  def pong do
    receive do
      {ping, :ping} ->
        IO.puts "pong"
        send(ping, {self(), :pong})
    end

    pong()
  end
end
