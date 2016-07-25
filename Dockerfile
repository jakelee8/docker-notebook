# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

# Ubuntu 16.04 LTS
FROM ubuntu:xenial
MAINTAINER Jake Lee <jake@jakelee.net>
WORKDIR /tmp

# Configure environment
ENV SHELL /bin/bash
ENV NB_USER jake
ENV NB_UID 1000
ENV HOME /home/$NB_USER
ENV PATH=$HOME/.local/bin:$PATH

ENV TINI_VERSION 0.9.0
ENV TINI_SHA256 faafbfb5b079303691a939a747d7f60591f2143164093727e870b289a44d9872

USER root

# Generate localization
RUN LC_ALL= locale-gen --lang $LANG

# Use all available sources
ADD sources.list /etc/apt/sources.list

# Install OS dependencies
ADD packages.txt .
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install --yes --no-install-recommends --purge --auto-remove \
    $(cat packages.txt | \
        sed -nr '/^#/d;/^\s+/d;/\s$/d;/.+/p' | \
        sort -u | \
        sed ':a;N;$!ba;s/\n/ /' \
    )

# Create jake user with UID=1000 and in the 'users' group
RUN useradd -m -s /bin/bash -N -u $NB_UID $NB_USER

# Install start-notebook.sh
ADD start-notebook.sh /usr/local/bin/
RUN chmod ugo+x /usr/local/bin/start-notebook.sh

# Fix permissions
RUN chown -R $NB_USER:users $HOME

USER $NB_USER

# Install Python dependencies
ADD requirements.txt .
RUN mkdir -p pip-cache pip-downloads
RUN pip download \
    --cache-dir pip-cache \
    --disable-pip-version-check \
    --dest pip-downloads \
    --requirement requirements.txt
RUN pip install \
    --cache-dir pip-cache \
    --disable-pip-version-check \
    pip-downloads/*

# # Install Python 2 kernel spec.
# RUN python -m ipykernel install

# # Install mxnet
# RUN git clone --recursive https://github.com/dmlc/mxnet
# WORKDIR /tmp/mxnet
# RUN make -j $(nproc)
# RUN python setup.py --user .
# WORKDIR /tmp
# RUN python mxnet/example/image-classification/train_mnist.py
# RUN rm -rf * $HOME/.cache

# Configure ipython kernel to use matplotlib inline backend by default
RUN mkdir -p $HOME/.ipython/profile_default/startup/
ADD mplimporthook.py $HOME/.ipython/profile_default/startup/

# Configure ipyparallel (allow Docker to kill the container)
RUN ipcluster start -n 1 --daemonize; true

USER root

# Activate ipywidgets
RUN jupyter nbextension enable --py widgetsnbextension --sys-prefix

# Activate ipcluster
RUN jupyter serverextension enable --py ipyparallel --sys-prefix
RUN jupyter nbextension install --py ipyparallel --sys-prefix
RUN jupyter nbextension enable --py ipyparallel --sys-prefix

# Install Tini
ADD https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini tini
RUN echo "$TINI_SHA256 tini" | sha256sum -c -
RUN install tini /usr/local/bin

# Clean up
RUN apt-get clean
RUN rm -rf * $HOME/.cache /var/lib/apt/lists/*

# Configure container startup as root
EXPOSE 8888
VOLUME ["$HOME/notebook"]
WORKDIR $HOME/notebook
ENTRYPOINT ["tini", "--"]
CMD ["start-notebook.sh"]
