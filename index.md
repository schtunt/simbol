[![Build Status](https://travis-ci.org/nima/site.png?branch=stable)](https://travis-ci.org/nima/site)
[![views](https://sourcegraph.com/api/repos/github.com/nima/site/counters/views.png)](https://sourcegraph.com/github.com/nima/site)
[![authors](https://sourcegraph.com/api/repos/github.com/nima/site/badges/authors.png)](https://sourcegraph.com/github.com/nima/site)
[![status](https://sourcegraph.com/api/repos/github.com/nima/site/badges/status.png)](https://sourcegraph.com/github.com/nima/site)
<!--
<a href="https://twitter.com/intent/tweet?button_hashtag=SiteSupport" class="twitter-hashtag-button" data-size="large" data-related="SiteSysOpsUtil">Tweet #SiteSupport</a>
<script>!function(d,s,id){var js,fjs=d.getElementsByTagName(s)[0],p=/^http:/.test(d.location)?'http':'https';if(!d.getElementById(id)){js=d.createElement(s);js.id=id;js.src=p+'://platform.twitter.com/widgets.js';fjs.parentNode.insertBefore(js,fjs);}}(document, 'script', 'twitter-wjs');</script>
-->

# OVERVIEW
**MISSION STATEMENT**: _To simplify and standardize collaborative scripting, reporting and automation tasks_

**TARGET AUDIENCE**: _System Administrators, System Engineers, #TechOps, #DevOps, System Reliability Engineers #SREs, and Test Engineers_

Site was written for its target audience, by its target audience; it is a superset of bash, and structured to scale with your scripting requirements.

## News
<a class="twitter-timeline" href="https://twitter.com/SiteSysOpsUtil" data-widget-id="435631222664880128">Follow @SiteSysOpsUtil on Twitter!</a>
<script>!function(d,s,id){var js,fjs=d.getElementsByTagName(s)[0],p=/^http:/.test(d.location)?'http':'https';if(!d.getElementById(id)){js=d.createElement(s);js.id=id;js.src=p+"://platform.twitter.com/widgets.js";fjs.parentNode.insertBefore(js,fjs);}}(document,"script","twitter-wjs");</script>

## The Code
Site is broken up into two main chunks:

1. The bits that *we* write/maintain:
    * the *site engine*: `libsite.sh`
    * the *core modules*: `module/*`

2. The bits that *you* write (and maintain):
    * the *user modules*: `~/.site/module/*`

**Quick note to developers**: If you ever write a user module that you'd like to share with us, simply hit us up with a [github pull request](https://help.github.com/articles/using-pull-requests).

## The Config
Site is configured in two places:

1. One for *your organization*: `~/.site/etc/site.conf`
2. One just for *you*: `~/.siterc`

The prior contains things that are specific to your organization and should be in a private VCS/SCM accessible by your team.

The latter contains configuration settings specific to you and your desktop (user details and command alias overrides mostly).  It should not be shared with anyone as it pertains only to you.


---
# REQUIREMENTS

## Core Requirements

You need bash v4.0+ to start with, but this is easier than you might think:  if your version of bash is older, simply compile a newer one locally in you home directory, and set the environment variable `SITE_SHELL` to point to it.  You don't even need to do this in your user profile, simply place it (and any other overrides) into your `~/.siterc` or ~/.site/etc/site.conf`.  More on those files later!

You also need a handful of utilities and interpreters such as gnu grep, gawk, gsed, nc, socat, etc. The full list is covered in the installation section bellow.

## Additional Requirements

The site modules will themselves check for any python, ruby, or perl module you need for that particular module.


---
# INSTALLATION

0. Clone It

    ```bash
    cd ~/
    git clone https://github.com/nima/site.git
    git checkout stable
    cd site
    ```
1. Install prerequisite software

    Do what [Travis](https://travis-ci.org/nima/site/builds) does:
    ```bash
    sed -ne '/^before_install:/,/^$/{/^ /p}' .travis.yml
    ```
2. Set up yout new `PROFILE`

    ```bash
    export PROFILE=MYCOMPANY
    mkdir -p profile/${PROFILE}/etc/
    mkdir -p profile/${PROFILE}/module/
    cp share/examples/site.conf.eg profile/${PROFILE}/etc/
    cp share/examples/siterc.eg ~/.siterc
    ```
3. Install

    ```bash
    make install
    ```

4. Create organizational site git (or other VCS) repository

    ```bash
    cd
    mv ~/.site/profile/${PROFILE} site-${PROFILE}
    ln -s ~/.site/profile/${PROFILE} `pwd`/site-${PROFILE}
    cd site-${PROFILE}
    git init .
    ```

## Files and Filesystem Layout
Site is designed to be run by your local user; it is designed to be installed on your desktop machine, and it will communicate with your hosts remotely.  You should never need to install site on a server.

### Site will not crap all over your filesystem or home directory
Here are the only files that will exist outside of `${SITE_SCM}` (where you cloned site to):

* `~/bin/site -> ${SITE_SCM}/bin/site`
* `~/.site/`
* `~/.siterc`

The installer installs everything required monolithically under `~/.site/`, and even that is just a set of symbolic links pointing back to various folders within `${SITE_SCM}`.

The `~/.siterc` is where you can store configuration overrides for you particular user.

### Secrets, Passwords, and API Keys
Do not store any passwords or sensitive data in this file; site ships with the *vault* module which was written to address this problem directly:  The file `~/.site/etc/site.vault` will be a GPG-encrypted file where you cam store all your secrets, passwords, and API keys.

The unencrypted vault has a very simple format: `<secret-id>     <secret-token>`, one entry per line.  The `secret-token` can contain spaces of course, or any other character; the first token must be alphanumeric however without any spaces; quotes are taken as literal characters and there is no escaping in this file format.

Site will provide you with the necessary high-level tools to create, edit, and read to and from this file, so you don't have to invoke GPG commands directly.

Note that site also ships with a *gpg* module which you will want to use first to create your user-specific gpg key.

### Site can be uninstalled as easily as it can be installed
To uninstall, simply run `make uninstall`, and if you want to delete all downloaded third-party software as well, then run `make purge`.

### Site doesn't expect your bash profile to be changed
Instead, if you ever need to tell it to use a different executable, simply do so via `~/.siterc`; for example:

```bash
function grep() { /usr/local/bin/grep "$@"; return $?; }
```
That means that you do not need to change your `PATH` to accomodate it, and the only environment variable that site cares (deeply) about, is `PROFILE`.

---
# HELP

## Asking for Help (Support)
If you want to keep up with the latest, follow us on `@SiteSysOpsUtil`.

If you need help, tweet the hashtag `#SiteSupport`.

## Offering to Help (Contribustion)
We're always looking for users and developers.  Simply telling us about your experience installing and using site is of great value to us.  If you want to get your hands dirty, well send us a pull request!  Remember site is modular, and there is no reason why you couldn't add your own modules to site.  If those modules are generic and could be of use to other users, we would love to hear from you!

---
# PHILOSOPHY
Minimalism, simplicity, scalability, and code-reuse; these are some of the words that sang a tune in our ear while we were looking for a shell script framework.  We did find a couple of ideas floating around, but nothing that was actively developed or cam across as anything more than a hobby.

Enter: **site**!

Instead of hardcoding tediously long and complex commands over and over again in various scripts and various places, implement them once, and implement them well.  That is all you need to do (as far as scripting habits go), and you can start using site (almost) seamlessly.

All you have to do is to break up your scripts into small, single-purpose *functions*, and then group them contextually into *modules*.  Of course you don't have to break your scripts up at all if you don't want, you can simply wrap it in site to make it have a common home with you other scripts - but if do want reuse any part of that script, the this is the best way forward.

## Simplicity
Site is simple to use; and most UI concerns are semi-automatically accounted for, simply as a result of you writing your code within the framework.

For example, if you implement a function called `say:hello()` in `~/.site/profile/module/say`, and another function `say:hello:usage()' which does what it says on the can, and you will instantly get:

```bash
$ site
Using /bin/bash 4.2.37(1)-release (export SITE_SHELL to override)

usage4nima@SITE01
    site say:1/0; A module that greets the world
    ...
$
```

Now that we know of the `say` module:
```bash
$ site say
Using /bin/bash 4.2.37(1)-release (export SITE_SHELL to override)

usage4nima@SITE01 say
    site say hello {no-args}
$
```

And now, that we know how to use it:
```bash
$ site say hello
Hello World!
$
```

## Verifiability
### Unit Testing Framework
Scripts change over time, and so unit-testing is as relevant to systems scripts as it is to any piece of software.  Site comes with a flexible unit-testing module. This module reads everything it needs to know about every function test from a unit-testing configuration file, and warns you for functions that are missing unit-test data.

```bash
$ site unit test
```

**Note**: Please only run this on a throw-away development host, as it needs to make changes to `/etc/hosts`, ssh user and hosts keys, and possibly more user/system files in order to allow for thorough unit-testing.  A safeguard has been added to the unit module to prevent you from (or forces some acrobatic shell loop hoppery upon you for) running the unit tests, so no need to fear - site is safe :).

### Bash Traceback
That's right, we have a traceback so you can debug your scripts (site user modules).  Of course bash doesn't provide such functionality natively, so we had to get creative.

## Security Measures
Site doesn't expect to be run as root; in fact it should _never_ be run as root.  It will never _require_ root access on your desktop machine - which is the only place it needs to be installed.

It could however need root access when communicating tasks to remote hosts, and in that event it will resort to your vault, as covered earlier.

---

###### TAGS: `abstraction`, `automation`, `reporting`, `verifiability`, `standards`, `monitoring`, `unit-testing`, `bash`, `ssh`, `tmux`, `netgroup`, `hosts`, `users`, `ldap`, `mongo`, `softlayer`, `gnupg`, `remote-execution`, `sudo`, `tmux`, `shell-scripting`, `traceback`, `ldif`
