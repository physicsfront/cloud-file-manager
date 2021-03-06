[![build status](https://git.physics.front/Sam/ukde-cloud-file-manager/badges/master/build.svg)](https://git.physics.front/Sam/ukde-cloud-file-manager/commits/master)

# UKDE-CFM

This version of cloud file manager includes the `ukde` document provider,
which is the (only) document provider that UKDE at PF requires or uses.  All
other document providers are left intact, while they are not used by UKDE.

The (somewhat evolving) specification of `ukde` document provider can be
gleaned from the html document
[src/assets/examples/ukde.html](src/assets/examples/ukde.html) ([deployed
page is here for better
readability](https://physicsfront.com/cfm-dev/examples/ukde.html)).

# Development and deployment

`UKDE-CFM` development and deployment uses somewhat different approach than
the original cloud file manger.  First, it adds `GNUmakefile`, which collects
and manages all commands used by `UKDE-CFM`.  Second, the deployment is
performed using Gitlab CI (`.gitlab-ci.yml`).

In order to see `UKDE-CFM` in action, two web sites can be visited.

* https://physicsfront.com/cfm-dev/examples/ukde.html : This standalone
  website is OK for now, but it will stop being functional for the final
  version.

* https://ukde-dev.physicsfront.com/user/ucfm-test :  This is one of the
  pages where `UKDE-CFM` is intended for.  This site works now and also in
  the future as the software gets more fully featured.  In order to access
  this page, one must have an account in UKDE.

# Original README file

It is `readme.md` file.  [It can be opened here](readme.md).
