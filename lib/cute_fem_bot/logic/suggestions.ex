defmodule CuteFemBot.Logic.Suggestions do
  @moduledoc """
  Contains shared suggestions logic
  """

  @suggestion_btns [:approve_sfw, :approve_nsfw, :reject, :ban]
  @suggestions_btns_str Enum.map(@suggestion_btns, &Atom.to_string/1)

  def suggestion_btn_key_to_data(key) when key in @suggestion_btns, do: Atom.to_string(key)

  def suggestion_btn_data_to_key(data) when data in @suggestions_btns_str,
    do: {:ok, String.to_existing_atom(data)}

  def suggestion_btn_data_to_key(_), do: :error
end
