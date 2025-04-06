# app/controllers/dashboard_controller.rb
require 'net/http'
require 'json'

class DashboardController < ApplicationController
  def index
    @courses = fetch_canvas_courses
  end

  def course
    slug = params[:course_name]
    courses = fetch_canvas_courses  # Fetch courses from the API
    @course = courses.find { |course| course["name"].parameterize == slug }
    if @course
      render :course  # This now looks for app/views/dashboard/course.html.erb
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
  
    current_term = current_canvas_term
    
    # Filter courses to only include those in Spring 25.
    filtered_courses = all_courses.select do |course|
      term_name = course.dig("term", "name")
      term_name&.strip&.casecmp(current_term)&.zero?
    end

    # Remove the first 'word' from each course name, e.g. "CEN4020.001S25.15531 Software Engineering"
    # becomes "Software Engineering"
    filtered_courses.each do |course|
      original_name = course["name"].to_s
      # Split by the first space; if there's no space, it falls back to the entire name.
      trimmed_name = original_name.split(" ", 2).last || original_name
      course["name"] = trimmed_name
    end

  filtered_courses
  end

  def current_canvas_term
    now = Time.zone.now
    year_suffix = now.year.to_s[-2..]  # "2025" => "25"
  
    season =
      case now.month
      when 1..4
        "Spring"
      when 5..7
        "Summer"
      else
        "Fall"
      end
  
    "#{season} #{year_suffix}"  # e.g., "Spring 25"
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end
end
