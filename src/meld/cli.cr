module Meld
  class CLI
    def self.run(args)
      if args.empty?
        self.help
        return
      end

      command = args.shift

      case command
      when "init"
        Project.init
      when "add"
        if args.empty?
          puts "Error: shard name required"
          puts "Usage: meld add <shard> [version] [--dev]"
          return
        end

        shard = args.shift
        version = nil
        dev_dependency = false

        # Parse remaining arguments
        while !args.empty?
          arg = args.shift
          case arg
          when "--dev"
            dev_dependency = true
          else
            version = arg if version.nil?
          end
        end

        # Set default version if not provided
        version = "~> 0.1.0" if version.nil?

        Project.add(shard, version, dev_dependency)
      when "search"
        if args.empty?
          puts "Error: search query required"
          puts "Usage: meld search <query>"
          return
        end
        query = args.join(" ")
        Project.search(query)
      when "install"
        Project.install
      when "update"
        shard = args.empty? ? nil : args.shift
        Project.update(shard)
      when "exec"
        if args.empty?
          puts "Error: command required"
          puts "Usage: meld exec <command>"
          return
        end
        cmd = args.join(" ")
        Project.exec(cmd)
      when "binstubs"
        if args.empty?
          puts "Error: shard name required"
          puts "Usage: meld binstubs <shard>"
          return
        end
        shard = args.shift
        Project.binstubs(shard)
      when "help", nil
        self.help
      else
        puts "Unknown command: #{command}"
        self.help
      end
    end

    def self.help
      puts <<-HELP
        Meld - Crystal Lang Package Manager

        Usage:
          meld <command> [options]

        Commands:
          init                     Initialize project (shard.yml)
          add <shard> [ver] [--dev] Add a shard to project
          search <query>           Search for available shards
          install                  Install dependencies
          update [shard]           Update all or a specific shard
          exec <cmd>               Run a command in project context
          binstubs <shard>         Generate executable wrappers
          help                     Show this help

        Options:
          --dev                    Add as development dependency

        Examples:
          meld init
          meld add kemal "~> 1.0.0"
          meld add spec --dev
          meld add ameba "~> 1.4.0" --dev
          meld search "web framework"
          meld install
          meld exec "crystal spec"
      HELP
    end
  end
end
