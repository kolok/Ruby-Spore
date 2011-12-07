# encoding: utf-8
require 'rubygems'
require 'uri'
require 'net/http'
require 'httpclient'

# we need to be able to build an HTTPResponse object,
# and apparently, there's no way to do that outside of the HTTPResponse class
# WTF?
module HTTP
  class Message
    def body=(value)
      @body = value
    end
  end
end

# SPORE
class Spore

  attr_accessor :name, :author
  attr_accessor :base_url, :format, :version
  attr_accessor :methods
  attr_accessor :middlewares
  attr_reader :specs, :config

  class RequiredParameterExptected < Exception
  end

  class UnexpectedResponse < Exception
  end

  class UnsupportedSpec < Exception
  end

  class InvalidHeaders < Exception
  end

  ##
  # Initialize a Spore instance with a specification file<br/>
  # Optionally a file to require the parser from and the custom bound Parser class 
  #
  # :call-seq:
  #   new(file_path, options = {} )
  #
  #   Spore.new('/tmp/github.json')
  #
  # or
  #
  #   Spore.new('/tmp/spec.dot', :require => 'my_custom_lib', :parser => 'DotParser')
  #
  # DotParser must implement a class method load_file
  #
  #   class DotParser
  #     def self.load_file(f)
  #       str = ""
  #       File.open(f) do |f|
  #         str = ...
  #         # Do what you have to here
  #       end
  #     end
  #   end
  #
  def initialize(spec,options = {})
    # Don't load gems that are not needed
    # Only When it requires json, then json is loaded
    parser = self.class.load_parser(spec, options)
    @config = options[:client_config] || {:ssl_verify_mode =>  OpenSSL::SSL::VERIFY_PEER | OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT }
      
    specs = parser.load_file(spec)

    inititliaze_api_attrs(specs)
    construct_client_class(self.methods)
    self.middlewares = []
  end

  ##
  # :call-seq:
  #   spore.enable(Spore::Middleware::SomeThing, :optionX => 42)
  # 
  # This method takes a middleware class as its first argument.
  # Options to pass to the middleware can be given as a second
  # argument.
  # Once this method is called, the Spore client will pass the request
  # and the response objects to the middleware whenever appropriate.
  # The order in which middlewares are enabled is respected by Spore.
  # (same order for processing the request before it's sent, reverse
  # order for processing response, as described in the Spore
  # specification).
  #

  def enable(middleware, args={})
    m = middleware.new(args)
    self.middlewares.push({
      :condition => Proc.new { true }, 
      :middleware => m
    })
  end

  ##
  # :call-seq:
  #   spore.enable_if(Spore::Middleware::SomeThing, :optionX => 42) do |env| {
  #     # return true or false, depending on env to say if the
  #     # middleware should be enabled or not for this request
  # }
  # 
  # Same as the enable method, but is enabled dynamically, depending
  # of the current request env.
  # A block is given and is passed the env stack, it should return a
  # boolean value to tell if the middleware should be enabled or not.
  # 
  def enable_if(middleware, args={}, &block)
    m = middleware.new(args)
    self.middlewares.push({
      :condition => block,
      :middleware => m
    })
  end

  ##
  # :call-seq:
  #   load_parser(spec_file, options = {})
  #
  # This method takes two arguments spec_file and options<br/>
  # If spec is a yml or json file options is skipped<br/>
  # Else options is used for requiring and loading the correct parser<br/><br/>
  # options is a Hash with :require and :parser keys.
  # *  :require is a file to require
  # *   :parser is a String to pass in Object.const_get
  #

  def self.load_parser(spec, options = {})
    case spec
    when /\.ya?ml/
      require('spore/spec_parser/yaml')
      Spore::SpecParser::Yaml
    when /\.json/
      require 'spore/spec_parser/json'
      Spore::SpecParser::Json
    else
      if options.has_key?(:require)
        require options[:require]
        if options.has_key?(:parser)
          Object.const_get(options[:parser])
        else
          Object.const_get(options[:require].to_s.capitalize)
        end
      else
        raise UnsupportedSpec, "don't know how to parse '#{spec}'"
      end
    end
  end

  private

  def inititliaze_api_attrs(spec)
    self.name = spec['name']
    self.author = spec['author']
    self.base_url = spec['base_url'].gsub(/\/$/, '')
    self.format = spec['format']
    self.version = spec['version']
    self.methods = spec['methods']
  end

  # FIXME : collapse methods 
  # Hmmm I think it is not good
  # If we use Github API and Facebook API in the same project, methods may be overriden

  def construct_client_class(methods)
    methods.keys.each do |m|
      define_method(m, methods[m])
    end
  end

  def define_method(name, m)
    method = m['method'].downcase
    path = m['path']
    params = m['params']
    required = m['required_params'] || m['required'] || []
    expected = m['expected']
    desc = m['description']

    mod = Module.new
    mod.send(:define_method, name) do |args| 

      # make sure all mandatory params are sent
      required.each do |mandatory|
        if not args.has_key?(mandatory.to_sym)
          raise RequiredParameterExptected, "parameter `#{mandatory}' expected"
        end
      end

      # build the real path (expand named tokens)
      path_detail = path.split(/\?/)
      real_path = path_detail[0]
      additional_args = path_detail[1].split(/&/).map{ |c| c.split(/=/) } if !path_detail[1].nil?

      while m = real_path.match(/:([^:\/\.]+)/)
        if not args.has_key?(m[1].to_sym)
          raise RequiredParameterExptected, "named token `#{m[1]}' expected"
        end
        real_path = real_path.gsub(/:#{m[1]}/, args[m[1].to_sym].to_s)
          args.delete(m[1].to_sym)
      end

      additional_args.each{ |c|
        args[c[0].to_sym] = c[1]
      } if !additional_args.nil?

      full_path = "#{self.base_url}#{real_path}"

      # build the ENV hash
      env = {}
      env['spore.request_method'] = method
      env['spore.request_path'] = full_path
      env['spore.request_params'] = args
      env['spore.request_headers'] = []

      response = nil

      # call all middlewares
      self.middlewares.each do |m|
        if m[:condition].call(env)
          response = m[:middleware].process_request(env)
          break if response 
        end
      end

      # transoform the SPORE response to a valid HTTPResponse object
      if response
        response = to_http(response)
      end

      if not response

        res = send_http_request(
          env['spore.request_method'],
          env['spore.request_path'],
          env['spore.request_params'],
          env['spore.request_headers'])

          # parse the response and make sure we have expected result
          if expected && (not expected.include?(res.code.to_i))
            raise UnexpectedResponse, "response status: '#{res.code}' expected is: #{expected.to_json}"
          end

          response = res
      end

      # process response with middlewares in reverse orders
      self.middlewares.reverse.each do |m|
        if m[:condition].call(env)
          response = m[:middleware].process_response(response, env)
        end
      end

      response
    end
    self.extend(mod)
  end

  def send_http_request(method_name, path, params, headers)
  
    # our HttpClient object
    client = HTTPClient.new
    client.ssl_config.verify_mode = @config[:ssl_verify_mode]

    # normalize our headers for HttpClient
    h = headers.map{|header| header.values_at(:name,:value)}

    # force content type to form urlencoded
    if ! h.any?{|a| a[0] == 'Content-Type' } && method_name != 'get'
      h.push(['Content-Type', 'application/x-www-form-urlencoded'])
    end

    # the response object we expect to have
    resp = client.send(method_name,path, params, h) if method_name =~ %r{get|post|put}
    resp = client.delete(path, h) if method_name == 'delete'

    return resp
  end

  def to_http(spore_resp)
    return nil if spore_resp.nil?
    return spore_resp if spore_resp.class != Array

    code    = spore_resp[0]
    headers = spore_resp[1]
    body    = spore_resp[2][0]

    if headers.size % 2 != 0
      raise InvalidHeaders, "Odd number of elements in SPORE headers"
    end

    r = Net::HTTPResponse.new('1.1', code, '')  
    i = 0
    while i < headers.size
      header = headers[i]
      value  = headers[i+1]
      r.add_field(header, value)
      i += 2
    end

    r.body = body if body
    return r
  end
end
