# frozen_string_literal: true
require "erb"
require "simplecov"

class SimpleCov::Formatter::ERBFormatter
  # This is the entry point.
  def format(result)
    File.open(output_filepath, "wb") { |file| file.puts template.result(binding) }
    puts output_message(result)
  end

  # These come as class methods when configured via a spec_helper or similar.
  def self.output_filename=(filename)
    @output_filename = filename
  end

  def self.erb_file=(filename)
    @erb_file = filename
  end

  # This may be called from within an ERB template to get the line numbers with
  # missed coverage.
  #
  # source_file - A source file object from SimpleCov
  #
  # Returns an Array of line numbers whose test coverage is "missed".
  def missed_lines(source_file)
    result = []
    source_file.lines.each_with_index do |line, index|
      result << (index+1) if line.missed?
    end
    result
  end

  # This may be called from within an ERB template to get the file name relative
  # to the SimpleCov root.
  #
  # filename - A String with the full path to the file.
  #
  # Returns a String with the filename relative to the SimpleCov root.
  def shortened_filename(filename)
    if filename.start_with?(SimpleCov.root)
      filename[SimpleCov.root.length..-1]
    else
      filename
    end
  end

  private

  def template
    # This syntax changed between Ruby versions 2.5 and 2.6. Although 2.5 is EOL, this will keep backward
    # compatibility for those who are not yet on 2.6+. We use Gem::Version to compare instead of strings,
    # which are rife with errors.
    if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("2.6.0")
      ERB.new(File.read(erb_file), trim_mode: "-")
    else
      ERB.new(File.read(erb_file), nil, "-")
    end
  end

  def output_message(result)
    "Coverage report generated for #{result.command_name} to #{output_filepath}. #{result.covered_lines} / #{result.total_lines} LOC (#{result.covered_percent.round(2)}%) covered."
  end

  # erb_file is a class variable when set via the configuration, but an instance variable when
  # retrieved. Define it both ways here, so the instance variable defers to the class.
  def self.erb_file
    @erb_file
  end

  def erb_file
    self.class.erb_file || File.expand_path("../views/simplecov.erb", File.dirname(__FILE__))
  end

  # output_filename is a class variable when set via the configuration, but an instance variable when
  # retrieved. Define it both ways here, so the instance variable defers to the class.
  def self.output_filename
    @output_filename
  end

  def output_filename
    self.class.output_filename ? File.basename(self.class.output_filename) : "coverage.txt"
  end

  # Misc. helper methods.
  def output_filepath
    File.join(output_path, output_filename)
  end

  def output_path
    SimpleCov.coverage_path
  end
end
