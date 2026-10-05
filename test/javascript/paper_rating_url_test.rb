require "test_helper"
require "open3"

class PaperRatingUrlTest < ActiveSupport::TestCase

  test "browser validation accepts only rating URLs at the selected server origin" do
    script = <<~JAVASCRIPT
      const assert = require("node:assert/strict");
      const fs = require("node:fs");
      const vm = require("node:vm");
      vm.runInThisContext(fs.readFileSync(process.argv[1], "utf8"));

      assert.equal(
        paperRatingUrl("https://example.test", "https://EXAMPLE.test:443/rate/42/reference%2Fvalue"),
        "https://example.test/rate/42/reference%2Fvalue"
      );
      for (const url of [
        "https://untrusted.test/?next=https://example.test/rate/42/reference",
        "https://example.test.untrusted.test/rate/42/reference",
        "http://example.test/rate/42/reference",
        "https://example.test:444/rate/42/reference",
        "https://reader@example.test/rate/42/reference",
        "https://example.test/rate/42/reference?next=other",
        "https://example.test/rate/42/reference#other",
        "https://example.test/publications/42/reference",
        "https://example.test/rate/42/reference/extra",
        "https://example.test/rate/0/reference",
        "javascript:alert(1)",
        undefined,
      ]) {
        assert.throws(() => paperRatingUrl("https://example.test", url), TypeError);
      }
    JAVASCRIPT
    output, error, status = Open3.capture3(
      "node", "-e", script, Rails.root.join("app/assets/javascripts/shared.js").to_s
    )

    assert status.success?, "Browser rating URL validation failed: #{output}#{error}"
  end

  test "the extraction interface validates the returned link before opening it" do
    script = Rails.root.join("app/assets/javascripts/main.js").read

    assert_includes script, 'paperRatingUrl(window.location.origin, data["baseUrl"])'
    assert_not_includes script, 'window.open(data["baseUrl"]'
    assert_includes script, "window.open(ratingUrl"
  end

end
