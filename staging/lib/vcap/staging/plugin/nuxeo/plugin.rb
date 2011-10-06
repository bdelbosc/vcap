require File.expand_path('../../common', __FILE__)
require File.join(File.expand_path('../', __FILE__), 'nuxeo.rb')
require File.join(File.expand_path('../', __FILE__), 'database_support.rb')

class NuxeoPlugin < StagingPlugin
  include NuxeoDatabaseSupport

  def framework
    'nuxeo'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      plugins_path = Nuxeo.prepare(destination_directory)
      copy_source_files(plugins_path)
      create_startup_script
      create_nuxeo_conf
    end
  end

  def create_nuxeo_conf
    nuxeo_conf = File.join(destination_directory, 'nuxeo', 'bin', 'nuxeo.conf')
    conf = { 'jvm_mem' => application_memory }.merge(database_config)
    File.open(nuxeo_conf, 'w') do |f|
      f.puts Nuxeo.nuxeo_conf(conf)
    end
  end

  # Overriden because we don't need an app directory
  def create_app_directories
    FileUtils.mkdir_p File.join(destination_directory, 'logs')
  end

  # Overriden to kill all descendants
  def generate_startup_script(env_vars = {})
    after_env_before_script = block_given? ? yield : "\n"
    template = <<-SCRIPT
#!/bin/bash
<%= environment_statements_for(env_vars) %>
<%= after_env_before_script %>
<%= change_directory_for_start %>
<%= start_command %> > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
echo "#!/bin/bash" >> ../stop
echo "killtree() { local _pid=\\$1; for _child in \\$(ps -o pid --no-headers --ppid \\${_pid}); do killtree \\${_child}; done; kill -9 \\${_pid}; }" >> ../stop
echo "killtree $STARTED" >> ../stop
echo "killtree $PPID" >> ../stop
chmod 755 ../stop
wait $STARTED
    SCRIPT
    # TODO - ERB is pretty irritating when it comes to blank lines, such as when 'after_env_before_script' is nil.
    # There is probably a better way that doesn't involve making the above Heredoc horrible.
    ERB.new(template).result(binding).lines.reject {|l| l =~ /^\s*$/}.join
  end

  def change_directory_for_start
    "cd nuxeo"
  end

  def start_command
    "./bin/nuxeoctl console"
  end

  private
  # called by create_startup_script
  def startup_script
    vars = environment_hash
    generate_startup_script(vars) do
      <<-NUXEOF
env > env.log
PORT=-1
while getopts ":p:" opt; do
  case $opt in
    p)
      PORT=$OPTARG
      ;;
  esac
done
if [ $PORT -lt 0 ] ; then
  echo "Missing or invalid port (-p)"
  exit 1
fi
# TODO: fix hard coded fqdn
  ruby resources/update_nuxeo_conf $PORT $VCAP_APP_HOST $VMC_APP_NAME
      NUXEOF
    end
  end

end
