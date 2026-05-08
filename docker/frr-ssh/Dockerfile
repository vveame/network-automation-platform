FROM frrouting/frr:v8.4.0

USER root

# Install SSH and basic tools.
RUN apk update && apk add --no-cache openssh bash shadow \
    && mkdir -p /run/sshd /etc/local /root/.ssh \
    && ssh-keygen -A \
    && chmod 700 /root/.ssh

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22

CMD ["/entrypoint.sh"]