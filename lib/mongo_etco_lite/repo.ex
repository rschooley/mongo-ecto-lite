defmodule MongoEctoLite.Repo do
  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      # @behaviour MongoEctoLite.Repo

      @default_dynamic_repo opts[:default_dynamic_repo] || __MODULE__

      ## Queryable

      def all(queryable, query \\ %{}, opts \\ []) do
        repo = get_dynamic_repo()
        MongoEctoLite.Repo.Queryable.all(repo, queryable, query, opts)
      end

      def get!(queryable, id, opts \\ []) do
        repo = get_dynamic_repo()
        MongoEctoLite.Repo.Queryable.get!(repo, queryable, id, opts)
      end

      def get_by(queryable, id, opts \\ []) do
        repo = get_dynamic_repo()
        MongoEctoLite.Repo.Queryable.get_by(repo, queryable, id, opts)
      end

      def one(queryable, query \\ %{}, opts \\ []) do
        repo = get_dynamic_repo()
        MongoEctoLite.Repo.Queryable.one(repo, queryable, query, opts)
      end

      def delete_all(queryable, query, opts \\ []) do
        repo = get_dynamic_repo()
        MongoEctoLite.Repo.Queryable.delete_all(repo, queryable, query, opts)
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

      def insert!(changeset) do
        repo = get_dynamic_repo()
        MongoEctoLite.Repo.Schema.insert!(repo, changeset)
      end

      def update(changeset) do
        repo = get_dynamic_repo()
        MongoEctoLite.Repo.Schema.update(repo, changeset)
      end

      @compile {:inline, get_dynamic_repo: 0}

      def get_dynamic_repo() do
        Process.get({__MODULE__, :dynamic_repo}, @default_dynamic_repo)
      end

      def put_dynamic_repo(dynamic) when is_atom(dynamic) or is_pid(dynamic) do
        Process.put({__MODULE__, :dynamic_repo}, dynamic) || @default_dynamic_repo
      end

      def with_dynamic_repo(repo, callback) do
        default_dynamic_repo = get_dynamic_repo()

        try do
          put_dynamic_repo(repo)
          callback.()
        after
          put_dynamic_repo(default_dynamic_repo)
        end
      end
    end
  end

  @callback get_dynamic_repo() :: atom() | pid()
end
