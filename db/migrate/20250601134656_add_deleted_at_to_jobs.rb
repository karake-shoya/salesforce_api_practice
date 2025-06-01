class AddDeletedAtToJobs < ActiveRecord::Migration[8.0]
  def change
    add_column :jobs, :deleted_at, :datetime
  end
end
