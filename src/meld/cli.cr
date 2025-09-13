require "option_parser"

module Meld
  class CLI
    VERSION = "0.1.0"

    def self.run(argv : Array(String))
      # Phase 0: split argv into global flags, subcommand, and subcommand args
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

      # Global flags (apply only before subcommand)
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
          search <query>                     Search for available shards
          install                            Install dependencies
          update [shard]                     Update all or a specific shard
          exec <cmd>                         Run a command in project context
          binstubs <shard>                   Generate executable wrappers
          help [command]                     Show help (global or for a command)

        Options:
        BANNER

        parser.on("-v", "--version", "Show version") { show_version = true }
        parser.on("-h", "--help", "Show help") { show_help = true }

        parser.unknown_args do |_|
          # ignore unknowns here; argv already split
        end
      end

      begin
        global.parse(global_argv)
      rescue ex
        STDERR.puts "Error: #{ex.message}"
        STDERR.puts
        STDERR.puts global
        return
      end

      # Only supported help form: meld help <command>
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
        opt_version : String? = nil
        opt_branch  : String? = nil
        opt_tag     : String? = nil
        opt_commit  : String? = nil

        add_parser.on("--dev", "Add as development dependency") { add_dev = true }
        add_parser.on("-v VALUE", "--ver VALUE", "Version constraint (e.g. \"~> 1.2.3\" or \"1.6.4\")") { |val| opt_version = val }
        add_parser.on("-b NAME", "--branch NAME", "Git branch to pin") { |val| opt_branch = val }
        add_parser.on("-t NAME", "--tag NAME", "Git tag to pin") { |val| opt_tag = val }
        add_parser.on("-c SHA", "--commit SHA", "Git commit to pin") { |val| opt_commit = val }

        add_shard : String? = nil
        seen_positional = false

        begin
          add_parser.unknown_args do |rest|
            rest.each do |tok|
              if tok.starts_with?("-")
                # flags handled by OptionParser
              else
                unless seen_positional
                  add_shard = tok
                  seen_positional = true
                else
                  # ignore extra positionals
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

        if add_shard.to_s.strip.empty?
          STDERR.puts "Error: shard name required"
          STDERR.puts
          STDERR.puts add_parser
          return
        end

        # Build selector from flags; if none, leave unpinned
        selector = Meld::Project::AddSelector.new

        v_commit  = opt_commit.to_s
        v_tag     = opt_tag.to_s
        v_branch  = opt_branch.to_s
        v_verflag = opt_version.to_s

        if !v_commit.empty?
          selector.type = Meld::Project::SelectorType::Commit
          selector.value = v_commit
        elsif !v_tag.empty?
          selector.type = Meld::Project::SelectorType::Tag
          selector.value = v_tag
        elsif !v_branch.empty?
          selector.type = Meld::Project::SelectorType::Branch
          selector.value = v_branch
        elsif !v_verflag.empty?
          selector.type = Meld::Project::SelectorType::Version
          selector.value = v_verflag
        else
          # No selector flags: add unpinned dependency (no version/branch/tag/commit line)
          selector.type = Meld::Project::SelectorType::Version
          selector.value = ""
        end

        Meld::Project.add(add_shard.not_nil!, selector, add_dev)

      when "search"
        search_parser = OptionParser.new do |parser|
          parser.banner = <<-B
          Usage:
            meld search <query>

          Notes:
            Query is required (positional). Example: meld search "web framework"
          B
        end

        search_query : String? = nil
        begin
          search_parser.unknown_args do |rest|
            q = rest.join(" ")
            search_query = q unless q.strip.empty?
          end
          search_parser.parse(sub_args)
        rescue ex
          STDERR.puts "Error: #{ex.message}"
          STDERR.puts
          STDERR.puts search_parser
          return
        end

        if search_query.to_s.strip.empty?
          STDERR.puts "Error: search query required"
          STDERR.puts search_parser
          return
        end

        Meld::Project.search(search_query.not_nil!)

      when "install"
        Meld::Project.install

      when "update"
        update_parser = OptionParser.new do |parser|
          parser.banner = <<-B
          Usage:
            meld update [shard]

          Notes:
            If shard is provided, updates only that shard; otherwise updates all.
          B
        end

        update_shard : String? = nil
        begin
          update_parser.unknown_args do |rest|
            update_shard = rest.shift?
          end
          update_parser.parse(sub_args)
        rescue ex
          STDERR.puts "Error: #{ex.message}"
          STDERR.puts
          STDERR.puts update_parser
          return
        end

        Meld::Project.update(update_shard)

      when "exec"
        exec_parser = OptionParser.new do |parser|
          parser.banner = <<-B
          Usage:
            meld exec <command>

          Notes:
            Executes the given shell command in project context.
          B
        end

        exec_cmd : String? = nil
        begin
          exec_parser.unknown_args do |rest|
            joined = rest.join(" ")
            exec_cmd = joined unless joined.strip.empty?
          end
          exec_parser.parse(sub_args)
        rescue ex
          STDERR.puts "Error: #{ex.message}"
          STDERR.puts
          STDERR.puts exec_parser
          return
        end

        if exec_cmd.to_s.strip.empty?
          STDERR.puts "Error: command required"
          STDERR.puts exec_parser
          return
        end

        Meld::Project.exec(exec_cmd.not_nil!)

      when "binstubs"
        bin_parser = OptionParser.new do |parser|
          parser.banner = <<-B
          Usage:
            meld binstubs <shard>

          Notes:
            Generates executable wrappers for a shard.
          B
        end

        bin_shard : String? = nil
        begin
          bin_parser.unknown_args do |rest|
            bin_shard = rest.shift?
          end
          bin_parser.parse(sub_args)
        rescue ex
          STDERR.puts "Error: #{ex.message}"
          STDERR.puts
          STDERR.puts bin_parser
          return
        end

        if bin_shard.to_s.strip.empty?
          STDERR.puts "Error: shard name required"
          STDERR.puts bin_parser
          return
        end

        Meld::Project.binstubs(bin_shard.not_nil!)

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
      else
        puts "Unknown command: #{cmd}"
      end
    end
  end
end
