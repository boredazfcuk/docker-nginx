FROM nginx:mainline-alpine
MAINTAINER boredazfcuk
ARG app_dependencies="shadow apache2-utils"
ENV config_dir="/etc/nginx" 

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD STARTED *****" && \
   mkdir "${config_dir}/locations/" && \
   echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install dependencies" && \
   apk add --no-cache --no-progress ${app_dependencies} && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Add nginx GeoIP module" && \
   apk add --no-cache --no-progress nginx-mod-http-geoip && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Backup default nginx config" && \
   mv -v "/usr/share/nginx/html" "/usr/share/nginx/html.default" && \
   mv -v "${config_dir}/nginx.conf" "${config_dir}/nginx.conf.default" && \
   mv -v "${config_dir}/conf.d/default.conf" "${config_dir}/conf.d/default.conf.default"

COPY nginx/* "${config_dir}/"
COPY conf.d/* "${config_dir}/conf.d/"
COPY locations/* "${config_dir}/locations/"
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh

RUN echo  "$(date '+%d/%m/%Y - %H:%M:%S') | Set permissions on scripts" && \
   chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD COMPLETE *****"

HEALTHCHECK --start-period=10s --interval=1m --timeout=10s \
   CMD /usr/local/bin/healthcheck.sh

VOLUME "${config_dir}" /var/cache/nginx/

ENTRYPOINT "/usr/local/bin/entrypoint.sh"