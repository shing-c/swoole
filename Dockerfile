FROM php:7.2-fpm

# 定义扩展版本号 #redis 扩展 
ENV PHPREDIS_VERSION 4.0.0 
#swoole 扩展 
ENV SWOOLE_VERSION 4.4.12
ENV MSGPACK_VERSION 2.0.3
ENV HIREDIS_VERSION 0.14.0

# 设置时间 
ENV TIME_ZONE Asia/Shanghai
RUN /bin/cp /usr/share/zoneinfo/$TIME_ZONE /etc/localtime && echo $TIME_ZONE > /etc/timezone

# 使用 阿里源 替换
RUN sed -i "s@http://deb.debian.org@http://mirrors.aliyun.com@g" /etc/apt/sources.list && rm -Rf /var/lib/apt/lists/* &&  cat /etc/apt/sources.list

# 一些既不在 PHP 源码包，也不再 PECL 扩展仓库中的扩展，使用apt直接安装扩展 
RUN apt-get update && apt-get install -y \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libssl-dev \
    libz-dev \
    libnghttp2-dev \
    libpcre3-dev \
    libmemcached-dev \
    zlib1g-dev \
    libmcrypt-dev \
    libpng-dev \
    curl \
    wget \
    git \
    zip \
    && docker-php-ext-install -j$(nproc) iconv \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    #Mysqli 扩展 
    && docker-php-ext-install mysqli \
    # PDO 扩展 
    && docker-php-ext-install pdo_mysql \
    #Bcmath
    && docker-php-ext-install bcmath

# composer
RUN curl -sS https://getcomposer.org/installer | php \
    && mv composer.phar /usr/local/bin/composer \
    && composer self-update --clean-backups

# use aliyun composer
RUN composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/

# 一些不包含在PHP源码文件中，但是PHP 的扩展库仓库中存在的扩展。用 pecl install 安装扩展，再用 docker-php-ext-enable 命令启用扩展 
RUN wget http://pecl.php.net/get/redis-${PHPREDIS_VERSION}.tgz -O /tmp/redis.tgz \
    && pecl install /tmp/redis.tgz \
    && rm -rf /tmp/redis.tgz \
    && docker-php-ext-enable redis 
#msgpack 扩展下载 pecl本地安装 开启扩展(延迟队列使用减少源数据占用空间) 
RUN wget http://pecl.php.net/get/msgpack-${MSGPACK_VERSION}.tgz -O /tmp/msgpack.tgz \
    && pecl install /tmp/msgpack.tgz \
    && rm -rf /tmp/msgpack.tgz \
    && docker-php-ext-enable msgpack 
#Hiredis依赖安装 
RUN wget https://github.com/redis/hiredis/archive/v${HIREDIS_VERSION}.tar.gz -O /tmp/hiredis.tar.gz \
    && mkdir -p /tmp/hiredis \
    && tar -xf /tmp/hiredis.tar.gz -C /tmp/hiredis --strip-components=1 \
    && rm /tmp/hiredis.tar.gz \
    && (\
    cd /tmp/hiredis&&make -j $(nproc) && make install && ldconfig \
    ) && rm -r /tmp/hiredis 
# Swoole 扩展安装 开启扩展 
RUN wget https://github.com/swoole/swoole-src/archive/v${SWOOLE_VERSION}.tar.gz -O /tmp/swoole.tar.gz \
    && mkdir -p /tmp/swoole \
    && tar -xf/tmp/swoole.tar.gz -C /tmp/swoole --strip-components=1 \
    && rm /tmp/swoole.tar.gz \
    && (\
    cd /tmp/swoole && phpize  && ./configure --enable-async-redis --enable-mysqlnd --enable-openssl --enable-http2 \
    && make -j$(nproc) && make install \
    ) && rm -r /tmp/swoole \
    && docker-php-ext-enable swoole
