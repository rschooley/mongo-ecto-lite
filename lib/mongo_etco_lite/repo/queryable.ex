defmodule MongoEctoLite.Repo.Queryable do
  alias MongoEctoLite.Repo.Helpers

  def find(repo, queryable, query, opts \\ []) do
    collection_name = queryable.__schema__(:source)
    struct = queryable.__struct__

    Mongo.find(repo, collection_name, query, opts)
    |> Enum.to_list()
    |> Enum.map(fn item -> string_keyed_map_to_struct(item, queryable) end)
    |> Enum.map(fn item -> Helpers.struct_embeds!(item, struct) end)
  end

  def get!(repo, queryable, id, opts \\ []) do
    case find(repo, queryable, %{_id: id}, opts) do
      [one] -> one
      [] -> raise Ecto.NoResultsError, queryable: queryable
      other -> raise Ecto.MultipleResultsError, queryable: queryable, count: length(other)
    end
  end

  defp string_keyed_map_to_struct(map, struct) do
    Kernel.struct(struct, to_atom_keys(map))
  end

  defp to_atom_keys(map) when is_map(map) do
    Map.new(map, &to_atom_keys/1)
  end

  defp to_atom_keys({k, %BSON.ObjectId{} = v}) do
    {String.to_existing_atom(k), v}
  end

  defp to_atom_keys({k, %{} = v}) do
    {String.to_existing_atom(k), to_atom_keys(v)}
  end

  defp to_atom_keys({k, v}) do
    {String.to_existing_atom(k), v}
  end
end