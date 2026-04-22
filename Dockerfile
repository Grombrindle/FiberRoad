# Stage 1: Build Composer dependencies
FROM composer:2 AS composer

# Composer 2 uses PHP 8.3 by default, but we can still install extensions for compatibility.
# However, to ensure platform requirements match PHP 8.4, we'll use a PHP 8.4 base for Composer too.
# Alternatively, we can ignore platform reqs, but better to match.
# Let's use php:8.4-cli for the composer stage to ensure consistent PHP version.
# But composer:2 image is convenient; we'll install extensions and use --ignore-platform-reqs temporarily,
# then the final stage will have PHP 8.4.

RUN apk add --no-cache \
    icu \
    icu-data-full \
    libpng \
    libjpeg-turbo \
    freetype \
    oniguruma \
    libxml2 \
    libzip \
    icu-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    oniguruma-dev \
    libxml2-dev \
    libzip-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure intl \
    && docker-php-ext-install -j$(nproc) \
    pdo_mysql \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    intl \
    zip

WORKDIR /app
COPY . .

# Ignore platform requirements because composer image has PHP 8.3 but we'll run on 8.4
RUN composer install --no-dev --optimize-autoloader --no-interaction --ignore-platform-req=php

# Stage 2: Final runtime image with PHP 8.4
FROM php:8.4-fpm-alpine

RUN apk add --no-cache \
    nginx \
    supervisor \
    icu \
    icu-data-full \
    libpng \
    libjpeg-turbo \
    freetype \
    oniguruma \
    libxml2 \
    libzip \
    && apk add --no-cache --virtual .build-deps \
    icu-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    oniguruma-dev \
    libxml2-dev \
    libzip-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure intl \
    && docker-php-ext-install -j$(nproc) \
    pdo_mysql \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    intl \
    zip \
    && apk del .build-deps

# Copy application code and vendor from composer stage
COPY . /var/www/html
COPY --from=composer /app/vendor /var/www/html/vendor

# Copy service configurations
COPY nginx.conf /etc/nginx/nginx.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Set permissions and prepare directories
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache \
    && mkdir -p /var/run/php \
    && chown -R www-data:www-data /var/run/php \
    && mkdir -p /var/log/supervisor \
    && chown -R www-data:www-data /var/log/supervisor

EXPOSE 80

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]