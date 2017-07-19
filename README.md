# NAME

Yukki::Manual::Installation - installaction instructions

# VERSION

version 0.99\_02

# SYNOPSIS

     # Install the module
     perl -MCPAN -e 'install Yukki'
    
     # OR better, install cpanm and run...
     cpanm Yukki

     # Setup your wiki's installation folder
     yukki-setup mysite
     cd mysite

     # Setup the repositories
     yukki-git-init main
     yukki-git-init yukki git://github.com/zostay/yukki-help.git

     # Add a user
     yukki-add-user

     # Start the server
     yukki.psgi

# DESCRIPTION

The ["SYNOPSIS"](#synopsis) pretty well sums up the highlights of installation. The rest of this document discusses what each piece does and how to customize it further.

# INSTALLATION

The code can be installed like any other CPAN module. By using [App::cpanminus](https://metacpan.org/pod/App::cpanminus) or [CPAN](https://metacpan.org/pod/CPAN), you will get all the dependencies downloaded and installed automatically for you.

# SITE SETUP

To setup your site, you run the `yukki-setup` script:

    yukki-setup mysite

This will create a directory named `mysite` in the current folder and will copy into a skeleton installation that you may customize to suit the needs of your wiki site.

In it you will find these files and directories:

- `etc/yukki.conf`. This is the configuraiton file for your application. You will want to read this to make sure it is correct before continuing. The default install includes two repositories. The one named "main" is intended to be a repository for you to use to suite your needs. The one named "yukki" contains a repository of online help for the wiki software itself.
- `repositories`. This directory might not exist until ["REPOSITORY INITIALIZATION"](#repository-initialization) is finished, but it will contain local copies o fthe git repositories that contain the wiki's files.
- `root/script`. This contains all the JavaScript files served by your site. You may add to these or customize to suit your needs.
- `root/style`. This contains all the CSS stylseheets served by your site. You may add to these or customize to suit your needs.
- `root/template`. This contains all the templates used to render the pages for your site. You may customize these to suit your needs.
- `var/db/users`. This is the directory that will contain your user database. At this point, users are stored as a colleciton of [YAML](https://metacpan.org/pod/YAML) formatted files.

# CONFIGURATION FILE

Most of these commands (all except `yukki-setup`) look for a file named `etc/yukki.conf` in the current working directory. If this file is not found, the script checks for an environment variable named `YUKKI_CONFIG`, which should point to a [YAML](https://metacpan.org/pod/YAML) formatted configuration for your wiki site.

If no file is found, the script will stop and complain of an error.

See [Yukki::Settings](https://metacpan.org/pod/Yukki::Settings) and [Yukki::Web::Settings](https://metacpan.org/pod/Yukki::Web::Settings) for a complete list of configuration directives.

# REPOSITORY INITIALIZATION

Once the site directory is setup, you will need to initialize each of the git repositories that will contain the files stored by the wiki.

This is most easily performed by running:

    yukki-git-init foobar

for each of the repositories. This will create a git repository that contains a single commit containing a master index file. The name of this file and the branch that it belongs to is named in the ["CONFIGURATION FILE"](#configuration-file).

In addition to running this command, you may choose to run:

    yukki-git-init foobar git://path/to/romote

Instead of initailizing an empty reposotiry, it will clone the named remote repository into a local mirror. This is useful if you want to sync a repository between different sites. (As of this writing, Yukki provides no help for this, but git already provides all the tools you need to do it.)

This latter command is similar to running:

    git clone --mirror git://path/to/remote repositories/foobar.git

# CREATE USERS

Finally, to use Yukki, you will need one or more users with access to get into your wiki. The simple way to do this is to run:

    yukki-add-user

The script will ask you for information to create each user. You can then lookup the user files and edit them if you need to make later modifications.

# AUTHOR

Andrew Sterling Hanenkamp <hanenkamp@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2017 by Qubling Software LLC.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
