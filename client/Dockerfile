ARG GLEAM_VERSION=v1.18.1

FROM ghcr.io/gleam-lang/gleam:${GLEAM_VERSION}-erlang-alpine AS builder

WORKDIR /build

COPY shared/gleam.toml shared/manifest.toml ./shared/
COPY client/gleam.toml client/manifest.toml ./client/

RUN cd shared && gleam deps download
RUN cd client && gleam deps download

COPY shared/src ./shared/src
COPY client/src ./client/src
COPY client/assets ./client/assets

WORKDIR /build/client

RUN gleam run -m lustre/dev -- build --minify

FROM nginx:1.29-alpine AS runtime

COPY client/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /build/client/dist /usr/share/nginx/html
COPY client/config.js.template /etc/nginx/templates/config.js.template

ENV NGINX_ENVSUBST_OUTPUT_DIR=/usr/share/nginx/html

EXPOSE 80
