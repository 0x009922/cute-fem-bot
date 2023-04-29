FROM elixir:1.13-alpine

WORKDIR /app

ENV PORT=4000
ENV MIX_ENV=prod

RUN mix do local.hex --force, local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get

COPY config config

# This ones are joined into a single build step, because otherwise
# the final image gets bloated by the layer where all the build dependencies are installed.
# If we ever switch to a multistage build, I guess these steps can be separated,
# because they no longer will affect the size of the final image.
# Separating them also means better caching for the image build process.
ARG BUILD_DEPS="build-base erlang-dev"
RUN apk add --no-cache $BUILD_DEPS && \
    mix deps.compile && \
    apk del $BUILD_DEPS

COPY lib lib
COPY priv priv
RUN mix release --path dist

RUN mkdir data
COPY docker_entry.sh ./

EXPOSE 4000

CMD [ "/bin/sh", "docker_entry.sh" ]
