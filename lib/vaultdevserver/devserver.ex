defmodule VaultDevServer.DevServer do
  @moduledoc """
  Runs a Vault dev server in a subprocess for test purposes.
  """

  use GenServer

  @vault_first_line "==> Vault server configuration:"
  @vault_started_line "==> Vault server started! Log data will stream in below:"

  defmodule State do
    @moduledoc false

    alias VaultDevServer.Output

    defstruct [:port, :output_state, :output_lines, :api_addr, :root_token]

    def new(port, pid),
      do: %__MODULE__{
        port: port,
        output_state: Output.new(pid),
        output_lines: [],
        api_addr: nil,
        root_token: nil
      }

    def add_data(state, data) do
      %__MODULE__{state | output_state: Output.collect_lines(state.output_state, data)}
    end

    def add_line(state, line) do
      %__MODULE__{state | output_lines: [line | state.output_lines]}
    end
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @spec api_addr(GenServer.server()) :: String.t()
  def api_addr(ds), do: GenServer.call(ds, :api_addr)

  @spec root_token(GenServer.server()) :: String.t()
  def root_token(ds), do: GenServer.call(ds, :root_token)

  # Collect raw output from the subprocess and feed it to the output processor.
  # Eventually we'll receive a complete line from the output processor, which
  # we return alongside the updated state.
  #
  # We call this from init(), so we don't have any GenServer machinery set up
  # yet. This means it's safe (and necessary) to call receive().
  defp receive_line(state) do
    port = state.port

    receive do
      # Raw output from the subprocess, collect it and recurse.
      {^port, {:data, data}} -> state |> State.add_data(data) |> receive_line()
      # Complete line from the output collector, add it to our state and return it.
      {:output_line, line} -> {state |> State.add_line(line), line}
    after
      5000 -> {:error, "Timed out waiting for Vault to start"}
    end
  end

  # Match Vault a line of Vault output and extract the relevant information from it.
  defp config_line(state, "Api Address: " <> addr), do: %State{state | api_addr: addr}
  defp config_line(state, "Root Token: " <> token), do: %State{state | root_token: token}
  defp config_line(state, _), do: state

  # Collect any config information we need from Vault's startup output.
  defp collect_config(state) do
    case receive_line(state) do
      {:error, err} -> {:error, err}
      # We've reached the end of the config block, so return what we've collected.
      {state, @vault_started_line} -> state
      # This might be a config line, so trim whitespace and attempt to parse it.
      {state, line} -> state |> config_line(String.trim(line)) |> collect_config()
    end
  end

  # Wait for Vault's startup output to arrive and parse it for config information.
  defp wait_for_startup(state) do
    case receive_line(state) do
      {:error, err} -> {:error, err}
      # The first line of output is what we expect, so collect the config.
      {state, @vault_first_line} -> collect_config(state)
      # The first line of output isn't what we expect, so return an error.
      {_state, line} -> {:error, "Unexpected Vault output: #{line}"}
    end
  end

  defp default_executable do
    case System.get_env("VAULT_EXECUTABLE") do
      nil -> "vault"
      vault_executable -> vault_executable
    end
  end

  defp find_executable(executable) do
    case System.get_env("VAULT_PATH") do
      nil -> System.find_executable(executable)
      vault_path -> Path.join(vault_path, executable)
    end
  end

  defp vault_executable(opts) do
    opts
    |> Keyword.get(:vault_executable, default_executable())
    |> find_executable()
  end

  defp vault_args(opts) do
    root_token = Keyword.get(opts, :root_token, "root")
    extra_args = Keyword.get(opts, :extra_args, [])
    ["server", "-dev", "-dev-root-token-id=#{root_token}" | extra_args]
  end

  @impl GenServer
  def init(opts) do
    Process.flag(:trap_exit, true)

    port =
      Port.open(
        {:spawn_executable, vault_executable(opts)},
        [:binary, :stderr_to_stdout, args: vault_args(opts)]
      )

    state = State.new(port, self())

    case wait_for_startup(state) do
      {:error, err} ->
        # Clean up the subprocess, with an assignment to make dialyzer happy.
        _ = kill_vault(state)
        {:stop, err}

      state ->
        {:ok, state}
    end
  end

  defp kill_vault(state) do
    case Port.info(state.port) do
      nil -> nil
      info -> System.cmd("kill", [to_string(info[:os_pid])], stderr_to_stdout: true)
    end
  end

  @impl GenServer
  def terminate(_reason, state), do: kill_vault(state)

  @impl GenServer
  def handle_call(:api_addr, _from, state), do: {:reply, state.api_addr, state}
  def handle_call(:root_token, _from, state), do: {:reply, state.root_token, state}

  @impl GenServer
  def handle_info({_port, {:data, data}}, state), do: {:noreply, State.add_data(state, data)}

  def handle_info({:output_line, line}, state), do: {:noreply, State.add_line(state, line)}
end
