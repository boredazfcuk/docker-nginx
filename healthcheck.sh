#!/bin/ash

wget --quiet --tries=1 --spider "http://${HOSTNAME}/robots.txt" || exit 1

if [ ! -z "${HTTPS}" ] && [ "${HTTPS}" = "True" ]; then
   wget --quiet --tries=1 --spider "https://${HOSTNAME}/robots.txt" --no-check-certificate || exit 1
fi