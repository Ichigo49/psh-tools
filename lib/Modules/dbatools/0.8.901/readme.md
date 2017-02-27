# dbatools
[![licence badge]][licence]
[![Build status](https://ci.appveyor.com/api/projects/status/cy5sm45x6atculse/branch/master?svg=true)](https://ci.appveyor.com/project/sqlcollaborative/dbatools/branch/master)

[licence badge]:https://img.shields.io/badge/License-GPL%20v3-blue.svg
[stars badge]:https://img.shields.io/github/stars/sqlcollaborative/dbatools.svg
[forks badge]:https://img.shields.io/github/forks/sqlcollaborative/dbatools.svg
[issues badge]:https://img.shields.io/github/issues/sqlcollaborative/dbatools.svg

[licence]:https://github.com/sqlcollaborative/dbatools/blob/master/LICENSE.txt
[stars]:https://github.com/sqlcollaborative/dbatools/stargazers
[forks]:https://github.com/sqlcollaborative/dbatools/network
[issues]:https://github.com/sqlcollaborative/dbatools/issues 

This module is a SQL Server DBA's best friend.

The dbatools project initially started out as Start-SqlMigration.ps1, but has now grown into a collection of various commands that help automate DBA tasks and encourage best practices.

See the [getting started](https://dbatools.io/getting-started) page on [dbatools.io](https://dbatools.io) for more information.

<center>![dbatools logo](https://blog.netnerds.net/wp-content/uploads/2016/05/dbatools.png)</center>

Got ideas for new commands? Please join [Trello board](https://dbatools.io/trello) and let us know what you'd like to see. Bug reports should be filed under this repository's [issues](https://github.com/sqlcollaborative/dbatools/issues) section.

There's also around a hundred of us on the [SQL Server Community Slack](https://sqlcommunity.slack.com) in the #dbatools channel. Need an invite? Check out the [self-invite page](https://dbatools.io/slack/). Drop by if you'd like to chat about dbatools or even [join the team](https://dbatools.io/team)!

## Installer
This module is now in the PowerShell Gallery. Run the following from an administrative prompt to install:
```powershell
Install-Module dbatools
```

Or if you don't have a version of PowerShell that supports the Gallery, you can install it manually:
```powershell
Invoke-Expression (Invoke-WebRequest https://git.io/vn1hQ)
```


## dbatools.io is awesome
This module has been documented in its entirety pretty much, using Markdown, at [dbatools.io](https://dbatools.io). Please go visit there, it's pretty. To skip right to the documentation, [visit the functions page](https://dbatools.io/functions/) or you can start with the [getting started](https://dbatools.io/getting-started/) page.
