require 'nokogiri'
require 'fileutils'
require 'erb'

class Nuxeo
  def self.resource_dir
    File.join(File.dirname(__FILE__), 'resources')
  end

  def self.prepare(dir)
    FileUtils.cp_r(File.join(File.dirname(__FILE__), 'resources'), dir)
    output = %x[cd #{dir}; unzip -q resources/nuxeo.zip]
    raise "Could not unpack Nuxeo: #{output}" unless $? == 0
    plugins_path = File.join(dir, "nuxeo", "nxserver", "plugins")
    FileUtils.rm(File.join(dir, "resources", "nuxeo.zip"))
    FileUtils.mv(File.join(dir, "resources", "droplet.yaml"), dir)
    plugins_path
  end

  def self.nuxeo_conf(conf)
    nx_template = conf['template']
    jvm_mem = conf['jvm_mem']
    db_host = conf['host']
    db_port = conf['port']
    db_user = conf['username']
    db_password = conf['password']
    db_name = conf['database']
    template = <<-ERB
JAVA_OPTS=-Xms<%= jvm_mem %>m -Xmx<%= jvm_mem %>m -XX:MaxPermSize=512m -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000 -Dfile.encoding=UTF-8
# Enable gc log
JAVA_OPTS=$JAVA_OPTS -Xloggc:${nuxeo.log.dir}/gc.log -verbose:gc -XX:+PrintGCDetails -XX:+PrintGCTimeStamps
nuxeo.force.generation=true
nuxeo.wizard.done=true
launcher.override.java.tmpdir=false
# disable ajp and admin port
nuxeo.server.ajp.port=-1
nuxeo.server.tomcat-admin.port=-1
nuxeo.bind.address=TCATHOST
nuxeo.server.http.port=TCATPORT
nuxeo.url=http://FQDN/nuxeo
nuxeo.loopback.url=http://TCATHOST:TCATPORT/nuxeo
<% if (nx_template == 'postgresql') %>
nuxeo.templates=postgresql
nuxeo.db.name=<%= db_name %>
nuxeo.db.user=<%= db_user %>
nuxeo.db.password=<%= db_password %>
nuxeo.db.host=<%= db_host %>
nuxeo.db.port=<%= db_port %>
# activate cluster mode, binaries are not persisted at the moment
repository.clustering.enabled=true
repository.clustering.delay=2000
repository.binary.store=${nuxeo.data.dir}/binaries
<% else %>
nuxeo.templates=default
<% end %>
ERB
    ERB.new(template).result(binding)
  end

end
