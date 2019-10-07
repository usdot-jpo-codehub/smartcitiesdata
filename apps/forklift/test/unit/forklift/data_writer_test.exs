defmodule Forklift.DataWriterTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.DataWriter
  alias SmartCity.TestDataGenerator, as: TDG
  import Mox

  setup :set_mox_global
  setup :verify_on_exit!

  describe "compact_datasets/0" do
    test "compacts other tables if one fails" do
      test = self()

      datasets = [
        TDG.create_dataset(%{technical: %{systemName: "fail"}}),
        TDG.create_dataset(%{technical: %{systemName: "one"}}),
        TDG.create_dataset(%{technical: %{systemName: "two"}})
      ]

      allow Forklift.Datasets.get_all!(), return: datasets
      allow DataWriter.Metric.record(any(), any()), return: :ok

      expect(Forklift.MockTable, :compact, 3, fn args ->
        case args[:table] do
          "fail" ->
            {:error, "reason"}

          table ->
            send(test, table)
            :ok
        end
      end)

      assert :ok = DataWriter.compact_datasets()
      assert_receive "one"
      assert_receive "two"
      refute_receive "fail"
    end

    test "records duration" do
      expect(MockMetricCollector, :count_metric, 2, fn "dataset_compaction_duration_total", _, _, _ -> [100] end)
      expect(MockMetricCollector, :record_metrics, 2, fn [100], "forklift" -> {:ok, :ok} end)
      expect(Forklift.MockTable, :compact, 2, fn _ -> :ok end)

      datasets = [TDG.create_dataset(%{}), TDG.create_dataset(%{})]
      allow Forklift.Datasets.get_all!(), return: datasets

      assert :ok = DataWriter.compact_datasets()
    end
  end
end
