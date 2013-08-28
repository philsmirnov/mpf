set -e

rm -rf  source/glossariy
rm -fr source/texts

bundle exec ruby ./gdrive_fetcher/gdrive_fetcher.rb

bundle exec middleman build --clean

touch build/texts build/glossariy
scp  -r build/* u48777@u48777.ssh.masterhost.ru:~/gerome.ru/www/mp3
                                                                   s