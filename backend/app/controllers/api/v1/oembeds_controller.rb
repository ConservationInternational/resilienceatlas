module Api
  module V1
    class OembedsController < ApiController
      require "addressable/uri"

      before_action :set_format
      before_action :decode_url
      # after_action :send_content_type_headers

      def show
        oembed = Oembed.new
        oembed.width = params[:maxwidth].to_i if params[:maxwidth]
        oembed.height = params[:maxheight].to_i if params[:maxheight]
        oembed.provider_name = @domain
        oembed.provider_url = "http://#{@domain}"
        src_url = @url.to_s.gsub(@url.path.to_s.force_encoding("UTF-8"), "").gsub(@url.query.to_s.force_encoding("UTF-8"), "").delete("?")
        oembed.html = %(<iframe frameborder="0" width="#{oembed.width}" height="#{oembed.height}" src="#{src_url.gsub("http://", "https://")}/embed/map?#{@query}"></iframe>)
        case @format
        when "xml"
          render xml: JSON.parse(oembed.to_json).to_xml(root: "oembed")
        when "json"
          render json: oembed
        end
      end

      private

      def send_content_type_headers
        response.headers["Content-Type"] = "application/#{@format}"
      end

      def set_format
        @format = if params[:format] && params[:format] == "xml"
          "xml"
        else
          "json"
        end
      end

      def decode_url
        if params[:url] && params[:url] != ""
          url = request.query_string.gsub("url=", "")
          unless url.include?("http://") || url.include?("https://")
            begin
              url = Base64.decode64(url).force_encoding("UTF-8")
            rescue => _e
              render_error(422)
            end
          end
          validate(url)
        else
          render_error(404)
        end
      end

      def validate(url)
        permitted_domains = %w[vitalsigns.org resilienceatlas.org localhost globalresiliencepartnership.org]
        begin
          url = Addressable::URI.parse(url)
          @url = url
        rescue => _e
          render_error(400)
          return
        end
        return render_error(422) if url&.host.blank?

        domain = url.host.split(".")[-2, 2]
        parsed_domain = domain.present? ? domain.join(".") : url.host
        render_error(403) unless permitted_domains.include?(parsed_domain)
        render_error(400) unless url.path.include?("/map")
        @domain = parsed_domain
        @query = url.query || ""
      end

      def render_error(status)
        self.response_body = nil
        st_codes = [404, 422, 400, 403]
        st_texts = ["Not Found", "Unprocesable Entity", "Bad Request", "Forbidden"]
        st_index = st_codes.index(status)
        error_string = st_texts[st_index]
        json_error_string = %( {"error": "#{error_string}"} )
        if @format == "json"
          render json: json_error_string, status: status and return
        else
          render xml: JSON.parse(json_error_string).to_xml(root: "oembed"), status: status and return
        end
      end
    end
  end
end
