defmodule MongoEctoLite.Repo.SchemaTest do
  use ExUnit.Case

  @database "mongo_ecto_lite_test"
  @pool_size 10
  @auth_source "admin"
  @username "root"
  @password "example"

  defmodule Repo do
    use MongoEctoLite.Repo,
      default_dynamic_repo: :mongo
  end

  defmodule BasicSchema do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:_id, :binary_id, autogenerate: true}
    schema "basic_schema" do
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

  defmodule EmbedsOneSchema do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:_id, :binary_id, autogenerate: true}
    schema "embeds_one_schema" do
      field(:name, :string)

      embeds_one :child, Child, on_replace: :update, primary_key: false do
        field(:name, :string)
        field(:other, :string)
      end

      timestamps()
    end

    def changeset(item, attrs) do
      item
      |> cast(attrs, [:name])
      |> cast_embed(:child, with: &child_changeset/2)
      |> validate_required([:name])
    end

    defp child_changeset(schema, attrs) do
      schema
      |> cast(attrs, [:name, :other])
      |> validate_required([:name, :other])
    end
  end

  defmodule EmbedsManySchema do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:_id, :binary_id, autogenerate: true}
    schema "embeds_many_schema" do
      field(:name, :string)

      embeds_many :child, Child, primary_key: false, on_replace: :delete do
        field(:name, :string)
        field(:other, :string)
      end

      timestamps()
    end

    def changeset(item, attrs) do
      item
      |> cast(attrs, [:name])
      |> cast_embed(:child, with: &child_changeset/2)
      |> validate_required([:name])
    end

    def child_changeset(field, attrs) do
      field
      |> cast(attrs, [:name, :other])
      |> validate_required([:name, :other])
    end
  end

  describe "basic schema" do
    alias BasicSchema, as: Schema

    setup do
      conn_opts = [
        name: :mongo,
        database: @database,
        pool_size: @pool_size,
        auth_source: @auth_source,
        username: @username,
        password: @password
      ]

      {:ok, _conn} = Mongo.start_link(conn_opts)

      on_exit(fn ->
        opts = Keyword.drop(conn_opts, [:name])
        {:ok, cleanup} = Mongo.start_link(opts)
        Mongo.drop_collection(cleanup, "basic_schema")
      end)

      :ok
    end

    def basic_schema_fixture(attrs \\ %{}) do
      attrs =
        Enum.into(attrs, %{
          name: "some name",
          child: %{
            name: "some child name"
          }
        })

      {:ok, record} =
        %Schema{}
        |> Schema.changeset(attrs)
        |> Repo.insert()

      record
    end

    @invalid_attrs %{name: nil, child: nil}

    test "all/2 returns all records" do
      fixture = basic_schema_fixture()
      assert Repo.all(Schema) == [fixture]
    end

    test "all/2 with query returns matching record(s)" do
      _fixture = basic_schema_fixture()
      other_fixture = basic_schema_fixture(%{name: "some other name"})

      assert Repo.all(Schema, %{name: "some other name"}) == [other_fixture]
    end

    test "get!/2 returns the record with given id" do
      fixture = basic_schema_fixture()
      assert Repo.get!(Schema, fixture._id) == fixture
    end

    test "insert/1 with valid changeset" do
      valid_attrs = %{name: "some name", child: %{name: "some child name"}}

      assert {:ok, %Schema{} = inserted} =
               %Schema{}
               |> Schema.changeset(valid_attrs)
               |> Repo.insert()

      assert inserted._id
      assert inserted.name == valid_attrs.name
      assert inserted.child.name == valid_attrs.child.name

      assert queried = Repo.get!(Schema, inserted._id)
      assert queried._id == inserted._id
      assert queried.name == inserted.name
      assert queried.child.name == inserted.child.name
    end

    test "insert/1 with invalid changeset returns error changeset" do
      changeset = Schema.changeset(%Schema{}, @invalid_attrs)

      assert {:error, %Ecto.Changeset{}} = Repo.insert(changeset)
    end

    test "update/1 with valid changeset" do
      fixture = basic_schema_fixture()
      update_attrs = %{name: "some updated name", child: %{name: "some updated child name"}}

      assert {:ok, %Schema{} = updated} =
               fixture
               |> Schema.changeset(update_attrs)
               |> Repo.update()

      assert updated._id == fixture._id
      assert updated.updated_at != fixture.updated_at
      assert updated.child.name == update_attrs.child.name

      assert queried = Repo.get!(Schema, fixture._id)
      assert queried._id == fixture._id
      assert queried.name == update_attrs.name
      assert queried.child.name == update_attrs.child.name
    end

    test "update/1 with valid changeset for partial child" do
      fixture =
        basic_schema_fixture(%{child: %{name: "some child name", other: "some other field"}})

      update_attrs = %{name: "some updated name", child: %{name: "some updated child name"}}

      assert {:ok, %Schema{} = updated} =
               fixture
               |> Schema.changeset(update_attrs)
               |> Repo.update()

      assert updated._id == fixture._id
      assert updated.child.name == update_attrs.child.name
      assert updated.child.other == fixture.child.other

      assert queried = Repo.get!(Schema, fixture._id)
      assert queried._id == fixture._id
      assert queried.updated_at > fixture.updated_at
      assert queried.name == update_attrs.name
      assert queried.child.name == update_attrs.child.name
      assert queried.child.other == fixture.child.other
    end

    test "update/1 with invalid changeset returns error changeset" do
      fixture = basic_schema_fixture()

      assert {:error, %Ecto.Changeset{}} =
               fixture
               |> Schema.changeset(@invalid_attrs)
               |> Repo.update()
    end

    test "delete/1 deletes the record" do
      fixture = basic_schema_fixture()

      assert {:ok, %Schema{}} = Repo.delete(fixture)
      assert_raise Ecto.NoResultsError, fn -> Repo.get!(Schema, fixture._id) end
    end
  end

  describe "embeds one schema" do
    alias EmbedsOneSchema, as: Schema

    setup do
      conn_opts = [
        name: :mongo,
        database: @database,
        pool_size: @pool_size,
        auth_source: @auth_source,
        username: @username,
        password: @password
      ]

      {:ok, _conn} = Mongo.start_link(conn_opts)

      on_exit(fn ->
        opts = Keyword.drop(conn_opts, [:name])
        {:ok, cleanup} = Mongo.start_link(opts)
        Mongo.drop_collection(cleanup, "embeds_one_schema")
      end)

      :ok
    end

    def embeds_one_schema_fixture(attrs \\ %{}) do
      attrs =
        Enum.into(attrs, %{
          name: "some name",
          child: %{
            name: "some child name",
            other: "some child other"
          }
        })

      {:ok, record} =
        %Schema{}
        |> Schema.changeset(attrs)
        |> Repo.insert()

      record
    end

    @invalid_attrs %{name: nil, child: nil}

    test "all/2 returns all records" do
      fixture = embeds_one_schema_fixture()
      assert Repo.all(Schema) == [fixture]
    end

    test "all/2 with query returns matching record(s)" do
      _fixture = embeds_one_schema_fixture()
      other_fixture = embeds_one_schema_fixture(%{name: "some other name"})

      assert Repo.all(Schema, %{name: "some other name"}) == [other_fixture]
    end

    test "get!/2 returns the record with given id" do
      fixture = embeds_one_schema_fixture()
      assert Repo.get!(Schema, fixture._id) == fixture
    end

    test "insert/1 with valid changeset" do
      valid_attrs = %{
        name: "some name",
        child: %{name: "some child name", other: "some child other"}
      }

      assert {:ok, %Schema{} = inserted} =
               %Schema{}
               |> Schema.changeset(valid_attrs)
               |> Repo.insert()

      assert inserted._id
      assert inserted.name == valid_attrs.name
      assert inserted.child.name == valid_attrs.child.name
      assert inserted.child.other == valid_attrs.child.other

      assert queried = Repo.get!(Schema, inserted._id)
      assert queried._id == inserted._id
      assert queried.name == inserted.name
      assert queried.child.name == inserted.child.name
      assert queried.child.other == inserted.child.other
    end

    test "insert/1 with invalid changeset returns error changeset" do
      changeset = Schema.changeset(%Schema{}, @invalid_attrs)

      assert {:error, %Ecto.Changeset{}} = Repo.insert(changeset)
    end

    test "update/1 with valid changeset" do
      fixture = embeds_one_schema_fixture()

      update_attrs = %{
        name: "some updated name",
        child: %{name: "some updated child name", other: "some updated child other"}
      }

      assert {:ok, %Schema{} = updated} =
               fixture
               |> Schema.changeset(update_attrs)
               |> Repo.update()

      assert updated._id == fixture._id
      assert updated.updated_at > fixture.updated_at
      assert updated.child.name == update_attrs.child.name
      assert updated.child.other == update_attrs.child.other

      assert queried = Repo.get!(Schema, fixture._id)
      assert queried._id == fixture._id
      assert queried.updated_at > fixture.updated_at
      assert queried.name == update_attrs.name
      assert queried.child.name == update_attrs.child.name
      assert queried.child.other == update_attrs.child.other
    end

    test "update/1 with valid changeset for partial child" do
      fixture = embeds_one_schema_fixture()
      update_attrs = %{name: "some updated name", child: %{name: "some updated child name"}}

      assert {:ok, %Schema{} = updated} =
               fixture
               |> Schema.changeset(update_attrs)
               |> Repo.update()

      assert updated._id == fixture._id
      assert updated.updated_at > fixture.updated_at
      assert updated.name == update_attrs.name
      assert updated.child.name == update_attrs.child.name
      assert updated.child.other == fixture.child.other

      assert queried = Repo.get!(Schema, fixture._id)
      assert queried._id == fixture._id
      assert queried.updated_at > fixture.updated_at
      assert queried.name == update_attrs.name
      assert queried.child.name == update_attrs.child.name
      assert queried.child.other == fixture.child.other
    end

    test "update/1 with invalid changeset returns error changeset" do
      fixture = embeds_one_schema_fixture()

      assert {:error, %Ecto.Changeset{}} =
               fixture
               |> Schema.changeset(@invalid_attrs)
               |> Repo.update()
    end

    test "delete/1 deletes the record" do
      fixture = embeds_one_schema_fixture()

      assert {:ok, %Schema{}} = Repo.delete(fixture)
      assert_raise Ecto.NoResultsError, fn -> Repo.get!(Schema, fixture._id) end
    end
  end

  describe "embeds many schema" do
    alias EmbedsManySchema, as: Schema

    setup do
      conn_opts = [
        name: :mongo,
        database: @database,
        pool_size: @pool_size,
        auth_source: @auth_source,
        username: @username,
        password: @password
      ]

      {:ok, _conn} = Mongo.start_link(conn_opts)

      on_exit(fn ->
        opts = Keyword.drop(conn_opts, [:name])
        {:ok, cleanup} = Mongo.start_link(opts)
        Mongo.drop_collection(cleanup, "embeds_many_schema")
      end)

      :ok
    end

    def embeds_many_schema_fixture(attrs \\ %{}) do
      attrs =
        Enum.into(attrs, %{
          name: "some name",
          child: [
            %{
              name: "some child name",
              other: "some child other"
            }
          ]
        })

      {:ok, record} =
        %Schema{}
        |> Schema.changeset(attrs)
        |> Repo.insert()

      record
    end

    @invalid_attrs %{name: nil, child: nil}

    test "all/2 returns all records" do
      fixture = embeds_many_schema_fixture()
      assert Repo.all(Schema) == [fixture]
    end

    test "all/2 with query returns matching record(s)" do
      _fixture = embeds_many_schema_fixture()
      other_fixture = embeds_many_schema_fixture(%{name: "some other name"})

      assert Repo.all(Schema, %{name: "some other name"}) == [other_fixture]
    end

    test "get!/2 returns the record with given id" do
      fixture = embeds_many_schema_fixture()
      assert Repo.get!(Schema, fixture._id) == fixture
    end

    test "insert/1 with valid changeset" do
      valid_attrs = %{
        name: "some name",
        child: [%{name: "some child name", other: "some child other"}]
      }

      assert {:ok, %Schema{} = inserted} =
               %Schema{}
               |> Schema.changeset(valid_attrs)
               |> Repo.insert()

      assert inserted._id
      assert inserted.name == valid_attrs.name
      assert hd(inserted.child).name == hd(valid_attrs.child).name
      assert hd(inserted.child).other == hd(valid_attrs.child).other

      assert queried = Repo.get!(Schema, inserted._id)
      assert queried._id == inserted._id
      assert queried.name == inserted.name
      assert hd(queried.child).name == hd(inserted.child).name
      assert hd(queried.child).other == hd(inserted.child).other
    end

    test "insert/1 with invalid changeset returns error changeset" do
      changeset = Schema.changeset(%Schema{}, @invalid_attrs)

      assert {:error, %Ecto.Changeset{}} = Repo.insert(changeset)
    end

    test "update/1 with valid changeset" do
      fixture = embeds_many_schema_fixture()

      update_attrs = %{
        name: "some updated name",
        child: [%{name: "some updated child name", other: "some updated child other"}]
      }

      assert {:ok, %Schema{} = updated} =
               fixture
               |> Schema.changeset(update_attrs)
               |> Repo.update()

      assert updated._id == fixture._id
      assert updated.updated_at > fixture.updated_at
      assert hd(updated.child).name == hd(update_attrs.child).name
      assert hd(updated.child).other == hd(update_attrs.child).other

      assert queried = Repo.get!(Schema, fixture._id)
      assert queried._id == fixture._id
      assert queried.updated_at > fixture.updated_at
      assert queried.name == update_attrs.name
      assert hd(queried.child).name == hd(update_attrs.child).name
      assert hd(queried.child).other == hd(update_attrs.child).other
    end

    test "update/1 children with valid changeset" do
      fixture = embeds_many_schema_fixture()

      update_attrs = %{
        name: "some updated name",
        child: [
          %{name: "some child name", other: "some other 1"},
          %{name: "item 2", other: "some other 2"}
        ]
      }

      assert {:ok, %Schema{} = updated} =
               fixture
               |> Schema.changeset(update_attrs)
               |> IO.inspect()
               |> Repo.update()

      assert updated._id == fixture._id
      assert updated.updated_at > fixture.updated_at

      update_attrs.child |> Enum.with_index |> Enum.each(fn {item, index} ->
        assert Enum.at(updated.child, index).name == item.name
        assert Enum.at(updated.child, index).other == item.other
      end)

      assert queried = Repo.get!(Schema, fixture._id)
      assert queried._id == fixture._id
      assert queried.updated_at > fixture.updated_at

      update_attrs.child |> Enum.with_index |> Enum.each(fn {item, index} ->
        assert Enum.at(queried.child, index).name == item.name
        assert Enum.at(queried.child, index).other == item.other
      end)
    end

    test "update/1 with invalid changeset returns error changeset" do
      fixture = embeds_many_schema_fixture()

      assert {:error, %Ecto.Changeset{}} =
               fixture
               |> Schema.changeset(@invalid_attrs)
               |> Repo.update()
    end

    test "delete/1 deletes the record" do
      fixture = embeds_many_schema_fixture()

      assert {:ok, %Schema{}} = Repo.delete(fixture)
      assert_raise Ecto.NoResultsError, fn -> Repo.get!(Schema, fixture._id) end
    end
  end

  describe "schemaless changesets" do
    @collection "schemaless"
    @types %{name: :string, child: :map}
    @data %{__meta__: %{source: @collection}}

    setup do
      conn_opts = [
        name: :mongo,
        database: @database,
        pool_size: @pool_size,
        auth_source: @auth_source,
        username: @username,
        password: @password
      ]

      {:ok, _conn} = Mongo.start_link(conn_opts)

      on_exit(fn ->
        opts = Keyword.drop(conn_opts, [:name])
        {:ok, cleanup} = Mongo.start_link(opts)
        Mongo.drop_collection(cleanup, @collection)
      end)

      :ok
    end

    def schemaless_fixture(attrs \\ %{}) do
      attrs =
        Enum.into(attrs, %{
          name: "some name",
          child: %{
            name: "some child name"
          }
        })

      changeset =
        {%{__meta__: %{source: @collection}}, @types}
        |> Ecto.Changeset.cast(attrs, Map.keys(@types))

      {:ok, record} = Repo.insert(changeset)

      record
    end

    @invalid_attrs %{name: nil, child: nil}

    test "all/2 returns all records" do
      fixture = schemaless_fixture()
      assert Repo.all(@data) == [fixture]
    end

    test "all/2 with query returns matching record(s)" do
      _fixture = schemaless_fixture()
      other_fixture = schemaless_fixture(%{name: "some other name"})

      assert Repo.all(@data, %{name: "some other name"}) == [other_fixture]
    end

    test "get!/2 returns the record with given id" do
      fixture = schemaless_fixture()
      assert Repo.get!(@data, fixture._id) == fixture
    end

    test "insert/1 with valid changeset" do
      valid_attrs = %{name: "some name", child: %{name: "some child name"}}

      changeset =
        {@data, @types}
        |> Ecto.Changeset.cast(valid_attrs, Map.keys(@types))

      assert {:ok, %{} = inserted} = Repo.insert(changeset)

      assert inserted._id
      assert inserted.name == valid_attrs.name
      assert inserted.child.name == valid_attrs.child.name

      assert queried = Repo.get!(@data, inserted._id)
      assert queried._id == inserted._id
      assert queried.name == inserted.name
      assert queried.child.name == inserted.child.name
    end

    test "insert/1 with invalid changeset returns error changeset" do
      changeset =
        {@data, @types}
        |> Ecto.Changeset.cast(@invalid_attrs, Map.keys(@types))
        |> Ecto.Changeset.validate_required([:name, :child])

      assert {:error, %Ecto.Changeset{}} = Repo.insert(changeset)
    end

    test "update/1 with valid changeset" do
      fixture = schemaless_fixture()
      update_attrs = %{name: "some updated name", child: %{name: "some updated child name"}}
      data = Map.merge(fixture, @data)

      changeset =
        {data, @types}
        |> Ecto.Changeset.cast(update_attrs, Map.keys(@types))

      assert {:ok, %{} = updated} = Repo.update(changeset)

      assert updated._id == fixture._id
      assert updated.updated_at != fixture.updated_at
      assert updated.child.name == update_attrs.child.name

      assert queried = Repo.get!(@data, fixture._id)
      assert queried._id == fixture._id
      assert queried.name == update_attrs.name
      assert queried.child.name == update_attrs.child.name
    end

    test "update/1 with valid changeset for partial child" do
      fixture =
        schemaless_fixture(%{child: %{name: "some child name", other: "some other field"}})

      update_attrs = %{name: "some updated name", child: %{name: "some updated child name"}}
      data = Map.merge(fixture, @data)

      changeset =
        {data, @types}
        |> Ecto.Changeset.cast(update_attrs, Map.keys(@types))

      assert {:ok, %{} = updated} = Repo.update(changeset)

      assert updated._id == fixture._id
      assert updated.child.name == update_attrs.child.name
      assert updated.child.other == fixture.child.other

      assert queried = Repo.get!(@data, fixture._id)
      assert queried._id == fixture._id
      assert queried.updated_at > fixture.updated_at
      assert queried.name == update_attrs.name
      assert queried.child.name == update_attrs.child.name
      assert queried.child.other == fixture.child.other
    end

    test "update/1 with invalid changeset returns error changeset" do
      fixture = schemaless_fixture()
      data = Map.merge(fixture, @data)

      changeset =
        {data, @types}
        |> Ecto.Changeset.cast(@invalid_attrs, Map.keys(@types))
        |> Ecto.Changeset.validate_required([:name, :child])

      assert {:error, %Ecto.Changeset{}} = Repo.update(changeset)
    end

    test "delete/1 deletes the record" do
      fixture = schemaless_fixture()
      data = Map.merge(fixture, @data)

      changeset =
        {data, @types}
        |> Ecto.Changeset.change()

      assert {:ok, %{}} = Repo.delete(changeset)
      assert_raise Ecto.NoResultsError, fn -> Repo.get!(@data, fixture._id) end
    end
  end

  describe "dynamic repositories" do
    alias BasicSchema, as: Schema

    setup do
      conn_opts = [
        pool_size: @pool_size,
        auth_source: @auth_source,
        username: @username,
        password: @password
      ]

      conn_opts_1 = Keyword.put(conn_opts, :database, "mongo_ecto_lite_test_tenant_1")
      conn_opts_2 = Keyword.put(conn_opts, :database, "mongo_ecto_lite_test_tenant_2")

      {:ok, conn_1} = Mongo.start_link(conn_opts_1)
      {:ok, conn_2} = Mongo.start_link(conn_opts_2)

      on_exit(fn ->
        {:ok, cleanup_1} = Mongo.start_link(conn_opts_1)
        {:ok, cleanup_2} = Mongo.start_link(conn_opts_2)

        Mongo.drop_collection(cleanup_1, "basic_schema")
        Mongo.drop_collection(cleanup_2, "basic_schema")
      end)

      {:ok, %{conn_1: conn_1, conn_2: conn_2}}
    end

    test "with_dynamic_repo/2 calls separate databases", %{conn_1: conn_1, conn_2: conn_2} do
      item_1 = %{name: "name 1", child: %{name: "child 1"}}
      item_2 = %{name: "name 2", child: %{name: "child 2"}}

      Repo.with_dynamic_repo(conn_1, fn ->
        assert {:ok, _} =
                 %Schema{}
                 |> Schema.changeset(item_1)
                 |> Repo.insert()
      end)

      Repo.with_dynamic_repo(conn_2, fn ->
        assert {:ok, _} =
                 %Schema{}
                 |> Schema.changeset(item_2)
                 |> Repo.insert()
      end)

      Repo.with_dynamic_repo(conn_1, fn ->
        [item] = Repo.all(Schema)

        assert item.name == item_1.name
        assert item.child.name == item_1.child.name
      end)

      Repo.with_dynamic_repo(conn_2, fn ->
        [item] = Repo.all(Schema)

        assert item.name == item_2.name
        assert item.child.name == item_2.child.name
      end)
    end
  end
end
