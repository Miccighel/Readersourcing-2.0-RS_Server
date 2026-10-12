require "test_helper"
require "open3"

class PublicationOpenPathTest < ActiveSupport::TestCase

  test "the browser opens only a local publication path with a valid identifier" do
    script = <<~JAVASCRIPT
      const assert = require("node:assert/strict");
      const fs = require("node:fs");
      const vm = require("node:vm");
      vm.runInThisContext(fs.readFileSync(process.argv[1], "utf8"));

      assert.equal(publicationOpenPath(42), "/publications/42/open");
      assert.equal(publicationOpenPath("17"), "/publications/17/open");
      for (const value of [undefined, null, false, [], [42], {}, "", 0, -1, 1.5,
        Number.MAX_SAFE_INTEGER + 1, "01", "42/extra", "42?other", "https://other.test/"]) {
        assert.throws(() => publicationOpenPath(value), TypeError);
      }
    JAVASCRIPT
    output, error, status = Open3.capture3(
      "node", "-e", script, Rails.root.join("app/assets/javascripts/shared.js").to_s
    )

    assert status.success?, "Browser publication path validation failed: #{output}#{error}"
  end

  test "the preparation and table controls do not reopen a cached signed URL" do
    source = Rails.root.join("app/assets/javascripts/main.js").read

    assert_not_includes source, 'window.open(data["pdf_download_url_link"]'
    assert_not_includes source, 'openButton.attr("href", data["pdf_download_url_link"])'
    assert_equal 3, source.scan('const openPath = publicationOpenPath(data["id"]);').length
    assert_equal 3, source.scan('openButton.off("click.preparation").on("click.preparation"').length
  end

end
