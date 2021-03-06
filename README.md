# MongoEctoLite

Note: this library is experimental and not ready for production use.

The goal is to tranparently use Ecto Changesets with MongoDB.

Built on top of [mongodb_driver](https://hexdocs.pm/mongodb_driver/readme.html).

Currently supports basic schemas, `embeds_one`, `embeds_many`, schemaless, and dynamic repositories.

Not all functions from Ecto are implemented.  Functions generated by `mix phx.gen`,
including `mix.gen.auth`, are currently covered.  Please note implementations may be naive
when compared to their Ecto counterparts.

Additionally, Ecto style queries are not supported.  Repo functions take an additional
mongodb style query arg when needed.

## Examples:

Please see the test dir for full examples.

```elixir
  defmodule DiscoveryReadStore.Repo do
    # same name supplied to the Mongo driver in application.ex
    # see https://hexdocs.pm/mongodb_driver/readme.html for more information on configuation
    use MongoEctoLite.Repo,
      default_dynamic_repo: :mongo
  end

  defmodule MyCollection do
    use Ecto.Schema
    import Ecto.Changeset

    # note autogenerate does not do anything but is required
    #  manually set one or mongo will add one automatically
    @primary_key {:_id, :binary_id, autogenerate: false}
    schema "my_collection" do
      field(:name, :string)
      field(:child, :map)

      timestamps()
    end

    def changeset(item, attrs) do
      item
      |> cast(attrs, [:name, :child])
      |> validate_required([:name, :child])
    end
  end

  attrs = %{name: "some name", child: %{name: "some child name"}}

  {:ok, my_collection} =
    %MyCollection{}
    |> MyCollection.changeset(attrs)
    |> Repo.insert()

  results = Repo.all(Schema, %{name: "some name"})
```

## Installation

The lib is not currently on hex / hexdocs.
