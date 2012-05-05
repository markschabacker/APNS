module APNS
  require 'socket'
  require 'openssl'
  require 'json'

  @host = 'gateway.sandbox.push.apple.com'
  @port = 2195
  # openssl pkcs12 -in mycert.p12 -out client-cert.pem -nodes -clcerts
  @pem = nil # this should be the path of the pem file not the contentes
  @pem_contents = nil
  @pass = nil
  
  class << self
    attr_accessor :host, :pem, :pem_contents, :port, :pass
  end
  
  def self.send_notification(device_token, message)
    n = APNS::Notification.new(device_token, message)
    self.send_notifications([n])
  end
  
  def self.send_notifications(notifications)
    sock, ssl = self.open_connection
    
    notifications.each do |n|
      ssl.write(n.packaged_notification)
    end
    
    ssl.close
    sock.close
  end
  
  def self.feedback
    sock, ssl = self.feedback_connection
    
    apns_feedback = []
    
    while line = sock.gets   # Read lines from the socket
      line.strip!
      f = line.unpack('N1n1H140')
      apns_feedback << [Time.at(f[0]), f[2]]
    end
    
    ssl.close
    sock.close
    
    return apns_feedback
  end
  
  protected

  def self.open_connection
    pem_contents = self.pem_contents
    if (pem_contents.nil?)
      raise "The path to your pem file is not set. (APNS.pem = /path/to/cert.pem)" unless self.pem
      raise "The path to your pem file does not exist!" unless File.exist?(self.pem)
      pem_contents = File.read(self.pem)
    end
    
    context      = OpenSSL::SSL::SSLContext.new
    context.cert = OpenSSL::X509::Certificate.new(pem_contents)
    context.key  = OpenSSL::PKey::RSA.new(pem_contents, self.pass)

    sock         = TCPSocket.new(self.host, self.port)
    ssl          = OpenSSL::SSL::SSLSocket.new(sock,context)
    ssl.connect

    return sock, ssl
  end
  
  def self.feedback_connection
    pem_contents = @pem_contents
    unless (pem_contents.nil?)
      raise "The path to your pem file is not set. (APNS.pem = /path/to/cert.pem)" unless self.pem
      raise "The path to your pem file does not exist!" unless File.exist?(self.pem)
      pem_contents = File.read(self.pem)
    end
    
    context      = OpenSSL::SSL::SSLContext.new
    context.cert = OpenSSL::X509::Certificate.new(pem_contents)
    context.key  = OpenSSL::PKey::RSA.new(pem_contents, self.pass)

    fhost = self.host.gsub!('gateway','feedback')
    puts fhost
    
    sock         = TCPSocket.new(fhost, 2196)
    ssl          = OpenSSL::SSL::SSLSocket.new(sock,context)
    ssl.connect

    return sock, ssl
  end
  
end
