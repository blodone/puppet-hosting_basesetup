class hosting_basesetup::monitoring (
  Boolean $zabbix_agent                        = true,
  String $zabbix_server                        = 'zabbix',
  String $zabbix_server_active                 = 'zabbix',
  String $zabbix_listenip                      = '127.0.0.1',
  String $zabbix_hostmetadata                  = '|Linux|Puppet|',
  Array[String] $additional_agent_packages     = [],
  String $additional_agent_packages_ensure     = 'installed',
  Boolean $use_zabbix_agent_extensions         = false,
  String  $use_zabbix_agent_extensions_pkgname = 'zabbix-agent-extensions',
  String  $use_zabbix_agent_extensions_release = 'present',
) {
  if $zabbix_agent {
    class { 'zabbix::agent':
      server       => "${zabbix_server}, 127.0.0.1",
      serveractive => $zabbix_server,
      listenip     => $zabbix_listenip,
      buffersize   => 500,
      hostmetadata => $zabbix_hostmetadata,
    }
    include ::zabbix::sender

    ensure_packages(["zabbix-get"],
      {
        'require' => Class['zabbix::agent'],
      }
    )
    ensure_packages(
      $additional_agent_packages,
      {
        'ensure'  => $additional_agent_packages_ensure,
        'require' => Class['zabbix::agent'],
      }
    )
  }

  if $use_zabbix_agent_extensions and $zabbix_agent {
    # ensure that this package is part of the package repos
    ensure_packages([$use_zabbix_agent_extensions_pkgname],
      {
        'ensure'  => $use_zabbix_agent_extensions_release,
        'require' => Class['zabbix::agent'],
        'before'  => [ File['/etc/zabbix/zabbix_agentd.conf'], Service['zabbix-agent'], ]
      }
    )
    file { '/etc/sudoers.d/zabbix':
      ensure => present,
      mode   => '0440',
      owner  => 'root',
      group   => 'root',
    }
    file { '/etc/zabbix/zabbix_agentd.d/zabbix-agent-extensions':
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => '# Maintained by puppet
Include=/usr/share/zabbix-agent-extensions/include.d/
          ',
      notify  => Service['zabbix-agent'],
    }
    file_line { '/etc/zabbix/zabbix_agentd.conf':
      ensure            => absent,
      path              => '/etc/zabbix/zabbix_agentd.conf',
      match             => '^Include=/usr/share/zabbix-agent-extensions/include.d/.*',
      match_for_absence => true,
      notify            => Service['zabbix-agent'],
    }
  }
}
