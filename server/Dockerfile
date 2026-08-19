ARG GLEAM_VERSION=v1.18.1
ARG ERLANG_VERSION=27.1.1.0

FROM ghcr.io/gleam-lang/gleam:${GLEAM_VERSION}-scratch AS gleam

FROM erlang:${ERLANG_VERSION}-alpine AS build
COPY --from=gleam /bin/gleam /bin/gleam

WORKDIR /app
COPY shared ./shared
COPY server ./server

WORKDIR /app/server
# Dependencies are prepared once in this clean container build directory. The
# root .dockerignore deliberately excludes host `*/build` directories.
RUN gleam deps download

# Compose selects this target for the one-off migration container. It must run
# at container start, when the `postgres` service is available, not at build time.
FROM build AS migrate
CMD ["gleam", "run", "-m", "cigogne", "all"]

FROM build AS shipment
RUN gleam export erlang-shipment

FROM erlang:${ERLANG_VERSION}-alpine AS runtime
RUN addgroup --system webapp \
  && adduser --system --ingroup webapp webapp

COPY --from=shipment --chown=webapp:webapp /app/server/build/erlang-shipment /app
WORKDIR /app
USER webapp
ENTRYPOINT ["/bin/sh", "/app/entrypoint.sh"]
CMD ["run"]
