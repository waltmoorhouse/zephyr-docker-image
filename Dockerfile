FROM ubuntu:22.04

ARG ZSDK_VERSION=0.16.1
ARG NRF_CONNECT_SDK_VERSION=v2.5.1
ARG DOXYGEN_VERSION=1.9.6
ARG CMAKE_VERSION=3.25.2
ARG RENODE_VERSION=1.13.3
ARG LLVM_VERSION=14
ARG BSIM_VERSION=v1.0.3
ARG WGET_ARGS="-q --show-progress --progress=bar:force:noscroll --no-check-certificate"

ARG UID=1000
ARG GID=1000

# Set default shell during Docker image build to bash
SHELL ["/bin/bash", "-c"]

# Set non-interactive frontend for apt-get to skip any user confirmations
ENV DEBIAN_FRONTEND=noninteractive

# Set up ZDK ENVs
ENV ZSDK_HOME /home/user/ncs
ENV ZSDK_VERSION $ZSDK_VERSION

# Install base packages
RUN apt-get -y update && \
	apt-get -y upgrade && \
	apt-get install --no-install-recommends -y \
		software-properties-common \
		lsb-release \
		autoconf \
		automake \
		bison \
		build-essential \
		ca-certificates \
		ccache \
		chrpath \
		cmake \
		cpio \
        curl \
		device-tree-compiler \
		dfu-util \
		diffstat \
		dos2unix \
		doxygen \
		file \
		flex \
		g++ \
		gawk \
		gcc \
		gcovr \
		gdb \
		git \
		git-core \
		gnupg \
		gperf \
		gtk-sharp2 \
		help2man \
		iproute2 \
		lcov \
		libcairo2-dev \
        libcurl4-openssl-dev \
		libglib2.0-dev \
		libgtk2.0-0 \
		liblocale-gettext-perl \
		libncurses5-dev \
		libpcap-dev \
		libpopt0 \
		libsdl1.2-dev \
		libsdl2-dev \
		libssl-dev \
		libtool \
		libtool-bin \
		locales \
		make \
		net-tools \
		ninja-build \
		openssh-client \
		parallel \
		pkg-config \
		protobuf-compiler \
		python3-dev \
		python3-pip \
		python3-ply \
		python3-setuptools \
		python-is-python3 \
		qemu \
		rsync \
		socat \
		srecord \
		sudo \
		texinfo \
		unzip \
		valgrind \
		wget \
		ovmf \
		xz-utils

# Install multi-lib gcc (x86 only)
RUN if [ "${HOSTTYPE}" = "x86_64" ]; then \
	apt-get install --no-install-recommends -y \
		gcc-multilib \
		g++-multilib \
	; fi

# Install i386 packages (x86 only)
RUN if [ "${HOSTTYPE}" = "x86_64" ]; then \
	dpkg --add-architecture i386 && \
	apt-get -y update && \
	apt-get -y upgrade && \
	apt-get install --no-install-recommends -y \
		libsdl2-dev:i386 \
	; fi

# Initialise system locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Install Doxygen (x86 only)
# NOTE: Pre-built Doxygen binaries are only available for x86_64 host.
#RUN if [ "${HOSTTYPE}" = "x86_64" ]; then \
#	wget ${WGET_ARGS} https://downloads.sourceforge.net/project/doxygen/rel-${DOXYGEN_VERSION}/doxygen-${DOXYGEN_VERSION}.linux.bin.tar.gz && \
#	tar xf doxygen-${DOXYGEN_VERSION}.linux.bin.tar.gz -C /opt && \
#	ln -s /opt/doxygen-${DOXYGEN_VERSION}/bin/doxygen /usr/local/bin && \
#	rm doxygen-${DOXYGEN_VERSION}.linux.bin.tar.gz \
#	; fi

# Install CMake
#RUN wget ${WGET_ARGS} https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-Linux-${HOSTTYPE}.sh && \
#	chmod +x cmake-${CMAKE_VERSION}-Linux-${HOSTTYPE}.sh && \
#	./cmake-${CMAKE_VERSION}-Linux-${HOSTTYPE}.sh --skip-license --prefix=/usr/local && \
#	rm -f ./cmake-${CMAKE_VERSION}-Linux-${HOSTTYPE}.sh

# Install renode (x86 only)
# NOTE: Renode is currently only available for x86_64 host.
RUN if [ "${HOSTTYPE}" = "x86_64" ]; then \
	apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF && \
	echo "deb https://download.mono-project.com/repo/ubuntu stable-bionic main" | tee /etc/apt/sources.list.d/mono-official-stable.list && \
	apt-get -y update && \
	wget ${WGET_ARGS} https://github.com/renode/renode/releases/download/v${RENODE_VERSION}/renode_${RENODE_VERSION}_amd64.deb && \
	apt-get install -y ./renode_${RENODE_VERSION}_amd64.deb && \
	rm renode_${RENODE_VERSION}_amd64.deb \
	; fi

# Install Python dependencies
RUN python3 -m pip install -U --no-cache-dir pip && \
	pip3 install -U --no-cache-dir wheel setuptools && \
	pip3 install --no-cache-dir pygobject && \
	pip3 install --no-cache-dir \
		-r https://raw.githubusercontent.com/zephyrproject-rtos/zephyr/main/scripts/requirements.txt \
		-r https://raw.githubusercontent.com/zephyrproject-rtos/mcuboot/main/scripts/requirements.txt \
		GitPython imgtool junitparser numpy protobuf PyGithub \
		pylint sh statistics west \
		nrf-regtool>=5.1.0 && \
	pip3 check


# Install BSIM
RUN mkdir -p /opt/bsim && \
	cd /opt/bsim && \
	rm -f repo && \
	wget ${WGET_ARGS} https://storage.googleapis.com/git-repo-downloads/repo && \
	chmod a+x ./repo && \
	python3 ./repo init -u https://github.com/BabbleSim/manifest.git -m zephyr_docker.xml -b ${BSIM_VERSION} --depth 1 &&\
	python3 ./repo sync && \
	make everything -j 8 && \
	echo ${BSIM_VERSION} > ./version && \
	chmod ag+w . -R

# Install cargo environment
RUN wget -q -O-  "https://sh.rustup.rs" | sh -s -- -y

# Install uefi-run utility
RUN ~/.cargo/bin/cargo install uefi-run --root /usr

# Install LLVM and Clang
RUN wget ${WGET_ARGS} https://apt.llvm.org/llvm.sh && \
	chmod +x llvm.sh && \
	./llvm.sh ${LLVM_VERSION} all && \
	rm -f llvm.sh

# Install sparse package for static analysis
RUN mkdir -p /opt/sparse && \
	cd /opt/sparse && \
	git clone https://git.kernel.org/pub/scm/devel/sparse/sparse.git && \
	cd sparse && git checkout ${SPARSE_VERSION} && \
	make -j8 && \
	PREFIX=/opt/sparse make install && \
	rm -rf /opt/sparse/sparse

# Install protobuf-compiler
#RUN mkdir -p /opt/protoc && \
#	cd /opt/protoc && \
#	PROTOC_HOSTTYPE=$(case $HOSTTYPE in x86_64) echo "x86_64";; aarch64) echo "aarch_64";; esac) && \
#	wget ${WGET_ARGS} https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-${PROTOC_HOSTTYPE}.zip && \
#	unzip protoc-${PROTOC_VERSION}-linux-${PROTOC_HOSTTYPE}.zip && \
#	ln -s /opt/protoc/bin/protoc /usr/local/bin && \
#	rm -f protoc-${PROTOC_VERSION}-linux-${PROTOC_HOSTTYPE}.zip

# Install Zephyr SDK
RUN mkdir -p /opt/toolchains && \
    cd /opt/toolchains && \
    wget ${WGET_ARGS} https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZSDK_VERSION}/zephyr-sdk-${ZSDK_VERSION}_linux-${HOSTTYPE}.tar.xz && \
    tar xf zephyr-sdk-${ZSDK_VERSION}_linux-${HOSTTYPE}.tar.xz && \
    zephyr-sdk-${ZSDK_VERSION}/setup.sh -t all -h -c && \
    rm zephyr-sdk-${ZSDK_VERSION}_linux-${HOSTTYPE}.tar.xz

# Clean up stale packages
RUN apt-get clean -y && \
	apt-get autoremove --purge -y && \
	rm -rf /var/lib/apt/lists/*

# Create 'user' account
RUN groupadd -g $GID -o user

RUN useradd -u $UID -m -g user -G plugdev user \
	&& echo 'user ALL = NOPASSWD: ALL' > /etc/sudoers.d/user \
	&& chmod 0440 /etc/sudoers.d/user

# Create Entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# Run the Zephyr SDK setup script as 'user' in order to ensure that the
# `Zephyr-sdk` CMake package is located in the package registry under the
# user's home directory.
USER user

# Install GN (for Matter apps)
RUN mkdir ${HOME}/gn && \
    cd ${HOME}/gn && \
    wget ${WGET_ARGS} -O gn.zip https://chrome-infra-packages.appspot.com/dl/gn/gn/linux-amd64/+/latest && \
    unzip gn.zip && \
    rm gn.zip && \
    echo 'export PATH=${HOME}/gn:"$PATH"' >> ${HOME}/.bashrc && \
    source ${HOME}/.bashrc

# Setup nRF Connect SDK
RUN mkdir ${HOME}/ncs && \
    cd ${HOME}/ncs && \
    west init -m https://github.com/nrfconnect/sdk-nrf --mr ${NRF_CONNECT_SDK_VERSION} && \
    west update && \
    west zephyr-export && \
    pip3 install --user -r zephyr/scripts/requirements.txt && \
    pip3 install --user -r nrf/scripts/requirements.txt && \
    pip3 install --user -r bootloader/mcuboot/scripts/requirements.txt

RUN sudo -E -- bash -c ' \
	/opt/toolchains/zephyr-sdk-${ZSDK_VERSION}/setup.sh -c && \
	chown -R user:user /home/user/.cmake \
	'

RUN echo "source /opt/toolchains/zephyr-sdk-${ZSDK_VERSION}/environment-setup-x86_64-pokysdk-linux" >> /home/user/.bashrc
RUN echo "source ~/ncs/zephyr/zephyr-env.sh" >> /home/user/.bashrc

WORKDIR /workdir
