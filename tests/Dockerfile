# syntax=docker/dockerfile:1
ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}

ENV TZ=Asia/Tokyo
ENV USER_NAME=sakurai-miyo

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
    && apt-get install -y \
        curl \
        git \
        vim \
        sudo \
    && git config --global --add safe.directory /dotfiles/.git

RUN adduser --disabled-password --gecos "" ${USER_NAME} \
    && echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER_NAME}-sudo \
    && chmod 0440 /etc/sudoers.d/${USER_NAME}-sudo

COPY --chown=${USER_NAME}:${USER_NAME} .. /home/${USER_NAME}/dotfiles
COPY --chmod=755 tests/setup.sh /tests/setup.sh
COPY --chmod=755 tests/verify.sh /tests/verify.sh

USER ${USER_NAME}
WORKDIR /home/${USER_NAME}

CMD ["/tests/setup.sh"]
