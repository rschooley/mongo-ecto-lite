defmodule MongoEctoLite.Repo.Queryable do
  alias MongoEctoLite.Repo.{Helpers, Metadata}

  def all(repo, queryable, query, opts) do
    collection_name = Metadata.collection_name(queryable)
    struct = Metadata.struct(queryable)

    Mongo.find(repo, collection_name, query, opts)
    |> Enum.to_list()
    |> Enum.map(fn item -> to_atom_keys(item) end)
    |> Enum.map(fn item -> to_struct(queryable, item) end)
    |> Enum.map(fn item -> Helpers.struct_embeds!(item, struct) end)
  end

  def get!(repo, queryable, id, opts) do
    case all(repo, queryable, %{_id: id}, opts) do
      [one] -> one
      [] -> raise Ecto.NoResultsError, queryable: queryable
      other -> raise Ecto.MultipleResultsError, queryable: queryable, count: length(other)
    end
  end

  def get_by(repo, queryable, query, opts) do
    one(repo, queryable, query, opts)
  end

  def one(repo, queryable, query, opts) do
    case all(repo, queryable, query, opts) do
      [one] -> one
      [] -> nil
      other -> raise Ecto.MultipleResultsError, queryable: queryable, count: length(other)
    end
  end

  def delete_all(repo, queryable, query, opts) do
    collection_name = Metadata.collection_name(queryable)

    case Mongo.delete_many(repo, collection_name, query, opts) do
      {:ok, _} ->
        :ok

      {:error, err} ->
        {:error, err}
    end
  end

  defp to_struct(struct, item) when is_atom(struct) do
    Kernel.struct(struct, item)
  end

  defp to_struct(struct, item) do
    # for schemaless queries
    Map.put(item, :__meta__, struct.__meta__)
  end

  defp to_atom_keys(map) when is_map(map) do
    Map.new(map, &to_atom_keys/1)
  end

  defp to_atom_keys({k, %BSON.ObjectId{} = v}) do
    {String.to_existing_atom(k), v}
  end

  defp to_atom_keys({k, v}) when is_list(v) do
    {String.to_existing_atom(k), Enum.map(v, fn item -> to_atom_keys(item) end)}
  end

  defp to_atom_keys({k, %{} = v}) do
    {String.to_existing_atom(k), to_atom_keys(v)}
  end

  defp to_atom_keys({k, v}) do
    {String.to_existing_atom(k), v}
  end
end
