module NuxeoDatabaseSupport
  # Returns the service binding that was used for the 'production' db entry.
  def database_config
    bindings = bound_databases
    case bindings.size
    when 0
      empty_config
    else
      database_config_for(binding)
    end
  end

  def empty_config
    { 'template' => 'default',
      'host' => 'localhost', 'port' => -1,
      'username' => 'sa', 'password' => '',
      'database' => 'sys' }
  end

  def database_config_for(binding)
    case binding[:label]
    when /^postgresql/
      { 'template' => 'postgresql' }.merge(credentials_from(binding))
    else
      # Should never get here, so it is an exception not 'exit 1'
      raise "Unable to configure unknown database: #{binding.inspect}"
    end
  end

  # return host, port, username, password, and database
  def credentials_from(binding)
    creds = binding[:credentials]
    unless creds
      puts "Database binding failed to include credentials: #{binding.inspect}"
      exit 1
    end
    { 'host' => creds[:hostname], 'port' => creds[:port],
      'username' => creds[:user], 'password' => creds[:password],
      'database' => creds[:name] }
  end

  def bound_databases
    bound_services.select { |binding| known_database?(binding) }
  end

  def known_database?(binding)
    if label = binding[:label]
      case label
      when /^postgresql/
        binding
      end
    end
  end
end
