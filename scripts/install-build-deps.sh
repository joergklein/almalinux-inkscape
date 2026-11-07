#!/usr/bin/env bash

set -Eeuo pipefail

echo "Installing RPM build dependencies..."

if [[ ! -f /etc/almalinux-release ]]; then
    echo "Error: This script must run on AlmaLinux."
    exit 1
fi

dnf install -y epel-release
dnf install -y dnf-plugins-core

dnf config-manager --set-enabled crb

dnf install -y \
    rpm-build \
    rpmdevtools \
    mock \
    cmake \
    ninja-build \
    gcc \
    gcc-c++ \
    make \
    git \
    curl \
    tar \
    xz \
    pkgconf-pkg-config \
    gettext \
    desktop-file-utils \
    gtk3-devel \
    gdk-pixbuf2-devel \
    cairo-devel \
    fontconfig-devel \
    freetype-devel \
    pango-devel \
    libxml2-devel \
    libpng-devel \
    zlib-devel

echo "Build dependencies installed successfully."
