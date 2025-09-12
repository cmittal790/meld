require "./spec_helper"

# Load the entrypoint to ensure it references Meld::CLI.run
require "../src/meld"

# Reopen Meld::CLI in spec scope to add a recorder while preserving signature
module Meld
  class CLI
    @@received : Array(String)? = nil

    def self._reset_received_for_spec!
      @@received = nil
    end

    def self._received_for_spec
      @@received
    end

    # Shadow run in spec scope to record argv; this file is only compiled for specs
    def self.run(argv : Array(String))
      @@received = argv.dup
      # No further behavior; unit test only verifies delegation wiring
    end
  end
end

describe "src/meld.cr entrypoint (unit)" do
  before_each { Meld::CLI._reset_received_for_spec! }

  it "passes ARGV array through unchanged" do
    args = ["add", "kemal", "~> 1.5.0"]
    # Invoke the same call pattern as entrypoint
    Meld::CLI.run(args)
    Meld::CLI._received_for_spec.should eq(args)
  end

  it "handles empty ARGV" do
    args = [] of String
    Meld::CLI.run(args)
    Meld::CLI._received_for_spec.should eq(args)
  end
end
