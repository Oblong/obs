rem @Echo off

goto :main

:usage
  echo "Convenience script for buildbot slaves"
  echo "Usage:"
  echo " bslave.bat install"
  echo " bslave.bat init"
  echo " bslave.bat run"
  goto :eof

:install
  pip install twisted
  pip install pypiwin32
  pip install buildbot-worker
  exit /B

:init
  mkdir c:\qq
  c:
  cd \qq
  SET /P WORKERPW=<secrets.dir\my-buildbot-work-pw
  echo WORKERPW is %WORKERPW%
  hostname > hostname.txt
  SET /P HOSTNAME=<hostname.txt
  echo HOSTNAME is %HOSTNAME%
  buildbot-worker create-worker -a file --umask=0o22 c:\qq %MASTER% %HOSTNAME% %WORKERPW%
  exit /B

:run
  c:
  cd \qq
  buildbot-worker start --nodaemon c:\qq
  exit /B

:uninit
  c:
  cd \
  rmdir /Q /S c:\qq
  exit /B

:uninstall
  pip3 uninstall buildbot-worker
  exit /B

:main
SET MASTER=buildhost5.oblong.com

IF /I "%1" == "" goto usage
IF /I %1 == INSTALL goto install
IF /I %1 == INIT goto init
IF /I %1 == RUN goto run
IF /I %1 == UNINIT goto uninit
IF /I %1 == UNINSTALL goto uninstall
IF /I %1 == HELP goto usage
