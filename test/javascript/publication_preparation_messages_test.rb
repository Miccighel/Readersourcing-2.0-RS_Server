require "test_helper"
require "open3"

class PublicationPreparationMessagesTest < ActiveSupport::TestCase

  test "successful preparation clears the previous preparation error" do
    script = <<~JAVASCRIPT
      const assert = require("node:assert/strict");
      const fs = require("node:fs");
      const vm = require("node:vm");
      const source = fs.readFileSync(process.argv[1], "utf8");
      const shared = fs.readFileSync(process.argv[2], "utf8");
      const handler = source.match(/function showPreparedPublication[\\s\\S]*?\\n\\t}\\r?\\n/)[0];
      const calls = [];
      const handlers = new Map();
      const opened = [];
      const control = name => new Proxy({}, {
        get: (_, method) => (...args) => {
          calls.push({name, method, args});
          if (name === "openButton" && method === "off") handlers.delete(args[0]);
          if (name === "openButton" && method === "on") handlers.set(args[0], args[1]);
          return control(name);
        },
      });
      const context = {
        saveForLaterSection: {find: section => {
          assert.equal(section, "preparation errors");
          return {
            hide: () => calls.push({name: "preparation errors", method: "hide"}),
            find: alert => {
              assert.equal(alert, "alert");
              return {empty: () => calls.push({name: "preparation alert", method: "empty"})};
            },
          };
        }},
        errorsSection: "preparation errors", alert: "alert", reloadIcons: "reload icons",
        showPreparationStatus: state => calls.push({name: "status", method: state}),
      };
      for (const name of ["saveForLaterCaptionFirst", "saveForLaterCaptionSecond",
        "downloadButton", "openButton", "refreshButton", "sourceUploadSuccess", "sourceUploadError"]) {
        context[name] = control(name);
      }
      vm.createContext(context);
      vm.runInContext(shared, context);
      vm.runInContext(handler, context);
      context.window = {open: path => {opened.push(path); return {focus() {}};}};
      for (const [id, openPublication] of [[42, false], [43, true]]) {
        context.showPreparedPublication({id, pdf_download_url_link: "/expired-prepared.pdf"}, openPublication);
      }
      assert.equal(calls.filter(call => call.name === "preparation errors" && call.method === "hide").length, 2);
      assert.equal(calls.filter(call => call.name === "preparation alert" && call.method === "empty").length, 2);
      assert.equal(calls.filter(call => call.name === "status" && call.method === "complete").length, 2);
      assert.deepEqual(calls.filter(call => call.name === "openButton" && call.method === "attr")
        .map(call => call.args), [["href", "/publications/42/open"], ["href", "/publications/43/open"]]);
      assert.equal(handlers.size, 1);
      handlers.get("click.preparation")();
      assert.deepEqual(opened, ["/publications/43/open", "/publications/43/open"]);
    JAVASCRIPT
    output, error, status = Open3.capture3(
      "node", "-e", script, Rails.root.join("app/assets/javascripts/main.js").to_s,
      Rails.root.join("app/assets/javascripts/shared.js").to_s
    )

    assert status.success?, "Preparation message display failed: #{output}#{error}"
  end

end
