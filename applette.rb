#!/usr/bin/env ruby
#
# A silly webapp to track ideas for other silly webapps
#
# == Authors
#
# * Ben Bleything <ben@bleything.net>
#
# == Copyright
#
# Copyright (c) 2009 Ben Bleything
#
# This code released under the terms of the MIT license.
#

require 'rubygems'
require 'sinatra'
require 'sequel'

gem 'ruby-openid', '>=2.1.2'
require 'openid'
require 'openid/store/filesystem'

########################################################################
### S E T U P   A N D   F I L T E R S
########################################################################
enable :sessions

configure do
  APP_ROOT = File.dirname( __FILE__ )
  
  OPENID_STORE_DIR = File.join( APP_ROOT, 'tmp', 'openid' )
  OPENID_STORE = OpenID::Store::Filesystem.new( OPENID_STORE_DIR )
end

before do
  @page_title = "big ideas for small apps"
  @header     = partial( :header )
  
  # simulate Rails' flash concept.  Supports three kinds of flash,
  # warning, error and message.
  session[ :flash ] ||= {}
  
  if session[ :flash ][ :warning ]
    @warning = session[ :flash ][ :warning ].dup
    session[ :flash ].delete :warning
  end
  
  if session[ :flash ][ :message ]
    @message = session[ :flash ][ :message ].dup
    session[ :flash ].delete :message
  end
  
  if session[ :flash ][ :error ]
    @error = session[ :flash ][ :error ].dup
    session[ :flash ].delete :error
  end

  # grab @user; we'll need it later.
  @user = User.find( :id => session[:user_id] ) if session[ :user_id ]
end


########################################################################
### H E L P E R S
########################################################################
helpers do
  def partial( name )
    # the haml method expects a symbol, so we have to do this stupid
    # interning crap.
    haml "partials/_#{name}".to_sym, :layout => false
  end

  def display_userbox
    if session[ :user ]
      # partial :userinfo
    else
      partial :login_note
    end
  end
  
  # this is required for the openid code jacked from
  # http://github.com/ahaller/sinatra-openid-consumer-example/tree/master
  def openid_consumer
    @openid_consumer ||= OpenID::Consumer.new( session, OPENID_STORE )
  end

  # this is required for the openid code jacked from
  # http://github.com/ahaller/sinatra-openid-consumer-example/tree/master  
  def root_url
    request.url.match(/(^.*\/{2}[^\/]*)/)[1]
  end
  
  # simulate Rails' flash concept.  This supports three kinds of flash,
  # warning, error and message.
  def flash( type, message )
    session[ :flash ] ||= {}
    session[ :flash ][ type ] = message
  end
end


#####################################################################
###	E R R O R   H A N D L E R S
#####################################################################
error OpenID::DiscoveryFailure do
  openid = request.env['rack.request.form_hash']['openid']

  @error = "Sorry, we couldn't find your OpenID <span class='openid'>#{openid}</span>. Double-check that you've got the address right and try again."
  
  haml :login
end


########################################################################
### A S S E T S
########################################################################
get '/css/applette.css' do
  content_type 'text/css'
  sass :styles
end

########################################################################
### A C T I O N S
########################################################################
get '/' do
  @header = partial( :banner )
  haml :index
end

get '/login' do
  haml :login
end

#####################################################################
###	O P E N I D   H A N D L I N G
#####################################################################
post '/login' do
  # this might raise OpenID::DiscoveryFailure.  We have an error handler elsewhere to deal with
  # that, so don't bother rescuing it here.
  oidreq = openid_consumer.begin( params[ :openid ] )
  
  # we want the user's name (for greeting them) and email (for gravatar)
  oidreq.add_extension_arg( 'sreg', 'optional', 'fullname,email,nickname' )

  # Send request - first parameter: Trusted Site,
  # second parameter: redirect target
  redirect oidreq.redirect_url( root_url, root_url + "/login/complete" )
end

get '/login/complete' do
  oidresp = openid_consumer.complete( params, request.url )
  openid = oidresp.display_identifier
  
  case oidresp.status
    when OpenID::Consumer::FAILURE
      @error = "Sorry, we could not authenticate you with <span class='openid'>#{openid}</span>."
 
    when OpenID::Consumer::SETUP_NEEDED
      @error = "I have no idea what this error means.  Please contact me via email at ben@bleything.net if you get it!"
 
    when OpenID::Consumer::CANCEL
      @error = "Authorization cancelled.  Please try again."
 
    when OpenID::Consumer::SUCCESS
      user = User.find_or_create( :openid => openid )

      user.email    = params[ 'openid.sreg.email'    ] rescue nil
      user.name     = params[ 'openid.sreg.fullname' ] rescue nil
      user.nickname = params[ 'openid.sreg.nickname' ] rescue nil
      
      user.save
      
      session[ :user_id ] = user.id
      
      flash :message, "Login successful! #{session.inspect}"
      
      redirect '/user_details'
  end
  
  haml :login
end