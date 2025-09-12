# src/meld/cli.cr

require "option_parser"

module Meld
  class CLI
    VERSION = "0.1.0"

    def self.run(argv : Array(String))
      # Global flags
      show_version = false
      show_help = false

      # Subcommand dispatch
      command : String? = nil
      cmd_args = [] of String

      global = OptionParser.new do |parser|
        parser.banner = <<-BANNER
        Meld - Crystal Lang Package Manager

        Usage:
          meld [options] <command> [command options]

        Commands:
          init                       Initialize project (shard.yml)
          add <shard> [ver] [--dev]  Add a shard to project
          search <query>             Search for available shards
          install                    Install dependencies
          update [shard]             Update all or a specific shard
          exec <cmd>                 Run a command in project context
          binstubs <shard>           Generate executable wrappers
          help [command]             Show help (global or for a command)

        Options:
        BANNER

        parser.on("-v", "--version", "Show version") { show_version = true }
        parser.on("-h", "--help", "Show help") { show_help = true }

        # Capture first non-flag as subcommand; remaining as that subcommand's args
        parser.unknown_args do |unknown|
          if unknown.size > 0
            command = unknown.shift?
            cmd_args = unknown
          end
        end
      end

      begin
        global.parse(argv)
      rescue ex
        STDERR.puts "Error: #{ex.message}"
        STDERR.puts
        STDERR.puts global
        return
      end

      if show_version
        puts "meld #{VERSION}"
        return
      end

      if show_help && command.nil?
        puts global
        return
      end

      # Support: meld help [command]
      if command == "help"
        sub = cmd_args.shift?
        if sub
          self.print_command_help(sub)
        else
          puts global
        end
        return
      end

      if command.nil?
        puts global
        return
      end

      case command
      when "init"
        Meld::Project.init

      when "add"
        add_parser = OptionParser.new do |parser|
          parser.banner = <<-B
          Usage:
            meld add <shard> [version] [--dev]

          Options:
            --dev    Add as development dependency
          B
        end

        add_dev = false
        add_parser.on("--dev", "Add as development dependency") { add_dev = true }

        add_shard : String? = nil
        add_version : String? = nil

        begin
          add_parser.unknown_args do |rest|
            rest.each do |tok|
              if tok.starts_with?("-")
                # flags handled by OptionParser
              elsif add_shard.nil?
                add_shard = tok
              elsif add_version.nil?
                add_version = tok
              end
            end
          end
          add_parser.parse(cmd_args)
        rescue ex
          STDERR.puts "Error: #{ex.message}"
          STDERR.puts
          STDERR.puts add_parser
          return
        end

        # Require shard
        if add_shard.to_s.strip.empty?
          STDERR.puts "Error: shard name required"
          STDERR.puts add_parser
          return
        end

        # Default version if missing/blank (coerce before calling String methods)
        v = add_version.to_s
        v = "~> 0.1.0" if v.strip.empty?

        Meld::Project.add(add_shard.not_nil!, v, add_dev)

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
          search_parser.parse(cmd_args)
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
          update_parser.parse(cmd_args)
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
          exec_parser.parse(cmd_args)
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
          bin_parser.parse(cmd_args)
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
        STDERR.puts "Unknown command: #{command}"
        puts
        puts global
      end
    end

    def self.print_command_help(cmd : String)
      case cmd
      when "init"
        puts "Usage: meld init\n\nInitialize project (shard.yml)."
      when "add"
        puts "Usage: meld add <shard> [version] [--dev]\n\nAdd a shard to project. Use --dev for development dependency."
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
