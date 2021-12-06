#!/bin/sh

export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
export INITRD=no

export container=docker

export > /etc/envvars

exec /sbin/runit-init
