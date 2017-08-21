defmodule Card do
  @type card :: {suit(), value()}
  @type suit :: :heart | :spade | :diamond | :clover
  @type value :: 2..10 | :A | :J | :K | :Q
end
