# frozen_string_literal: true

class Failbot < Hooks::Plugins::Instruments::FailbotBase
  def initialize
    # just a demo implementation
  end

  def oh_no
    log.error("oh no, something went wrong!")
  end
end
