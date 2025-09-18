defmodule Turso.Schemas do
  @moduledoc """
  Provides NimbleOptions schema definitions for Turso API functions.

  This module provides a macro-based DSL for defining and using NimbleOptions schemas
  throughout the Turso library. It follows the pattern from Anthropix.
  """

  @doc """
  When used, imports NimbleOptions and provides helpers for schema definition.

  ## Example

      defmodule MyModule do
        use Turso.Schemas

        schema :my_opts, [
          name: [type: :string, required: true, doc: "The name"],
          count: [type: :pos_integer, default: 1, doc: "The count"]
        ]

        def my_function(opts \\\\ []) do
          opts = NimbleOptions.validate!(opts, @my_opts_schema)
          # Use validated opts
        end
      end
  """
  defmacro __using__(_opts) do
    quote do
      import NimbleOptions
      import Turso.Schemas
    end
  end

  @doc false
  defmacro schema(name, opts) do
    quote do
      schema_name = :"#{unquote(name)}_schema"
      Module.put_attribute(__MODULE__, schema_name, NimbleOptions.new!(unquote(opts)))
    end
  end

  @doc false
  defmacro doc(schema_name) when is_atom(schema_name) do
    quote do
      schema_attr = Module.get_attribute(__MODULE__, unquote(:"#{schema_name}_schema"))

      if schema_attr do
        NimbleOptions.docs(schema_attr)
      else
        ""
      end
    end
  end
end
