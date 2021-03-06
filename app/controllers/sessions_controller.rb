# This controller handles the login/logout function of the site.  
class SessionsController < ApplicationController
  # Be sure to include AuthenticationSystem in Application Controller instead
  include AuthenticatedSystem

  protect_from_forgery :except => :create

  # render new.rhtml
  def new
  end

  def create
    logout_keeping_session!
    if using_open_id?
      if params[:openid_url] # 当有openid的输入时，格式化unicode的openid为ascii的标准url
        # 将unicode字符编码URI为符合IDN标准的ascii punycode URI
        idn = "http://" + Idna.toASCII(params[:openid_url].gsub(/[a-zA-Z]+:\/\//,'')) 
        ret = OpenIdAuthentication.normalize_url(idn) # 将OpenID标准化
        open_id_authentication(ret)
      else # openid提供者返回的标准ascii url不需要再格式化
        open_id_authentication(params[:openid_url])
      end
    else
      password_authentication(params[:login], params[:password])
    end
  end

  def destroy
    logout_killing_session!
    flash[:notice] = "You have been logged out."
    redirect_back_or_default('/')
  end

protected
  def password_authentication(login, password)
    user = User.authenticate(login, password)
    if user
      # Protects against session fixation attacks, causes request forgery
      # protection if user resubmits an earlier form using back
      # button. Uncomment if you understand the tradeoffs.
      # reset_session
      self.current_user = user
      new_cookie_flag = (params[:remember_me] == "1")
      handle_remember_cookie! new_cookie_flag
      redirect_back_or_default('/')
      flash[:notice] = "Logged in successfully"
    else
      note_failed_signin
      @login       = params[:login]
      @remember_me = params[:remember_me]
      render :action => 'new'
    end
  end
  
  # Track failed login attempts
  def note_failed_signin
    flash[:error] = "Couldn't log you in as '#{params[:login]}'"
    logger.warn "Failed login for '#{params[:login]}' from #{request.remote_ip} at #{Time.now.utc}"
  end
  
  # 纯认证，不带注册支持
  # def open_id_authentication(identity_url)
  #   authenticate_with_open_id(identity_url) do |result, identity_url|
  #     if result.successful?
  #       if @openid = OpenId.find_by_url(identity_url)
  #        self.current_user = @openid.user
  #         successful_login
  #       else
  #         failed_login "Sorry, no user by that identity URL exists (#{identity_url})"
  #       end
  #     else
  #       failed_login result.message
  #     end
  #   end
  # end
  
  # 带OpenID简单注册支持的认证，如果是新OpenID，提供注册表格
  def open_id_authentication(identity_url)
    # Pass optional :required and :optional keys to specify what sreg fields you want.
    # Be sure to yield registration, a third argument in the #authenticate_with_open_id block.
    authenticate_with_open_id(identity_url, :required => [ :nickname, :email ],:optional => :fullname) do |result, identity_url, registration|
      case result.status
      when :missing
        failed_login "Sorry, the OpenID server couldn't be found"
      when :invalid
        failed_login "Sorry, but this does not appear to be a valid OpenID"
      when :canceled
        failed_login "OpenID verification was canceled"
      when :failed
        failed_login "Sorry, the OpenID verification failed"
      when :successful
        if @openid = OpenId.find_by_url(identity_url) # 如果存在，让其登录
          self.current_user = @openid.user
          successful_login
        elsif # 如不存在，提供注册表格
          @user = User.new
          assign_registration_attributes!(registration)
          @user.open_ids.build(:url => identity_url)
          render :file => 'sessions/new_user', :use_full_path => true, :layout => true
        else
          failed_login "Sorry, no user by that identity URL exists"
        end
      end
    end
  end

  # registration is a hash containing the valid sreg keys given above
  # use this to map them to fields of your user model
  def assign_registration_attributes!(registration)
    model_to_registration_mapping.each do |model_attribute, registration_attribute|
      unless registration[registration_attribute].blank?
        @user.send("#{model_attribute}=", registration[registration_attribute])
      end
    end
  end

  def model_to_registration_mapping
    { :login => 'nickname', :email => 'email', :name => 'fullname' }
  end
  
private
  
  def successful_login
    session[:user_id] = self.current_user.id
    # redirect_to(root_url)
    redirect_back_or_default('/')
    flash[:notice] = "Logged in successfully"
  end

  def failed_login(message)
    flash[:error] = message
    redirect_to(new_session_url)
  end
  
end
