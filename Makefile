client-run-dev:
	cd client && gleam run -m lustre/dev -- start

client-build:
	cd client && gleam run -m lustre/dev -- build --minify

server-run:
	cd server && gleam run
