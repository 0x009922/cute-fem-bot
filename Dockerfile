FROM elixir:alpine

ENV PORT=3000
ENV MIX_ENV=prod

RUN mix do local.hex --force, local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get

COPY config config
RUN mix deps.compile

COPY lib lib
COPY config.yml ./
RUN mix release --path dist

RUN mkdir data

EXPOSE 3000
CMD [ "/dist/bin/cute_fem_bot", "start" ]
