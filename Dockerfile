# Following image is used to help debug openssl FIPS
FROM arm64v8/fedora

ARG OPENSSL_TAG=openssl-3.0.8

ENV HOME=/root/

ENV OPENSSL_HOME=${HOME}/.local/${OPENSSL_TAG}-fips-debug/
ENV OPENSSL_INCLUDE=${OPENSSL_HOME}/include/
ENV OPENSSL_LIB=${OPENSSL_HOME}/lib/
ENV OPENSSL_BIN=${OPENSSL_HOME}/bin/

# Fetch deps
RUN dnf -y update \
    && dnf install -y git \
                      gcc \
                      g++ \
                      gdb \
                      make \
                      perl \
		      strace \
		      ltrace \
                      gettext-envsubst \
                      emacs-nox

# Setup openssl
RUN git clone https://github.com/openssl/openssl.git /usr/local/openssl \
    && cd /usr/local/openssl \
    && git checkout $OPENSSL_TAG \
    && ./Configure \
       --prefix=${OPENSSL_HOME} \
       --libdir=lib \
       shared \
       enable-fips \
       enable-trace \
       no-asm -g3 -O0 -fno-omit-frame-pointer -fno-inline-functions -ggdb3 \
    && make -j$(nproc) \
    && make install_sw install_ssldirs install_fips \
    && LD_LIBRARY_PATH=${OPENSSL_LIB} ${OPENSSL_BIN}/openssl version -a

COPY openssl_fips.cnf.tpl ${OPENSSL_HOME}/ssl/openssl_fips.cnf.tpl
RUN cat ${OPENSSL_HOME}/ssl/openssl_fips.cnf.tpl | envsubst > ${OPENSSL_HOME}/ssl/openssl_fips.cnf

# Sanity check
RUN git clone https://github.com/junaruga/openssl-test.git /usr/local/fips-test \
    && cd /usr/local/fips-test \
    && gcc -I ${OPENSSL_INCLUDE} \
           -L ${OPENSSL_LIB} \
           -lcrypto \
           -o fips_mode \
           fips_mode.c \
    && LD_LIBRARY_PATH=${OPENSSL_LIB} \
       OPENSSL_CONF=${OPENSSL_HOME}/ssl/openssl_fips.cnf \
       ./fips_mode

# Add some helper scripts and debug an issue 
# Example:
RUN git clone https://github.com/junaruga/report-openssl-fips-ed25519.git /usr/local/ed25519_test \
    && cd /usr/local/ed25519_test \
    && echo "gcc -I ${OPENSSL_INCLUDE} -L ${OPENSSL_LIB} -ggdb3 -O0 -o ed25519 ed25519.c -lcrypto" > rc.sh \
    && echo "OPENSSL_CONF=${OPENSSL_HOME}/ssl/openssl_fips.cnf OPENSSL_CONF_INCLUDE=${OPENSSL_HOME}/ssl OPENSSL_MODULES=${OPENSSL_LIB}/ossl-modules gdb --args ./ed25519 ed25519_pub.pem" > db.sh \
    && chmod +x *.sh \
    && ./rc.sh \
    && trap "OPENSSL_CONF=${OPENSSL_HOME}/ssl/openssl_fips.cnf OPENSSL_CONF_INCLUDE=${OPENSSL_HOME}/ssl OPENSSL_MODULES=${OPENSSL_LIB}/ossl-modules ./ed25519 ed25519_pub.pem" EXIT