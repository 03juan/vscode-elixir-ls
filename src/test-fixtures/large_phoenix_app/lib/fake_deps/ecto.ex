defmodule Ecto.Schema do
  @moduledoc """
  Fake Ecto.Schema for testing ElixirLS IDE Coordinator.

  Provides minimal schema functionality for compilation and
  dependency analysis without requiring actual Ecto.
  """

  @doc """
  Defines a field on the schema with given name and type.
  """
  defmacro field(name, type \\ :string, opts \\ []) do
    quote do
      # Store field definition for schema introspection
      @fields {unquote(name), unquote(type), unquote(opts)}
    end
  end

  @doc """
  Defines the schema source and block.
  """
  defmacro schema(source, do: block) do
    quote do
      @primary_key {:id, :id, autogenerate: true}
      @foreign_key_type :id
      @schema_source unquote(source)

      # Initialize fields list
      Module.register_attribute(__MODULE__, :fields, accumulate: true)
      Module.register_attribute(__MODULE__, :associations, accumulate: true)

      unquote(block)

      # Generate struct with all fields
      field_names = @fields |> Enum.map(fn {name, _type, _opts} -> name end)
      all_fields = [:id | field_names]
      defstruct all_fields

      # Generate __schema__ callbacks for introspection
      def __schema__(:source), do: @schema_source
      def __schema__(:fields) do
        @fields |> Enum.map(fn {name, _type, _opts} -> name end)
      end
      def __schema__(:associations) do
        @associations |> Enum.map(fn {name, _assoc, _opts} -> name end)
      end
      def __schema__(:type, field) do
        case Enum.find(@fields, fn {name, _type, _opts} -> name == field end) do
          {_name, type, _opts} -> type
          nil -> nil
        end
      end
    end
  end

  @doc """
  Defines a has_many association.
  """
  defmacro has_many(name, queryable, opts \\ []) do
    quote do
      @associations {unquote(name), unquote(queryable), unquote(opts)}
    end
  end

  @doc """
  Defines a has_one association.
  """
  defmacro has_one(name, queryable, opts \\ []) do
    quote do
      @associations {unquote(name), unquote(queryable), unquote(opts)}
    end
  end

  @doc """
  Defines a belongs_to association.
  """
  defmacro belongs_to(name, queryable, opts \\ []) do
    quote do
      @associations {unquote(name), unquote(queryable), unquote(opts)}
      # Auto-generate foreign key field
      field String.to_atom("#{unquote(name)}_id"), :id
    end
  end

  @doc """
  Defines a many_to_many association.
  """
  defmacro many_to_many(name, queryable, opts \\ []) do
    quote do
      @associations {unquote(name), unquote(queryable), unquote(opts)}
    end
  end

  @doc """
  Adds timestamp fields (inserted_at, updated_at).
  """
  defmacro timestamps(opts \\ []) do
    quote do
      field :inserted_at, :naive_datetime
      unless unquote(opts)[:updated_at] == false do
        field :updated_at, :naive_datetime
      end
    end
  end

  @doc """
  Hook called when module is used.
  """
  defmacro __using__(_opts) do
    quote do
      import Ecto.Schema, only: [schema: 2, field: 2, field: 3,
                                 has_many: 2, has_many: 3,
                                 has_one: 2, has_one: 3,
                                 belongs_to: 2, belongs_to: 3,
                                 many_to_many: 2, many_to_many: 3,
                                 timestamps: 0, timestamps: 1]
      import Ecto.Changeset, only: [cast: 3, validate_required: 2,
                                    validate_length: 3, validate_format: 3, validate_format: 4,
                                    validate_number: 3, unique_constraint: 2,
                                    unique_constraint: 3, get_field: 2, put_change: 3,
                                    validate_inclusion: 3, validate_inclusion: 4, change: 1, change: 2,
                                    get_change: 2, delete_change: 2]
    end
  end
end

defmodule Ecto.Query do
  @moduledoc """
  Fake Ecto.Query for testing ElixirLS IDE Coordinator.

  Provides minimal query functionality for compilation and
  dependency analysis without requiring actual Ecto.
  """

  @doc """
  Creates a query.
  """
  defmacro from(expr, kw \\ []) do
    quote do
      %{from: unquote(expr), clauses: unquote(kw)}
    end
  end

  @doc """
  Creates a query with keyword syntax.
  """
  defmacro from(binding, :in, expr, kw \\ []) do
    quote do
      %{from: unquote(expr), binding: unquote(binding), clauses: unquote(kw)}
    end
  end

  @doc """
  A select query expression.
  """
  defmacro select(query, binding \\ [], expr) do
    quote do
      Map.put(unquote(query), :select, {unquote(binding), unquote(expr)})
    end
  end

  @doc """
  A where query expression.
  """
  defmacro where(query, binding \\ [], expr) do
    quote do
      Map.update(unquote(query), :where, [{unquote(binding), unquote(expr)}],
        &[{unquote(binding), unquote(expr)} | &1])
    end
  end

  @doc """
  A join query expression.
  """
  defmacro join(query, qual, binding \\ [], expr, opts \\ []) do
    quote do
      Map.update(unquote(query), :joins,
        [{unquote(qual), unquote(binding), unquote(expr), unquote(opts)}],
        &[{unquote(qual), unquote(binding), unquote(expr), unquote(opts)} | &1])
    end
  end

  @doc """
  An order_by query expression.
  """
  defmacro order_by(query, binding \\ [], expr) do
    quote do
      Map.put(unquote(query), :order_by, {unquote(binding), unquote(expr)})
    end
  end

  @doc """
  A limit query expression.
  """
  defmacro limit(query, binding \\ [], expr) do
    quote do
      Map.put(unquote(query), :limit, {unquote(binding), unquote(expr)})
    end
  end

  @doc """
  Import query macros.
  """
  defmacro __using__(_opts) do
    quote do
      import Ecto.Query
    end
  end
end

defmodule Ecto.Changeset do
  @moduledoc """
  Fake Ecto.Changeset for testing ElixirLS IDE Coordinator.
  """

  defstruct data: nil, changes: %{}, errors: [], valid?: true

  @doc """
  Creates a changeset.
  """
  def cast(data, params, permitted_fields) do
    %__MODULE__{
      data: data,
      changes: Map.take(params, permitted_fields),
      valid?: true
    }
  end

  @doc """
  Validates required fields.
  """
  def validate_required(changeset, fields) do
    errors = Enum.filter(fields, fn field ->
      not Map.has_key?(changeset.changes, field)
    end)

    case errors do
      [] -> changeset
      _ -> %{changeset | valid?: false, errors: errors}
    end
  end

  @doc """
  Validates length of a field.
  """
  def validate_length(changeset, _field, _opts) do
    # Simplified validation
    changeset
  end

  @doc """
  Validates format of a field.
  """
  def validate_format(changeset, _field, _format) do
    # Simplified validation
    changeset
  end

  @doc """
  Validates format of a field with options.
  """
  def validate_format(changeset, _field, _format, _opts) do
    # Simplified validation
    changeset
  end

  @doc """
  Validates number constraints.
  """
  def validate_number(changeset, _field, _opts) do
    # Simplified validation
    changeset
  end

  @doc """
  Adds a unique constraint.
  """
  def unique_constraint(changeset, _field, _opts \\ []) do
    # Simplified constraint
    changeset
  end

  @doc """
  Gets a field value from changeset.
  """
  def get_field(changeset, field) do
    Map.get(changeset.changes, field) ||
      (changeset.data && Map.get(changeset.data, field))
  end

  @doc """
  Puts a change in the changeset.
  """
  def put_change(changeset, field, value) do
    %{changeset | changes: Map.put(changeset.changes, field, value)}
  end

  @doc """
  Validates inclusion in a list.
  """
  def validate_inclusion(changeset, _field, _list, _opts \\ []) do
    # Simplified validation
    changeset
  end

  @doc """
  Creates a changeset from a struct.
  """
  def change(struct, changes \\ %{}) do
    %__MODULE__{data: struct, changes: changes, valid?: true}
  end

  @doc """
  Gets a change from changeset.
  """
  def get_change(changeset, field) do
    Map.get(changeset.changes, field)
  end

  @doc """
  Deletes a change from changeset.
  """
  def delete_change(changeset, field) do
    %{changeset | changes: Map.delete(changeset.changes, field)}
  end
end

defmodule Ecto.Repo do
  @moduledoc """
  Fake Ecto.Repo for testing ElixirLS IDE Coordinator.
  """

  @doc """
  Gets a single record by ID.
  """
  def get(queryable, id, opts \\ []) do
    # Return fake struct for testing
    struct(queryable, %{id: id})
  end

  @doc """
  Gets a single record by criteria.
  """
  def get_by(queryable, clauses, opts \\ []) do
    # Return fake struct for testing
    struct(queryable, clauses)
  end

  @doc """
  Fetches all records matching query.
  """
  def all(queryable, opts \\ []) do
    # Return empty list for testing
    []
  end

  @doc """
  Inserts a changeset.
  """
  def insert(changeset_or_struct, opts \\ []) do
    {:ok, changeset_or_struct}
  end

  @doc """
  Updates a changeset.
  """
  def update(changeset, opts \\ []) do
    {:ok, changeset.data}
  end

  @doc """
  Deletes a struct.
  """
  def delete(struct, opts \\ []) do
    {:ok, struct}
  end

  defmacro __using__(_opts) do
    quote do
      def get(queryable, id, opts \\ []), do: Ecto.Repo.get(queryable, id, opts)
      def get_by(queryable, clauses, opts \\ []), do: Ecto.Repo.get_by(queryable, clauses, opts)
      def all(queryable, opts \\ []), do: Ecto.Repo.all(queryable, opts)
      def insert(changeset_or_struct, opts \\ []), do: Ecto.Repo.insert(changeset_or_struct, opts)
      def update(changeset, opts \\ []), do: Ecto.Repo.update(changeset, opts)
      def delete(struct, opts \\ []), do: Ecto.Repo.delete(struct, opts)
    end
  end
end
