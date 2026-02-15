defmodule Craftplan.Orders.OrderTotalCost do
  @moduledoc false
  use Ash.Resource.Calculation

  @impl true
  def init(opts) do
    if opts[:keys] && is_list(opts[:keys]) && Enum.all?(opts[:keys], &is_atom/1) do
      {:ok, opts}
    else
      {:error, "Expected a `keys` option for which keys to concat"}
    end
  end

  @impl true
  def load(_query, _opts, _context), do: [items: [:unit_price, :quantity]]

  @impl true
  def calculate(records, opts, _context) do
    currency = Keyword.get(opts, :currency, :USD)
    Enum.map(records, &cost(&1, currency))
  end

  def cost(record, currency) do
    Enum.reduce(record.items, Money.new(0, currency), fn x, acc ->
      x |> Map.get(:unit_price) |> Money.mult!(Map.get(x, :quantity)) |> Money.add!(acc)
    end)
  end
end
