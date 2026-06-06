FROM frrouting/frr:v8.4.0

USER root

# Install SSH and basic tools.
RUN apk update && apk add --no-cache openssh bash shadow net-snmp net-snmp-tools \
    && mkdir -p /run/sshd /etc/local /root/.ssh /var/lib/net-snmp \
    && ssh-keygen -A \
    && chmod 700 /root/.ssh

COPY entrypoint.sh /entrypoint.sh
COPY start-snmp.sh /start-snmp.sh

RUN sed -i 's/\r$//' /entrypoint.sh /start-snmp.sh \
 && chmod +x /entrypoint.sh /start-snmp.sh

EXPOSE 22
EXPOSE 1161/udp

CMD ["/entrypoint.sh"]