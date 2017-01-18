#!/bin/bash

set -e

source ./deploy_shared.sh

DRBD_FILENAME=drbd-9.0.6-1
DRBD_UTILS_FILENAME=drbd-utils-8.9.10

if (($FORCE_INSTALL)) || ! modinfo drbd | grep '9\.0\.6' >/dev/null 2>&1 ; then
  echo "[DRBD-MOD] Downloading sources..."
  get_file "http://www.drbd.org/download/drbd/9.0/${DRBD_FILENAME}.tar.gz" ${DRBD_FILENAME}.tar.gz

  echo "[DRBD-MOD] Extracting..."
  tar xf ${DRBD_FILENAME}.tar.gz

  echo "[DRBD-MOD] Compiling and installing kernel module..."
  cd $DRBD_FILENAME
  make
  make install
  cd ..

  echo "[DRBD-MOD] Installed!"

  set +e
  rmmod -f drbd >/dev/null
  modprobe drbd >/dev/null
  set -e
else
  echo "[DRBD-MOD] Already installed, skipping."
fi

if ! hash drbdadm 2>/dev/null ; then
  echo "[DRBD-USER] Downloading sources..."
  get_file "http://www.drbd.org/download/drbd/utils/${DRBD_UTILS_FILENAME}.tar.gz" ${DRBD_UTILS_FILENAME}.tar.gz

  echo "[DRBD-USER] Extracting..."
  tar xf ${DRBD_UTILS_FILENAME}.tar.gz

  echo "[DRBD-USER] Installing dependencies..."
  apt-get -qq install -y --force-yes flex xsltproc

  echo "[DRBD-USER] Compiling and installing userland tools..."
  cd $DRBD_UTILS_FILENAME
  ./configure --prefix=/usr --localstatedir=/var --sysconfdir=/etc --without-83support --without-84support
  make
  make install
  cd ..

  echo "[DRBD-USER] Installed!"
else
  echo "[DRBD-USER] Already installed, skipping."
fi
