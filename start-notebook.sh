#!/bin/bash

# Handle special flags if we're root
if [ $UID -eq 0 ] ; then
    # Change UID of NB_USER to NB_UID if it does not match
    if [ $NB_UID -ne $(id -u $NB_USER) ]; then
        usermod -u $NB_UID $NB_USER
        chown -R $NB_UID $HOME
    fi

    # Set permissions on workdir
    chown -R $NB_UID ~

    # Enable sudo if requested
    if [ ! -z "$GRANT_SUDO" ]; then
        echo "$NB_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/notebook
    fi

    # Start the notebook server
    exec su $NB_USER -c "env PATH=$PATH jupyter notebook $*"
else
    # Otherwise just exec the notebook
    exec jupyter notebook $*
fi
