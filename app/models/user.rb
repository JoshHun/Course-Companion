class User < ApplicationRecord
    # A user can have many courses.
    has_many :courses, dependent: :destroy
  
    # Add validations or additional logic as needed
    validates :email, presence: true, uniqueness: true
  end