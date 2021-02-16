FROM debian:stable-slim

ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -x && \
    TEMP_PACKAGES=() && \
    KEPT_PACKAGES=() && \
    KEPT_PIP_PACKAGES=() && \
    KEPT_RUBY_PACKAGES=() && \
    # Required for building multiple packages.
    # TEMP_PACKAGES+=(build-essential) && \
    TEMP_PACKAGES+=(pkg-config) && \
    # TEMP_PACKAGES+=(cmake) && \
    TEMP_PACKAGES+=(git) && \
    TEMP_PACKAGES+=(automake) && \
    TEMP_PACKAGES+=(autoconf) && \
    KEPT_PACKAGES+=(wget) && \
    # logging
    KEPT_PACKAGES+=(gawk) && \
    KEPT_PACKAGES+=(pv) && \
    # required for S6 overlay
    # curl kept for healthcheck
    # ca-certificates kept for python
    TEMP_PACKAGES+=(gnupg2) && \
    TEMP_PACKAGES+=(file) && \
    KEPT_PACKAGES+=(curl) && \
    KEPT_PACKAGES+=(ca-certificates) && \
    #
    # a few KEPT_PACKAGES for debugging - they can be removed in the future
    KEPT_PACKAGES+=(procps nano aptitude netcat) && \
    #
    # Get prerequisite packages for PlaneFence and Socket30003:
    #
    KEPT_PACKAGES+=(python-pip) && \
    KEPT_PACKAGES+=(python-numpy) && \
    KEPT_PACKAGES+=(python-pandas) && \
    KEPT_PACKAGES+=(python-dateutil) && \
    KEPT_PACKAGES+=(jq) && \
    KEPT_PACKAGES+=(bc) && \
    KEPT_PACKAGES+=(gnuplot-nox) && \
    KEPT_PACKAGES+=(lighttpd) && \
    KEPT_PACKAGES+=(perl) && \
    KEPT_PACKAGES+=(iputils-ping) && \
    KEPT_PACKAGES+=(ruby) && \
    KEPT_PACKAGES+=(alsa-utils) && \
    KEPT_PIP_PACKAGES+=(tzlocal) && \
    KEPT_RUBY_PACKAGES+=(twurl) && \
    #
    # Install packages.
    #
    # first fix the file locations for a few files. This is needed for the amd64 image to build correctly
    mkdir -p /usr/sbin/ && \
    ln -s /usr/bin/dpkg-split /usr/sbin/dpkg-split && \
    ln -s /usr/bin/dpkg-deb /usr/sbin/dpkg-deb && \
    ln -s /bin/tar /usr/sbin/tar && \ 
    # now go on with the actual install:
    apt-get update && \
    apt-get install -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -o Dpkg::Options::="--force-confold" --force-yes -y --no-install-recommends  --no-install-suggests\
        ${KEPT_PACKAGES[@]} \
        ${TEMP_PACKAGES[@]} \
        && \
    git config --global advice.detachedHead false && \
    pip install ${KEPT_PIP_PACKAGES[@]} && \
    gem install twurl && \
    #
    # Use normal shell commands to install
    #
    # Install dump1090.socket30003
    mkdir -p /usr/share/socket30003 && \
    mkdir -p /run/socket30003 && \
    mkdir -p /etc/services.d/socket30003 && \
    git clone https://github.com/kx1t/dump1090.socket30003.git /git/socket30003 && \
    pushd "/git/socket30003" && \
    ./install.pl -install /usr/share/socket30003 -data /run/socket30003 -log /run/socket30003 -output /run/socket30003 -pid /run/socket30003 && \
    chmod a+x /usr/share/socket30003/*.pl && \
    popd && \
    #
    # Install PlaneFence
    mkdir -p /usr/share/planefence/html && \
    mkdir -p /usr/share/planefence/stage && \
    mkdir -p /etc/services.d/planefence && \
    git clone https://github.com/kx1t/planefence4docker.git /git/planefence && \
    pushd /git/planefence && \
    cp scripts/* /usr/share/planefence && \
    cp jscript/* /usr/share/planefence/stage && \
    cp systemd/start_* /usr/share/planefence && \
    cp systemd/start_planefence /etc/services.d/planefence/run && \
    cp systemd/start_socket30003 /etc/services.d/socket30003/run && \
    chmod a+x /usr/share/planefence/*.sh /usr/share/planefence/*.py /usr/share/planefence/*.pl /etc/services.d/planefence/run /etc/services.d/socket30003/run && \
    ln -s /usr/share/socket30003/socket30003.cfg /usr/share/planefence/socket30003.cfg && \
    popd && \
    ln -s /usr/share/planefence/config_tweeting.sh /root/config_tweeting.sh && \
    #
    # install S6 Overlay
    curl -s https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay.sh | sh && \
    #
    # Clean up
    apt-get remove -y ${TEMP_PACKAGES[@]} && \
    apt-get autoremove -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -y && \
    apt-get clean -y && \
    rm -rf /src/* /tmp/* /var/lib/apt/lists/* /etc/services.d/planefence/.blank /etc/services.d/socket30003/.blank /run/socket30003/install-*
    # rm -rf /git/*

COPY rootfs/ /

ENTRYPOINT [ "/init" ]

EXPOSE 80
EXPOSE 30003

# Add healthcheck
HEALTHCHECK --start-period=3600s --interval=600s CMD /scripts/healthcheck.sh
