defmodule AshBackpex.ResourceAction.Info do
  @moduledoc """
  Introspection module for AshBackpex resource actions.
  """

  use Spark.InfoGenerator, extension: AshBackpex.ResourceAction.Dsl

  @doc """
  Returns the configured Ash resource.
  """
  @spec resource(module()) :: module() | nil
  def resource(module) do
    Spark.Dsl.Extension.get_opt(module, [:backpex], :resource)
  end

  @doc """
  Returns the configured Ash action name.
  """
  @spec action(module()) :: atom() | nil
  def action(module) do
    Spark.Dsl.Extension.get_opt(module, [:backpex], :action)
  end

  @doc """
  Returns the configured label for the action button.
  """
  @spec label(module()) :: String.t() | nil
  def label(module) do
    Spark.Dsl.Extension.get_opt(module, [:backpex], :label)
  end

  @doc """
  Returns the configured title for the action modal.
  """
  @spec title(module()) :: String.t() | nil
  def title(module) do
    Spark.Dsl.Extension.get_opt(module, [:backpex], :title)
  end

  @doc """
  Returns the configured fields for the action.
  """
  @spec fields(module()) :: [map()] | nil
  def fields(module) do
    Spark.Dsl.Extension.get_entities(module, [:backpex, :fields])
  end
end
