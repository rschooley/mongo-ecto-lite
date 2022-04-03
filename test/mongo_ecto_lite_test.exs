defmodule MongoEctoLiteTest do
  use ExUnit.Case
  doctest MongoEctoLite

  test "greets the world" do
    assert MongoEctoLite.hello() == :world
  end
end
