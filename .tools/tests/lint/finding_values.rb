# frozen_string_literal: true

# Project native diagnostic fields without changing check selection or test assertions.
module FindingValues
  def finding_kinds(code, *rules)
    findings(code, *rules).map { |problem| problem[:kind] }
  end

  def finding_lines(code, *rules)
    findings(code, *rules).map { |problem| problem[:line] }
  end
end
