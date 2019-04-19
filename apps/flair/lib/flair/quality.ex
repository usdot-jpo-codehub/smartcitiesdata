defmodule Flair.Quality do
  @moduledoc false

  alias SmartCity.Dataset
  alias SmartCity.Data

  def get_required_fields(dataset_id) do
    Dataset.get!(dataset_id).technical.schema
    |> Enum.map(fn field -> get_sub_required_fields(field, "") end)
    |> List.flatten()
    |> remove_dot()
  end

  defp remove_dot([]), do: []

  defp remove_dot(list) do
    Enum.map(list, fn value -> String.slice(value, 1..(String.length(value) - 1)) end)
  end

  defp get_sub_required_fields(required_field, parent_name) do
    cond do
      Map.get(required_field, :required, false) == false ->
        []

      Map.get(required_field, :subSchema, nil) == nil ->
        [parent_name <> "." <> Map.get(required_field, :name)]

      true ->
        name = parent_name <> "." <> Map.get(required_field, :name)

        sub_field =
          required_field
          |> Map.get(:subSchema)
          |> Enum.map(fn sub_field -> get_sub_required_fields(sub_field, name) end)

        sub_field ++ [name]
    end
  end

  def reducer(%Data{dataset_id: id, version: version, payload: data}, acc) do
    existing_dataset_map = Map.get(acc, id, %{})
    existing_version_map = Map.get(existing_dataset_map, version, %{})

    updated_map =
      id
      |> get_required_fields()
      |> Enum.reduce(existing_version_map, fn field_name, acc ->
        update_field_count(acc, field_name, data)
      end)
      |> Map.update(:record_count, 1, fn value -> value + 1 end)

    Map.put(acc, id, Map.put(existing_dataset_map, version, updated_map))
  end

  defp update_field_count(acc, field_name, data) do
    field_path = String.split(field_name, ".")

    if get_in(data, field_path) != nil do
      Map.update(acc, field_name, 1, fn existing_value -> existing_value + 1 end)
    else
      Map.update(acc, field_name, 0, fn existing_value -> existing_value end)
    end
  end

  def calculate_quality({dataset_id, raw_quality}) do
    calculated_quality =
      raw_quality
      |> Map.keys()
      |> Enum.map(fn version -> explode_version(dataset_id, version, raw_quality) end)
      |> List.flatten()

    {dataset_id, calculated_quality}
  end

  defp explode_version(dataset_id, version, full_map) do
    version_map = Map.get(full_map, version)
    record_count = Map.get(version_map, :record_count)
    fields = Map.get(version_map, :fields)

    fields
    |> Map.keys()
    |> Enum.map(fn key ->
      %{
        dataset_id: dataset_id,
        schema_version: version,
        field: key,
        valid_values: Map.get(fields, key),
        records: record_count
      }
    end)
  end
end
