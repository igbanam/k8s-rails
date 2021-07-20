from ruby:3.0.0

run curl -fsSL https://deb.nodesource.com/setup_14.x
add https://dl.yarnpkg.com/debian/pubkey.gpg /tmp/yarn-pubkey.gpg
run apt-key add /tmp/yarn-pubkey.gpg && rm /tmp/yarn-pubkey.gpg
run echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
run apt-get update && apt-get install -y nodejs yarn postgresql-client

run mkdir /app
workdir /app
copy Gemfile Gemfile.lock ./
run gem install bundler
run bundle install
copy . .

run yarn install --check-files
run bundle exec rails webpacker:install
run rake assets:precompile

cmd ["rails", "server", "-b", "0.0.0.0"]
