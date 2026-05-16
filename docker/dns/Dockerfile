FROM alpine:latest

RUN apk add --no-cache bind bind-tools iproute2 iputils

COPY hosts/dns-server.sh /opt/pfe/host-ip.sh
COPY docker/dns/named.conf /etc/bind/named.conf
COPY docker/dns/db.pfe.local /etc/bind/db.pfe.local
COPY docker/dns/entrypoint.sh /entrypoint.sh

RUN sed -i 's/\r$//' /opt/pfe/host-ip.sh /entrypoint.sh /etc/bind/named.conf /etc/bind/db.pfe.local && \
    chmod +x /opt/pfe/host-ip.sh /entrypoint.sh && \
    named-checkconf /etc/bind/named.conf && \
    named-checkzone pfe.local /etc/bind/db.pfe.local

ENTRYPOINT ["/entrypoint.sh"]