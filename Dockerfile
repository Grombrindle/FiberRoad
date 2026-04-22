# Stage 1: Build Composer dependencies
FROM composer:2 AS composer
WORKDIR /app
COPY . .
# Install dependencies without dev packages for production efficiency
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Stage 2: Final runtime image
FROM php:8.3-fpm-alpine

# Install system dependencies and PHP extensions required by Laravel
RUN apk add --no-cache \
    nginx \
    supervisor \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    oniguruma-dev \
    libxml2-dev \
    zip \
    unzip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) pdo_mysql mbstring exif pcntl bcmath gd

# Copy application code
COPY . /var/www/html

# Copy vendor folder from the composer stage
COPY --from=composer /app/vendor/ /var/www/html/vendor/

# Copy Nginx configuration file
COPY nginx.conf /etc/nginx/nginx.conf

# Copy Supervisor configuration file
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Set proper permissions for Laravel storage and cache
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Create a directory for PHP-FPM socket
RUN mkdir -p /var/run/php && chown -R www-data:www-data /var/run/php

# Expose port 80 for Nginx
EXPOSE 80

# Start Supervisor which will manage both Nginx and PHP-FPM
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]