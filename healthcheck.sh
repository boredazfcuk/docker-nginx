#!/bin/ash

wget --quiet --tries=1 --spider "http://${HOSTNAME}/robots.txt" && exit 0 || echo "http check failed"; exit 1

if [ ! -z "${HTTPS}" ] && [ "${HTTPS}" = "True" ]; then
   wget --quiet --tries=1 --spider "https://${HOSTNAME}/robots.txt" --no-check-certificate && exit 0 || echo "https check failed"; exit 1
fi

exit 0