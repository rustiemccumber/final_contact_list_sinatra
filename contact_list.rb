#contact_list.rb

require 'sinatra'
require 'sinatra/reloader' if development?
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'
require "bcrypt"

configure do 
  enable :sessions
  set :erb, :escape_html => true
end

before do
  @contacts = load_contacts
  @credentials = load_user_credentials
end

def generate_credentials_path
  File.expand_path("../user_credentials.yml", __FILE__)
end

def load_user_credentials
  credentials_path = generate_credentials_path
  YAML.load_file(credentials_path)
end

def valid_credentials?(username, password)

  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

def generate_contacts_path
  File.expand_path("../contacts.yml", __FILE__)
end

def load_contacts
  contacts_path = generate_contacts_path
  YAML.load_file(contacts_path)
end

def update_contacts
  File.open(generate_contacts_path, "w") { |file| file.write(@contacts.to_yaml) }
end

def update_credentials
  File.open(generate_credentials_path, "w") {|file| file.write(@credentials.to_yaml)}
end

def update_contact_name(original_name, new_contact_name)
  @contacts[new_contact_name] = @contacts.delete(original_name)
end

def update_contact_info(new_first_name, new_last_name, original_name)
  new_contact_name = new_first_name + " " + new_last_name
  update_contact_name(original_name, new_contact_name)
  @contacts[new_contact_name]["phone"], @contacts[new_contact_name]["email"] = params[:phone_number], params[:email]
  update_contacts
end 

def contact_details_empty?
  params.values.any? { |value| value == ""}
end

def redirect_invalid_user
  session[:message] = "You need to be sign-ed in to do that!"
  redirect "/" unless session[:username]
end

def password_matches?(password, re_password)
  password == re_password
end

get '/' do
  @contacts
  p session[:username]
  erb :contacts
end

get '/login' do
  
  erb :login
end

post '/login' do
  username = params[:username]
  if valid_credentials?(username, params[:password])
    session[:username] = username
    session[:message] = "Wecome #{username}"
    redirect "/"
  else
    session[:message] = "invalid credentials"
    status 422
    erb :login
  end
end

post '/logout' do
  session[:message] = "You have been logged out"
  session[:username] = nil
  redirect "/"
end

get '/signup' do
  erb :signup
end

post '/signup' do
  if password_matches?(params[:password], params[:re_password])
    @credentials[params[:username]] = BCrypt::Password.create(params[:password]).to_s
    update_credentials
    redirect "login"
  else
    session[:message] = "please provide a matching passord"
    erb :signup
  end
end

get '/contact/new' do
  redirect_invalid_user
  erb :new_contact
end

post '/contact/new' do

  if contact_details_empty?
    session[:message] = "please ensure all input fields are filled out"
    erb :new_contact
  else 
    new_contact_details = { "phone" => params[:phone_number], "email" => params[:email] }
    @contacts["#{params[:first_name]} #{params[:last_name]}"] = new_contact_details
  
    update_contacts
    
    session[:message] = "#{params[:first_name]} #{params[:last_name]} was succesfully added to your contacts"
    redirect "/"
  end
end

get '/contact/:name' do

  @contact_name = params[:name]
  erb :contact
end

get '/contact/:name/edit' do

  redirect_invalid_user

  @contact_name = params[:name].gsub(/[^a-zA-Z]/, " ").squeeze(' ')
  params[:first_name], params[:last_name] = @contact_name.split(" ")
  params[:phone_number], params[:email] = @contacts[@contact_name]["phone"], @contacts[@contact_name]["email"]
  erb :edit_contact
end


post '/contact/:name/update' do

  p original_name = params[:name].gsub(/[^a-zA-Z]/, " ").squeeze(' ')
  update_contact_info(params[:first_name], params[:last_name], original_name)
  session[:message] = "#{params[:first_name]} #{params[:last_name]} contact information was succesfully updated"
  redirect "/"
end


post '/contact/:name/delete' do
  redirect_invalid_user

  @contact_name = params[:name].gsub(/[^a-zA-Z]/, " ").squeeze(' ')
  @contacts.delete(@contact_name)

  update_contacts

  redirect "/"
end