FROM elixir:1.13

WORKDIR /app

# ENV PORT=3000
ENV MIX_ENV=prod

RUN mix do local.hex --force, local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get

COPY config config
RUN mix deps.compile

COPY lib lib
COPY priv priv
RUN mix release --path dist

RUN mkdir data
COPY docker_entry.sh ./

# EXPOSE 3000
CMD [ "/bin/sh", "docker_entry.sh" ]
