defmodule CuteFemBotWeb.Router do
  use CuteFemBotWeb, :router
  alias CuteFemBotWeb.Controllers

  pipeline :api do
    plug(:accepts, ["json"])
    plug(CuteFemBotWeb.Plugs.Auth)
  end

  # for health check
  get("/", Controllers.Health, :index)

  scope "/api/v1" do
    pipe_through(:api)

    get("/auth", Controllers.Auth, :show)

    resources("/suggestions", Controllers.Suggestions, only: [:index, :update], param: "file_id")

    get("/files/:file_id", Controllers.File, :show)
  end
end
