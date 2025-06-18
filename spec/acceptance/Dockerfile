FROM ruby:3.4.4-slim@sha256:93664239ae7e485147c2fa83397fdc24bf7b7f1e15c3ad9d48591828a50a50e7

WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential libyaml-dev curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

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
