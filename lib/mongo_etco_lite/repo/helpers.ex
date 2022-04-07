defmodule MongoEctoLite.Repo.Helpers do
  #
  # ref: https://stackoverflow.com/a/39402374
  #
  def flatten(map) when is_map(map) do
    map
    |> to_list_of_tuples
    |> Enum.into(%{})
  end

  defp to_list_of_tuples(m) do
    m
    |> Enum.map(&process/1)
    |> List.flatten()
  end

  defp process({key, sub_map}) when is_map(sub_map) do
    for {sub_key, value} <- sub_map do
      {join(key, sub_key), value}
    end
  end

  defp process({key, value}) do
    {to_string(key), value}
  end

  defp join(a, b) do
    to_string(a) <> "." <> to_string(b)
  end

  #
  # ref: https://stackoverflow.com/a/38865647
  #
  def deep_merge(left, right) do
    Map.merge(left, right, &deep_resolve/3)
  end

  # Key exists in both maps, and both values are maps as well.
  # These can be merged recursively.
  defp deep_resolve(_key, left = %{}, right = %{}) do
    deep_merge(left, right)
  end

  # Key exists in both maps, but at least one of the values is
  # NOT a map. We fall back to standard merge behavior, preferring
  # the value on the right.
  defp deep_resolve(_key, _left, right) do
    right
  end

  #
  # turn embed results into struct
  #
  def struct_embeds!(result, %{__struct__: _schema} = struct) do
    # doing one level, update with recursive calls if needed
    schema = struct.__struct__
    embeds = schema.__schema__(:embeds)

    Enum.reduce(embeds, result, fn item, acc ->
      embed = schema.__schema__(:embed, item)

      old_value = Map.get(result, embed.field)
      new_value = Kernel.struct!(embed.related, old_value)

      Map.replace(acc, embed.field, new_value)
    end)
  end

  def struct_embeds!(result, _struct) do
    # handle dynamic repositories
    result
  end
end
