defmodule Dogma.Rules.FunctionArity do
  @moduledoc """
  A rule that disallows functions and macros with arity greater than 4, meaning
  a function may not take more than 4 arguments.

  By default this function is considered invalid by this rule:

      def transform(a, b, c, d, e) do
        # Do something
      end

  The maximum allowed arity for this rule can be configured with the `max`
  option in your mix config.
  """

  @behaviour Dogma.Rule

  alias Dogma.Script
  alias Dogma.Error

  def test(script), do: test(script, [])

  def test(script, _config = []) do
    test(script, max: 4)
  end

  def test(script, max: max) do
    script
    |> Script.walk(fn node, errs ->
      check_node(node, errs, max)
    end)
  end

  defp check_node({:def, _, _} = node, errors, max_arity) do
    check_def(node, errors, max_arity)
  end
  defp check_node({:defp, _, _} = node, errors, max_arity) do
    check_def(node, errors, max_arity)
  end
  defp check_node({:defmacro, _, _} = node, errors, max_arity) do
    check_def(node, errors, max_arity)
  end
  defp check_node(node, errors, _max_arity) do
    {node, errors}
  end

  defp check_def(node, errors, max_arity) do
    case node do
      {_, [line: line_number], [{_, _, args}, _function_body]}
        -> check_args(args, line_number, errors, max_arity)
      {_, [line: line_number], [{_, _, args}]}
        -> check_args(args, line_number, errors, max_arity)
    end
  end

  defp check_args(function_args, line_number, errors, max_arity) do
    function_arity = Enum.count(function_args || [])
    if (function_arity > max_arity) do
      {node, [error(line_number, max_arity) | errors]}
    else
      {node, errors}
    end
  end

  defp error(line_number, max_arity) do
    %Error{
      rule:     __MODULE__,
      message:  "Function arity should be #{max_arity} or less",
      line: line_number,
    }
  end
end
