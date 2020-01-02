FROM nginx:mainline-alpine
MAINTAINER boredazfcuk
ARG APPDEPENDENCIES="shadow apache2-utils"
ENV CONFIGDIR="/etc/nginx" 

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD STARTED *****" && \
   echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install dependencies" && \
   apk add --no-cache --no-progress ${APPDEPENDENCIES} && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Add nginx GeoIP module" && \
   apk add --no-cache --no-progress nginx-mod-http-geoip && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Backup default nginx config" && \
   mv -v "/usr/share/nginx/html" "/usr/share/nginx/html.default" && \
   mv -v "${CONFIGDIR}/nginx.conf" "${CONFIGDIR}/nginx.conf.default" && \
   mv -v "${CONFIGDIR}/conf.d/default.conf" "${CONFIGDIR}/conf.d/default.conf.default" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Configure logging" && \
   ln -sfv /var/log/nginx/access.log /dev/stdout && \
   ln -sfv /var/log/nginx/error.log /dev/stderr

COPY nginx/* "${CONFIGDIR}/"
COPY conf.d/* "${CONFIGDIR}/conf.d/"
COPY html/* "${CONFIGDIR}/html/"
COPY locations/* "${CONFIGDIR}/locations/"
COPY start-nginx.sh /usr/local/bin/start-nginx.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh

RUN echo  "$(date '+%d/%m/%Y - %H:%M:%S') | Set permissions on scripts" && \
   chmod +x /usr/local/bin/start-nginx.sh /usr/local/bin/healthcheck.sh && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD COMPLETE *****"

HEALTHCHECK --start-period=10s --interval=1m --timeout=10s \
   CMD /usr/local/bin/healthcheck.sh

VOLUME "${CONFIGDIR}" /var/cache/nginx/

CMD /usr/local/bin/start-nginx.sh