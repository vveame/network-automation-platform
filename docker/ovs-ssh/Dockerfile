FROM gns3/openvswitch:latest

USER root

RUN apk update && apk add --no-cache \
    openssh \
    bash \
    iptables \
    iproute2 \
    net-snmp \
    net-snmp-tools \
    && ssh-keygen -A \
    && mkdir -p /run/sshd /etc/local /root/.ssh /etc/snmp /var/lib/net-snmp \
    && chmod 700 /root/.ssh

COPY entrypoint.sh /entrypoint.sh
COPY start-snmp.sh /start-snmp.sh

RUN sed -i 's/\r$//' /entrypoint.sh /start-snmp.sh \
 && chmod +x /entrypoint.sh /start-snmp.sh

EXPOSE 22
EXPOSE 1161/udp

CMD ["/entrypoint.sh"]
