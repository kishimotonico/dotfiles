FROM ubuntu:24.04

ENV TZ=Asia/Tokyo
ENV USER_NAME=testuser

RUN apt-get update \
    && apt-get install -y \
        curl \
        git \
        vim \
        sudo \
    && git config --global --add safe.directory /dotfiles-repo/.git \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

COPY .. /dotfiles-repo

RUN adduser --disabled-password --gecos "" ${USER_NAME} \
    && echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER_NAME}-sudo \
    && chmod 0440 /etc/sudoers.d/${USER_NAME}-sudo \
    && chown -R ${USER_NAME}:${USER_NAME} /dotfiles-repo

USER ${USER_NAME}
WORKDIR /home/${USER_NAME}

# コンテナのビルドではセットアップはまだしない
# RUN sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply /dotfiles-repo
