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
