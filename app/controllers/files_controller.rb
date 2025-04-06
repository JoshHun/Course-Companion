require 'net/http'
require 'uri'
require 'pdf-reader'  # For PDF parsing
require 'docx'        # For DOCX parsing
require 'zip'         # For PPTX parsing
require 'nokogiri'    # For PPTX slides
require 'stringio'
require 'time'
require 'redcarpet'    # For Markdown conversion

class FilesController < ApplicationController
  before_action :require_login

  helper_method :current_user  # So it's accessible in views

  def summary
    file_url = params[:file_url]
    file_name = params[:file_name] || "unknown"

    #Rails.logger.info("File URL passed: #{file_url.inspect}")
    raw_text = download_and_extract_text_from_url(file_url, file_name)
    #Rails.logger.info("Extracted text (first 200 chars): #{raw_text[0..200]}")

    # Build an explicit prompt for Gemini
    prompt_text = "Please summarize the following file content in a concise study guide:\n\n#{raw_text}"
    #Rails.logger.info("Calling Gemini with prompt (first 200 chars): #{prompt_text[0..200]}")

    ai_response = generate_content(prompt_text)
    #Rails.logger.info("Gemini API parsed response: #{ai_response.inspect}")

    gemini_text = ai_response.dig("candidates", 0, "content", "parts", 0, "text") || "No summary available."
    #Rails.logger.info("\nRaw AI Summary: #{gemini_text.inspect}\n")


    # Convert the normalized text to HTML using Markdown
    html_summary = to_html_markdown(gemini_text)
    #Rails.logger.info("HTML Summary: #{html_summary.inspect}\n")

    render html: <<-HTML.html_safe
      <turbo-frame id="file_summary">
        #{render_to_string(partial: "files/summary", locals: { summary_text: html_summary, file_name: file_name })}
      </turbo-frame>
    HTML
  end
  

  private

  def download_and_extract_text_from_url(file_url, file_name)
    unless file_url.present?
      #Rails.logger.info("No file URL provided.")
      return "No file URL provided."
    end

    file_bytes = download_file(file_url)
    if file_bytes.blank?
      #Rails.logger.info("No file bytes were downloaded.")
      return "No file content available."
    else
      #Rails.logger.info("Downloaded file bytes size: #{file_bytes.bytesize}")
    end

    extracted_text = parse_text(file_name, file_bytes)
    #Rails.logger.info("Extracted text (first 200 chars): #{extracted_text[0..200]}")
    
    extracted_text
  end

  # Download file from Canvas, following redirects if needed, and include authorization.
  def download_file(file_url, limit = 5)
    raise "Too many redirects" if limit == 0

    uri = URI(file_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{current_user.canvas_token}"  # Include the token

    res = http.request(req)

    case res
    when Net::HTTPSuccess
      res.body
    when Net::HTTPRedirection
      new_location = res['location']
      #Rails.logger.info("Redirecting to: #{new_location}")
      download_file(new_location, limit - 1)
    else
      #Rails.logger.info("Download failed with code: #{res.code}")
      nil
    end
  end

  # Parse text from file based on its extension
  def parse_text(filename, file_bytes)
    fn = filename.downcase
    if fn.end_with?(".pdf")
      parse_pdf(file_bytes)
    elsif fn.end_with?(".docx")
      parse_docx(file_bytes)
    elsif fn.end_with?(".pptx")
      parse_pptx(file_bytes)
    else
      "No text extraction for #{filename}"
    end
  end

  def parse_pdf(file_bytes)
    eof_marker = "%%EOF"
    unless file_bytes.strip.end_with?(eof_marker)
      #Rails.logger.info("PDF file does not end with EOF marker. File might be incomplete or corrupted.")
      return "Unable to parse PDF: PDF does not contain EOF marker"
    end

    reader = PDF::Reader.new(StringIO.new(file_bytes))
    reader.pages.map(&:text).join("\n")
  rescue => e
    "Unable to parse PDF: #{e.message}"
  end

  def parse_docx(file_bytes)
    doc = Docx::Document.open(StringIO.new(file_bytes))
    doc.paragraphs.map(&:text).join("\n")
  rescue => e
    "Unable to parse DOCX: #{e.message}"
  end

  def parse_pptx(file_bytes)
    extracted_text = ""
    Zip::File.open_buffer(StringIO.new(file_bytes)) do |zip_file|
      zip_file.glob("ppt/slides/slide*.xml").each do |entry|
        slide_xml = entry.get_input_stream.read
        doc = Nokogiri::XML(slide_xml)
        doc.xpath("//a:t").each do |node|
          extracted_text << node.text.strip + " "
        end
      end
    end
    extracted_text.strip
  rescue => e
    "Unable to parse PPTX: #{e.message}"
  end

  def generate_content(text)
    api_key = ENV["GEMINI_API_KEY"]
    #Rails.logger.info("API KEY being used: #{api_key}") # Debug line
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=#{api_key}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
  
    request = Net::HTTP::Post.new(uri, { 'Content-Type' => 'application/json' })
  
    payload = {
      "contents" => [
        {
          "parts" => [
            { "text" => text }
          ]
        }
      ]
    }
  
    request.body = payload.to_json
  
    response = http.request(request)
    #Rails.logger.info("Gemini API raw response: #{response.body}")
    
    begin
      parsed = JSON.parse(response.body)
      #Rails.logger.info("Gemini API parsed response: #{parsed.inspect}")
      parsed
    rescue JSON::ParserError
      response.body
    end
  end

  # Converts Markdown text to HTML using Redcarpet.
  def to_html_markdown(text)
    renderer = Redcarpet::Render::HTML.new(
      filter_html: true,
      hard_wrap: false, # turn off hard_wrap to avoid <br> on every new line
      with_toc_data: false
    )
    
    markdown = Redcarpet::Markdown.new(
      renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      no_intra_emphasis: true,
      strikethrough: true,
      lax_spacing: true,
      space_after_headers: true
    )
  
    markdown.render(text).html_safe
  end
  
  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def require_login
    unless current_user
      redirect_to root_path, alert: "Please log in to continue."
    end
  end

end
