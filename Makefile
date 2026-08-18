# include .env
NAME ?= Init
# PG_USER ?= postgres
# PG_PASSWORD ?= pass
# PG_HOST ?= localhost
# PG_PORT ?= 5432
# PG_DB ?= postgres

# DATABASE_URL = postgresql://$(PG_USER):$(PG_PASSWORD)@$(PG_HOST):$(PG_PORT)/$(PG_DB)?sslmode=disable

client-run-dev:
	cd client && gleam run -m lustre/dev start

client-build:
	cd client && gleam run -m lustre/dev build --minify=true

client-deploy: client-build
	sudo cp -a client/dist/. /var/www/html/

nginx-install:
	sudo cp client/nginx.conf /etc/nginx/sites-available/default
	sudo nginx -t
	sudo systemctl reload nginx

server-run:
	cd server && gleam run

format:
	cd server && gleam format
	cd client && gleam format
	cd shared && gleam format

test:
	cd server && gleam test
	cd client && gleam test
	cd shared && gleam test

create-migration:
	cd server && gleam run -m cigogne new --name $(NAME)

# migrate-up:
# 	@echo "Running database migrations..."
# 	cd server && DATABASE_URL=$(DATABASE_URL) gleam run -m cigogne all
