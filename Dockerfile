FROM elixir:alpine

ENV PORT=3000

RUN mix do local.hex --force, local.rebar --force

COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get

COPY lib lib
COPY config.yml ./
RUN MIX_ENV=prod mix release

RUN mkdir data

EXPOSE 3000
CMD [ "/_build/prod/rel/cute_fem_bot/bin/cute_fem_bot", "start" ]
