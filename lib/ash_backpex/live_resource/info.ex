defmodule AshBackpex.LiveResource.Info do
  use Spark.InfoGenerator, extension: AshBackpex.LiveResource.Dsl, sections: [:backpex]
end
