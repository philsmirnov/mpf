set -e

rm -rf  source/glossariy source/texts

bundle exec ruby ./gdrive_fetcher/gdrive_fetcher.rb "$@"

bundle exec middleman build --clean

touch build/texts build/glossariy

ssh u48777@u48777.ssh.masterhost.ru rm -rf ~/gerome.ru/www/mp3/*

scp  -r build/. u48777@u48777.ssh.masterhost.ru:~/gerome.ru/www/mp3

cd ../../mps/current/
RAILS_ENV=production bundle exec rake ts:rebuild
