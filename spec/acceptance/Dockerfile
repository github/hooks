FROM ruby:3.4.2-slim@sha256:342bfeb04d3660045ceba063197d22baafec6b163f019714ddf8fc83c59aabee

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential libyaml-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# create nonroot user
RUN useradd -m nonroot

COPY --chown=nonroot:nonroot lib/hooks/version.rb ./lib/hooks/version.rb
COPY --chown=nonroot:nonroot .ruby-version Gemfile Gemfile.lock hooks.gemspec ./
COPY --chown=nonroot:nonroot vendor/cache ./vendor/cache
COPY --chown=nonroot:nonroot script ./script
COPY --chown=nonroot:nonroot .bundle ./.bundle

RUN script/bootstrap

COPY --chown=nonroot:nonroot . .

# switch to the nonroot user
USER nonroot
