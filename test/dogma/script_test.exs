defmodule Dogma.ScriptTest do
  use ShouldI

  alias Dogma.Error
  alias Dogma.Script
  alias Dogma.Script.InvalidScriptError
  alias Dogma.Util.Comment

  having "parse/2" do

    having "a valid script" do
      setup context do
        source = """
        defmodule Foo do
          def greet do
            "Hello world!" # Comment
          end # Another
        end
        """
        %{
          source: source,
          script: Script.parse( source, "lib/foo.ex" ),
        }
      end

      should "assign path", context do
        assert "lib/foo.ex" == context.script.path
      end

      should "assign source", context do
        assert context.source == context.script.source
      end

      should "assign processed source", context do
        processed_source = """
        defmodule Foo do
          def greet do
            "" # Comment
          end # Another
        end
        """
        assert processed_source == context.script.processed_source
      end

      should "assign an empty list of errors", context do
        assert [] == context.script.errors
      end

      should "assigns lines", context do
        lines = [
          {1,  ~s(defmodule Foo do)},
          {2,  ~s(  def greet do)},
          {3,  ~s(    "Hello world!" # Comment)},
          {4,  ~s(  end # Another)},
          {5,  ~s(end)},
        ]
        assert lines == context.script.lines
      end

      should "assigns processed lines", context do
        lines = [
          {1,  ~s(defmodule Foo do)},
          {2,  ~s(  def greet do)},
          {3,  ~s(    "" # Comment)},
          {4,  ~s(  end # Another)},
          {5,  ~s(end)},
        ]
        assert lines == context.script.processed_lines
      end

      should "assign valid? as true", context do
        assert context.script.valid?
      end

      should "assigns the quoted abstract syntax tree", context do
        {:ok, ast} = Code.string_to_quoted( context.source )
        assert ast == context.script.ast
      end

      should "include line numbers in the quoted ast" do
        script = Script.parse( "1 + 1", "" )
        assert {:+, [line: 1], [1, 1]} == script.ast
      end

      should "assigns the tokenized source", context do
        assert [
          {:identifier, _, :defmodule}, {:aliases, _, [:Foo]},
          {:do, _}, {:eol, _}, {:identifier, _, :def},
          {:do_identifier, _, :greet}, {:do, _}, {:eol, _},
          {:bin_string, _, ["Hello world!"]}, {:eol, _}, {:end, _},
          {:eol, _}, {:end, _}, {:eol, _},
        ] = context.script.tokens
      end

      should "assign comments", context do
        assert context.script.comments == [
          %Comment{ content: " Comment", line: 3 },
          %Comment{ content: " Another", line: 4 },
        ]
      end
    end


    having "an invalid script" do
      setup context do
        source = ~s"""
        <>>>>>>><><>><><>>>>>>>>>>>>>><<><
        """
        %{
          script: Script.parse( source, "" ),
        }
      end

      should "assign valid? as false", context do
        refute context.script.valid?
      end

      should "assign nil in place of AST", context do
        assert nil == context.script.ast
      end

      should "assign nil in place of tokens", context do
        assert nil == context.script.ast
      end

      should "assign nil in place of lines", context do
        assert nil == context.script.lines
      end

      should "assign nil in place of processed_source", context do
        assert nil == context.script.processed_source
      end

      should "assign nil in place of processed_lines", context do
        assert nil == context.script.processed_lines
      end

      should "assign a syntax error", context do
        error = %Error{
          rule: SyntaxError,
          message: ~s[missing terminator: >> (for "<<" starting at line 1)],
          line: 1,
        }
        assert [error] == context.script.errors
      end
    end


    having "a script with trailing blank lines" do
      setup context do
        source = """
        1 + 2


        """
        %{
          source: source,
          script: Script.parse( source, "lib/foo.ex" ),
        }
      end

      should "preserve the extra blank lines", context do
        lines = [
          {1, "1 + 2"},
          {2, ""},
          {3, ""},
        ]
        assert lines == context.script.lines
      end
    end

    should "register ignored lines" do
      script = """
      defmodule Foo_Bar do # dogma:ignore Something SomethingElse
        @foo 1 # dogma:ignore SomethingElse
      end
      """ |> Script.parse("")
      expected = %{
        Something     => Enum.into([1], HashSet.new),
        SomethingElse => Enum.into([1, 2], HashSet.new),
      }
      assert script.ignore_index == expected
    end
  end

  having "parse!/2" do
    should "raise InvalidScriptError with an invalid script" do
      assert_raise InvalidScriptError, "Invalid syntax in foo.ex", fn ->
        "<>>>>>>><><>><><>>>>>>>>>>>>>><<><" |> Script.parse!( "foo.ex" )
      end
    end

    should "be identical to parse/2 for valid scripts" do
      source = """
      defmodule Foo do
        def greet do
          "Hello world!"
        end
      end
      """
      expected = source |> Script.parse( "foo.ex" )
      actual   = source |> Script.parse!( "foo.ex" )
      assert expected == actual
    end
  end


  having "walk/2" do
    setup context do
      %{
        script: Script.parse( "2 * 3 + 1", "foo.ex" )
      }
    end

    should "run the fn on each node, and return the accumulator", context do
      fun    = fn(node, errors) -> {node, [node | errors]} end
      walked = Script.walk( context.script, fun )
      nodes_walked = [
        1,
        3,
        2,
        {:*, [line: 1], [2, 3]},
        {:+, [line: 1], [{:*, [line: 1], [2, 3]}, 1]}
      ]
      assert nodes_walked == walked
    end

    should "allow you to skip nodes", context do
      fun    = fn(node, errors) -> {[], [node | errors]} end
      walked = Script.walk( context.script, fun )
      nodes_walked = [
        {:+, [line: 1], [{:*, [line: 1], [2, 3]}, 1]}
      ]
      assert nodes_walked == walked
    end
  end
end
