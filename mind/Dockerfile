FROM elixir:1.13-slim

WORKDIR /app

ENV PORT=4000
ENV MIX_ENV=prod

RUN mix do local.hex --force, local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get

COPY config config

# to stop dpkg from trying to interactively configure timezones
ARG DEBIAN_FRONTEND=noninteractive
ARG BUILD_DEPS="build-essential erlang-dev"
RUN apt update && apt install -y $BUILD_DEPS && \
    mix deps.compile && \
    apt purge -y $BUILD_DEPS && apt autopurge -y && apt clean

COPY lib lib
COPY priv priv
RUN mix release --path dist

RUN mkdir data
COPY docker_entry.sh ./

EXPOSE 4000

CMD [ "/bin/sh", "docker_entry.sh" ]
