FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
  apt-get -y dist-upgrade && \
  apt-get -y install python3-dev \
                     ca-cacert \
                     libncurses5-dev libncursesw5-dev \
                     git \
                     tcl-dev \
                     tcllib && \
  apt-get -y autoremove

RUN ln -fs /usr/share/zoneinfo/Europe/London /etc/localtime && \
  dpkg-reconfigure --frontend noninteractive tzdata

RUN mkdir -p $HOME/vim && \
    cd $HOME/vim && \
    git clone https://github.com/vim/vim && \
    cd vim && \
    git checkout v8.1.0958 && \
    ./configure --with-features=huge \
                --enable-python3interp \
                --enable-terminal \
                --enable-multibyte \
                --enable-fail-if-missing && \
    make -j 8 install

