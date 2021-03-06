ActiveAdmin.register_page 'Languages' do

  page_action :edit do; end

  page_action :update, method: :patch do; end

  controller do
    def index
      @languages = I18n.available_locales
      render layout: 'active_admin'
    end

    def edit
      @languages = I18n.available_locales
      render layout: 'active_admin'
    end

    def update
      begin
        I18n.available_locales = params[:languages].split(' ')
        redirect_to admin_languages_path, notice: 'Changes saved'
      rescue
        redirect_to admin_languages_path, notice: "Changes couldn't be saved"
      end
    end
  end

end
