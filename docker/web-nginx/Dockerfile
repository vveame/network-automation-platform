FROM nginx:alpine

RUN apk add --no-cache iproute2 iputils curl

COPY hosts/web-server.sh /etc/local/host-ip.sh
COPY docker/web-nginx/entrypoint.sh /entrypoint.sh
COPY docker/web-nginx/index.html /usr/share/nginx/html/index.html

RUN sed -i 's/\r$//' /etc/local/host-ip.sh /entrypoint.sh && \
    chmod +x /etc/local/host-ip.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]