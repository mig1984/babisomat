# source this file and then execute bin/start, etc.

export HOST=127.0.0.1
export PORT=8080
export ENVIRONMENT=development
#export ENVIRONMENT=production

export DATABASE_URL="sqlite://data/db.sqlite"

export URL_HOST=https://babisomat.cz
export APP_USER=babisomatcz
export APP_HOME=/home/babisomatcz
export RSH="ssh $APP_USER@10.1.0.1 -p 31293"
export TMPDIR=` realpath ./tmp `
export MAGICK_OCL_DEVICE=OFF
export LANG=en_US.UTF-8

#export PATH=/usr/local/rvm/gems/ruby-2.6.4/wrappers:$PATH
