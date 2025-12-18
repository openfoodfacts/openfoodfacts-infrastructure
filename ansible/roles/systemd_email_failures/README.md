# Systemd email failures

This role install a very simple service named email-failures.

It is called in the OnFailure directive of important services,
to create a notification if a service fail.