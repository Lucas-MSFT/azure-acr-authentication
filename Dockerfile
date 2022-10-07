FROM ubuntu:18.04

RUN apt-get update && apt-get install bash-completion apt-transport-https gnupg wget curl vim openssh-client iputils-ping nmap jq -y \
    && curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
    && curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/microsoft.asc.gpg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor > /etc/apt/keyrings/docker.gpg \
    && echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list \
    && echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ bionic main" > /etc/apt/sources.list.d/azure-cli.list \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu focal stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update && apt-get install -y kubectl azure-cli jq docker-ce docker-ce-cli containerd.io docker-compose-plugin \
    && apt-get clean all

COPY ./bashrc /root/.bashrc

COPY ./acrlabs_binaries/* /usr/local/bin/

CMD ["/bin/sh"]
