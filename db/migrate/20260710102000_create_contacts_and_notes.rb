class CreateContactsAndNotes < ActiveRecord::Migration[7.0]
  def change
    create_table :contacts do |t|
      t.string :position
      t.string :firstname
      t.string :lastname
      t.string :phone
      t.string :phone2
      t.string :email
      t.string :note
      t.integer :customer_id

      t.timestamps
    end

    create_table :notes do |t|
      t.string :name
      t.string :pass
      t.integer :customer_id
      t.integer :user_id
      t.string :text
      t.boolean :account_note, default: false

      t.timestamps
    end
  end
end
