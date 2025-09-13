# spec/meld/project_spec.cr

require "../spec_helper"
require "file_utils"

# Helper: isolated temp directory per call
def with_tmpdir(&block : String ->)
  base = Dir.tempdir
  path = File.join(base, "meld_project_spec_#{Time.utc.to_unix_ns}")
  Dir.mkdir(path)
  begin
    Dir.cd(path) { yield path }
  ensure
    FileUtils.rm_r(path) if Dir.exists?(path)
  end
end

# Helper: minimal shard.yml for add tests
def write_minimal_shard_yml
  File.write("shard.yml", <<-YAML)
  name: test
  version: 0.1.0
  authors:
  - "X <x@y>"
  description: "d"
  crystal: ">= 1.0.0"
  license: MIT
  targets:
    test:
      main: src/test.cr
  dependencies: {}
  YAML
end

# Helper: build selector
def selector(type : Meld::Project::SelectorType, value : String = "") : Meld::Project::AddSelector
  s = Meld::Project::AddSelector.new
  s.type = type
  s.value = value
  s
end

# Helper: extract a dependency block by name (best-effort YAML-ish parsing)
def extract_dep_block(yaml_text : String, dep_name : String) : String
  lines = yaml_text.lines
  # locate the 'dep_name:' line with any leading spaces
  idx = lines.index { |ln| ln.lstrip.starts_with?("#{dep_name}:") }
  raise "dependency '#{dep_name}' not found" unless idx
  block = [] of String
  block << lines[idx]
  j = idx + 1
  # Capture following indented lines (at least two spaces) until a non-indented or blank line of lesser indent breaks
  while j < lines.size
    ln = lines[j]
    # stop if next top-level key or lesser indent (starts with no spaces)
    break if ln.match(/^([^\s]|$)/)
    # keep indented lines (2+ spaces)
    if ln.match(/^\s{2,}\S/)
      block << ln
      j += 1
    else
      break
    end
  end
  block.join
end

describe Meld::Project do
  describe ".init" do
    it "creates shard.yml when absent" do
      with_tmpdir do
        File.exists?("shard.yml").should be_false
        Meld::Project.init
        File.exists?("shard.yml").should be_true
        content = File.read("shard.yml")
        content.should contain("name:")
        content.should contain("dependencies:")
      end
    end

    it "does not overwrite existing shard.yml" do
      with_tmpdir do
        File.write("shard.yml", "name: keepme\ndependencies: {}\n")
        original = File.read("shard.yml")
        Meld::Project.init
        File.read("shard.yml").should eq(original)
      end
    end
  end

  describe ".add" do
    it "returns when shard.yml missing" do
      with_tmpdir do
        File.exists?("shard.yml").should be_false
        Meld::Project.add("kemal", selector(Meld::Project::SelectorType::Version, "~> 1.5.0"), false)
        File.exists?("shard.yml").should be_false
      end
    end

    it "adds dependency with version selector" do
      with_tmpdir do
        write_minimal_shard_yml
        Meld::Project.add("kemal", selector(Meld::Project::SelectorType::Version, "~> 1.5.0"), false)
        c = File.read("shard.yml")
        c.should contain("dependencies:")
        c.should contain("kemal:")
        c.should contain("github: kemalcr/kemal")
        kemal_block = extract_dep_block(c, "kemal")
        kemal_block.should contain(%(version: "~> 1.5.0"))
      end
    end

    it "adds dependency unpinned when selector is empty version" do
      with_tmpdir do
        write_minimal_shard_yml
        Meld::Project.add("kemal", selector(Meld::Project::SelectorType::Version, ""), false)
        c = File.read("shard.yml")
        c.should contain("dependencies:")
        c.should contain("kemal:")
        c.should contain("github: kemalcr/kemal")
        kemal_block = extract_dep_block(c, "kemal")
        kemal_block.includes?("version:").should be_false
      end
    end

    it "adds development dependency under development_dependencies" do
      with_tmpdir do
        File.write("shard.yml", <<-YAML)
        name: test
        version: 0.1.0
        authors:
        - "X <x@y>"
        description: "d"
        crystal: ">= 1.0.0"
        license: MIT
        targets:
          test:
            main: src/test.cr
        dependencies: {}
        YAML

        Meld::Project.add("spec", selector(Meld::Project::SelectorType::Version, "~> 1.0.0"), true)
        c = File.read("shard.yml")
        c.should contain("development_dependencies:")
        c.should contain("spec:")
        c.should contain("github: crystal-lang/spec")
        spec_block = extract_dep_block(c, "spec")
        spec_block.should contain(%(version: "~> 1.0.0"))
      end
    end

    it "appends to existing dependencies section" do
      with_tmpdir do
        File.write("shard.yml", <<-YAML)
        name: test
        version: 0.1.0
        authors:
        - "X <x@y>"
        description: "d"
        crystal: ">= 1.0.0"
        license: MIT
        targets:
          test:
            main: src/test.cr
        dependencies:
          colorize:
            github: crystal-lang/colorize
            version: "~> 0.2.0"
        YAML

        Meld::Project.add("kemal", selector(Meld::Project::SelectorType::Version, "~> 1.5.0"), false)
        c = File.read("shard.yml")
        c.should contain("colorize:")
        c.should contain("kemal:")
      end
    end

    it "supports github: specifier via version value" do
      with_tmpdir do
        write_minimal_shard_yml
        Meld::Project.add("foo", selector(Meld::Project::SelectorType::Version, "github:bar/baz"), false)
        File.read("shard.yml").should contain("github: bar/baz")
      end
    end

    it "supports git: specifier via version value" do
      with_tmpdir do
        write_minimal_shard_yml
        Meld::Project.add("libgit", selector(Meld::Project::SelectorType::Version, "git:https://example.com/libgit.git"), false)
        c = File.read("shard.yml")
        c.should contain("libgit:")
        c.should contain("git: https://example.com/libgit.git")
      end
    end

    it "writes tag selector" do
      with_tmpdir do
        write_minimal_shard_yml
        Meld::Project.add("kemal", selector(Meld::Project::SelectorType::Tag, "v1.3.0"), false)
        c = File.read("shard.yml")
        kemal_block = extract_dep_block(c, "kemal")
        kemal_block.should contain("tag: v1.3.0")
      end
    end

    it "writes branch selector" do
      with_tmpdir do
        write_minimal_shard_yml
        Meld::Project.add("kemal", selector(Meld::Project::SelectorType::Branch, "main"), false)
        c = File.read("shard.yml")
        kemal_block = extract_dep_block(c, "kemal")
        kemal_block.should contain("branch: main")
      end
    end

    it "writes commit selector" do
      with_tmpdir do
        write_minimal_shard_yml
        Meld::Project.add("kemal", selector(Meld::Project::SelectorType::Commit, "deadbeef"), false)
        c = File.read("shard.yml")
        kemal_block = extract_dep_block(c, "kemal")
        kemal_block.should contain("commit: deadbeef")
      end
    end
  end

  describe ".set_metadata" do
    it "updates selected fields" do
      with_tmpdir do
        File.write("shard.yml", <<-YAML)
        name: test
        version: 0.1.0
        authors:
        - "A <a@a>"
        description: "old"
        crystal: ">= 1.0.0"
        license: MIT
        targets:
          test:
            main: src/test.cr
        dependencies: {}
        YAML

        Meld::Project.set_metadata(
          name: "newname",
          version: "0.2.0",
          author: "B <b@b>",
          description: "new desc",
          crystal_version: ">= 1.5.0",
          license: "Apache-2.0"
        )

        c = File.read("shard.yml")
        c.should contain("name: newname")
        c.should contain("version: 0.2.0")
        c.should contain(%(- "B <b@b>"))
        c.should contain(%(description: "new desc"))
        c.should contain(%(crystal: ">= 1.5.0"))
        c.should contain("license: Apache-2.0")
      end
    end

    it "returns when shard.yml missing" do
      with_tmpdir do
        File.exists?("shard.yml").should be_false
        Meld::Project.set_metadata(name: "x")
        File.exists?("shard.yml").should be_false
      end
    end
  end

  describe ".search" do
    it "runs without raising" do
      with_tmpdir do
        Meld::Project.search("web framework")
        true.should be_true
      end
    end
  end

  describe ".install" do
    it "returns when shard.yml missing" do
      with_tmpdir do
        File.exists?("shard.yml").should be_false
        Meld::Project.install
        File.exists?("shard.yml").should be_false
      end
    end
  end

  describe ".update" do
    it "accepts shard-name path" do
      with_tmpdir do
        Meld::Project.update("kemal")
        true.should be_true
      end
    end

    it "accepts all-shards path" do
      with_tmpdir do
        Meld::Project.update
        true.should be_true
      end
    end
  end

  describe ".exec" do
    it "accepts command string" do
      with_tmpdir do
        Meld::Project.exec("echo hello")
        true.should be_true
      end
    end
  end

  describe ".binstubs" do
    it "prints message path" do
      with_tmpdir do
        Meld::Project.binstubs("ameba")
        true.should be_true
      end
    end
  end
end
