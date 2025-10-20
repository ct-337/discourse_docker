FROM alpine:3.18

ENV RUBY_VERSION=3.2.2
ENV LANG=C.UTF-8
ENV RUBY_ROOT=/opt/ruby
ENV GEM_HOME=$RUBY_ROOT/lib/ruby/gems/3.2.0
ENV GEM_PATH=$GEM_HOME
ENV PATH=$RUBY_ROOT/bin:$GEM_HOME/bin:$PATH
ENV BUNDLE_PATH=/app/vendor/bundle

RUN apk update && apk add --no-cache \
  bash build-base curl git libxml2-dev libxslt-dev \
  libffi-dev yaml-dev readline-dev zlib-dev \
  openssl openssl-dev gmp-dev libpq-dev jemalloc-dev \
  imagemagick libjpeg-turbo-dev libpng-dev \
  nodejs npm pkgconfig

WORKDIR /tmp
RUN curl -O https://cache.ruby-lang.org/pub/ruby/3.2/ruby-${RUBY_VERSION}.tar.gz && \
    tar -xzf ruby-${RUBY_VERSION}.tar.gz && \
    cd ruby-${RUBY_VERSION} && \
    ./configure --prefix=$RUBY_ROOT \
      --with-openssl-dir=/usr/include/openssl \
      --with-jemalloc \
      --enable-shared \
      --enable-load-relative && \
    make -j$(nproc) && make install && \
    cd .. && rm -rf ruby-${RUBY_VERSION}*

RUN gem update --system && gem install bundler -v 2.4.4 && \
    ln -sf $(which bundle) /usr/bin/bundle && \
    ln -sf $(which bundler) /usr/bin/bundler

RUN git clone https://github.com/discourse/discourse.git /app
WORKDIR /app

RUN rm -rf vendor/bundle tmp/cache \
    && find . -name '*.so' -delete \
    && find . -name '*.bundle' -delete

RUN bundle config set --local path "$BUNDLE_PATH" && \
    bundle config set --local without 'development test' && \
    bundle install --jobs=2 --retry=3

RUN bundle exec rake plugin:install['https://github.com/discourse/docker_manager.git']
RUN bundle exec rake assets:precompile

EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
