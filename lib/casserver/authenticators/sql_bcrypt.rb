require 'casserver/authenticators/sql'

require 'bcrypt'

# Essentially the same as the standard SQL authenticator but assumes that
# BCrypt has been used to encrypt the password. If you're using
# has_secure_password, then this is probably for you.
class CASServer::Authenticators::SQLBcrypt < CASServer::Authenticators::SQL

  protected

  def matching_users
    results = Array(username_column).map{ |col| user_model.find(:all, :conditions => ["#{col} = ?", @username]) }.flatten(1).uniq
    results.select { |user| BCrypt::Password.new(user.send(password_column.to_sym)) == @password }
  end

end
