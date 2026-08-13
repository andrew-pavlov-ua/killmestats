client-run-dev:
	cd client && gleam run -m lustre/dev -- start

client-build:
	cd client && gleam run -m lustre/dev -- build --minify

server-run:
	cd server && gleam run

format:
	cd server && gleam format; \
	cd ../client && gleam format; \
	cd ../shared && gleam format
