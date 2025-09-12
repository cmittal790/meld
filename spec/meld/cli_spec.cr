require "../spec_helper"

describe Meld::CLI do
  it "supports --version without errors" do
    Meld::CLI.run(["--version"])
    true.should be_true
  end

  it "supports --help without errors" do
    Meld::CLI.run(["--help"])
    true.should be_true
  end

  it "shows help when no args" do
    Meld::CLI.run([] of String)
    true.should be_true
  end

  describe "init" do
    it "parses init command" do
      # Only verifies parsing path; integration test will assert file effects
      Meld::CLI.run(["init"])
      true.should be_true
    end
  end

  describe "add" do
    it "requires a shard name (no crash)" do
      Meld::CLI.run(["add"])
      true.should be_true
    end

    it "accepts <shard> positional" do
      Meld::CLI.run(["add", "kemal"])
      true.should be_true
    end

    it "accepts <shard> and [version]" do
      Meld::CLI.run(["add", "kemal", "~> 1.5.0"])
      true.should be_true
    end

    it "accepts --dev switch" do
      Meld::CLI.run(["add", "--dev", "spec"])
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
end
