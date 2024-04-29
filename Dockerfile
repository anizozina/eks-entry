FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    git \
    curl \
    sudo \
    unzip \
    vim \
    wget  \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ARG USERNAME=terraform
ARG USER_ID="10000"
ARG GROUP_ID="10001"
RUN groupadd -g $GROUP_ID $USERNAME \
    && useradd -m -s /bin/bash -u $USER_ID -g $GROUP_ID -G sudo $USERNAME \
    && echo $USERNAME:$USERNAME | chpasswd \
    && echo "$USERNAME   ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER $USERNAME
WORKDIR /home/${USERNAME}

RUN git clone --depth=1 https://github.com/tfutils/tfenv.git ~/.tfenv \
    && echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bash_profile \
    && sudo ln -s ~/.tfenv/bin/* /usr/local/bin

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"\
    && unzip awscliv2.zip \
    && sudo ./aws/install

RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    && chmod 700 get_helm.sh \
    && ./get_helm.sh \
    && rm -rf ./get_helm.sh