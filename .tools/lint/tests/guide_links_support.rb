# frozen_string_literal: true

require 'cgi'
require 'uri'

module ProjectLint
  # Inspect repository-local Markdown links and anchors without checking external URLs.
  module GuideLinks
    def prose(text)
      fence = nil
      text.lines.map do |line|
        hidden = fence || line.match?(/\A\s*(?:`{3,}|~{3,})/)
        fence = next_fence(line, fence)
        hidden ? "\n" : line
      end.join
    end

    def next_fence(line, fence)
      return line[/\A\s*(`{3,}|~{3,})/, 1] unless fence

      fence unless line.match?(/\A\s*#{Regexp.escape(fence[0])}{#{fence.length},}\s*\z/)
    end

    def heading_anchors(text)
      used = {}
      prose(text).scan(/^\#{1,6} (.+)$/).flatten.map do |title|
        base = CGI.unescapeHTML(title).downcase.gsub(/[^\p{Word}\s-]/, '').strip.tr(' ', '-')
        unique_anchor(base, used)
      end
    end

    def unique_anchor(base, used)
      anchor = base
      suffix = 0
      while used[anchor]
        suffix += 1
        anchor = "#{base}-#{suffix}"
      end
      used[anchor] = true
      anchor
    end

    def anchors(text)
      heading_anchors(text) + prose(text).scan(/<a\s+id=["']([^"']+)["']/).flatten
    end

    def link_errors(text, source:, root:)
      prose(text).lines.each_with_index.flat_map do |line, index|
        # Code spans show syntax; their contents do not create clickable links.
        visible = line.gsub(/(`+).*?\1/, '')
        visible.scan(/\]\((?:<([^>]+)>|([^\s)]+))(?:\s+"[^"]*")?\)/).filter_map do |targets|
          link = targets.compact.first
          error = link_error(link, source: source, root: root)
          "#{source}:#{index + 1}: #{error}: #{link}" if error
        end
      end
    end

    def link_error(link, source:, root:)
      return if link.match?(%r{\A(?:[a-z][a-z\d+.-]*:|//)}i)

      path, fragment = link.split('#', 2)
      target = link_target(path, source: source, root: root)
      target = File.join(target, 'README.md') if fragment && File.directory?(target)
      return 'Missing link target' unless File.exist?(target)

      fragment_error(target, fragment)
    end

    def fragment_error(target, fragment)
      return unless fragment && File.file?(target) && File.extname(target).casecmp?('.md')

      'Missing link anchor' unless anchors(File.read(target)).include?(URI::DEFAULT_PARSER.unescape(fragment))
    end

    def link_target(path, source:, root:)
      decoded = URI::DEFAULT_PARSER.unescape(path)
      base = decoded.start_with?('/') ? root : File.dirname(source)
      decoded.empty? ? source : File.expand_path(decoded.delete_prefix('/'), base)
    end
  end
end
