# Witness fail-over bash script
This is a steemd fail-over script using steem-python. If the server is unreachable or has missed blocks (set by the threshold value), it will fail over to the backup server. If something is wrong there, the signing key is disabled. If enabled, an email will be sent by the sendnotice.py script.

# Install prerequisites
`apt -y install apt-utils locales git nano python3 python3-pip python3-dev python3-setuptools libssl-dev cron curl iputils-ping screen jq`

`pip3 install --upgrade pip`

I'm using Furion's steem-python because it has more features.

`pip3 install -U git+https://github.com/Netherdrake/steem-python`

But, you can use the official steem-python, it should work just fine.

`pip3 install -U git+https://github.com/steemit/steem-python`

# Install
`git clone https://github.com/Jolly-Pirate/witness-failover.git`

# Usage
### Configure the steempy wallet
Run `steempy addkey`

Enter your Active PRIVATE key.
Enter and confirm a passphrase for the wallet.
Press ENTER to quit.

Check that your account and Active PUBLIC key are showing up in the wallet.

`steempy listaccounts`

The wallet is stored in `~/.local/share/steem/steem.sqlite`, in case you want to remove it from your computer.

### Set up the scripts
Go to the git cloned folder.

`cd ~/witness-failover`

Secure the files, they will contain sensitive information, and set execution permission.

`chmod 700 witness_failover.sh sendnotice.py`

Edit `witness_failover.sh` and `sendnotice.py` files with your own values.

If using Gmail's SMTP, test it first by running `./sendnotice.py test`. If you get an *SMTPAuthenticationError*, go to https://accounts.google.com/DisplayUnlockCaptcha to allow the device then retry.

Start and enter a screen session: `screen -S failover`
Start the script: `./witness_failover.sh`

Detach from the screen session with `CTRL-a-d`. This will leave it running in the background.

Reattach to the session with `screen -r failover` to monitor its status.

If you want to terminate the script press `CTRL-c`, then type `exit` to close the screen session.
