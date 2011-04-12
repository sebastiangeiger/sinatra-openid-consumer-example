# An example for an OpenID consumer using Sinatra

require 'rubygems'
require 'sinatra'
require 'openid'
require 'openid/store/filesystem'
require 'openid/extensions/sreg'
require 'openid/extensions/ax'
require 'haml'

  
  def openid_consumer
    @openid_consumer ||= OpenID::Consumer.new(session,
        OpenID::Store::Filesystem.new("#{File.dirname(__FILE__)}/tmp/openid"))  
  end

  def root_url
    request.url.match(/(^.*\/{2}[^\/]*)/)[1]
  end

  # In a real app, you might want to do something like this 
  #
  # enable :sessions 
  #
  # Returns true if somebody is logged in  
  # def logged_in?
  #   !session[:user].nil?
  # end
  #
  # Visit /logout to log out
  # get '/logout' do
  #   session[:user] = nil
  #   # redirect '/login'
  # end

  get '/login' do    
    haml :login
  end

  post '/login/openid' do
    openid = params[:openid_identifier]
    begin
      oidreq = openid_consumer.begin(openid)
    rescue OpenID::DiscoveryFailure => why
      "Sorry, we couldn't find your identifier '#{openid}'"
    else
      # You could request additional information here - see specs:
      # http://openid.net/specs/openid-simple-registration-extension-1_0.html
      # sregreq = OpenID::SReg::Request.new
      # sregreq.request_field('email', true)     #email is required 
      # sregreq.request_field('fullname', false) #fullname is optional      
      # oidreq.add_extension(sregreq)
      # Requesting the additional information via Attribute Exchange
      # see: http://www.axschema.org
      ax_req = OpenID::AX::FetchRequest.new
      ax_req.add(OpenID::AX::AttrInfo.new('http://axschema.org/contact/email', 'email', true))
      oidreq.add_extension(ax_req)
      oidreq.return_to_args['did_ax'] = 'y'
      # Send request - first parameter: Trusted Site,
      # second parameter: redirect target
      redirect oidreq.redirect_url(root_url, root_url + "/login/openid/complete")
    end
  end

  get '/login/openid/complete' do
    oidresp = openid_consumer.complete(params, request.url)

    case oidresp.status
      when OpenID::Consumer::FAILURE
        "Sorry, we could not authenticate you with the identifier '{openid}'."

      when OpenID::Consumer::SETUP_NEEDED
        "Immediate request failed - Setup Needed"

      when OpenID::Consumer::CANCEL
        "Login cancelled."

      when OpenID::Consumer::SUCCESS
        ax_response = OpenID::AX::FetchResponse.from_success_response(oidresp)
        @email = ax_response['http://axschema.org/contact/email'].first
        haml :welcome
        # Maybe something like
        # session[:user] = User.find_by_email(@email)
    end
  end

__END__

@@ login

%form{:method => "post", :action => '/login/openid'}
	%label Your OpenID
	%input{:type => 'text', :name => 'openid_identifier'}
	%input{:type => 'submit', :value => "Login"}
