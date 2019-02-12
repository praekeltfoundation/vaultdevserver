defmodule VaultDevServer.DevServerTest do
  use ExUnit.Case

  alias VaultDevServer.DevServer

  test "start" do
    {:ok, ds} = start_supervised(DevServer)
    assert DevServer.api_addr(ds) == "http://127.0.0.1:8200"
    assert DevServer.root_token(ds) == "root"
  end

  test "custom root token" do
    {:ok, ds} = start_supervised({DevServer, root_token: "tuber"})
    assert DevServer.api_addr(ds) == "http://127.0.0.1:8200"
    assert DevServer.root_token(ds) == "tuber"
  end

  test "extra args" do
    {:ok, ds} = start_supervised({DevServer, extra_args: ["-dev-listen-address=127.0.0.1:8202"]})
    assert DevServer.api_addr(ds) == "http://127.0.0.1:8202"
    assert DevServer.root_token(ds) == "root"
  end

  test "start failure" do
    {:error, {err, _}} = start_supervised({DevServer, extra_args: ["-invalid-arg"]})
    assert err == "Unexpected Vault output: flag provided but not defined: -invalid-arg"
  end

  test "start twice" do
    {:ok, ds} = start_supervised(DevServer)
    assert DevServer.api_addr(ds) == "http://127.0.0.1:8200"
    assert DevServer.root_token(ds) == "root"
    {:error, {:already_started, ^ds}} = start_supervised(DevServer)
  end
end
