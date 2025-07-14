defmodule AshBackpex.FieldHelpers do
  @moduledoc """
  Helper functions for deriving field types and modules from Ash types.
  """

  @doc """
  Derives the appropriate Backpex field module from an Ash type.
  """
  def derive_field_module(type) do
    case type do
      {:array, _inner_type} ->
        Backpex.Fields.MultiSelect

      Ash.Type.String ->
        Backpex.Fields.Text

      Ash.Type.Atom ->
        Backpex.Fields.Text

      Ash.Type.CiString ->
        Backpex.Fields.Text

      Ash.Type.Integer ->
        Backpex.Fields.Number

      Ash.Type.Boolean ->
        Backpex.Fields.Boolean

      Ash.Type.Float ->
        Backpex.Fields.Number

      Ash.Type.Date ->
        Backpex.Fields.Date

      Ash.Type.DateTime ->
        Backpex.Fields.DateTime

      Ash.Type.UtcDatetime ->
        Backpex.Fields.DateTime

      Ash.Type.UtcDatetimeUsec ->
        Backpex.Fields.DateTime

      Ash.Type.NaiveDateTime ->
        Backpex.Fields.DateTime

      Ash.Type.Time ->
        Backpex.Fields.Time

      Ash.Type.UUID ->
        Backpex.Fields.Text

      Ash.Type.File ->
        Backpex.Fields.Upload

      type when is_atom(type) ->
        # Check if it's a resource module
        if ash_resource?(type) do
          Backpex.Fields.BelongsTo
        else
          Backpex.Fields.Text
        end

      _ ->
        Backpex.Fields.Text
    end
  end

  @doc """
  Derives the appropriate Ecto type from an Ash type for use in changesets.
  """
  def derive_ecto_type(type) do
    case type do
      {:array, inner_type} -> {:array, derive_ecto_type(inner_type)}
      Ash.Type.String -> :string
      Ash.Type.Integer -> :integer
      Ash.Type.Boolean -> :boolean
      Ash.Type.Float -> :float
      Ash.Type.Date -> :date
      Ash.Type.DateTime -> :utc_datetime
      Ash.Type.UtcDatetime -> :utc_datetime
      Ash.Type.UtcDatetimeUsec -> :utc_datetime_usec
      Ash.Type.NaiveDateTime -> :naive_datetime
      Ash.Type.Time -> :time
      Ash.Type.UUID -> Ecto.UUID
      Ash.Type.Atom -> :string
      Ash.Type.CiString -> :string
      Ash.Type.File -> :string
      _ -> :string
    end
  end

  @doc """
  Checks if a module is an Ash resource.
  """
  def ash_resource?(module) when is_atom(module) do
    function_exported?(module, :__ash_resource__, 0) and module.__ash_resource__()
  rescue
    _ -> false
  end

  def ash_resource?(_), do: false
end
