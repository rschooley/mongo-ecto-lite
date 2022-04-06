defmodule MongoEctoLite.Repo.Schema do
  alias Ecto.Changeset
  alias MongoEctoLite.Repo.Helpers

  def insert(repo, %Changeset{} = changeset) do
    do_insert(repo, changeset)
  end

  defp do_insert(repo, %Changeset{valid?: true} = changeset) do
    struct = struct_from_changeset!(:insert, changeset)
    collection_name = collection_name_from_changeset!(changeset)

    changes =
      changeset
      |> do_changes()
      |> Map.merge(%{inserted_at: timestamp(), updated_at: timestamp()})

    case Mongo.insert_one(repo, collection_name, changes) do
      {:ok, %{inserted_id: inserted_id}} ->
        # TODO: pull @primary_key from Schema
        changes_with_id = Map.put(changes, :_id, inserted_id)

        result =
          changeset
          |> load_changes(changes_with_id)
          |> Helpers.struct_embeds!(struct)

        {:ok, result}

      {:error, err} ->
        {:error, err}
    end
  end

  defp do_insert(_repo, %Changeset{valid?: false} = changeset) do
    {:error, changeset}
  end

  def update(repo, %Changeset{} = changeset) do
    do_update(repo, changeset)
  end

  defp do_update(repo, %Changeset{valid?: true} = changeset) do
    collection_name = collection_name_from_changeset!(changeset)

    changes =
      changeset
      |> do_changes()
      |> Map.merge(%{updated_at: timestamp()})

    flattened_changes = Helpers.flatten(changes)

    # TODO: pull @primary_key from Schema
    id = Map.fetch!(changeset.data, :_id)

    case Mongo.update_one(repo, collection_name, %{_id: id}, %{"$set": flattened_changes}) do
      {:ok, _} ->
        {:ok, load_changes(changeset, changes)}

      {:error, err} ->
        {:error, err}
    end
  end

  defp do_update(_repo, %Changeset{valid?: false} = changeset) do
    {:error, changeset}
  end

  def delete(repo, %{__struct__: _} = struct) do
    do_delete(repo, Ecto.Changeset.change(struct))
  end

  defp do_delete(repo, %Changeset{valid?: true} = changeset) do
    collection_struct = struct_from_changeset!(:insert, changeset)
    collection_name = collection_name_from_changeset!(changeset)

    id = Map.fetch!(changeset.data, :_id)

    {:ok, _} = Mongo.delete_one(repo, collection_name, %{_id: id})
    {:ok, collection_struct}
  end

  defp do_delete(repo, %Changeset{valid?: false} = changeset) do
    {:error, changeset}
  end

  defp struct_from_changeset!(action, %{data: nil}),
    do: raise(ArgumentError, "cannot #{action} a changeset without :data")

  defp struct_from_changeset!(_action, %{data: struct}), do: struct

  defp collection_name_from_changeset!(changeset) do
    Map.fetch!(changeset.data.__meta__, :source)
  end

  defp load_changes(changeset, changes) do
    %{data: data} = changeset

    Helpers.deep_merge(data, changes)
  end

  #
  # Get changeset changes recursively
  #  Supports embeds_one
  #
  defp do_changes(%Changeset{} = changeset) do
    Enum.reduce(changeset.changes, %{}, &do_changes/2)
  end

  defp do_changes({k, %Changeset{} = v}, acc) do
    Map.put(acc, k, do_changes(v))
  end

  defp do_changes({k, v}, acc) do
    Map.put(acc, k, v)
  end

  defp timestamp() do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end
end
