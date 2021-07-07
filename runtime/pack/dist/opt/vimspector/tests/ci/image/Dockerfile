FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL C.UTF-8

RUN apt-get update && \
  apt-get -y dist-upgrade && \
  apt-get -y install python3-dev \
                     python3-pip \
                     ca-cacert \
                     locales \
                     language-pack-en \
                     libncurses5-dev libncursesw5-dev \
                     git \
                     tcl-dev \
                     tcllib \
                     gdb \
                     lldb \
                     curl \
                     nodejs \
                     npm && \
  apt-get -y autoremove

RUN ln -fs /usr/share/zoneinfo/Europe/London /etc/localtime && \
  dpkg-reconfigure --frontend noninteractive tzdata

## cleanup of files from setup
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ARG VIM_VERSION=v8.1.1270

ENV CONF_ARGS "--with-features=huge \
               --enable-python3interp \
               --enable-terminal \
               --enable-multibyte \
               --enable-fail-if-missing"

RUN mkdir -p $HOME/vim && \
    cd $HOME/vim && \
    git clone https://github.com/vim/vim && \
    cd vim && \
    git checkout ${VIM_VERSION} && \
    make -j 4 && \
    make install

# linuxbrew (homebrew)
RUN mkdir -p /home/linuxbrew/.linuxbrew &&\
    chmod -R go+rwx /home/linuxbrew && \
    mkdir -p /home/linuxbrew/.linuxbrew/bin && \
    git clone  https://github.com/Homebrew/brew /home/linuxbrew/.linuxbrew/Homebrew && \
    ln -s /home/linuxbrew/.linuxbrew/Homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin && \
    echo "eval \$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" \
        > /etc/bash.bashrc

RUN /home/linuxbrew/.linuxbrew/bin/brew install golang

# clean up
RUN /home/linuxbrew/.linuxbrew/bin/brew cleanup && \
    rm -rf ~/.cache && \
    rm -rf $HOME/vim
