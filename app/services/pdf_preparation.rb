require "tmpdir"

class PdfPreparation

  Result = Struct.new(:metadata, :page_count, :stdout, keyword_init: true)

  def initialize(
    runner:,
    inspector: PdfInspector.new,
    verifier: AnnotatedPdfVerifier.new
  )
    @runner = runner
    @inspector = inspector
    @verifier = verifier
  end

  def call(download:, storage_path:, target_path:, original_path:, rate_path:, deadline: PdfOperationDeadline.new)
    source = @inspector.call(download.io.path, deadline: deadline)

    Dir.mktmpdir("rs-pdf-", storage_path.to_s) do |staging_path|
      temporary_name = File.basename(download.io.path, File.extname(download.io.path))
      staged_output = File.join(staging_path, "#{temporary_name}#{Settings.rs_pdf_link_suffix}.pdf")
      result = @runner.call(
        input_path: download.io.path,
        output_path: staging_path,
        url: rate_path,
        caption: "Express your rating",
        expected_output: staged_output,
        deadline: deadline
      )
      @verifier.call(
        staged_output,
        source_page_count: source.page_count,
        expected_url: rate_path,
        deadline: deadline
      )
      deadline.check!
      yield source.metadata if block_given?
      deadline.check!
      FileUtils.cp(download.io.path, original_path)
      FileUtils.mv(staged_output, target_path, force: true)
      deadline.check!

      return Result.new(
        metadata: source.metadata,
        page_count: source.page_count,
        stdout: result.stdout
      )
    end
  end

end
