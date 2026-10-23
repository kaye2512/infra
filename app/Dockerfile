# En prod, épingler une version précise (ex. nginx:1.xx-alpine) plutôt que alpine
FROM nginx:alpine

# Valeur injectée par Jenkins (--build-arg) ; "dev" pour un build local
ARG APP_VERSION=dev

COPY index.html /usr/share/nginx/html/index.html
RUN sed -i "s/__VERSION__/${APP_VERSION}/g" /usr/share/nginx/html/index.html