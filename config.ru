require 'rubygems'
require 'sinatra'
 
set :env,  :production
disable :run

require 'applette'

run Sinatra.application