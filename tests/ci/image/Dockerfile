FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
  apt-get -y dist-upgrade && \
  apt-get -y install python3 \
                     ca-cacert \
                     vim \
                     git \
                     tcl-dev \
                     tcllib && \
  apt-get -y autoremove

RUN ln -fs /usr/share/zoneinfo/Europe/London /etc/localtime && \
  dpkg-reconfigure --frontend noninteractive tzdata
