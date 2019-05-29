defmodule Forklift.TopicManager do
  import Record, only: [defrecord: 2, extract: 2]

  defrecord :kpro_rsp, extract(:kpro_rsp, from_lib: "kafka_protocol/include/kpro.hrl")

  def create(topic, opts \\ []) do
    with_connection(endpoints(), fn connection ->
      create_topic_args = %{
      topic: topic,
      num_partitions: Keyword.get(opts, :partitions, 1),
      replication_factor: Keyword.get(opts, :replicas, 1),
      replica_assignment: [],
      config_entries: []
    }

      version = get_api_version(connection, :create_topics)
      topic_request = :kpro_req_lib.create_topics(version, [create_topic_args], %{timeout: 5_000})

      send_request(connection, topic_request, 5_000)
    end)
  end

  defp endpoints() do
    Application.get_env(:kaffe, :consumer)[:endpoints]
  end

  def with_connection(endpoints, fun) when is_function(fun) do
    endpoints
    |> :kpro.connect_any([])
    |> do_with_connection(fun)
  end

  def reformat_endpoints(endpoints) do
    Enum.map(endpoints, fn {key, value} -> {to_charlist(key), value} end)
  end

  def get_api_version(connection, api) do
    {:ok, api_versions} = :kpro.get_api_versions(connection)
    {_, version} = Map.get(api_versions, api)
    version
  end

  defp do_with_connection({:ok, connection}, fun) do
    fun.(connection)
  after
    :kpro.close_connection(connection)
  end

  defp do_with_connection({:error, reason}, _fun) do
    raise Error, message: format_reason(reason)
  end

  defp format_reason(reason) do
    cond do
      is_binary(reason) -> reason
      Exception.exception?(reason) -> Exception.format(:error, reason)
      true -> inspect(reason)
    end
  end

  defp send_request(connection, request, timeout) do
    case :kpro.request_sync(connection, request, timeout) do
      {:ok, response} -> check_response(response)
      result -> result
    end
  end

  defp check_response(response) do
    message = kpro_rsp(response, :msg)

    case Enum.find(message.topic_errors, fn error -> error.error_code != :no_error end) do
      nil -> :ok
      error -> {:error, error.error_message}
    end
  end
end
