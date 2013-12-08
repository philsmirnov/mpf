set -e

rm -rf  source/glossariy source/texts

bundle exec ruby ./gdrive_fetcher/gdrive_fetcher.rb "$@"

bundle exec middleman build --clean

touch build/texts build/glossariy

ssh u48777@u48777.ssh.masterhost.ru rm -rf ~/gerome.ru/www/mp3/*
scp  -r build/. u48777@u48777.ssh.masterhost.ru:~/gerome.ru/www/mp3

ssh papush@ssh.papush.nichost.ru rm -rf ~/app.papush.ru/docs/*
scp  -r build/. papush@ssh.papush.nichost.ru:~/app.papush.ru/docs

cd ../../../mps/current/
RAILS_ENV=production bundle exec rake ts:rebuild


OFFLINE=true bundle exec middleman build --clean
touch build/texts build/glossariy

ssh papush@ssh.papush.nichost.ru rm -rf ~/offlineapp.papush.ru/docs/*
scp  -r build/. papush@ssh.papush.nichost.ru:~/offlineapp.papush.ru/docs
