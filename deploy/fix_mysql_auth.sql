ALTER USER 'cron'@'10.10.0.11' IDENTIFIED WITH mysql_native_password BY 'Vic1d!al2026Secure';
ALTER USER 'cron'@'10.10.0.12' IDENTIFIED WITH mysql_native_password BY 'Vic1d!al2026Secure';
ALTER USER 'cron'@'localhost' IDENTIFIED WITH mysql_native_password BY 'Vic1d!al2026Secure';
ALTER USER 'cron'@'%' IDENTIFIED WITH mysql_native_password BY 'Vic1d!al2026Secure';
FLUSH PRIVILEGES;
SELECT user,host,plugin FROM mysql.user WHERE user='cron';
