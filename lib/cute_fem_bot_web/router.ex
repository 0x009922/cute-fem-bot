defmodule CuteFemBotWeb.Router do
  use CuteFemBotWeb, :router
  alias CuteFemBotWeb.Controllers

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/api" do
    pipe_through(:api)

    get("/auth", Controllers.Auth, :show)

    resources("/suggestions", Controllers.Suggestions, only: [:index, :update], param: "file_id")

    get("/file/:file_id", Controllers.File, :show)
  end
end
