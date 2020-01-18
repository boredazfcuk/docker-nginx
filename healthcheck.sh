#!/bin/ash
exit_code=0
exit_code="$(wget --quiet --tries=1 --spider "http://${HOSTNAME}/robots.txt" | echo ${?})"
if [ "${exit_code}" != 0 ]; then
   echo "HTTP check failed with error: ${exit_code}"
   exit 1
fi
if [ ! -z "${HTTPS}" ] && [ "${HTTPS}" = "True" ]; then
   exit_code="$(wget --quiet --tries=1 --spider --no-check-certificate "https://${HOSTNAME}/robots.txt" | echo ${?})"
   if [ "${exit_code}" != 0 ]; then
      echo "HTTPS check failed with error: ${exit_code}"
      exit 1
   fi
   echo -n "HTTPS and "
fi
echo "HTTP connection$(if [ "${HTTPS}" = "True" ]; then echo s; fi) available"
exit 0