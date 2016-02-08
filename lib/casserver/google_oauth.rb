require 'casserver/utils'
require 'casserver/base'
require 'google/api_client'
require 'open-uri'
require 'json'

module CASServer
  class Server < CASServer::Base
    # Hack in Google Auth
    configure do
      client = Google::APIClient.new
      client.authorization.client_id = settings.config['google_oauth']['client_id']
      client.authorization.client_secret = settings.config['google_oauth']['client_secret']
      client.authorization.scope = 'email'

      set :api_client, client
      set :google_conf, settings.config[:google_oauth]

      if settings.config[:google_oauth][:database]
        conf  = settings.config[:google_oauth]
        model = conf[:user_model].constantize
        unless model
          model = Class.new(ActiveRecord::Base)
          table = conf[:user_table] || 'users'
          if ActiveRecord::VERSION::STRING >= '3.2'
            model.table_name = table
          else
            model.set_table_name(table)
          end
        end
        begin
          model.establish_connection(conf[:database])
          model.connection
        rescue => e
          $LOG.warn e.message
          raise "Google Authenticator can not connect to database"
        end

        set :user_model, model
      else
        set :user_model, nil
      end
    end

    use Rack::Session::Cookie,
      :key => 'rack.session',
      :path => '/',
      :secret => settings.config[:session_secret]

    def api_client; settings.api_client; end
    def user_model; settings.user_model; end
    def google_conf; settings.google_conf; end

    def user_credentials
      @authorization ||= (
        auth = api_client.authorization.dup
        auth.redirect_uri = to('/oauth2callback')
        # auth.update_token!(session)
        auth
      )
    end

    get '/oauth2authorize' do
      CASServer::Utils::log_controller_action(self.class, params)

      # Request authorization
      session[:google_auth_service] = clean_service_url(params['service'])
      $LOG.info("Setting service in session to: #{session[:google_auth_service]}")
      redirect user_credentials.authorization_uri.to_s, 303
    end

    get '/oauth2callback' do
      CASServer::Utils::log_controller_action(self.class, params)

      # if there is already someone logged in, then log them out
      perform_full_logout

      begin
        @lt = generate_login_ticket.ticket
        # Exchange token
        user_credentials.code = params[:code]
        $LOG.debug("Got response code from google: #{params[:code]}")
        user_credentials.fetch_access_token!
        # session[:access_token] = user_credentials.access_token
        # session[:refresh_token] = user_credentials.refresh_token
        # session[:expires_in] = user_credentials.expires_in
        # session[:issued_at] = user_credentials.issued_at
        data = URI.parse("https://www.googleapis.com/oauth2/v1/tokeninfo?id_token=#{user_credentials.id_token}").read
        data = JSON.parse(data)
        @username = data["email"]
        $LOG.debug("Got email address from google: #{@username}")
        raise 'Failed to get username from Google' unless @username

        if user_model
          user = user_in_db(@username)
          raise "Your email address is not in our databases" unless user
        else
          user = nil
        end

        extra_attributes = get_extra_attributes(user)
        tgt = generate_ticket_granting_ticket(@username, extra_attributes)
        response.set_cookie('tgt', tgt.to_s)
        @message = {:type => 'confirmation', :message => t.notice.success_logged_in}

      rescue => e
        $LOG.warn e.message
        @message = {
          :type => 'mistake',
          :message => "Failed to log you in with Google"
        }
        if settings.development?
          @message[:message] = e.message
        end
      end

      @service = session.delete(:google_auth_service)
      session[:message] = @message
      if @service.blank?
        redirect to('/login')
      else
        redirect to("/login?service=#{@service}")
      end
    end

    def user_in_db(username)
      return nil unless username && username.size > 0
      return nil unless user_model
      user_model.where(:email => @username).first
    end

    def get_extra_attributes(user)
      return {} unless user
      extra_attributes = {}
      google_conf[:extra_attributes].each do |col|
        extra_attributes[col] = user.respond_to?(col) ? user.send(col) : nil
      end
      extra_attributes
    end
  end
end

