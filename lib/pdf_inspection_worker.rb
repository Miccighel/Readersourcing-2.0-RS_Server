ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)
require "bundler/setup"
require "pdf/reader"
require_relative "../app/services/pdf_inspector"

begin
  document = PdfInspector.read(ARGV.fetch(0), allow_annotated: ARGV.fetch(1) == "true")
  puts JSON.generate(metadata: PdfInspectionProtocol.encode(document.metadata), page_count: document.page_count)
rescue PdfInspector::Error, ArgumentError => error
  message = error.message.encode("UTF-8", invalid: :replace, undef: :replace)[0, 1000]
  puts JSON.generate(error: error.class.name.split("::").last, message: message)
  exit 1
end
