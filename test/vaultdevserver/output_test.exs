defmodule VaultDevServer.OutputTest do
  use ExUnit.Case

  alias VaultDevServer.Output

  defp assert_line(line), do: assert_received({:output_line, ^line})

  defp assert_lines(lines) do
    # Assert that we've received each line.
    Enum.each(lines, &assert_line/1)
    # Assert that we haven't received any extra lines.
    refute_received {:output_line, _}
  end

  defp assert_output(state, buf, lines) do
    assert state.buf == buf
    assert_lines(lines)
  end

  defp newstate, do: Output.new(self())

  describe "collect_lines" do
    test "one chunk empty" do
      newstate()
      |> Output.collect_lines("")
      |> assert_output("", [])
    end

    test "one chunk partial line" do
      newstate()
      |> Output.collect_lines("hello")
      |> assert_output("hello", [])
    end

    test "one chunk one complete line" do
      newstate()
      |> Output.collect_lines("hello\n")
      |> assert_output("", ["hello"])
    end

    test "one chunk two complete lines" do
      newstate()
      |> Output.collect_lines("hello\nworld\n")
      |> assert_output("", ["hello", "world"])
    end

    test "one chunk two complete lines and a partial line" do
      newstate()
      |> Output.collect_lines("hello\nworld\nmy name is ")
      |> assert_output("my name is ", ["hello", "world"])
    end

    test "two chunks empty" do
      newstate()
      |> Output.collect_lines("")
      |> Output.collect_lines("")
      |> assert_output("", [])
    end

    test "two chunks partial line" do
      newstate()
      |> Output.collect_lines("hel")
      |> Output.collect_lines("lo")
      |> assert_output("hello", [])
    end

    test "multiple chunks" do
      newstate()
      |> Output.collect_lines("hello\nwo")
      |> Output.collect_lines("rld\n\n")
      |> Output.collect_lines("\nmy\nname\nis")
      |> Output.collect_lines(" ")
      |> assert_output("is ", ["hello", "world", "", "", "my", "name"])
    end
  end
end
