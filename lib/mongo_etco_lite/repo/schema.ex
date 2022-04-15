defmodule MongoEctoLite.Repo.Schema do
  alias Ecto.Changeset
  alias MongoEctoLite.Repo.Helpers

  def insert!(repo, struct_or_changeset) do
    case insert(repo, struct_or_changeset) do
      {:ok, struct} ->
        struct

      {:error, %Ecto.Changeset{} = changeset} ->
        raise Ecto.InvalidChangesetError, action: :insert, changeset: changeset
    end
  end

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
    {:error, put_action(changeset, :insert)}
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

  def delete(repo, %Changeset{} = changeset) do
    do_delete(repo, changeset)
  end

  def delete(repo, %{__struct__: _} = struct) do
    do_delete(repo, Ecto.Changeset.change(struct))
  end

  defp do_delete(repo, %Changeset{valid?: true} = changeset) do
    collection_struct = struct_from_changeset!(:insert, changeset)
    collection_name = collection_name_from_changeset!(changeset)

    # TODO: pull @primary_key from Schema
    id = Map.fetch!(changeset.data, :_id)

    case Mongo.delete_one(repo, collection_name, %{_id: id}) do
      {:ok, _} ->
        {:ok, collection_struct}

      {:error, err} ->
        {:error, err}
    end
  end

  defp do_delete(_repo, %Changeset{valid?: false} = changeset) do
    {:error, changeset}
  end

  defp put_action(changeset, action),
    do: %{changeset | action: action}

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

  defp do_changes({k, v}, acc) when is_list(v) do
    child_changeset_changes = Enum.map(v, fn child_changeset -> child_changeset.changes end)

    # TODO:
    # Ecto changesets for embeds_many without primary keys and on_replace: :delete
    # leaves empty maps in the list
    # this could be a desired input for some use cases, need to revisit
    # https://hexdocs.pm/ecto/Ecto.Schema.html#embeds_many/3
    child_changeset_changes = Enum.filter(child_changeset_changes, fn item -> item != %{} end)

    Map.put(acc, k, child_changeset_changes)
  end

  defp do_changes({k, v}, acc) do
    Map.put(acc, k, v)
  end

  defp timestamp() do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end
end
