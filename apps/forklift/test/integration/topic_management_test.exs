defmodule Forklift.TopicManagementTest do
  use ExUnit.Case
  use Divo, services: [:kafka, :redis]

  alias SmartCity.TestDataGenerator, as: TDG

  @endpoints Application.get_env(:forklift, :brod_brokers)

  test "create new topic for dataset when dataset event is received" do
    dataset = TDG.create_dataset(id: "ds1")
    SmartCity.Dataset.write(dataset)

    Patiently.wait_for!(
      fn ->
        {"integration-ds1", 1} in list_topics()
      end,
      dwell: 200,
      max_tries: 20
    )
  end

  test "create new topic for dataset when dataset event is received and topic already exists" do
    Forklift.TopicManager.create_and_subscribe("transformed-bob1")
    Forklift.TopicManager.create_and_subscribe("transformed-bob1")

    Patiently.wait_for!(
      fn ->
        {"transformed-bob1", 1} in list_topics()
      end,
      dwell: 200,
      max_tries: 20
    )
  end

  defp list_topics() do
    {:ok, metadata} = :brod.get_metadata(@endpoints, :all)

    metadata.topic_metadata
    |> Enum.map(fn topic_metadata ->
      {topic_metadata.topic, Enum.count(topic_metadata.partition_metadata)}
    end)
  end
end
