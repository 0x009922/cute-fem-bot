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

    scope "/suggestions" do
      get("", Controllers.Suggestions, :index)
      post("/:file_id/decision", Controllers.Suggestions, :make_decision)
    end

    get("/files/:file_id", Controllers.File, :show)
  end

  match(:*, "/*any", Controllers.NotFound, :show)
end
