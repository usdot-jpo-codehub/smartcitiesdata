defmodule Flair.PrestoClient do
  @table_name "operational_stats_3"

  def get_create_table_statement do
    """
    CREATE TABLE IF NOT EXISTS #{@table_name} (
      dataset_id varchar,
      app varchar,
      label varchar,
      timestamp bigint,
      stats row(
        count bigint,
        min double,
        max double,
        std double,
        average double
      )
    )
    """
  end

  def create_insert_statement(values_statement) do
    "INSERT INTO #{@table_name} VALUES #{values_statement}"
  end

  def values_statement(map) do
    """
    ('#{map.dataset_id}', '#{map.app}','#{map.label}', #{DateTime.utc_now() |> DateTime.to_unix()},
        row(#{map.count},#{map.min},#{map.max},#{map.stdev},#{map.average}))
    """
    |> String.replace("\n", "")
  end

  def execute(statement) do
    statement
    |> Prestige.execute()
    |> Prestige.prefetch()
  end
end
