class Course < ApplicationRecord
    # Each course belongs to a user.
    belongs_to :user
  
    # Add validations or additional logic as needed
    validates :course_name, :course_number, presence: true
  end
  