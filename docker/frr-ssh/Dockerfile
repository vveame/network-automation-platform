FROM frrouting/frr:v8.4.0

USER root

# Install SSH, SNMP, WireGuard and troubleshooting tools.
# WireGuard is baked into the image because live apk update inside
# GNS3 runtime containers can be unreliable.
RUN apk update && apk add --no-cache \
    openssh \
    bash \
    shadow \
    net-snmp \
    net-snmp-tools \
    wireguard-tools \
    iptables \
    tcpdump \
    curl \
    ca-certificates \
    && update-ca-certificates 2>/dev/null || true \
    && mkdir -p /run/sshd /etc/local /root/.ssh /var/lib/net-snmp /etc/wireguard \
    && ssh-keygen -A \
    && chmod 700 /root/.ssh /etc/wireguard

COPY entrypoint.sh /entrypoint.sh
COPY start-snmp.sh /start-snmp.sh

RUN sed -i 's/\r$//' /entrypoint.sh /start-snmp.sh \
  && chmod +x /entrypoint.sh /start-snmp.sh

EXPOSE 22
EXPOSE 1161/udp
EXPOSE 51820/udp

CMD ["/entrypoint.sh"]
