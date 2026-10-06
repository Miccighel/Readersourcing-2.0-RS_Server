require "test_helper"
require "open3"

class RegistrationMessagesTest < ActiveSupport::TestCase

  test "shows delivery errors without exposing the response status as a list of characters" do
    script = <<~JAVASCRIPT
      const assert = require("node:assert/strict");
      const fs = require("node:fs");
      const vm = require("node:vm");
      vm.runInThisContext(fs.readFileSync(process.argv[1], "utf8"));

      (async () => {
        assert.equal(
          await buildErrors(JSON.stringify({status: "confirmation_delivery_failed", errors: ["Confirmation delivery is unavailable."]})),
          '<span class="color-red-dark">Errors:</span><ul><li class="color-red-dark">Confirmation delivery is unavailable.</li></ul>'
        );
        assert.equal(
          await buildErrors(JSON.stringify({email: ["has already been taken"]})),
          '<span class="color-red-dark">Email:</span><ul><li class="color-red-dark">has already been taken</li></ul>'
        );
      })().catch(error => { console.error(error); process.exitCode = 1; });
    JAVASCRIPT
    output, error, status = Open3.capture3(
      "node", "-e", script, Rails.root.join("app/assets/javascripts/shared.js").to_s
    )

    assert status.success?, "Registration error display failed: #{output}#{error}"
  end

  test "the registration interface retains the server message on the login page" do
    script = Rails.root.join("app/assets/javascripts/main.js").read

    assert_includes script, 'localStorage.setItem("message", data["message"])'
    assert_includes script, 'window.location.href = "/login"'
  end

  test "Postman permits the expected delivery failure but still rejects unexpected server errors" do
    script = <<~JAVASCRIPT
      const assert = require("node:assert/strict");
      const fs = require("node:fs");
      const vm = require("node:vm");
      const collection = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
      const events = collection.event.concat(collection.item.flatMap(item => item.event || []));
      events.forEach(event => new vm.Script(event.script.exec.join("\\n")));
      const check = collection.event.find(event => event.listen === "test").script.exec.join("\\n");

      for (const [code, requestName, status, expected] of [
        [200, "Authentication (Authenticate)", undefined, true],
        [201, "Users (Create)", "confirmation_pending", true],
        [503, "Authentication (Authenticate)", "confirmation_delivery_failed", true],
        [503, "Authentication (Authenticate)", undefined, false],
        [503, "Users (Create)", "confirmation_delivery_failed", false],
        [500, "Authentication (Authenticate)", "confirmation_delivery_failed", false],
      ]) {
        const context = {pm: {
          info: {requestName},
          response: {code, json: () => ({status})},
          test: (_, callback) => callback(),
          expect: value => ({to: {equal: expected => assert.equal(value, expected)}}),
        }};
        if (expected) vm.runInNewContext(check, context);
        else assert.throws(() => vm.runInNewContext(check, context));
      }
    JAVASCRIPT
    output, error, status = Open3.capture3(
      "node", "-e", script, Rails.root.join("postman/Readersourcing_2.0.postman_collection.json").to_s
    )

    assert status.success?, "Postman response checks failed: #{output}#{error}"
  end

end
