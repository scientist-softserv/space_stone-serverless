# This file assists in building dependencies for our function on AWS Lambda
# Usage:
# docker build -t process_images .
# docker run -v $(pwd):/output process_images
# From https://hint.io/blog/lambda-layer-dependencies and https://gist.github.com/joelmichael/efe48be65d789c555459067b5a54e42d
###############################################################################
# Core
###############################################################################

# Use AWS Lambda ruby2.7 build environment
FROM lambci/lambda:build-ruby2.7

# Update all existing packages
RUN yum update -y

# Optimize compilation for size to try and stay below Lambda's 250 MB limit
# This reduces filesize by over 90% (!) compared to the default -O2
ENV CFLAGS "-Os"
ENV CXXFLAGS $CFLAGS

###############################################################################
# Leptonica
###############################################################################

WORKDIR /root

# Leptonica image-reading dependencies
RUN yum install -y libjpeg-devel libpng-devel libtiff-devel

RUN curl -O http://www.leptonica.org/source/leptonica-1.79.0.tar.gz
RUN tar zxvf leptonica-1.79.0.tar.gz

WORKDIR leptonica-1.79.0
RUN ./configure --prefix=/opt
RUN make install

###############################################################################
# Tesseract OCR
###############################################################################

WORKDIR /root

# Optional Tesseract foreign language training dependencies
# libicu-devel on Yum is of insufficient version (50, 52 is required)
# These are also not really necessary for our usage.
#RUN yum install -y libicu-devel pango-devel cairo-devel

RUN curl -Lo tesseract-4.1.1.tar.gz \
  https://github.com/tesseract-ocr/tesseract/archive/4.1.1.tar.gz
RUN tar zxvf tesseract-4.1.1.tar.gz

WORKDIR tesseract-4.1.1
RUN ./autogen.sh --prefix=/opt
# These ENV vars have to be set or it will not build
ENV LEPTONICA_CFLAGS -I/opt/include/leptonica
ENV LEPTONICA_LIBS -L/opt/lib -lleptonica
RUN ./configure --prefix=/opt
RUN make install

# English training data
WORKDIR /opt/share/tessdata
RUN curl -LO https://github.com/tesseract-ocr/tessdata_best/raw/main/eng.traineddata

###############################################################################
# GhostScript
###############################################################################

WORKDIR /root

RUN curl -LO \
  https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs952/ghostscript-9.52.tar.gz
RUN tar zxvf ghostscript-9.52.tar.gz

WORKDIR ghostscript-9.52
RUN ./configure --prefix=/opt
RUN make install

###############################################################################
# libvips
###############################################################################

# WORKDIR /root

# RUN yum install -y gtk-doc gobject-introspection-devel expat-devel

# RUN curl -o libvips-8.9.1.tar.gz \
#   https://codeload.github.com/libvips/libvips/tar.gz/v8.9.1
# RUN tar zxvf libvips-8.9.1.tar.gz

# WORKDIR libvips-8.9.1
# RUN ./autogen.sh --prefix=/opt/libvips
# RUN ./configure --prefix=/opt/libvips
# RUN make install

# WORKDIR /opt/libvips
# RUN zip -r /root/zips/libvips.zip *

###############################################################################
# ImageMagick
###############################################################################

WORKDIR /root

RUN yum install -y ghostscript-devel openjpeg2 opentjpeg2-devel openjpeg2-tools

RUN curl -Lo ImageMagick-7.0.10-6.tar.gz \
  https://github.com/ImageMagick/ImageMagick/archive/7.0.10-6.tar.gz
RUN tar zxvf ImageMagick-7.0.10-6.tar.gz

WORKDIR ImageMagick-7.0.10-6
RUN ./configure --prefix=/opt
RUN make install


###############################################################################
# Poppler
###############################################################################

WORKDIR /root
RUN yum install -y poppler poppler-utils

###############################################################################
# RPM dependencies
###############################################################################

WORKDIR /root

# Install yumdownloader and rpmdev-extract
RUN yum install -y yum-utils rpmdevtools

RUN mkdir rpms
WORKDIR rpms

# Download dependency RPMs
RUN yumdownloader libjpeg-turbo.x86_64 libpng.x86_64 libtiff.x86_64 \
  libgomp.x86_64 libwebp.x86_64 jbigkit-libs.x86_64 openjpeg2.x86_64

# Download poppler dependncies
RUN yumdownloader poppler.x86_64 poppler-utils.x86_64 openjpeg-libs.x86_64 poppler-data \
  cairo.x86_64 hwdata.x86_64 libXdamage.x86_64 libdrm.x86_64 libglvnd.x86_64 \
  libglvnd-egl.x86_64 libglvnd-glx.x86_64 libpciaccess.x86_64 \
  libwayland-client.x86_64 libwayland-server.x86_64 libxshmfence.x86_64 \
  mesa-libEGL.x86_64 mesa-libGL.x86_64 mesa-libgbm.x86_64 mesa-libglapi.x86_64 \
  lcms2.x86_64 pixman.x86_64 &&\
  cp /usr/lib64/libGLX_mesa.so.0 /opt/lib/libGLX_system.so.0

# GhostScript and dependencies
# To reduce dependencies, we are compiling GhostScript from source instead
# RUN yumdownloader ghostscript.x86_64 cups-libs.x86_64 fontconfig.x86_64 \
#   fontpackages-filesystem freetype.x86_64 ghostscript-fonts jasper-libs.x86_64 \
#   lcms2.x86_64 libICE.x86_64 libSM.x86_64 libX11.x86_64 libX11-common \
#   libXau.x86_64 libXext.x86_64 libXt.x86_64 libfontenc.x86_64 libxcb.x86_64 \
#   poppler-data stix-fonts urw-fonts xorg-x11-font-utils.x86_64 avahi-libs.x86_64 \
#   acl.x86_64 audit-libs.x86_64 cracklib.x86_64 cracklib-dicts.x86_64 cryptsetup-libs.x86_64 \
#   dbus.x86_64 dbus-libs.x86_64 device-mapper.x86_64 device-mapper-libs.x86_64 \
#   elfutils-default-yama-scope elfutils-libs.x86_64 gzip.x86_64 kmod.x86_64 kmod-libs.x86_64 \
#   libcap-ng.x86_64 libfdisk.x86_64 libpwquality.x86_64 libsemanage.x86_64 \
#   libsmartcols.x86_64 libutempter.x86_64 lz4.x86_64 pam.x86_64 qrencode-libs.x86_64 \
#   shadow-utils.x86_64 systemd.x86_64 systemd-libs.x86_64 ustr.x86_64 util-linux.x86_64 \
#   expat.x86_64 xz-libs.x86_64 libgcrypt.x86_64 libgpg-error.x86_64 elfutils-libelf.x86_64 \
#   bzip2-libs.x86_64

# Extract RPMs
RUN rpmdev-extract *.rpm
RUN rm *.rpm

# Copy all package files into /opt/rpms
RUN cp -vR */usr/* /opt

# The x86_64 packages extract as lib64, we need to move these files to lib
RUN yum install -y rsync
RUN rsync -av /opt/lib64/ /opt/lib/
# One of the libs is a symlink. we have to break the symlink and make it a copy or pdfinfo just crashes.
RUN rm -r /opt/lib64 && \
  unlink /opt/lib/libGLX_system.so.0 && cp /usr/lib64/libGLX_mesa.so.0 /opt/lib/libGLX_system.so.0

WORKDIR /opt/share/tessdata/configs
RUN mkdir -p /opt/share/tessdata/configs && curl -LO https://raw.githubusercontent.com/tesseract-ocr/tessconfigs/3decf1c8252ba6dbeef0bf908f4b0aab7f18d113/configs/hocr

###############################################################################
# Gems
###############################################################################

WORKDIR /var/task

# # Phashion dependencies
# # Can skip this step because they are already installed above for Leptonica
# #RUN yum install -y libjpeg-devel libpng-devel

# # Copy Gemfile from host into container's current directory
# TODO remove rodeo
COPY derivative_rodeo ./derivative_rodeo
COPY Gemfile* ./

RUN bundle config set --local path build
# RUN bundle config set --local without test development

RUN bundle

###############################################################################
# Zip all dependencies
###############################################################################

WORKDIR /opt
# RUN zip -r /root/ProcessDocumentLayer.zip *

###############################################################################
# Entrypoint: Copy zip file to host
###############################################################################
# TODO remove?
# ENTRYPOINT ["/bin/cp", "/root/ProcessDocumentLayer.zip", "/output"]

CMD "/bin/bash"
