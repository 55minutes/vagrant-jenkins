vagrant-jenkins
===============

[Vagrant][] recipe to set up a [Jenkins][] box for [Rails][] [continuous
integration][CI]

1.  [Download][vagrant download] and install Vagrant v1.2.2
2.  Install the [DigitalOcean Vagrant Provider][vagrant-digitalocean] using the
    README instructions
3.  Set your secrets:
    1.  Copy `secrets.example.yml` to `secrets.yml`
    2.  Change the settings in `secrets.yml` as necessary
4.  `vagrant up --provider=digital_ocean`

[Vagrant]: http://www.vagrantup.com
[Jenkins]: http://jenkins-ci.org
[Rails]: http://rubyonrails.org
[CI]: http://en.wikipedia.org/wiki/Continuous_integration
[vagrant download]: http://downloads.vagrantup.com/tags/v1.2.2
[vagrant-digitalocean]: https://github.com/smdahlen/vagrant-digitalocean
