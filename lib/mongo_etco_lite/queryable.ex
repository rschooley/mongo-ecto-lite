defimpl Ecto.Queryable, for: Map do
  # supports Ecto.NoResultsError, queryable: queryable for get! on schemaless queries
  def to_query(_query) do
    %{
      assocs: [],
      combinations: [],
      distinct: nil,
      from: nil,
      group_bys: [],
      havings: [],
      joins: [],
      limit: nil,
      lock: nil,
      offset: nil,
      order_bys: [],
      preloads: [],
      select: nil,
      updates: [],
      wheres: [],
      windows: []
    }
  end
end