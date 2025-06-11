# frozen_string_literal: true

module Hooks
  module Security
    # List of dangerous class names that should not be loaded as handlers
    # for security reasons. These classes provide system access that could
    # be exploited if loaded dynamically.
    #
    # @return [Array<String>] Array of dangerous class names
    DANGEROUS_CLASSES = %w[
      File Dir Kernel Object Class Module Proc Method
      IO Socket TCPSocket UDPSocket BasicSocket
      Process Thread Fiber Mutex ConditionVariable
      Marshal YAML JSON Pathname
    ].freeze
  end
end
