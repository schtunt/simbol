[![Build Status](https://travis-ci.org/schtunt/simbol.png?branch=stable)](https://travis-ci.org/schtunt/simbol)
[![views](https://sourcegraph.com/api/repos/github.com/schtunt/simbol/counters/views.png)](https://sourcegraph.com/github.com/schtunt/simbol)
[![authors](https://sourcegraph.com/api/repos/github.com/schtunt/simbol/badges/authors.png)](https://sourcegraph.com/github.com/schtunt/simbol)
[![status](https://sourcegraph.com/api/repos/github.com/schtunt/simbol/badges/status.png)](https://sourcegraph.com/github.com/schtunt/simbol)
<!--
<a href="https://twitter.com/intent/tweet?button_hashtag=SiteSupport" class="twitter-hashtag-button" data-size="large" data-related="SiteSysOpsUtil">Tweet #SiteSupport</a>
<script>!function(d,s,id){var js,fjs=d.getElementsByTagName(s)[0],p=/^http:/.test(d.location)?'http':'https';if(!d.getElementById(id)){js=d.createElement(s);js.id=id;js.src=p+'://platform.twitter.com/widgets.js';fjs.parentNode.insertBefore(js,fjs);}}(document, 'script', 'twitter-wjs');</script>
-->

# OVERVIEW
**MISSION STATEMENT**: _To simplify and standardize collaborative scripting, reporting and automation tasks_

**TARGET AUDIENCE**: _System Administrators, System Engineers, #TechOps, #DevOps, System Reliability Engineers #SREs, and Test Engineers_

Simbol was written for its target audience, by its target audience; it is a superset of bash, and structured to scale with your scripting requirements.

## News
<a class="twitter-timeline" href="https://twitter.com/SiteSysOpsUtil" data-widget-id="435631222664880128">Follow @SiteSysOpsUtil on Twitter!</a>
<script>!function(d,s,id){var js,fjs=d.getElementsByTagName(s)[0],p=/^http:/.test(d.location)?'http':'https';if(!d.getElementById(id)){js=d.createElement(s);js.id=id;js.src=p+"://platform.twitter.com/widgets.js";fjs.parentNode.insertBefore(js,fjs);}}(document,"script","twitter-wjs");</script>

## The Code
Simbol is broken up into two main chunks:

1. The bits that *we* write/maintain:
    * the *simbol engine*: `libsimbol.sh`
    * the *core modules*: `module/*`

2. The bits that *you* write (and maintain):
    * the *user modules*: `~/.simbol/module/*`

**Quick note to developers**: If you ever write a user module that you'd like to share with us, simply hit us up with a [github pull request](https://help.github.com/articles/using-pull-requests).

## The Config
Simbol is configured in two places:

1. One for *your organization*: `~/.simbol/etc/simbol.conf`
2. One just for *you*: `~/.simbolrc`

The prior contains things that are specific to your organization and should be in a private VCS/SCM accessible by your team.

The latter contains configuration settings specific to you and your desktop (user details and command alias overrides mostly).  It should not be shared with anyone as it pertains only to you.


---
# REQUIREMENTS

## Core Requirements

You need bash v4.0+ to start with, but this is easier than you might think:  if your version of bash is older, simply compile a newer one locally in you home directory, and set the environment variable `SIMBOL_SHELL` to point to it.  You don't even need to do this in your user profile, simply place it (and any other overrides) into your `~/.simbolrc` or ~/.simbol/etc/simbol.conf`.  More on those files later!

You also need a handful of utilities and interpreters such as gnu grep, gawk, gsed, nc, socat, etc. The full list is covered in the installation section bellow.

## Additional Requirements

The simbol modules will themselves check for any python, ruby, or perl module you need for that particular module.


---
# INSTALLATION

0. Clone It

    ```bash
    cd ~/
    git clone https://github.com/schtunt/simbol.git
    git checkout stable
    cd simbol
    ```
1. Install prerequisite software

    Do what [Travis](https://travis-ci.org/schtunt/simbol/builds) does:
    ```bash
    sed -ne '/^before_install:/,/^$/{/^ /p}' .travis.yml
    ```
2. Set up yout new `PROFILE`

    ```bash
    export PROFILE=MYCOMPANY
    mkdir -p profile/${PROFILE}/etc/
    mkdir -p profile/${PROFILE}/module/
    cp share/examples/simbol.conf.eg profile/${PROFILE}/etc/
    cp share/examples/simbolrc.eg ~/.simbolrc
    ```
3. Install

    ```bash
    make install
    ```

4. Create organizational simbol git (or other VCS) repository

    ```bash
    cd
    mv ~/.simbol/profile/${PROFILE} simbol-${PROFILE}
    ln -s ~/.simbol/profile/${PROFILE} `pwd`/simbol-${PROFILE}
    cd simbol-${PROFILE}
    git init .
    ```

## Files and Filesystem Layout
Simbol is designed to be run by your local user; it is designed to be installed on your desktop machine, and it will communicate with your hosts remotely.  You should never need to install simbol on a server.

### Simbol will not crap all over your filesystem or home directory
Here are the only files that will exist outside of `${SIMBOL_SCM}` (where you cloned simbol to):

* `~/bin/simbol -> ${SIMBOL_SCM}/bin/simbol`
* `~/.simbol/`
* `~/.simbolrc`

The installer installs everything required monolithically under `~/.simbol/`, and even that is just a set of symbolic links pointing back to various folders within `${SIMBOL_SCM}`.

The `~/.simbolrc` is where you can store configuration overrides for you particular user.

### Secrets, Passwords, and API Keys
Do not store any passwords or sensitive data in this file; simbol ships with the *vault* module which was written to address this problem directly:  The file `~/.simbol/etc/simbol.vault` will be a GPG-encrypted file where you cam store all your secrets, passwords, and API keys.

The unencrypted vault has a very simple format: `<secret-id>     <secret-token>`, one entry per line.  The `secret-token` can contain spaces of course, or any other character; the first token must be alphanumeric however without any spaces; quotes are taken as literal characters and there is no escaping in this file format.

Simbol will provide you with the necessary high-level tools to create, edit, and read to and from this file, so you don't have to invoke GPG commands directly.

Note that simbol also ships with a *gpg* module which you will want to use first to create your user-specific gpg key.

### Simbol can be uninstalled as easily as it can be installed
To uninstall, simply run `make uninstall`, and if you want to delete all downloaded third-party software as well, then run `make purge`.

### Simbol doesn't expect your bash profile to be changed
Instead, if you ever need to tell it to use a different executable, simply do so via `~/.simbolrc`; for example:

```bash
function grep() { /usr/local/bin/grep "$@"; return $?; }
```
That means that you do not need to change your `PATH` to accomodate it, and the only environment variable that simbol cares (deeply) about, is `PROFILE`.

---
# HELP

## Asking for Help (Support)
If you want to keep up with the latest, follow us on `@SiteSysOpsUtil`.

If you need help, tweet the hashtag `#SiteSupport`.

## Offering to Help (Contribustion)
We're always looking for users and developers.  Simply telling us about your experience installing and using simbol is of great value to us.  If you want to get your hands dirty, well send us a pull request!  Remember simbol is modular, and there is no reason why you couldn't add your own modules to simbol.  If those modules are generic and could be of use to other users, we would love to hear from you!

---
# PHILOSOPHY
Minimalism, simplicity, scalability, and code-reuse; these are some of the words that sang a tune in our ear while we were looking for a shell script framework.  We did find a couple of ideas floating around, but nothing that was actively developed or cam across as anything more than a hobby.

Enter: **simbol**!

Instead of hardcoding tediously long and complex commands over and over again in various scripts and various places, implement them once, and implement them well.  That is all you need to do (as far as scripting habits go), and you can start using simbol (almost) seamlessly.

All you have to do is to break up your scripts into small, single-purpose *functions*, and then group them contextually into *modules*.  Of course you don't have to break your scripts up at all if you don't want, you can simply wrap it in simbol to make it have a common home with you other scripts - but if do want reuse any part of that script, the this is the best way forward.

## Simplicity
Simbol is simple to use; and most UI concerns are semi-automatically accounted for, simply as a result of you writing your code within the framework.

For example, if you implement a function called `say:hello()` in `~/.simbol/profile/module/say`, and another function `say:hello:usage()' which does what it says on the can, and you will instantly get:

```bash
$ simbol
Using /bin/bash 4.2.37(1)-release (export SIMBOL_SHELL to override)

usage4nima@SITE01
    simbol say:1/0; A module that greets the world
    ...
$
```

Now that we know of the `say` module:
```bash
$ simbol say
Using /bin/bash 4.2.37(1)-release (export SIMBOL_SHELL to override)

usage4nima@SITE01 say
    simbol say hello {no-args}
$
```

And now, that we know how to use it:
```bash
$ simbol say hello
Hello World!
$
```

## Verifiability
### Unit Testing Framework
Scripts change over time, and so unit-testing is as relevant to systems scripts as it is to any piece of software.  Simbol comes with a flexible unit-testing module. This module reads everything it needs to know about every function test from a unit-testing configuration file, and warns you for functions that are missing unit-test data.

```bash
$ simbol unit test
```

**Note**: Please only run this on a throw-away development host, as it needs to make changes to `/etc/hosts`, ssh user and hosts keys, and possibly more user/system files in order to allow for thorough unit-testing.  A safeguard has been added to the unit module to prevent you from (or forces some acrobatic shell loop hoppery upon you for) running the unit tests, so no need to fear - simbol is safe :).

### Bash Traceback
That's right, we have a traceback so you can debug your scripts (simbol user modules).  Of course bash doesn't provide such functionality natively, so we had to get creative.

## Security Measures
Simbol doesn't expect to be run as root; in fact it should _never_ be run as root.  It will never _require_ root access on your desktop machine - which is the only place it needs to be installed.

It could however need root access when communicating tasks to remote hosts, and in that event it will resort to your vault, as covered earlier.

---

###### TAGS: `abstraction`, `automation`, `reporting`, `verifiability`, `standards`, `monitoring`, `unit-testing`, `bash`, `ssh`, `tmux`, `netgroup`, `hosts`, `users`, `ldap`, `mongo`, `softlayer`, `gnupg`, `remote-execution`, `sudo`, `tmux`, `shell-scripting`, `traceback`, `ldif`
