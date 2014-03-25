# Capun


###Prerequisites

We expect you to have the following things setup before you run `cap staging|production|beta|etc deploy`:
* linux server with a ssh user who would own a project (see the wiki page for instuctions on how to configure a user)
* `nginx` installed in the `/etc/nginx` directory
* dedicated host (e.g. `beta.example.com`)
* `unicorn` gem added to a `Gemfile` 
* rails project pushed to a git repo (you should also setup `ssh agent forwarding`, [see this article for instuctions](https://help.github.com/articles/using-ssh-agent-forwarding))


### Getting started

Capun works with Rails 4.0 onwards. You can add it to your Gemfile with:

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

### Contributing

1. Fork it ( http://github.com/zamylin/capun/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request