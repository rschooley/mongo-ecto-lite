defmodule MongoEctoLite.Repo.SchemaTest do
  use ExUnit.Case

  @database "mongo_ecto_lite_test"
  @pool_size 10
  @auth_source "admin"
  @username "root"
  @password "example"

  alias MongoEctoLite.Repo

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

  describe "basic schema" do
    alias BasicSchema, as: Schema

    setup do
      conn_opts = [
        name: MongoEctoLite.Repo,
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
      attrs = Enum.into(attrs, %{
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
      fixture = basic_schema_fixture(%{child: %{name: "some child name", other: "some other field"}})
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
        name: MongoEctoLite.Repo,
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
      attrs = Enum.into(attrs, %{
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
      valid_attrs = %{name: "some name", child: %{name: "some child name", other: "some child other"}}

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
      update_attrs = %{name: "some updated name", child: %{name: "some updated child name", other: "some updated child other"}}

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

  describe "dynamic repositories" do
    alias MongoEctoLite.Repo
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
