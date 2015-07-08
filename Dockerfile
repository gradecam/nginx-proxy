FROM nginx:1.9.2
MAINTAINER Richard Bateman rbateman@gradecam.com
ENV NGINX_VERSION=1.8.0

# Credit where due; this is forked from a project maintained by:
#MAINTAINER Jason Wilder jwilder@litl.com

# Create needed user, directories
RUN mkdir -p /var/cache/nginx \
 && chown -R nginx: /var/cache/nginx

# Install wget and install/updates certificates
RUN apt-get update \
 && apt-get install -y -q --no-install-recommends \
    ca-certificates \
    curl libxml2 libxslt1.1 libgd3 libgeoip1 libpcre3 \
    wget

WORKDIR /usr/src/

# Get extra nginx modules we want to compile in
RUN curl -L https://github.com/yaoweibin/ngx_http_substitutions_filter_module/archive/v0.6.4.tar.gz -o ngx_http_substitutions_filter_module.tar.gz \
    && tar xvzf ngx_http_substitutions_filter_module.tar.gz \
    && rm -f ngx_http_substitutions_filter_module.tar.gz \
    && mv ngx_http_substitutions_filter_module* ngx_http_substitutions_filter_module/

# Get nginx source
RUN curl -L -o nginx.tar.gz http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
    && tar xvzf nginx.tar.gz \
    && rm -f nginx.tar.gz \
    && mv nginx-*/ nginx/

WORKDIR /usr/src/nginx

# install needed build packages, configure / build nginx, and then remove them
RUN apt-get install -y build-essential libxml2-dev libxslt1-dev libgd-dev libgeoip-dev libpcre3-dev libssl-dev 
RUN ./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=nginx \
    --group=nginx \
    --with-http_ssl_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_stub_status_module \
    --with-http_dav_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-file-aio \
    --with-ipv6 \
    --with-http_spdy_module \
    --with-http_image_filter_module \
    --with-http_geoip_module \
    --with-pcre \
    --with-http_xslt_module \
    --add-module=../ngx_http_substitutions_filter_module \
    --with-cc-opt='-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector --param=ssp-buffer-size=4 -m64 -mtune=generic' \
 && make install \
 && apt-get purge -y build-essential libxml2-dev libxslt1-dev libgd-dev libpcre3-dev libssl-dev \
 && apt-get autoremove -y \
 && apt-get clean \
 && rm -r /var/lib/apt/lists/*

# Configure Nginx and apply fix for very long server names
RUN echo "daemon off;" >> /etc/nginx/nginx.conf \
 && sed -i 's/^http {/&\n    server_names_hash_bucket_size 128;/g' /etc/nginx/nginx.conf

# Install Forego
RUN wget -P /usr/local/bin https://godist.herokuapp.com/projects/ddollar/forego/releases/current/linux-amd64/forego \
 && chmod u+x /usr/local/bin/forego

ENV DOCKER_GEN_VERSION 0.4.0

WORKDIR /

RUN wget https://github.com/jwilder/docker-gen/releases/download/$DOCKER_GEN_VERSION/docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz \
 && tar -C /usr/local/bin -xvzf docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz \
 && rm /docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz

COPY . /app/
WORKDIR /app/

ENV DOCKER_HOST unix:///tmp/docker.sock

VOLUME ["/etc/nginx/certs"]

CMD ["forego", "start", "-r"]
