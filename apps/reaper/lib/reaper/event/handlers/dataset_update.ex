defmodule Reaper.Event.Handlers.DatasetUpdate do
  @moduledoc false
  require Logger

  import SmartCity.Event, only: [data_extract_start: 0, file_ingest_start: 0]

  alias Quantum.Job
  alias Reaper.Collections.Extractions

  def handle(%SmartCity.Dataset{technical: %{cadence: "never"}}) do
    :ok
  end

  def handle(%SmartCity.Dataset{technical: %{cadence: "once"}} = dataset) do
    case Extractions.get_last_fetched_timestamp!(dataset.id) do
      nil -> Brook.Event.send(determine_event(dataset), :reaper, dataset)
      _ -> :ok
    end
  end

  def handle(%SmartCity.Dataset{technical: %{cadence: cadence}} = dataset) do
    with {:ok, cron} <- parse_cron(cadence),
         :ok <- delete_job(dataset) do
      create_job(cron, dataset)
    else
      {:error, reason} -> Logger.warn(reason)
    end

    :ok
  end

  defp parse_cron(cron_string) do
    extended? = (String.split(cron_string, " ") |> length()) > 5
    case Crontab.CronExpression.Parser.parse(cron_string, extended?) do
      {:error, reason} ->
        {:error,
         "event(dataset:update) unable to parse cadence(#{cron_string}) as cron expression, error reason: #{
           inspect(reason)
         }"}

      ok_result ->
        ok_result
    end
  end

  defp delete_job(dataset) do
    dataset.id
    |> String.to_atom()
    |> Reaper.Scheduler.delete_job()
  end

  defp create_job(cron_expression, dataset) do
    Reaper.Scheduler.new_job()
    |> Job.set_name(String.to_atom(dataset.id))
    |> Job.set_schedule(cron_expression)
    |> Job.set_task({Brook.Event, :send, [determine_event(dataset), :reaper, dataset]})
    |> Reaper.Scheduler.add_job()
  end

  defp determine_event(%SmartCity.Dataset{technical: %{sourceType: "host"}}) do
    file_ingest_start()
  end

  defp determine_event(_) do
    data_extract_start()
  end
end
