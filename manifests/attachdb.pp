# This defined type is to attach a zip file containing
# mdf & ldf files into a new database within MS SQL Server 2012.
define tse_sqlserver::attachdb (
  $file_source,
  $mdf_file      = 'AdventureWorks2012_Data.mdf',
  $ldf_file      = 'AdventureWorks2012_log.ldf',
  $zip_file      = 'AdventureWorks2012_Data.zip',
  $dbinstance    = 'MYINSTANCE',
  $owner         = 'CloudShop',
  $dbpass        = 'Azure$123',
) {
  case $::tse_sqlserver::sqlserver_version {
    '2012':  {
      $data_path  = "C:\\Program Files\\Microsoft SQL Server\\MSSQL11.${$dbinstance}\\MSSQL\\DATA"
      $sqlps_path = 'C:\Program Files (x86)\Microsoft SQL Server\110\Tools\PowerShell\Modules\SQLPS'
    }
    '2014':  {
      $data_path  = "C:\\Program Files\\Microsoft SQL Server\\MSSQL12.${dbinstance}\\MSSQL\\DATA"
      $sqlps_path = 'C:\Program Files (x86)\Microsoft SQL Server\120\Tools\PowerShell\Modules\SQLPS'
    }
    default: {
      abort('Invalid SQL Server Version supplied')
    }
  }
  staging::file { $zip_file:
    source => "${file_source}\\${zip_file}",
  }
  unzip { "SQL Data ${zip_file}":
    source    => "${::staging_windir}\\${module_name}\\${zip_file}",
    creates   => "${data_path}\\${mdf_file}",
    subscribe => Staging::File[$zip_file],
    notify    => Exec["Attach ${title}"],
  }

  exec { "Attach ${title}":
    command     => "import-module \'${sqlps_path}\'; invoke-sqlcmd \"USE [master] CREATE DATABASE [${title}] ON (FILENAME = \'${data_path}\\${mdf_file}\'),(FILENAME = \'${data_path}\\${ldf_file}\') for ATTACH\" -QueryTimeout 3600  -username \'sa\' -password \'${::tse_sqlserver::sql::sa_pass}\' -ServerInstance \'${::hostname}\\${dbinstance}\'",
    provider    => powershell,
    path        => $sqlps_path,
    refreshonly => true,
  }

  exec { "Change owner of ${title}":
    command     => "import-module \'${sqlps_path}\'; invoke-sqlcmd \"USE [${title}] ALTER AUTHORIZATION ON DATABASE::${title} TO ${owner};\" -QueryTimeout 3600 -username \'sa\' -password \'${::tse_sqlserver::sql::sa_pass}\' -ServerInstance \'${::hostname}\\${dbinstance}\'",
    provider    => powershell,
    subscribe   => Exec["Attach ${title}"],
    refreshonly => true,
  }

  sqlserver::login{ $owner:
    instance => $dbinstance,
    password => $dbpass,
    notify   => Exec["Attach ${title}"],
    require  => Unzip["SQL Data ${zip_file}"],
  }
}
