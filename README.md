# Capun
`Capun` is merely a combination of `rails + capistrano3 + unicorn` related gems (namely, [capistrano-rails](https://github.com/capistrano/rails), [rvm1-capistrano3](https://github.com/rvm/rvm1-capistrano3), [capistrano-bundler](https://github.com/capistrano/bundler), [capistrano3-unicorn](https://github.com/tablexi/capistrano3-unicorn)) and a couple of convenient rails generators that help to setup deployment scheme in less than a minute.

###Prerequisites

We expect you to have the following things setup before you run `cap staging|production|beta|etc deploy`:
* linux server with a ssh user (should be configured as passwordless sudo, [see this serverfault.com article for instructions](http://serverfault.com/questions/160581/how-to-setup-passwordless-sudo-on-linux))
* Node.js installed (e.g. `sudo apt-get install -y nodejs && sudo ln -sf /usr/bin/nodejs /usr/local/bin/node` for Debian 8 Jessie)
* `nginx` installed in the `/etc/nginx` directory
* dedicated host (e.g. `beta.example.com`)
* `unicorn` gem added to a `Gemfile` 
* rails project pushed to a git repo (you should also setup `ssh agent forwarding`, [see this article for instuctions](https://help.github.com/articles/using-ssh-agent-forwarding))


### Getting started

`Capun` works with Rails 4.0 onwards. You can add it to your Gemfile with:

<pre><code>gem 'capun', group: :development
\#add unicorn as well, as we use it as application server
gem 'unicorn', group: :production
</pre></code>

Run the bundle command to install it.
After you install `Capun`, you need to run the generator:

<pre><code>rails generate capun:install
</pre></code>

It will ask you about user, server and repo you'd like to use.
Add stage to `capistrano` configurations:

<pre><code>rails generate capun:stage beta
</pre></code>

It will ask you about application name for stage selected and application url you'd like to use. Optionally, you can add basic authentication.
Now you are ready to make a deploy:

<pre><code>cap beta deploy
</pre></code>

### Configuration

**Capistrano 3 tasks**

If you need to add custom tasks to a deployed application, you can append them to `config/deploy.rb` file exactly the same way, as you would do with `capistrano3`.

**Uploading files and creating symbolic links**

If you like to upload or symlink files to a server, you should add them either to `uploads` or `symlinks` array in the `config/deploy.rb` file:

<pre><code>set :uploads, [
  {what: "config/somefile.rb", where: '#{shared_path}/config/somefile.rb'}
]
set :symlinks, [
  \#when creating a symlink, we assume that source file is located in #{shared_path}/config directory
  {what: "somefile.yml", where: '#{release_path}/config/somefile.yml'}
]
</pre></code>

If you upload file with `.erb` extension, it will be precompiled before upload.

**Figaro support**

If you use [figaro](https://github.com/laserlemon/figaro) gem, `Capun` will pick up `application.yml` file, upload it to `#{shared_path}/config/application.yml` and symlink to `#{release_path}/config/application.yml`. No configuration is required.

**ELK + logrotate support**

If you would like to forward your logs to `logstash`, you can enable it by answering 'yes' while generating a new stage. As a result, `lograge` gem and `lograge` configurations will be added along with `logstash` confgurations added and symlinked to `logstash` `conf.d` directory (which is assumed to be at `/etc/logstash/conf.d/`).
If you answer 'yes' to 'Would you like to add logrotate configuration to stage?' while generating a new stage, `logrotate` configuration file will be added and symlinked to `/etc/logrotate.d/` directory.

### Contributing

1. Fork it ( http://github.com/zamylin/capun/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request