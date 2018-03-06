class hosting_basesetup::kernel (
  String $sysctl_filename       = '/etc/sysctl.conf',
  String $ulimits_filename      = '/etc/security/limits.d/hosting_basesetup.conf',
  String $boot_options          = '',
  Hash $sysctl_config           = {},
  Array[String] $ulimit_config  = [],
  Boolean $sysctl_enable_fastnetworking_defaults = false,
  Boolean $sysctl_enable_tcp_timeout_optimzation = false,
  Boolean $sysctl_ignore_defaults = false,
  Boolean $ulimit_ignore_defaults = false,
  ) {
  # Sysctl reload
  file { 'sysctl_conf': name => $sysctl_filename, }

  exec { 'sysctl_file_load':
    command     => 'sysctl -p',
    refreshonly => true,
    subscribe   => File['sysctl_conf'],
    path        => "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
  }

  $sysctl_stdkernel = { 
    'kernel.panic'=> { 'value'=> 30 } ,
    'kernel.panic_on_oops' => { 'value'=> 30 } ,
    # Makes only sense on webservers/application servers where drastic reboot helps to get rid of performance problems
    # 'vm.panic_on_oom'=> { 'value'=> 1 } ,
    'vm.swappiness' => { 'value'=> 1 } ,
    'fs.aio-max-nr' => { 'value'=> 262144 },
    'fs.file-max' => { 'value'=> 1000000 },
    'kernel.pid_max' => 4194303,
    'vm.zone_reclaim_mode' => 0,
  }
  
  #################################################################################
  # TCP TIMEOUT Optimization
  # During low traffic intervals, a firewall configured with an idle connection 
  # timeout can close connections to local nodes and nodes in other data centers.
  if $sysctl_enable_tcp_timeout_optimzation {
    $sysctl_tcp_timout_optimization_defaults = {
      'net.ipv4.tcp_keepalive_time' => {'value' => '60'}, 
      'net.ipv4.tcp_keepalive_probes' => {'value' => '3'},
      'net.ipv4.tcp_keepalive_intvl' => {'value' => '10'},
    }
  }else{
    $sysctl_tcp_timout_optimization_defaults = {
    }
  }
  #################################################################################
  # Settings for 10G NIC/fast networks, optimized for network paths up to 100ms RTT,

  if $sysctl_enable_fastnetworking_defaults {
    notice("Enabling networking settings for 10g equipment")
    $sysctl_fastnetworking_defaults = {
      'net.core.netdev_max_backlog' => { 'value' => '30000'},
      'net.core.rmem_default'       => { 'value' => '16777216'},
      'net.core.wmem_default'       => { 'value' => '16777216'},
      'net.core.rmem_max'           => { 'value' => '16777216'},
      'net.core.wmem_max'           => { 'value' => '16777216'},
      'net.ipv4.tcp_rmem'           => { 'value' => '4096 87380 16777216'},
      'net.ipv4.tcp_wmem'           => { 'value' => '4096 65536 16777216'},
      'net.ipv4.tcp_syncookies'     => { 'value' => '1'},
      'net.ipv4.tcp_mtu_probing'    => { 'value' => '1'},
      'net.core.optmem_max'         => { 'value' => '40960' },
    }
  } else {
    $sysctl_fastnetworking_defaults = {
    }
  }

  if $sysctl_ignore_defaults {
    $sysctl_config_final = $sysctl_config
  } else {
    $sysctl_config_final = deep_merge(
        $sysctl_stdkernel, 
        $sysctl_config, 
        $sysctl_fastnetworking_defaults, 
        $sysctl_tcp_timout_optimization_defaults
        )
  }
  create_resources('hosting_basesetup::kernel::sysctl', $sysctl_config_final)
  
  ############################################################################################################
  $ulimits_stdkernel = [
    '*                soft    nofile     8192        # increase maximum number of open file descriptors',
    '*                hard    nofile     10240       # increase maximum number of open file descriptors',
    '*                soft    core       0           # Prevent corefiles from being generated by default.',
    '*                hard    core       unlimited   # Allow corefiles to be temporarily enabled.',
    '*                hard    nproc      10240       # Prevent fork-bombs from taking out the system.',
  ]

  if $ulimit_ignore_defaults {
    $ulimit_config_final = $ulimit_config
  } else {
    $ulimit_config_final = concat($ulimits_stdkernel, $ulimit_config)
  }

  file { $ulimits_filename:
    owner => 'root',
    group => 'root',
    mode => '0644',
    content => template("hosting_basesetup/limits.conf.erb"),
  }

  ############################################################################################################

  include hosting_basesetup::kernel::parameters

}
