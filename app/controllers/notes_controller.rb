class NotesController < ApplicationController

  def index
    @user = current_user
    @note = Note.new
  end
  
  def show
  end

  def new
    @note = Note.new
  end

  def edit
    @note = Note.find(params[:id])
  end

  def edit_notes
    #Used on Kanban
    @customer = Customer.find(params[:id])
    @indiv_notes = @customer.notes.where(:account_note => false).order(created_at: :desc)
    @note = Note.new
    @user = current_user
    render 'edit'
  end


  def create
    @note = Note.new(note_params)
    @c = Customer.find(@note.customer_id)
    if @note.save
        @c.update(:last_note => Time.now, :last_note_text => @note.text)
        flash[:notice] = "Note Created!"
        if @note.account_note?
          redirect_to customer_detail_path(@c, l: params[:l], view_account_notes: "view_account_notes")
        else
          redirect_to customer_detail_path(@c, l: params[:l], view_notes: "view_notes")
        end
    else
      flash[:notice] = "There was an error. Please Try Again"
      render :edit
    end

  end

# Not currently using
  def update
    @note = Note.find(params[:id])
    @c = Customer.find(@note.customer_id)
    if @note.update(note_params)
        flash[:notice] = "Note updated!"
        if @note.account_note?
          redirect_to customer_detail_path(@c, l: params[:l], view_account_notes: "view_account_notes")
        else
          redirect_to customer_detail_path(@c, l: params[:l], view_notes: "view_notes")
        end
    else
      flash[:notice] = "There was an error. Updating the Note."
      render :edit
    end
  end

  def destroy
    @note = Note.find(params[:id])
    @c = Customer.find(@note.customer_id)
    account_note = @note.account_note?
    @previous_2notes = Note.where("customer_id = ?", @c.id).last(2)
    @previous_note = @previous_2notes.first
    if @note.destroy
      if @previous_note&.created_at.present?
        @c.update(:last_note => @previous_note.created_at, :last_note_text => @previous_note.text)
      end

      flash[:notice] = "Note has been deleted!"
      if account_note
        redirect_to customer_detail_path(@c, l: params[:l], view_account_notes: "view_account_notes")
      else
        redirect_to customer_detail_path(@c, l: params[:l], view_notes: "view_notes")
      end
    else
      flash[:notice] = "Error Note has NOT been deleted!"
      redirect_to customer_detail_path(@c, l: params[:l], view_notes: "view_notes")
    end
  end

  private


    def note_params
      params.require(:note).permit(:name, :customer_id, :text, :user_id, :account_note)
    end
end
