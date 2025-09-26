# src/meld/cli.cr

require "option_parser"

module Meld
  class CLI
    VERSION = "0.1.0"

    def self.run(argv : Array(String))
      global_argv = [] of String
      subcommand : String? = nil
      sub_args = [] of String

      i = 0
      while i < argv.size
        tok = argv[i]
        if tok.starts_with?("-")
          global_argv << tok
          i += 1
        else
          subcommand = tok
          i += 1
          break
        end
      end
      while i < argv.size
        sub_args << argv[i]
        i += 1
      end

      show_version = false
      show_help = false

      global = OptionParser.new do |parser|
        parser.banner = <<-BANNER
        Meld - Crystal Lang Package Manager

        Usage:
          meld [options] <command> [command options]

        Commands:
          init                               Initialize project (shard.yml)
          add <shard> [-v|-b|-t|-c] [--dev]  Add a shard (pin with version/branch/tag/commit)
          remove <shard>                     Remove a shard from shard.yml and lib/
          search <query>                     Search for available shards
          install                            Install dependencies
          update [shard]                     Update all or a specific shard
          exec <cmd>                         Run a command in project context
          binstubs <shard>                   Generate executable wrappers
          global install <shard> [...]       Build and install shard executables globally
          help [command]                     Show help (global or for a command)

        Options:
        BANNER

        parser.on("-v", "--version", "Show version") { show_version = true }
        parser.on("-h", "--help", "Show help") { show_help = true }

        parser.unknown_args { |_| }
      end

      begin
        global.parse(global_argv)
      rescue ex
        STDERR.puts "Error: #{ex.message}"
        STDERR.puts
        STDERR.puts global
        return
      end

      if subcommand == "help"
        sub = sub_args.shift?
        if sub
          self.print_command_help(sub)
        else
          puts global
        end
        return
      end

      if show_version && subcommand.nil?
        puts "meld #{VERSION}"
        return
      end

      if show_help && subcommand.nil?
        puts global
        return
      end

      if subcommand.nil?
        puts global
        return
      end

      case subcommand
      when "init"
        Meld::Project.init
      when "add"
        add_parser = OptionParser.new do |parser|
          parser.banner = <<-B
          Usage:
            meld add <shard> [-v <version> | -b <branch> | -t <tag> | -c <commit>] [--dev]
          B
        end

        add_dev = false
        opt_version_raw : String? = nil
        opt_branch_raw : String? = nil
        opt_tag_raw : String? = nil
        opt_commit_raw : String? = nil

        add_parser.on("--dev", "Add as development dependency") { add_dev = true }
        add_parser.on("-v VALUE", "--ver VALUE", "Version constraint (e.g. \"~> 1.2.3\" or \"1.6.4\")") { |val| opt_version_raw = val }
        add_parser.on("-b NAME", "--branch NAME", "Git branch to pin") { |val| opt_branch_raw = val }
        add_parser.on("-t NAME", "--tag NAME", "Git tag to pin") { |val| opt_tag_raw = val }
        add_parser.on("-c SHA", "--commit SHA", "Git commit to pin") { |val| opt_commit_raw = val }

        add_shard_raw : String? = nil
        seen_positional = false

        begin
          add_parser.unknown_args do |rest|
            rest.each do |tok|
              if tok.starts_with?("-")
              else
                unless seen_positional
                  add_shard_raw = tok
                  seen_positional = true
                end
              end
            end
          end

          add_parser.parse(sub_args)
        rescue ex
          STDERR.puts "Error: #{ex.message}"
          STDERR.puts
          STDERR.puts add_parser
          return
        end

        add_shard = (add_shard_raw || "").to_s
        v_commit = (opt_commit_raw || "").to_s
        v_tag = (opt_tag_raw || "").to_s
        v_branch = (opt_branch_raw || "").to_s
        v_version = (opt_version_raw || "").to_s

        if add_shard.strip.empty?
          STDERR.puts "Error: shard name required"
          STDERR.puts
          STDERR.puts add_parser
          return
        end

        selector = Meld::Project::AddSelector.new
        if !v_commit.empty?
          selector.type = Meld::Project::SelectorType::Commit
          selector.value = v_commit
        elsif !v_tag.empty?
          selector.type = Meld::Project::SelectorType::Tag
          selector.value = v_tag
        elsif !v_branch.empty?
          selector.type = Meld::Project::SelectorType::Branch
          selector.value = v_branch
        elsif !v_version.empty?
          selector.type = Meld::Project::SelectorType::Version
          selector.value = v_version
        else
          selector.type = Meld::Project::SelectorType::Version
          selector.value = ""
        end

        Meld::Project.add(add_shard, selector, add_dev)
      when "remove"
        rm_parser = OptionParser.new do |parser|
          parser.banner = "Usage:\n  meld remove <shard>\n"
        end

        rm_shard_raw : String? = nil
        begin
          rm_parser.unknown_args { |rest| rm_shard_raw = rest.shift? }
          rm_parser.parse(sub_args)
        rescue ex
          STDERR.puts "Error: #{ex.message}"
          STDERR.puts
          STDERR.puts rm_parser
          return
        end

        rm_shard = (rm_shard_raw || "").to_s
        if rm_shard.strip.empty?
          STDERR.puts "Error: shard name required"
          STDERR.puts rm_parser
          return
        end

        Meld::Project.remove(rm_shard)
      when "search"
        search_parser = OptionParser.new do |parser|
          parser.banner = "Usage:\n  meld search <query>\n"
        end

        search_query_raw : String? = nil
        begin
          search_parser.unknown_args do |rest|
            q = rest.join(" ")
            search_query_raw = q unless q.strip.empty?
          end
          search_parser.parse(sub_args)
        rescue ex
          STDERR.puts "Error: #{ex.message}"
          STDERR.puts
          STDERR.puts search_parser
          return
        end

        search_query = (search_query_raw || "").to_s
        if search_query.strip.empty?
          STDERR.puts "Error: search query required"
          STDERR.puts search_parser
          return
        end

        Meld::Project.search(search_query)
      when "install"
        Meld::Project.install
      when "update"
        update_parser = OptionParser.new do |parser|
          parser.banner = "Usage:\n  meld update [shard]\n"
        end

        update_shard_raw : String? = nil
        begin
          update_parser.unknown_args { |rest| update_shard_raw = rest.shift? }
          update_parser.parse(sub_args)
        rescue ex
          STDERR.puts "Error: #{ex.message}"
          STDERR.puts
          STDERR.puts update_parser
          return
        end

        update_shard = (update_shard_raw || "").to_s
        update_shard = nil if update_shard.strip.empty?
        Meld::Project.update(update_shard)
      when "exec"
        exec_parser = OptionParser.new do |parser|
          parser.banner = "Usage:\n  meld exec <command>\n"
        end

        exec_cmd_raw : String? = nil
        begin
          exec_parser.unknown_args do |rest|
            joined = rest.join(" ")
            exec_cmd_raw = joined unless joined.strip.empty?
          end
          exec_parser.parse(sub_args)
        rescue ex
          STDERR.puts "Error: #{ex.message}"
          STDERR.puts
          STDERR.puts exec_parser
          return
        end

        exec_cmd = (exec_cmd_raw || "").to_s
        if exec_cmd.strip.empty?
          STDERR.puts "Error: command required"
          STDERR.puts exec_parser
          return
        end

        Meld::Project.exec(exec_cmd)
      when "binstubs"
        bin_parser = OptionParser.new do |parser|
          parser.banner = "Usage:\n  meld binstubs <shard>\n"
        end

        bin_shard_raw : String? = nil
        begin
          bin_parser.unknown_args { |rest| bin_shard_raw = rest.shift? }
          bin_parser.parse(sub_args)
        rescue ex
          STDERR.puts "Error: #{ex.message}"
          STDERR.puts
          STDERR.puts bin_parser
          return
        end

        bin_shard = (bin_shard_raw || "").to_s
        if bin_shard.strip.empty?
          STDERR.puts "Error: shard name required"
          STDERR.puts bin_parser
          return
        end

        Meld::Project.binstubs(bin_shard)
      when "global"
        subsub = sub_args.shift?
        if subsub != "install"
          STDERR.puts "Unknown global command"
          return
        end

        gi_parser = OptionParser.new do |parser|
          parser.banner = <<-B
          Usage:
            meld global install <shard> [-v <version> | -b <branch> | -t <tag> | -c <commit>] [--bin NAME] [--release] [--sudo-link] [--define NAME]
          Notes:
            - If --bin is omitted and the shard declares 1+ targets, all targets are built and installed.
            - If the shard declares 0 targets, an error is raised (library-only shard).
            - --sudo-link installs into /usr/local/bin, otherwise installs into ~/.local/bin.
            - --define NAME passes -DNAME to shards/crystal (repeatable).
          B
        end

        gi_shard_raw : String? = nil
        gi_version_raw : String? = nil
        gi_branch_raw : String? = nil
        gi_tag_raw : String? = nil
        gi_commit_raw : String? = nil
        gi_bin_raw : String? = nil
        gi_release = false
        gi_sudo = false
        gi_defines = [] of String

        gi_parser.on("-v VALUE", "--ver VALUE", "Version constraint") { |v| gi_version_raw = v }
        gi_parser.on("-b NAME", "--branch NAME", "Git branch to pin") { |v| gi_branch_raw = v }
        gi_parser.on("-t NAME", "--tag NAME", "Git tag to pin") { |v| gi_tag_raw = v }
        gi_parser.on("-c SHA", "--commit SHA", "Git commit to pin") { |v| gi_commit_raw = v }
        gi_parser.on("--bin NAME", "Explicit build target name to build/install") { |v| gi_bin_raw = v }
        gi_parser.on("--release", "Build with Crystal optimizations") { gi_release = true }
        gi_parser.on("--sudo-link", "Install into /usr/local/bin using sudo") { gi_sudo = true }
        gi_parser.on("--define NAME", "Pass -DNAME to compiler (repeatable)") { |v| gi_defines << v }

        begin
          gi_parser.unknown_args do |rest|
            rest.each do |tok|
              unless tok.starts_with?("-")
                gi_shard_raw ||= tok
              end
            end
          end
          gi_parser.parse(sub_args)
        rescue ex
          STDERR.puts "Error: #{ex.message}"
          STDERR.puts
          STDERR.puts gi_parser
          return
        end

        name = (gi_shard_raw || "").to_s
        if name.strip.empty?
          STDERR.puts "Error: shard name required"
          STDERR.puts gi_parser
          return
        end

        v_commit = (gi_commit_raw || "").to_s
        v_tag = (gi_tag_raw || "").to_s
        v_branch = (gi_branch_raw || "").to_s
        v_version = (gi_version_raw || "").to_s
        bin_name_s = (gi_bin_raw || "").to_s
        bin_arg = bin_name_s.empty? ? nil : bin_name_s

        selector = Meld::Project::AddSelector.new
        if !v_commit.empty?
          selector.type = Meld::Project::SelectorType::Commit
          selector.value = v_commit
        elsif !v_tag.empty?
          selector.type = Meld::Project::SelectorType::Tag
          selector.value = v_tag
        elsif !v_branch.empty?
          selector.type = Meld::Project::SelectorType::Branch
          selector.value = v_branch
        elsif !v_version.empty?
          selector.type = Meld::Project::SelectorType::Version
          selector.value = v_version
        else
          selector.type = Meld::Project::SelectorType::Version
          selector.value = ""
        end

        Meld::Project.global_install(
          name,
          selector,
          bin_arg,
          release: gi_release,
          sudo_link: gi_sudo,
          defines: gi_defines
        )
      else
        STDERR.puts "Unknown command: #{subcommand}"
        puts
        puts global
      end
    end

    def self.print_command_help(cmd : String)
      case cmd
      when "init"
        puts "Usage: meld init\n\nInitialize project (shard.yml)."
      when "add"
        puts "Usage: meld add <shard> [-v <version> | -b <branch> | -t <tag> | -c <commit>] [--dev]\n\nAdd a shard to project. Use --dev for development dependency."
      when "remove"
        puts "Usage: meld remove <shard>\n\nRemove shard from shard.yml and delete lib/<shard> directory."
      when "search"
        puts "Usage: meld search <query>\n\nSearch for available shards."
      when "install"
        puts "Usage: meld install\n\nInstall dependencies."
      when "update"
        puts "Usage: meld update [shard]\n\nUpdate all or a specific shard."
      when "exec"
        puts "Usage: meld exec <command>\n\nRun a command in project context."
      when "binstubs"
        puts "Usage: meld binstubs <shard>\n\nGenerate executable wrappers."
      when "global"
        puts "Usage: meld global install <shard> [-v|-b|-t|-c] [--bin NAME] [--release] [--sudo-link] [--define NAME]\n\nBuild and install shard executables globally."
      else
        puts "Unknown command: #{cmd}"
      end
    end
  end
end
