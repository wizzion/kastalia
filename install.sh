#Install PostgreSQL for the database core
apt install postgresql postgresql-contrib

#Additional tools:
apt install nginx
apt install memcached
apt install opus-tools
apt install cpanminus
apt install libdbd-pg-perl

#install CPAN Perl Packages (requirements defined in cpanfile):
cpanm --installdeps .

#Installation of Kastalia KMS as a service (do as root)
useradd -m kastalia
usermod -a -G www-data kastalia
mkdir /var/www/kastalia-kms
git clone https://scm.medienhaus.udk-berlin.de/wizzion/kms /var/www/kastalia-kms
cd /var/www/kastalia-kms
chown kastalia -R *
chown kastalia .
mv config_template.yml config.yml

#YOU HAVE TO EDIT config.yml now if ever You have some special needs

#create database, do as postgres user 
su postgres
createuser kastalia
createdb kastalia_db -O kastalia
cd /var/www/kastalia-kms/sql
psql kastalia_db <kastalia
exit

mv kastalia.service /etc/systemd/system/
mv kastalia.nginx /etc/nginx/sites-available

#if necessary UPDATE kastalia.nginx accordingly
ln -s /etc/nginx/sites-available/kastalia.nginx /etc/nginx/sites-enabled/kastalia.nginx

certbot -d YOURDOMAIN

systemctl enable kastalia
service kastalia start
service nginx restart

#most probably something is still missing so if the kastalia web does not appear at https://YOURDOMAIN check logs/ or run
perl bin/app.psgi
#to find out why the program croaks ;)
