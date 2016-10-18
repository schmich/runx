setlocal

set PACKAGE=traveling-ruby-20150210-2.1.5-win32.tar.gz
set PATH=%PATH%;C:\Program Files\7-Zip\

if exist runtime goto runtime_exists
mkdir runtime\lib\ruby
mkdir runtime\lib\app
curl -L -O --fail "https://d6r77u77i8pq3.cloudfront.net/releases/%PACKAGE%"
7z x "%PACKAGE%" -so | 7z x -aoa -si -ttar -o"runtime\lib\ruby"
del "%PACKAGE%"

:runtime_exists

copy /y runx.rb runtime\lib\app\runx.rb
go-bindata -nometadata runtime/...
go build -ldflags "-w -s"

endlocal
