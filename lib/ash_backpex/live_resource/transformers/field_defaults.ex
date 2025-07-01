# defmodule AshBackpex.LiveResource.Transformers.FieldDefaults do
#   alias Spark.Dsl.Transformer
#   use Transformer

#   def transform(dsl_state) do
#     dsl_state
#     |> Transformer.get_entities([:backpex, :fields])
#     |> Enum.map(fn e -> e.__identifier__ end)
#     |> dbg

#     {:ok, dsl_state}
#   end

#   defp set_field_default() do
#   end
# end
