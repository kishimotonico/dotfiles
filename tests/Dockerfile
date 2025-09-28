ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}

ENV TZ=Asia/Tokyo
ENV USER_NAME=testuser

RUN apt-get update \
    && apt-get install -y \
        curl \
        git \
        vim \
        sudo \
    && git config --global --add safe.directory /dotfiles/.git \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

RUN adduser --disabled-password --gecos "" ${USER_NAME} \
    && echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER_NAME}-sudo \
    && chmod 0440 /etc/sudoers.d/${USER_NAME}-sudo

COPY --chown=${USER_NAME}:${USER_NAME} .. /home/${USER_NAME}/dotfiles
COPY tests/test-setup.sh test-setup.sh
RUN sudo chmod +x /test-setup.sh

USER ${USER_NAME}
WORKDIR /home/${USER_NAME}

# テスト実行用のエントリーポイント
CMD ["/test-setup.sh"]
