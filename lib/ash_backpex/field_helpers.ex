defmodule AshBackpex.FieldHelpers do
  @moduledoc """
  Helper functions for deriving field types and modules from Ash types.
  """

  @doc """
  Derives the appropriate Backpex field module from an Ash type.
  """
  def derive_field_module(type) do
    case type do
      Ash.Type.String -> Backpex.Fields.Text
      Ash.Type.Atom -> Backpex.Fields.Text
      Ash.Type.CiString -> Backpex.Fields.Text
      Ash.Type.Integer -> Backpex.Fields.Number
      Ash.Type.Boolean -> Backpex.Fields.Boolean
      Ash.Type.Float -> Backpex.Fields.Number
      Ash.Type.Date -> Backpex.Fields.Date
      Ash.Type.DateTime -> Backpex.Fields.DateTime
      Ash.Type.UtcDatetime -> Backpex.Fields.DateTime
      Ash.Type.UtcDatetimeUsec -> Backpex.Fields.DateTime
      Ash.Type.NaiveDateTime -> Backpex.Fields.DateTime
      Ash.Type.Time -> Backpex.Fields.Time
      type when is_atom(type) -> 
        # Check if it's a resource module
        if is_ash_resource?(type) do
          Backpex.Fields.BelongsTo
        else
          Backpex.Fields.Text
        end
      _ -> Backpex.Fields.Text
    end
  end

  @doc """
  Derives the appropriate Ecto type from an Ash type for use in changesets.
  """
  def derive_ecto_type(type) do
    case type do
      Ash.Type.String -> :string
      Ash.Type.Integer -> :integer
      Ash.Type.Boolean -> :boolean
      Ash.Type.Float -> :float
      Ash.Type.Date -> :date
      Ash.Type.DateTime -> :utc_datetime
      Ash.Type.Time -> :time
      Ash.Type.UUID -> Ecto.UUID
      _ -> :string
    end
  end

  @doc """
  Checks if a module is an Ash resource.
  """
  def is_ash_resource?(module) when is_atom(module) do
    try do
      function_exported?(module, :__ash_resource__, 0) and module.__ash_resource__()
    rescue
      _ -> false
    end
  end

  def is_ash_resource?(_), do: false
end