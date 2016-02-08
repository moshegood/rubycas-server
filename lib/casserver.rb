module CASServer; end

require 'active_record'
require 'active_support'
require 'sinatra/base'
require 'builder' # for XML views
require 'logger'
$LOG = Logger.new(STDOUT)

require 'casserver/authenticators/base'
CASServer::Authenticators.autoload :LDAP, 'casserver/authenticators/ldap.rb'
CASServer::Authenticators.autoload :ActiveDirectoryLDAP, 'casserver/authenticators/active_directory_ldap.rb'
CASServer::Authenticators.autoload :SQL, 'casserver/authenticators/sql.rb'
CASServer::Authenticators.autoload :Google, 'casserver/authenticators/google.rb'
CASServer::Authenticators.autoload :SQLEncrypted, 'casserver/authenticators/sql_encrypted.rb'
CASServer::Authenticators.autoload :ActiveResource, 'casserver/authenticators/active_resource.rb'
CASServer::Authenticators.autoload :SQLBcrypt, 'casserver/authenticators/sql_bcrypt.rb'
CASServer::Authenticators.autoload :SQLRestAuth, 'casserver/authenticators/sql_rest_auth.rb'

require 'casserver/service_check/base'
CASServer::ServiceCheck.autoload :SQL, 'casserver/service_check/sql.rb'

require 'casserver/server'
require 'casserver/google_oauth' if CASServer::Server.settings.config[:google_oauth]
