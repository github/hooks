# frozen_string_literal: true

require_relative "lib/hooks"

app = Hooks.build(config: "./spec/acceptance/config/hooks.yaml")
run app
