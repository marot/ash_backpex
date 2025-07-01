defmodule AshBackpex.LiveResource do
  use Spark.Dsl,
    default_extensions: [
      extensions: [AshBackpex.LiveResource.Dsl]
    ]
end
