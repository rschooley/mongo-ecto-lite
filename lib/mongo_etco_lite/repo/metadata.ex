defprotocol MongoEctoLite.Repo.Metadata do
  def collection_name(value)
  def struct(value)
end

defimpl MongoEctoLite.Repo.Metadata, for: Atom do
  # TODO: error handling like
  #  https://github.com/elixir-ecto/ecto/blob/master/lib/ecto/queryable.ex#L13
  def collection_name(module), do: module.__schema__(:source)
  def struct(module), do: module.__struct__
end

defimpl MongoEctoLite.Repo.Metadata, for: Map do
  def collection_name(map), do: map.__meta__.source
  def struct(_map), do: nil
end
