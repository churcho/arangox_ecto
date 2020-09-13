defmodule ArangoXEcto.Adapter do
  @moduledoc """
  Ecto adapter for ArangoDB using ArangoX
  """

  @otp_app :arangox_ecto

  @behaviour Ecto.Adapter
  @behaviour Ecto.Adapter.Queryable

  @impl Ecto.Adapter
  defmacro __before_compile__(_env) do
    # Maybe something later
    :ok
  end

  use Bitwise, only_operators: true

  require Logger

  @doc """
  Starts the Agent with an empty list
  """
  def start_link({_module, config}) do
    Logger.debug(
      "#{inspect(__MODULE__)}.start_link",
      %{
        "#{inspect(__MODULE__)}.start_link-params" => %{
          config: config
        }
      }
    )

    Agent.start_link(fn -> [] end)
  end

  @doc """
  Initialise adapter with `config`
  """
  @impl Ecto.Adapter
  def init(config) do
    child = Arangox.child_spec(config)

    # Maybe something here later
    meta = %{}

    {:ok, child, meta}
  end

  @doc """
  Ensure all applications necessary to run the adapter are started
  """
  @impl Ecto.Adapter
  def ensure_all_started(config, type) do
    Logger.debug("#{inspect(__MODULE__)}.ensute_all_started", %{
      "#{inspect(__MODULE__)}.ensure_all_started-params" => %{
        type: type,
        config: config
      }
    })

    with {:ok, _} = Application.ensure_all_started(@otp_app) do
      {:ok, [config]}
    end
  end

  @behaviour Ecto.Adapter.Storage
  defdelegate storage_up(options), to: ArangoXEcto.Behaviour.Storage
  defdelegate storage_status(options), to: ArangoXEcto.Behaviour.Storage
  defdelegate storage_down(options), to: ArangoXEcto.Behaviour.Storage

  @doc """
  Checks out a connection for the duration of the given function.
  """
  @impl Ecto.Adapter
  def checkout(_meta, _opts, _fun) do
    raise "#{inspect(__MODULE__)}.checkout: #{inspect(__MODULE__)} does not currently support checkout"
  end

  defdelegate autogenerate(field_type), to: ArangoXEcto.Behaviour.Schema

  @doc """
  Returns the loaders of a given type.
  """
  @impl Ecto.Adapter
  def loaders(:uuid, Ecto.UUID), do: [&{:ok, &1}]
  def loaders(:date, _type), do: [&load_date/1]
  def loaders(:time, _type), do: [&load_time/1]
  def loaders(:utc_datetime, _type), do: [&load_utc_datetime/1]
  def loaders(:naive_datetime, _type), do: [&NaiveDateTime.from_iso8601/1]
  def loaders(:float, _type), do: [&load_float/1]
  def loaders(_primitive, type), do: [type]

  @doc """
  Returns the dumpers for a given type.
  """
  @impl Ecto.Adapter
  def dumpers(:uuid, Ecto.UUID), do: [&{:ok, &1}]
  def dumpers({:in, sub}, {:in, sub}), do: [{:array, sub}]

  def dumpers(:date, type) when type in [:date, Date],
    do: [fn %Date{} = d -> {:ok, Date.to_iso8601(d)} end]

  def dumpers(:time, type) when type in [:time, Time],
    do: [fn %Time{} = t -> {:ok, Time.to_iso8601(t)} end]

  def dumpers(:utc_datetime, type) when type in [:utc_datetime, DateTime],
    do: [fn %DateTime{} = dt -> {:ok, DateTime.to_iso8601(dt)} end]

  def dumpers(:naive_datetime, type) when type in [:naive_datetime, NaiveDateTime],
    do: [fn %NaiveDateTime{} = dt -> {:ok, NaiveDateTime.to_iso8601(dt)} end]

  def dumpers(_primitive, type), do: [type]

  @behaviour Ecto.Adapter.Queryable
  defdelegate stream(adapter_meta, query_meta, query_cache, params, options),
    to: ArangoXEcto.Behaviour.Queryable

  defdelegate prepare(atom, query), to: ArangoXEcto.Behaviour.Queryable

  defdelegate execute(adapter_meta, query_meta, query_cache, params, options),
    to: ArangoXEcto.Behaviour.Queryable

  @behaviour Ecto.Adapter.Schema
  defdelegate delete(adapter_meta, schema_meta, filters, options),
    to: ArangoXEcto.Behaviour.Schema

  defdelegate insert(adapter_meta, schema_meta, fields, on_conflict, returning, options),
    to: ArangoXEcto.Behaviour.Schema

  defdelegate insert_all(
                adapter_meta,
                schema_meta,
                header,
                list,
                on_conflict,
                returning,
                options
              ),
              to: ArangoXEcto.Behaviour.Schema

  defdelegate update(adapter_meta, schema_meta, fields, filters, returning, options),
    to: ArangoXEcto.Behaviour.Schema

  #  defp validate_struct(module, %{} = params),
  #    do: module.changeset(struct(module.__struct__), params)

  defp load_date(d) do
    case Date.from_iso8601(d) do
      {:ok, res} -> {:ok, res}
      {:error, _reason} -> :error
    end
  end

  defp load_time(t) do
    case Time.from_iso8601(t) do
      {:ok, res} -> {:ok, res}
      {:error, _reason} -> :error
    end
  end

  defp load_utc_datetime(dt) do
    case DateTime.from_iso8601(dt) do
      {:ok, res, _} -> {:ok, res}
      {:error, _reason} -> :error
    end
  end

  def load_float(arg) when is_number(arg), do: {:ok, :erlang.float(arg)}
  def load_float(_), do: :error
end