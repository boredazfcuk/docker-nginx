#!/bin/ash
EXIT_CODE=0
EXIT_CODE="$(wget --quiet --tries=1 --spider "http://${HOSTNAME}/robots.txt" | echo ${?})"
if [ "${EXIT_CODE}" != 0 ]; then
   echo "HTTP check failed with error: ${EXIT_CODE}"
   exit 1
fi
if [ ! -z "${HTTPS}" ] && [ "${HTTPS}" = "True" ]; then
   EXIT_CODE="$(wget --quiet --tries=1 --spider --no-check-certificate "https://${HOSTNAME}/robots.txt" | echo ${?})"
   if [ "${EXIT_CODE}" != 0 ]; then
      echo "HTTPS check failed with error: ${EXIT_CODE}"
      exit 1
   fi
   echo -n "HTTPS and "
fi
echo "HTTP connection$(if [ "${HTTPS}" = "True" ]; then echo s; fi) available"
exit 0