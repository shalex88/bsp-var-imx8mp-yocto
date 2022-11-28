FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive

# Upgrade system and Yocto Project basic dependencies
RUN apt-get update && \
apt-get -y install gawk wget git diffstat unzip texinfo gcc-multilib \
build-essential chrpath socat cpio python python3 python3-pip python3-pexpect \
xz-utils debianutils iputils-ping libsdl1.2-dev xterm libyaml-dev libssl-dev \
autoconf libtool libglib2.0-dev libarchive-dev \
sed cvs subversion coreutils texi2html docbook-utils python-pysqlite2 \
help2man make gcc g++ desktop-file-utils libgl1-mesa-dev libglu1-mesa-dev \
mercurial automake groff curl lzop asciidoc u-boot-tools dos2unix mtd-utils pv \
libncurses5 libncurses5-dev libncursesw5-dev libelf-dev zlib1g-dev bc rename rsync \
zstd libgnutls28-dev python3-git zstd liblz4-tool

# Fix "server cerificate verification failed" error
RUN apt-get -y install ntp apt-transport-https ca-certificates

# Support opening menuconfig in Yocto environment
RUN apt-get -y install screen

# Set up locales
RUN apt-get -y install locales apt-utils sudo && \
dpkg-reconfigure locales && \
locale-gen en_US.UTF-8 && \
update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
ENV LANG en_US.utf8

# Fix for nxp-wlan-sdk missing libraries
RUN apt-get install -y linux-headers-generic
RUN ln -s /lib/modules/* /lib/modules/$(uname -r)

# Clean up APT when done
RUN apt-get clean && \
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Replace dash with bash
RUN rm /bin/sh && ln -s bash /bin/sh

# Create user
ENV HOME /home/bsp
ENV USER bsp
RUN export uid=1000 gid=1000 && \
mkdir -p /home/${USER} && \
echo "${USER}:x:${uid}:${gid}:${USER},,,:${HOME}:/bin/bash" >> /etc/passwd && \
echo "${USER}:x:${uid}:" >> /etc/group && \
echo "${USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${USER} && \
chmod 0440 /etc/sudoers.d/${USER} && \
chown ${uid}:${gid} -R ${HOME}
USER ${USER}

# Install repo tool
RUN mkdir -p ${HOME}/.bin && \
curl https://storage.googleapis.com/git-repo-downloads/repo > ${HOME}/.bin/repo && \
chmod a+rx ${HOME}/.bin/repo
ENV PATH ${HOME}/.bin:${PATH}
