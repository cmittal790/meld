require "yaml"
require "http/client"
require "json"

module Meld
  class Project
    enum SelectorType
      Version
      Branch
      Tag
      Commit
    end

    struct AddSelector
      property type : SelectorType = SelectorType::Version
      property value : String = ""

      def version? : Bool; @type == SelectorType::Version; end
      def branch?  : Bool; @type == SelectorType::Branch;  end
      def tag?     : Bool; @type == SelectorType::Tag;     end
      def commit?  : Bool; @type == SelectorType::Commit;  end

      def empty? : Bool
        @value.empty?
      end
    end

    PROJECT_FILE = "shard.yml"

    def self.init
      if File.exists?(PROJECT_FILE)
        puts "shard.yml already exists!"
      else
        yaml_content = <<-YAML
          name: my_project
          version: 0.1.0
          authors:
          - "Your Name <[email protected]>"
          description: "A brief description of your shard and its purpose"
          crystal: ">= 1.0.0"
          license: MIT
          targets:
            my_project:
              main: src/my_project.cr
          dependencies: {}
        YAML

        File.write(PROJECT_FILE, yaml_content)
        puts "Initialized shard.yml for your project."
      end
    end

    # Accept selector for version/branch/tag/commit
    # When Version with empty value, add only the source (github/git) without any pin.
    def self.add(shard_name : String, selector : AddSelector, dev_dependency : Bool = false)
      unless File.exists?(PROJECT_FILE)
        puts "No shard.yml found! Run 'meld init' first."
        return
      end

      shard_info = get_github_shard_info(shard_name)
      dep_section = dev_dependency ? "development_dependencies" : "dependencies"

      github_repo : String? = nil
      git_url : String? = nil

      # Resolve repository
      if shard_info && shard_info.has_key?("github_repo")
        repo_value = shard_info["github_repo"]
        github_repo = repo_value.is_a?(JSON::Any) ? repo_value.as_s : repo_value.to_s
      else
        if selector.version?
          if selector.value.starts_with?("github:")
            github_repo = selector.value.lchop("github:")
          elsif selector.value.starts_with?("git:")
            git_url = selector.value.lchop("git:")
            github_repo = nil
          else
            github_repo = get_common_shard_repo(shard_name)
          end
        else
          github_repo = get_common_shard_repo(shard_name)
        end
      end

      content = File.read(PROJECT_FILE)

      dep_lines = [] of String
      dep_lines << "  #{shard_name}:"
      if git_url
        dep_lines << "    git: #{git_url}"
        if selector.branch? && !selector.empty?
          dep_lines << "    branch: #{selector.value}"
        elsif selector.tag? && !selector.empty?
          dep_lines << "    tag: #{selector.value}"
        elsif selector.commit? && !selector.empty?
          dep_lines << "    commit: #{selector.value}"
        end
      else
        dep_lines << "    github: #{github_repo}"
        if selector.version? && !selector.empty?
          dep_lines << "    version: \"#{selector.value}\""
        elsif selector.branch?
          dep_lines << "    branch: #{selector.value}"
        elsif selector.tag?
          dep_lines << "    tag: #{selector.value}"
        elsif selector.commit?
          dep_lines << "    commit: #{selector.value}"
        end
      end

      block_text = dep_lines.join("\n") + "\n"

      if content.includes?("#{dep_section}: {}")
        replacement = "#{dep_section}:\n#{block_text}"
        content = content.gsub("#{dep_section}: {}", replacement)
      elsif content.includes?("#{dep_section}:")
        lines = content.lines(chomp: false)
        new_lines = [] of String
        added = false

        lines.each do |line|
          new_lines << line
          if line.strip == "#{dep_section}:" && !added
            new_lines << block_text
            added = true
          end
        end

        content = new_lines.join
      else
        content += "\n#{dep_section}:\n#{block_text}"
      end

      File.write(PROJECT_FILE, content)

      dep_type = dev_dependency ? "development dependency" : "dependency"
      human_selector =
        if selector.version?
          selector.empty? ? "unlocked" : selector.value
        elsif selector.branch?
          "branch #{selector.value}"
        elsif selector.tag?
          "tag #{selector.value}"
        else
          "commit #{selector.value}"
        end

      puts "Added #{shard_name} (#{human_selector}) as #{dep_type} to shard.yml"

      if shard_info && shard_info.has_key?("description")
        desc_value = shard_info["description"]
        description = desc_value.is_a?(JSON::Any) ? desc_value.as_s : desc_value.to_s
        puts "Description: #{description}"
      end
    end

    private def self.get_common_shard_repo(shard_name)
      common_shards = {
        "kemal" => "kemalcr/kemal",
        "lucky" => "luckyframework/lucky",
        "amber" => "amberframework/amber",
        "marten" => "martenframework/marten",
        "pg" => "will/crystal-pg",
        "mysql" => "crystal-lang/crystal-mysql",
        "sqlite3" => "crystal-lang/crystal-sqlite3",
        "redis" => "stefanwille/crystal-redis",
        "jwt" => "crystal-community/jwt",
        "spec" => "crystal-lang/spec",
        "ameba" => "crystal-ameba/ameba",
        "webmock" => "manastech/webmock.cr",
        "crest" => "mamantoha/crest",
        "jennifer" => "imdrasil/jennifer.cr",
        "clear" => "anykeyh/clear",
        "granite" => "amberframework/granite",
        "tourmaline" => "protoncr/tourmaline",
        "hardware" => "crystal-community/hardware.cr",
        "colorize" => "crystal-lang/colorize",
        "db" => "crystal-lang/crystal-db",
        "minitest" => "ysbaddaden/minitest.cr",
        "mosquito" => "mosquito-cr/mosquito",
        "athena" => "athena-framework/athena",
        "invidious" => "iv-org/invidious",
        "lavinmq" => "cloudamqp/lavinmq"
      }

      common_shards[shard_name]? || "#{shard_name}/#{shard_name}"
    end

    private def self.get_github_shard_info(shard_name)
      begin
        github_repo = get_common_shard_repo(shard_name)
        response = HTTP::Client.get("https://api.github.com/repos/#{github_repo}")

        if response.status_code == 200
          repo_data = JSON.parse(response.body)
          description = repo_data["description"]?
          desc_string = description ? description.as_s : "No description available"

          return {
            "github_repo" => github_repo,
            "description" => desc_string
          }
        end
      rescue ex
        # Silently fail
      end

      nil
    end

    def self.install
      unless File.exists?(PROJECT_FILE)
        puts "No shard.yml found! Run 'meld init' first."
        return
      end
      puts "Installing dependencies via shards..."
      system("shards install")
      puts "Dependencies installed."
    end

    def self.update(shard_name = nil)
      cmd = "shards update"
      cmd += " #{shard_name}" if shard_name
      system(cmd)
      puts shard_name ? "Updated #{shard_name}" : "Updated all dependencies"
    end

    def self.exec(cmd)
      puts "Executing command in project context: #{cmd}"
      system(cmd)
    end

    def self.binstubs(shard_name)
      puts "Generating binstubs for: #{shard_name}"
      puts "Note: This feature is not implemented yet."
    end

    def self.set_metadata(name : String? = nil, version : String? = nil, author : String? = nil, description : String? = nil, crystal_version : String? = nil, license : String? = nil)
      unless File.exists?(PROJECT_FILE)
        puts "No shard.yml found! Run 'meld init' first."
        return
      end

      content = File.read(PROJECT_FILE)
      lines = content.lines(chomp: true)
      author_line_updated = false

      lines = lines.map do |line|
        stripped = line.strip

        if stripped.starts_with?("name:") && name
          "name: #{name}"
        elsif stripped.starts_with?("version:") && version
          "version: #{version}"
        elsif stripped.starts_with?("description:") && description
          "description: \"#{description}\""
        elsif stripped.starts_with?("crystal:") && crystal_version
          "crystal: \"#{crystal_version}\""
        elsif stripped.starts_with?("license:") && license
          "license: #{license}"
        elsif stripped.starts_with?("- \"") && author && !author_line_updated
          author_line_updated = true
          "- \"#{author}\""
        else
          line
        end
      end

      File.write(PROJECT_FILE, lines.join("\n") + "\n")
      puts "Updated shard.yml metadata"
    end

    def self.search(query)
      puts "Searching for Crystal shards matching '#{query}'..."
      puts "=" * 50

      local_matches = search_local_database(query)
      search_url = "https://shards.info/search?query=#{URI.encode_path(query)}"

      if local_matches.any?
        puts "Found #{local_matches.size} local matches:"
        puts ""

        local_matches.each_with_index do |shard, index|
          puts "#{index + 1}. #{shard[:name]}"
          puts "   Description: #{shard[:description]}"
          puts "   Repository: https://github.com/#{shard[:repo]}"
          puts ""
        end
      else
        puts "No local matches found."
      end

      puts "For complete results, visit: #{search_url}"
    end

    private def self.search_local_database(query)
      shards_db = [
        {name: "kemal", description: "Lightning Fast, Super Simple web framework", repo: "kemalcr/kemal"},
        {name: "lucky", description: "A full-featured Crystal web framework", repo: "luckyframework/lucky"},
        {name: "amber", description: "A Crystal web framework", repo: "amberframework/amber"},
        {name: "marten", description: "A pragmatic web framework", repo: "martenframework/marten"},
        {name: "pg", description: "PostgreSQL driver for Crystal", repo: "will/crystal-pg"},
        {name: "mysql", description: "MySQL connector for Crystal", repo: "crystal-lang/crystal-mysql"},
        {name: "sqlite3", description: "SQLite3 bindings for Crystal", repo: "crystal-lang/crystal-sqlite3"},
        {name: "redis", description: "Redis client for Crystal", repo: "stefanwille/crystal-redis"},
        {name: "jwt", description: "JWT implementation for Crystal", repo: "crystal-community/jwt"},
        {name: "spec", description: "Testing library for Crystal", repo: "crystal-lang/spec"},
        {name: "ameba", description: "A static code analysis tool for Crystal", repo: "crystal-ameba/ameba"},
        {name: "webmock", description: "HTTP mocking library", repo: "manastech/webmock.cr"},
        {name: "crest", description: "HTTP and REST client", repo: "mamantoha/crest"},
        {name: "jennifer", description: "Active Record pattern implementation", repo: "imdrasil/jennifer.cr"},
        {name: "clear", description: "Advanced ORM for PostgreSQL", repo: "anykeyh/clear"},
        {name: "granite", description: "ORM for Crystal", repo: "amberframework/granite"},
        {name: "tourmaline", description: "Telegram bot library", repo: "protoncr/tourmaline"},
        {name: "colorize", description: "Terminal colors", repo: "crystal-lang/colorize"},
        {name: "invidious", description: "Alternative front-end to YouTube", repo: "iv-org/invidious"},
        {name: "lavinmq", description: "Ultra quick message queue and streaming server", repo: "cloudamqp/lavinmq"},
        {name: "db", description: "Common database API for Crystal", repo: "crystal-lang/crystal-db"},
        {name: "minitest", description: "Test Unit for the Crystal programming language", repo: "ysbaddaden/minitest.cr"},
        {name: "mosquito", description: "Background task runner for crystal applications", repo: "mosquito-cr/mosquito"},
        {name: "athena", description: "An ecosystem of reusable, independent components", repo: "athena-framework/athena"},
        {name: "hardware", description: "Get CPU, Memory and Network informations", repo: "crystal-community/hardware.cr"}
      ]

      shards_db.select do |shard|
        shard[:name].includes?(query.downcase) ||
        shard[:description].downcase.includes?(query.downcase)
      end
    end
  end
end
