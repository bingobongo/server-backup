Automated, rotating server backup to Strongspace
================================================


Package Overview
----------------

    /LICENSE
    /README.md
    /backup.sh
    /config
    /exclude-rsync.txt
    /exclude-tar.txt


Setup
-----

1. Set up [password-less logins to Strongspace](https://www.strongspace.com/help/password-less-login-with-ssh-keys).  
To use multiple keys, name the file in which to save the key (e.g. `strongspace_rsa`) and subsequently specify it as the identity file in `config`. For example enter the code below to generate a new SSH key named `strongspace_rsa`. After generating the keys it will prompt for a passphrase which will be used when accessing the key. Leave it blank when using it for scheduled rsync backup.

        % ssh-keygen -f ~/.ssh/strongspace_rsa -t rsa
    Set the permissions of the key pair, especially of the non-public key, to `600`.

        % chmod 600 ~/.ssh/strongspace_rsa  ~/.ssh/strongspace_rsa.pub
    Add the public key `strongspace_rsa.pub` to the authorized keys at Strongspace. Therefore, log into Strongspace, go to “Account” – “SSH Public Keys” – “Add a new key…” and paste the public key in there, finally save.

2. Create an SSH alias as done in `config` and described in [type less with a SSH alias](https://www.strongspace.com/help/ssh-alias). To test the setup, log into Strongspace using the command line `sftp` tool. While connecting to Strongspace it may prompt for continuation once, continue with `yes`. After a  successfull login, the command `bye` or `exit` logs out.

        % sftp ss

3. Create the directory where to store database dumps and the backup script on your server, set its permissons to `700`, e.g.

        % mkdir -m 700 ~/backup

4. Configure `backup.sh`, `exclude-tar.txt` and `exclude-rsync.txt`, whereby the latter may be omitted if no synchronization with Strongspace is intended. Instructions on configuration are found inside `backup.sh`. Upload the files to the before created directory `~/backup` on your server. Set the permissons of `backup.sh` to `700` and the other two to `600`.  
    To prevent possible errors on a TextDrive **Shared** or when not running as root (e.g. group/owner bubkis), add the line

        `*/homes/db/Maildir`
    to `exclude-tar.txt` and

        `- homes/db/Maildir/`
    to `exclude-rsync.txt`.  
    The rest should be left as is.

5. Create the directories that will be used for the backup rotation purpose on Strongspace; they must all be in that same Strongspace Space.

6. Test the script and check that it runs okay.  
    Use option `v` to display the messages instead of writing them to the log file `~/backup/backup.log`.  
    With option `y` the backup is stored only locally without any synchronization with Strongspace.  
    Option `L` resets the log file before writing to it and `D` deletes backups of unlisted databases, directories and files; i.e.

        % ~/backup/backup.sh -vyLD

7. Finally add it as a cronjob.
    - On a Joyent **SmartMachine Standard** use `crontab` with option `e` while logged in as root to schedule a backup.

            % crontab -e
        For a backup once a week, for example at 6:00 a.m. every monday, add in a new line:
 
            0 6 * * 1 /full-pathname-to/backup/backup.sh
        Save, quit and it should run automatically on the next scheduled date.
    - On a Joyent **SmartMachine Plus** log into Webmin and navigate to “Webmin” – “System” – “Scheduled Cron Jobs”. There hit “Create a new scheduled cron job”. In the input box labelled “Execute cron job as” put `root` and in the input box labelled “Command” put the path to your backup script (dependent on its location, e.g. `/home/USERNAME/backup/backup.sh` or `/root/backup/backup.sh`). Finally set the day and time when you want it to execute and hit “Create” to finish.
    - On a TextDrive **Shared** log into Virtualmin and navigate to “Webmin Modules” – “Scheduled Cron Jobs”. There hit “Create a new scheduled cron job”. In the input box labelled “Command” put the path to your backup script (e.g. `/users/home/USERNAME/backup/backup.sh`). Finally set the day and time when you want it to execute and hit “Create” to finish.


License
-------

Read the `LICENSE` for license and copyright details.


Credits
-------

Kudos to **ExpanDrive** ([Password-less login to Strongspace with SSH Keys](https://www.strongspace.com/help/password-less-login-with-ssh-keys), [Type less with a SSH Alias](https://www.strongspace.com/help/ssh-alias), [Automated Offsite MySQL backup to Strongspace](https://www.strongspace.com/help/automated-offsite-mysql-backup)) and **Joyent** ([Automated backups to Strongspace](http://oldwiki.joyent.com/shared:automated-backups)).
