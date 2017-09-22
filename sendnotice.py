#!/usr/bin/env python3

#If using Gmail's SMTP, test it first by running this script.
#If you get an SMTPAuthenticationError, go to https://accounts.google.com/DisplayUnlockCaptcha to allow the device then retry.

import sys

# Import smtplib for the actual sending function
import smtplib

# Import the email modules we'll need
from email.mime.text import MIMEText

msg = MIMEText(sys.argv[1])
msg['Subject'] = "Witness Node Problem"
msg['From'] = "your@email.com"
msg['To'] = "target@email.com"
s = smtplib.SMTP_SSL('smtp.gmail.com')
s.login('youraccount@gmail.com', 'yourpassword')
s.sendmail(msg['From'], [msg['To']], msg.as_string())
s.quit()
