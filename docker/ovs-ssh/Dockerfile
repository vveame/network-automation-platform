FROM gns3/openvswitch:latest

USER root

RUN apk update && apk add --no-cache openssh bash iptables \
    && ssh-keygen -A \
    && mkdir -p /run/sshd /etc/local /root/.ssh \
    && chmod 700 /root/.ssh

COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 22

CMD ["/entrypoint.sh"]