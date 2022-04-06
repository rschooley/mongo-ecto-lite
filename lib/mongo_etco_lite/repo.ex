defmodule MongoEctoLite.Repo do
  ## Queryable

  def all(queryable, query \\ %{}, opts \\ []) do
    repo = get_dynamic_repo()
    MongoEctoLite.Repo.Queryable.find(repo, queryable, query, opts)
  end

  def get!(queryable, id) do
    repo = get_dynamic_repo()
    MongoEctoLite.Repo.Queryable.get!(repo, queryable, id)
  end

  ## Schemas

  def delete(struct) do
    repo = get_dynamic_repo()
    MongoEctoLite.Repo.Schema.delete(repo, struct)
  end

  def insert(changeset) do
    repo = get_dynamic_repo()
    MongoEctoLite.Repo.Schema.insert(repo, changeset)
  end

  def update(changeset) do
    repo = get_dynamic_repo()
    MongoEctoLite.Repo.Schema.update(repo, changeset)
  end

  @compile {:inline, get_dynamic_repo: 0}

  def get_dynamic_repo() do
    Process.get({__MODULE__, :dynamic_repo}, __MODULE__)
  end

  def put_dynamic_repo(dynamic) when is_atom(dynamic) or is_pid(dynamic) do
    Process.put({__MODULE__, :dynamic_repo}, dynamic) || __MODULE__
  end

  def with_dynamic_repo(repo, callback) do
    default_dynamic_repo = get_dynamic_repo()

    try do
      MongoEctoLite.Repo.put_dynamic_repo(repo)
      callback.()
    after
      MongoEctoLite.Repo.put_dynamic_repo(default_dynamic_repo)
    end
  end
end
