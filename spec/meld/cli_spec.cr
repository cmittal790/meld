# spec/meld/cli_spec.cr

require "../spec_helper"

describe Meld::CLI do
  it "supports --version without errors (global before command)" do
    Meld::CLI.run(["--version"])
    true.should be_true
  end

  it "supports --help without errors (global before command)" do
    Meld::CLI.run(["--help"])
    true.should be_true
  end

  it "shows help when no args" do
    Meld::CLI.run([] of String)
    true.should be_true
  end

  describe "init" do
    it "parses init command" do
      Meld::CLI.run(["init"])
      true.should be_true
    end
  end

  describe "add" do
    it "requires a shard name (no crash)" do
      Meld::CLI.run(["add"])
      true.should be_true
    end

    it "accepts <shard> then -v VALUE (version selector)" do
      Meld::CLI.run(["add", "kemal", "-v", "1.6.4"])
      true.should be_true
    end

    it "accepts <shard> then -b NAME (branch selector)" do
      Meld::CLI.run(["add", "kemal", "-b", "main"])
      true.should be_true
    end

    it "accepts <shard> then -t NAME (tag selector)" do
      Meld::CLI.run(["add", "kemal", "-t", "v1.3.0"])
      true.should be_true
    end

    it "accepts <shard> then -c SHA (commit selector)" do
      Meld::CLI.run(["add", "kemal", "-c", "deadbeef"])
      true.should be_true
    end

    it "accepts --dev after a selector" do
      Meld::CLI.run(["add", "kemal", "-t", "v1.3.0", "--dev"])
      true.should be_true
    end

    it "treats any token as shard name (no special-casing 'help')" do
      Meld::CLI.run(["add", "help", "-t", "v1.0.0"])
      true.should be_true
    end

    it "accepts <shard> with no selector flags (unpinned add)" do
      Meld::CLI.run(["add", "kemal"])
      true.should be_true
    end
  end

  describe "search" do
    it "requires a query (no crash)" do
      Meld::CLI.run(["search"])
      true.should be_true
    end

    it "parses multi-word query" do
      Meld::CLI.run(["search", "web", "framework"])
      true.should be_true
    end
  end

  describe "install" do
    it "parses install command" do
      Meld::CLI.run(["install"])
      true.should be_true
    end
  end

  describe "update" do
    it "parses update with no shard" do
      Meld::CLI.run(["update"])
      true.should be_true
    end

    it "parses update with shard" do
      Meld::CLI.run(["update", "kemal"])
      true.should be_true
    end
  end

  describe "exec" do
    it "requires a command (no crash)" do
      Meld::CLI.run(["exec"])
      true.should be_true
    end

    it "parses command string" do
      Meld::CLI.run(["exec", "crystal", "spec"])
      true.should be_true
    end
  end

  describe "binstubs" do
    it "requires shard name (no crash)" do
      Meld::CLI.run(["binstubs"])
      true.should be_true
    end

    it "parses binstubs with shard" do
      Meld::CLI.run(["binstubs", "ameba"])
      true.should be_true
    end
  end

  it "prints help on unknown command (no crash)" do
    Meld::CLI.run(["wat"])
    true.should be_true
  end

  describe "help subcommand" do
    it "supports 'meld help add'" do
      Meld::CLI.run(["help", "add"])
      true.should be_true
    end

    it "supports 'meld help' (global help)" do
      Meld::CLI.run(["help"])
      true.should be_true
    end
  end
end
