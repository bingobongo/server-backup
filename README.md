Automated, rotating server backups to Strongspace
=================================================

Kudos to **ExpanDrive**

- [Password-less login to Strongspace with SSH Keys](https://www.strongspace.com/help/password-less-login-with-ssh-keys)
- [Type less with a SSH Alias](https://www.strongspace.com/help/ssh-alias)
- [Automated Offsite MySQL backup to Strongspace](https://www.strongspace.com/help/automated-offsite-mysql-backup)

and **Joyent**

- [Automated backups to Strongspace](http://oldwiki.joyent.com/shared:automated-backups)


Setup
-----

1. Create the directory where to store database dumps and the backup script on your server; set its permissons to `700`; e.g.

		% mkdir -m 700 ~/backup

2. Create the directories that will be used for the backup rotation purpose on Strongspace; they must all be in that same Space.

3. Set up [password-less logins to Strongspace](https://www.strongspace.com/help/password-less-login-with-ssh-keys); set the permissions of the keys to `600`.  
To use multiple keys, name the file in which to save the key e.g. `ss_rsa` and specify it as identity file in `config`.

4. Create an SSH alias as done in the `config` file and described [here](https://www.strongspace.com/help/ssh-alias).

5. Configure `backup.sh` and `exclude.txt`. Instructions on configuration are found inside `backup.sh`. Upload the two files to the before created directory on your server. Set the permissons of `backup.sh` to `700` and `exclude.txt` to `600`.

6. Test the script and check that it runs okay.

		% ~/backup/backup.sh

7. Finally add it as a cronjob.
	- On a Joyent **SmartMachine** log in to Webmin and navigate to <b>Webmin</b> – <b>System</b> – <b>Scheduled Cron Jobs</b>. There hit <b>Create a new scheduled cron job</b>. In the input box labelled <b>Execute cron job as</b> put `root` and in the input box labelled <b>Command</b> put the path to your backup script (e.g. `/home/USERNAME/backup/backup.sh`). Finally set when you want it to execute and hit <b>Create</b> to finish.
	- On a Joyent **Shared SmartMachine** log in to Virtualmin and navigate to <b>Webmin Modules</b> – <b>Scheduled Cron Jobs</b>. There hit <b>Create a new scheduled cron job</b>. In the input box labelled <b>Command</b> put the path to your backup script (e.g. `/users/home/USERNAME/backup/backup.sh`). Finally set when you want it to execute and hit <b>Create</b> to finish.
