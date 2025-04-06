# app/controllers/courses_controller.rb
require 'net/http'
require 'json'
require 'stringio'
require 'time'

class CoursesController < ApplicationController
  def show
    slug = params[:course_name]
    courses = fetch_canvas_courses  # Fetch courses from the Canvas API
    @course = courses.find { |course| course["name"].parameterize == slug }
    
    if @course
        Rails.logger.info("Finding file")
        folder_files = fetch_course_files(@course["id"])
        Rails.logger.info("\n\nFinding modeule")
        module_files = fetch_module_files(@course["id"])
        @files = folder_files + module_files
      render :show  # Renders app/views/courses/show.html.erb
    else
      redirect_to dashboard_path, alert: "Course not found."
    end
  end

  private

  def fetch_canvas_courses
    return [] unless current_user&.canvas_token
  
    uri = URI("https://usflearn.instructure.com/api/v1/courses?enrollment_state=active&include[]=term")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
  
    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{current_user.canvas_token}"
  
    res = http.request(req)
    return [] unless res.code == "200"
  
    all_courses = JSON.parse(res.body)
  
    filtered_courses = all_courses.select do |course|
      term_name = course.dig("term", "name")
      term_name && term_name.strip.casecmp("Spring 25").zero?
    end
  
    filtered_courses.each do |course|
      original_name = course["name"].to_s
      trimmed_name = original_name.split(" ", 2).last || original_name
      course["name"] = trimmed_name
    end
  
    filtered_courses
  end

  def fetch_course_files(course_id)
    all_files = []
    folders_uri = URI("https://usflearn.instructure.com/api/v1/courses/#{course_id}/folders?per_page=50")
    folders = fetch_all_pages(folders_uri, current_user.canvas_token)
  
    folders.each do |folder|
      files_uri = URI("https://usflearn.instructure.com/api/v1/folders/#{folder['id']}/files?per_page=50")
      files = fetch_all_pages(files_uri, current_user.canvas_token)
      
      files.each do |file|
        # Print the file’s display_name (or filename if display_name is missing)
        name = file["display_name"] || file["filename"] || "Unknown file name"
        Rails.logger.info("Found folder file: #{name}")
      end
      
      all_files.concat(files)
    end
  
    all_files
  end
  
  def fetch_module_files(course_id)
    module_files = []
    modules_uri = URI("https://usflearn.instructure.com/api/v1/courses/#{course_id}/modules?per_page=50")
    modules = fetch_all_pages(modules_uri, current_user.canvas_token)
  
    modules.each do |mod|
      items_uri = URI("https://usflearn.instructure.com/api/v1/courses/#{course_id}/modules/#{mod['id']}/items?per_page=50")
      items = fetch_all_pages(items_uri, current_user.canvas_token)
      
      items.each do |item|
        # We assume module file items have "type" => "File"
        if item["type"] == "File"
          # Print the module item title (Canvas often stores the file name in "title" for module items)
          title = item["title"] || "Unknown module file name"
          Rails.logger.info("Found module file item: #{title}")
          module_files << item
        end
      end
    end
  
    module_files
  end

  def fetch_all_pages(uri, token)
    results = []
    loop do
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{token}"
      res = http.request(req)
      break unless res.code == "200"
      page_data = JSON.parse(res.body)
      results.concat(page_data)
      link_header = res['link']
      next_link = nil
      if link_header
        links = link_header.split(',').map(&:strip)
        links.each do |link|
          if link.include?('rel="next"')
            next_link = link[/<(.*?)>/, 1]
            uri = URI(next_link)
            break
          end
        end
      end
      break unless next_link
    end
    results
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end
end
