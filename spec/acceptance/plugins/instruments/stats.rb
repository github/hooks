# frozen_string_literal: true

class Stats < Hooks::Plugins::Instruments::StatsBase
  def initialize
    # just a demo implementation
  end

  def success
    log.debug("response success recorded")
  end
end
