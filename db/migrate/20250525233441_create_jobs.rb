class CreateJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :jobs do |t|
      t.string :title
      t.string :company
      t.text :description
      t.string :location
      t.string :salary
      t.string :employment_type
      t.text :requirements
      t.datetime :posted_at

      t.timestamps
    end
  end
end
