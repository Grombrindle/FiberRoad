# Stage 1: Build Composer dependencies
FROM composer:2 AS composer

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
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Stage 2: Final runtime image
FROM php:8.3-fpm-alpine

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

# Copy application code and vendor
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