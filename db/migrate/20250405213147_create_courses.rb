class CreateCourses < ActiveRecord::Migration[8.0]
  def change
    create_table :courses do |t|
      t.string :course_name
      t.string :course_number
      t.time :start_time
      t.time :end_time
      t.string :days_of_week

      t.timestamps
    end
  end
end
