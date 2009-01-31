#!/usr/bin/env ruby

require 'rubygems'
require 'compass'
require 'sinatra'
require 'sequel'


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
end

########################################################################
### S E T U P   A N D   F I L T E R S
########################################################################
configure do
end

before do
  @page_title = "small ideas for small apps"
  @header     = partial( :header )
end

########################################################################
### A S S E T S
########################################################################
get '/styles.css' do
  content_type 'text/css'

  # Use views/stylesheets & blueprint's stylesheet dirs in the Sass
  # loadpath
  sass :styles, {
    :sass => {
      :load_paths => (
        [ File.join( File.dirname(__FILE__), 'views' ) ] +
        Compass::Frameworks::ALL.map {|f| f.stylesheets_directory }
      )
    }
  }
end

########################################################################
### A C T I O N S
########################################################################
get '/' do
  @header = nil
  haml :index
end
